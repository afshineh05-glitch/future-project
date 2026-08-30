import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:future_project/models/my_why_entry.dart';
import 'package:future_project/services/my_why_encryption_service.dart';
import 'package:future_project/services/my_why_key_store.dart';
import 'package:future_project/services/my_why_service.dart';
import 'package:future_project/theme/app_theme.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:video_player/video_player.dart';

class MyWhySection extends StatefulWidget {
  final String? legacyPlaintext;

  const MyWhySection({super.key, this.legacyPlaintext});

  @override
  State<MyWhySection> createState() => _MyWhySectionState();
}

class _MyWhySectionState extends State<MyWhySection> {
  final MyWhyService _service = MyWhyService();
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final ImagePicker _picker = ImagePicker();
  MyWhyEntry? _entry;
  String? _text;
  String? _error;
  String? _recordingPath;
  DateTime? _recordingStartedAt;
  Timer? _recordingTimer;
  Duration _recordingDuration = Duration.zero;
  bool _loading = true;
  bool _busy = false;
  bool _recording = false;

  @override
  void initState() {
    super.initState();
    _load();
    _audioPlayer.onPlayerComplete.listen((_) => _service.clearPlaybackFiles());
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    unawaited(_disposePrivateResources());
    super.dispose();
  }

  Future<void> _disposePrivateResources() async {
    final capturePath = _recordingPath;
    try {
      if (_recording) await _recorder.stop();
    } catch (_) {
      // Best-effort shutdown without logging private capture details.
    }
    await _recorder.dispose();
    await _audioPlayer.dispose();
    if (capturePath != null) {
      try {
        final file = File(capturePath);
        if (await file.exists()) await file.delete();
      } catch (_) {
        // Best-effort cleanup without logging private paths.
      }
    }
    await _service.clearPlaybackFiles();
  }

  Future<void> _load() async {
    try {
      final state = await _service.load(
        legacyPlaintext: widget.legacyPlaintext,
      );
      if (!mounted) return;
      setState(() {
        _entry = state.entry;
        _text = state.text;
        _error = null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _userMessage(error);
        _loading = false;
      });
    }
  }

  Future<void> _editText() async {
    final controller = TextEditingController(text: _text);
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_text == null ? 'Write My Why' : 'Edit My Why'),
        content: SizedBox(
          width: 520,
          child: TextField(
            controller: controller,
            autofocus: true,
            minLines: 6,
            maxLines: 12,
            maxLength: MyWhyService.maxTextCharacters,
            decoration: const InputDecoration(
              hintText: 'What makes this future worth choosing?',
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null) return;
    await _run(() async {
      _entry = await _service.saveText(value);
      _text = value.trim().isEmpty ? null : value.trim();
    });
  }

  Future<void> _deleteText() async {
    await _run(() async {
      _entry = await _service.saveText('');
      _text = null;
    });
  }

  Future<void> _toggleRecording() async {
    if (_recording) {
      await _stopAndSaveRecording();
      return;
    }
    if (!await _recorder.hasPermission()) {
      _message('Microphone permission is required to record My Why.');
      return;
    }
    final directory = await getTemporaryDirectory();
    final path =
        '${directory.path}${Platform.pathSeparator}my_why_capture_${DateTime.now().microsecondsSinceEpoch}.m4a';
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 128000),
      path: path,
    );
    _recordingPath = path;
    _recordingStartedAt = DateTime.now();
    _recordingDuration = Duration.zero;
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final started = _recordingStartedAt;
      if (!mounted || started == null) return;
      final elapsed = DateTime.now().difference(started);
      setState(() => _recordingDuration = elapsed);
      if (elapsed >= MyWhyService.maxVoiceDuration) {
        _stopAndSaveRecording();
      }
    });
    if (mounted) setState(() => _recording = true);
  }

  Future<void> _stopAndSaveRecording() async {
    _recordingTimer?.cancel();
    final started = _recordingStartedAt;
    final stoppedPath = await _recorder.stop();
    final path = stoppedPath ?? _recordingPath;
    final duration = started == null
        ? _recordingDuration
        : DateTime.now().difference(started);
    if (mounted) setState(() => _recording = false);
    if (path == null) return;
    final file = File(path);
    try {
      if (await file.length() > MyWhyService.maxVoiceBytes) {
        throw const MyWhyValidationException(
          'Voice recordings must be 20 MB or smaller.',
        );
      }
      final bytes = await file.readAsBytes();
      await _run(() async {
        _entry = await _service.saveMedia(
          kind: MyWhyMediaKind.voice,
          clearBytes: bytes,
          duration: duration,
          playbackExtension: 'm4a',
          playbackMimeType: 'audio/mp4',
        );
      });
    } finally {
      if (await file.exists()) await file.delete();
      _recordingPath = null;
      _recordingStartedAt = null;
    }
  }

  Future<void> _recordVideo() async {
    final picked = await _picker.pickVideo(
      source: ImageSource.camera,
      maxDuration: MyWhyService.maxVideoDuration,
    );
    if (picked == null) return;
    final file = File(picked.path);
    VideoPlayerController? controller;
    try {
      controller = VideoPlayerController.file(file);
      await controller.initialize();
      if (await file.length() > MyWhyService.maxVideoBytes) {
        throw const MyWhyValidationException(
          'Videos must be 100 MB or smaller.',
        );
      }
      final bytes = await file.readAsBytes();
      final extension = picked.name.contains('.')
          ? picked.name.split('.').last
          : 'mp4';
      await _run(() async {
        _entry = await _service.saveMedia(
          kind: MyWhyMediaKind.video,
          clearBytes: bytes,
          duration: controller!.value.duration,
          playbackExtension: extension,
          playbackMimeType: 'video/mp4',
        );
      });
    } finally {
      await controller?.dispose();
      if (await file.exists()) await file.delete();
    }
  }

  Future<void> _playVoice() async {
    final entry = _entry;
    if (entry == null) return;
    await _run(() async {
      await _audioPlayer.stop();
      await _service.clearPlaybackFiles();
      final path = await _service.createPlaybackFile(
        entry,
        MyWhyMediaKind.voice,
      );
      await _audioPlayer.play(DeviceFileSource(path));
    });
  }

  Future<void> _playVideo() async {
    final entry = _entry;
    if (entry == null) return;
    await _run(() async {
      await _service.clearPlaybackFiles();
      final path = await _service.createPlaybackFile(
        entry,
        MyWhyMediaKind.video,
      );
      final controller = VideoPlayerController.file(File(path));
      try {
        await controller.initialize();
        if (!mounted) return;
        await controller.play();
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('My Why Video'),
            content: AspectRatio(
              aspectRatio: controller.value.aspectRatio,
              child: VideoPlayer(controller),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      } finally {
        await controller.dispose();
        await _service.clearPlaybackFiles();
      }
    });
  }

  Future<void> _deleteMedia(MyWhyMediaKind kind) async {
    await _run(() async => _entry = await _service.deleteMedia(kind));
  }

  Future<void> _deleteEntire() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete My Why?'),
        content: const Text(
          'This permanently deletes your encrypted text, voice, and video.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _run(() async {
      await _service.deleteEntire();
      _entry = null;
      _text = null;
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (error) {
      if (mounted) {
        final message = _userMessage(error);
        setState(() => _error = message);
        _message(message);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      if (!mounted) return;
      final message = _userMessage(error);
      setState(() => _error = message);
      _message(message);
    }
  }

  void _message(String value) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  String _userMessage(Object error) {
    if (error is MyWhyValidationException ||
        error is MyWhyPartialFailureException ||
        error is MyWhyAccessException ||
        error is MyWhyKeyUnavailableException ||
        error is MyWhyDecryptionException) {
      return error.toString();
    }
    return 'Could not update My Why. Your existing content was kept.';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final hasAny =
        _entry?.hasText == true ||
        _entry?.hasVoice == true ||
        _entry?.hasVideo == true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'MY WHY',
          style: TextStyle(
            fontSize: 12,
            letterSpacing: 1.4,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'The reason I chose this future.',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 15),
        ),
        const SizedBox(height: 8),
        const Row(
          children: [
            Icon(Icons.lock_outline_rounded, size: 15),
            SizedBox(width: 6),
            Text('Private to you.'),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Your My Why is encrypted before it is stored.',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
        ),
        if (_text != null) ...[
          const SizedBox(height: 16),
          DecoratedBox(
            decoration: const BoxDecoration(
              border: Border(
                left: BorderSide(color: AppTheme.primaryGreen, width: 3),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.only(left: 16, top: 4, bottom: 4),
              child: Text(
                _text!,
                style: const TextStyle(fontSize: 17, height: 1.45),
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _actionCard(
              icon: Icons.edit_note_rounded,
              label: _text == null ? 'Write' : 'Edit',
              onPressed: _editText,
            ),
            _actionCard(
              icon: _recording ? Icons.stop_circle_outlined : Icons.mic_none,
              label: _recording
                  ? 'Stop ${_recordingDuration.inMinutes}:${(_recordingDuration.inSeconds % 60).toString().padLeft(2, '0')}'
                  : _entry?.hasVoice == true
                  ? 'Replace Voice'
                  : 'Voice',
              onPressed: () => _guard(_toggleRecording),
            ),
            _actionCard(
              icon: Icons.videocam_outlined,
              label: _entry?.hasVideo == true ? 'Replace Video' : 'Video',
              onPressed: () => _guard(_recordVideo),
            ),
          ],
        ),
        if (_entry?.hasVoice == true || _entry?.hasVideo == true) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (_entry?.hasVoice == true) ...[
                TextButton.icon(
                  onPressed: _playVoice,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Play Voice'),
                ),
                TextButton(
                  onPressed: () => _deleteMedia(MyWhyMediaKind.voice),
                  child: const Text('Delete Voice'),
                ),
              ],
              if (_entry?.hasVideo == true) ...[
                TextButton.icon(
                  onPressed: _playVideo,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Play Video'),
                ),
                TextButton(
                  onPressed: () => _deleteMedia(MyWhyMediaKind.video),
                  child: const Text('Delete Video'),
                ),
              ],
            ],
          ),
        ],
        if (_text != null) ...[
          const SizedBox(height: 4),
          TextButton(onPressed: _deleteText, child: const Text('Delete Text')),
        ],
        if (hasAny)
          TextButton(
            onPressed: _deleteEntire,
            child: const Text('Delete My Why'),
          ),
        if (_busy) const LinearProgressIndicator(),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(
            _error!,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
        ],
        const SizedBox(height: 8),
        const Text(
          'V1 encryption is device-bound unless secure key recovery is implemented. Reinstalling the app or using another device may make existing My Why content unavailable.',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
        ),
      ],
    );
  }

  Widget _actionCard({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) => OutlinedButton.icon(
    onPressed: _busy ? null : onPressed,
    icon: Icon(icon),
    label: Text(label),
  );
}
