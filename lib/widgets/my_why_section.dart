import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:future_project/models/my_why_entry.dart';
import 'package:future_project/services/my_why_encryption_service.dart';
import 'package:future_project/services/my_why_key_store.dart';
import 'package:future_project/services/my_why_recovery_key_service.dart';
import 'package:future_project/services/my_why_service.dart';
import 'package:future_project/theme/app_theme.dart';
import 'package:image_picker/image_picker.dart';
import 'package:media_kit/media_kit.dart' as media_kit;
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
  final AudioPlayer? _audioPlayer = Platform.isWindows ? null : AudioPlayer();
  final ImagePicker _picker = ImagePicker();
  media_kit.Player? _windowsVoicePlayer;
  File? _windowsVoicePlaybackFile;
  MyWhyEntry? _entry;
  List<MyWhyVoiceRecording> _voiceRecordings = const [];
  String? _text;
  String? _error;
  String? _recordingPath;
  DateTime? _recordingStartedAt;
  Timer? _recordingTimer;
  StreamSubscription<Amplitude>? _recordingAmplitudeSubscription;
  StreamSubscription<String>? _audioLogSubscription;
  StreamSubscription<Duration>? _audioPositionSubscription;
  StreamSubscription<Duration>? _audioDurationSubscription;
  StreamSubscription<PlayerState>? _audioStateSubscription;
  StreamSubscription<bool>? _windowsVoiceCompleteSubscription;
  StreamSubscription<String>? _windowsVoiceErrorSubscription;
  StreamSubscription<bool>? _windowsVoicePlayingSubscription;
  StreamSubscription<Duration>? _windowsVoiceDurationSubscription;
  StreamSubscription<Duration>? _windowsVoicePositionSubscription;
  StreamSubscription<double>? _windowsVoiceVolumeSubscription;
  StreamSubscription<media_kit.AudioDevice>?
  _windowsVoiceAudioDeviceSubscription;
  StreamSubscription<List<media_kit.AudioDevice>>?
  _windowsVoiceAudioDevicesSubscription;
  StreamSubscription<media_kit.PlayerLog>? _windowsVoiceLogSubscription;
  Duration _recordingDuration = Duration.zero;
  bool _loading = true;
  bool _busy = false;
  bool _recording = false;
  int _recordingAmplitudeSamples = 0;
  double _recordingPeakDb = -160.0;
  String? _activeVoiceId;
  Duration _voicePosition = Duration.zero;
  Duration _voiceDuration = Duration.zero;
  bool _voicePlaying = false;
  bool _voiceSeeking = false;
  double _voiceVolume = 1.0;
  bool _hasUnrecoverableLegacy = false;

  @override
  void initState() {
    super.initState();
    _load();
    _audioPlayer?.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _voicePlaying = false;
          _activeVoiceId = null;
          _voicePosition = Duration.zero;
          _voiceDuration = Duration.zero;
        });
      }
      _service.clearPlaybackFiles();
    });
    _audioPositionSubscription = _audioPlayer?.onPositionChanged.listen((
      position,
    ) {
      if (mounted && !_voiceSeeking) {
        setState(() => _voicePosition = position);
      }
    });
    _audioDurationSubscription = _audioPlayer?.onDurationChanged.listen((
      duration,
    ) {
      if (mounted) setState(() => _voiceDuration = duration);
    });
    _audioStateSubscription = _audioPlayer?.onPlayerStateChanged.listen((
      state,
    ) {
      if (mounted) setState(() => _voicePlaying = state == PlayerState.playing);
    });
    _audioLogSubscription = _audioPlayer?.onLog.listen(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {
        _handleVoicePlaybackError(error);
      },
    );
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    unawaited(_recordingAmplitudeSubscription?.cancel());
    unawaited(_audioLogSubscription?.cancel());
    unawaited(_audioPositionSubscription?.cancel());
    unawaited(_audioDurationSubscription?.cancel());
    unawaited(_audioStateSubscription?.cancel());
    unawaited(_windowsVoiceCompleteSubscription?.cancel());
    unawaited(_windowsVoiceErrorSubscription?.cancel());
    unawaited(_windowsVoicePlayingSubscription?.cancel());
    unawaited(_windowsVoiceDurationSubscription?.cancel());
    unawaited(_windowsVoicePositionSubscription?.cancel());
    unawaited(_windowsVoiceVolumeSubscription?.cancel());
    unawaited(_windowsVoiceAudioDeviceSubscription?.cancel());
    unawaited(_windowsVoiceAudioDevicesSubscription?.cancel());
    unawaited(_windowsVoiceLogSubscription?.cancel());
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
    await _audioPlayer?.dispose();
    await _windowsVoicePlayer?.dispose();
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
        _voiceRecordings = state.voiceRecordings;
        _hasUnrecoverableLegacy = state.hasUnrecoverableLegacy;
        _error = state.hasUnrecoverableLegacy
            ? const MyWhyLegacyUnrecoverableException().toString()
            : null;
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
      _entry = await _service.saveText(
        value,
        startFreshIfLegacyUnrecoverable: _hasUnrecoverableLegacy,
      );
      _text = value.trim().isEmpty ? null : value.trim();
      _hasUnrecoverableLegacy = false;
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
    final hasPermission = await _recorder.hasPermission();
    if (Platform.isWindows) {
      debugPrint(
        'My Why recording diagnostic: microphone permission granted=$hasPermission',
      );
    }
    if (!hasPermission) {
      _message('Microphone permission is required to record My Why.');
      return;
    }
    InputDevice? windowsInputDevice;
    if (Platform.isWindows) {
      try {
        final devices = await _recorder.listInputDevices();
        final labels = devices.map((device) => device.label).toList();
        for (final device in devices) {
          final label = device.label.toLowerCase();
          if (label.contains('microphone') ||
              label.startsWith('mic') ||
              label.contains(' mic')) {
            windowsInputDevice = device;
            break;
          }
        }
        for (final device in devices) {
          if (windowsInputDevice != null) break;
          if (device.type == InputDeviceType.builtIn ||
              device.type == InputDeviceType.wiredHeadset ||
              device.type == InputDeviceType.usb ||
              device.type == InputDeviceType.bluetoothSco ||
              device.type == InputDeviceType.bluetoothLe) {
            windowsInputDevice = device;
          }
        }
        debugPrint(
          'My Why recording diagnostic: selected input=${windowsInputDevice?.label ?? 'Windows default communications input'} type=${windowsInputDevice?.type.name ?? 'default'}; available input labels=$labels',
        );
      } catch (error) {
        debugPrint(
          'My Why recording diagnostic: input device=Windows default communications input; device enumeration failed=${error.runtimeType}',
        );
      }
    }
    final directory = await getTemporaryDirectory();
    final extension = Platform.isWindows ? 'aac' : 'm4a';
    final path =
        '${directory.path}${Platform.pathSeparator}my_why_capture_${DateTime.now().microsecondsSinceEpoch}.$extension';
    final recordConfig = Platform.isWindows && windowsInputDevice != null
        ? RecordConfig(
            encoder: AudioEncoder.aacLc,
            bitRate: 128000,
            device: windowsInputDevice,
          )
        : const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 128000);
    await _recorder.start(recordConfig, path: path);
    if (Platform.isWindows) {
      final initialized = await _recorder.isRecording();
      debugPrint(
        'My Why recording diagnostic: input initialization succeeded=$initialized',
      );
      _recordingAmplitudeSamples = 0;
      _recordingPeakDb = -160.0;
      await _recordingAmplitudeSubscription?.cancel();
      _recordingAmplitudeSubscription = _recorder
          .onAmplitudeChanged(const Duration(milliseconds: 500))
          .listen(
            (amplitude) {
              final current = amplitude.current.isFinite
                  ? amplitude.current
                  : -160.0;
              final max = amplitude.max.isFinite ? amplitude.max : -160.0;
              _recordingAmplitudeSamples++;
              if (max > _recordingPeakDb) _recordingPeakDb = max;
              debugPrint(
                'My Why recording diagnostic: amplitude currentDb=${current.toStringAsFixed(1)} maxDb=${max.toStringAsFixed(1)}',
              );
            },
            onError: (Object error, StackTrace stackTrace) {
              debugPrint(
                'My Why recording diagnostic: amplitude monitoring failed=${error.runtimeType}',
              );
            },
          );
    }
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
    await _recordingAmplitudeSubscription?.cancel();
    _recordingAmplitudeSubscription = null;
    final path = stoppedPath ?? _recordingPath;
    final duration = started == null
        ? _recordingDuration
        : DateTime.now().difference(started);
    if (mounted) setState(() => _recording = false);
    if (path == null) return;
    final file = File(path);
    try {
      final fileSize = await file.length();
      if (Platform.isWindows) {
        final signalResult = _recordingAmplitudeSamples == 0
            ? 'unavailable'
            : _recordingPeakDb > -150.0
            ? 'non-silent'
            : 'silent';
        debugPrint(
          'My Why recording diagnostic: completed durationMs=${duration.inMilliseconds} fileBytes=$fileSize amplitudeSamples=$_recordingAmplitudeSamples peakDb=${_recordingPeakDb.toStringAsFixed(1)} microphoneSignal=$signalResult',
        );
      }
      if (fileSize > MyWhyService.maxVoiceBytes) {
        throw const MyWhyValidationException(
          'Voice recordings must be 20 MB or smaller.',
        );
      }
      final bytes = await file.readAsBytes();
      await _run(() async {
        final recording = await _service.addVoiceRecording(
          clearBytes: bytes,
          duration: duration,
          playbackExtension: Platform.isWindows ? 'aac' : 'm4a',
          playbackMimeType: Platform.isWindows ? 'audio/aac' : 'audio/mp4',
          startFreshIfLegacyUnrecoverable: _hasUnrecoverableLegacy,
        );
        _voiceRecordings = [recording, ..._voiceRecordings];
        _hasUnrecoverableLegacy = false;
      });
    } finally {
      if (await file.exists()) await file.delete();
      _recordingPath = null;
      _recordingStartedAt = null;
    }
  }

  Future<void> _recordVideo() async {
    if (!_picker.supportsImageSource(ImageSource.camera)) {
      if (mounted) {
        setState(() => _error = null);
        _message(
          'Video recording is not supported by the current Windows camera picker.',
        );
      }
      return;
    }
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
        _entry = await _service.saveVideo(
          clearBytes: bytes,
          duration: controller!.value.duration,
          playbackExtension: extension,
          playbackMimeType: 'video/mp4',
          startFreshIfLegacyUnrecoverable: _hasUnrecoverableLegacy,
        );
        _hasUnrecoverableLegacy = false;
      });
    } finally {
      await controller?.dispose();
      if (await file.exists()) await file.delete();
    }
  }

  Future<void> _playVoice(MyWhyVoiceRecording recording) async {
    if (Platform.isWindows) {
      debugPrint('My Why media_kit diagnostic: Play Voice callback reached');
    }
    await _run(() async {
      if (_activeVoiceId == recording.id) {
        if (_voicePlaying) {
          if (Platform.isWindows) {
            await _windowsVoicePlayer?.pause();
          } else {
            await _audioPlayer?.pause();
          }
        } else {
          if (_voiceDuration > Duration.zero &&
              _voicePosition >= _voiceDuration) {
            await _seekVoice(recording, 0);
          }
          if (Platform.isWindows) {
            await _windowsVoicePlayer?.play();
          } else {
            await _audioPlayer?.resume();
          }
        }
        return;
      }
      _activeVoiceId = recording.id;
      _voicePosition = Duration.zero;
      _voiceDuration = recording.duration;
      if (Platform.isWindows) {
        await _playVoiceOnWindows(recording);
        return;
      }
      final player = _audioPlayer!;
      await player.stop();
      await _service.clearPlaybackFiles();
      final path = await _service.createVoicePlaybackFile(recording);
      final source = DeviceFileSource(
        path,
        mimeType:
            recording.metadata['playback_mime_type']?.toString() ?? 'audio/mp4',
      );
      try {
        await player.play(source);
      } catch (error) {
        debugPrint('My Why voice playback error: $error');
        rethrow;
      }
    });
  }

  Future<void> _playVoiceOnWindows(MyWhyVoiceRecording recording) async {
    final player = _windowsVoicePlayer ??= _createWindowsVoicePlayer();
    debugPrint(
      'My Why media_kit diagnostic: Player exists=${_windowsVoicePlayer != null}',
    );
    await player.stop();
    await _service.clearPlaybackFiles();
    final path = await _service.createVoicePlaybackFile(recording);
    final file = File(path);
    _windowsVoicePlaybackFile = file;
    final exists = await file.exists();
    final bytes = exists ? await file.length() : null;
    debugPrint(
      'My Why media_kit diagnostic: before open fileExists=$exists bytes=$bytes',
    );
    try {
      debugPrint(
        'My Why media_kit diagnostic: calling await player.open(Media(fileUri), play: true)',
      );
      await player.open(media_kit.Media(Uri.file(path).toString()), play: true);
      final platform = player.platform as dynamic;
      final ao = await platform.getProperty('ao');
      final currentAo = await platform.getProperty('current-ao');
      final audioDevice = await platform.getProperty('audio-device');
      final audioOutParams = await platform.getProperty('audio-out-params');
      final muted = await platform.getProperty('mute');
      debugPrint(
        'My Why media_kit diagnostic: open completed playing=${player.state.playing} completed=${player.state.completed} durationMs=${player.state.duration.inMilliseconds} positionMs=${player.state.position.inMilliseconds} volume=${player.state.volume} muted=$muted ao=$ao currentAo=$currentAo audioDevice=$audioDevice selectedDevice=${player.state.audioDevice} audioOutParams=$audioOutParams availableDevices=${player.state.audioDevices} fileExists=${await file.exists()}',
      );
    } catch (error) {
      debugPrint(
        'My Why media_kit diagnostic: open threw=$error playing=${player.state.playing} completed=${player.state.completed} durationMs=${player.state.duration.inMilliseconds} positionMs=${player.state.position.inMilliseconds} volume=${player.state.volume} fileExists=${await file.exists()}',
      );
      rethrow;
    }
  }

  media_kit.Player _createWindowsVoicePlayer() {
    media_kit.MediaKit.ensureInitialized();
    final player = media_kit.Player(
      configuration: const media_kit.PlayerConfiguration(
        title: 'MuscleUp My Why',
        logLevel: media_kit.MPVLogLevel.info,
      ),
    );
    _windowsVoiceCompleteSubscription = player.stream.completed.listen((
      completed,
    ) async {
      final file = _windowsVoicePlaybackFile;
      final existsBeforeCleanup = file != null && await file.exists();
      debugPrint(
        'My Why media_kit diagnostic: completed=$completed fileExistsBeforeCleanup=$existsBeforeCleanup',
      );
      if (completed) {
        if (mounted) {
          setState(() {
            _voicePlaying = false;
            _activeVoiceId = null;
            _voicePosition = Duration.zero;
            _voiceDuration = Duration.zero;
          });
        }
        await _service.clearPlaybackFiles();
        debugPrint(
          'My Why media_kit diagnostic: completion cleanup finished fileExistsAfterCleanup=${file != null && await file.exists()}',
        );
      }
    });
    _windowsVoiceErrorSubscription = player.stream.error.listen((error) {
      debugPrint('My Why media_kit diagnostic: error stream=$error');
      _handleVoicePlaybackError(error);
    });
    _windowsVoicePlayingSubscription = player.stream.playing.listen((playing) {
      if (mounted) setState(() => _voicePlaying = playing);
      debugPrint('My Why media_kit diagnostic: playing=$playing');
    });
    _windowsVoiceDurationSubscription = player.stream.duration.listen((
      duration,
    ) {
      if (mounted) setState(() => _voiceDuration = duration);
      debugPrint(
        'My Why media_kit diagnostic: durationMs=${duration.inMilliseconds}',
      );
    });
    _windowsVoicePositionSubscription = player.stream.position.listen((
      position,
    ) {
      if (mounted && !_voiceSeeking) {
        setState(() => _voicePosition = position);
      }
      debugPrint(
        'My Why media_kit diagnostic: positionMs=${position.inMilliseconds}',
      );
    });
    _windowsVoiceVolumeSubscription = player.stream.volume.listen(
      (volume) => debugPrint('My Why media_kit diagnostic: volume=$volume'),
    );
    _windowsVoiceAudioDeviceSubscription = player.stream.audioDevice.listen(
      (device) => debugPrint(
        'My Why media_kit diagnostic: selected audio device=$device',
      ),
    );
    _windowsVoiceAudioDevicesSubscription = player.stream.audioDevices.listen(
      (devices) => debugPrint(
        'My Why media_kit diagnostic: available audio devices=$devices',
      ),
    );
    _windowsVoiceLogSubscription = player.stream.log.listen((log) {
      final prefix = log.prefix.toLowerCase();
      final text = log.text.toLowerCase();
      if (prefix.contains('ao') ||
          prefix.contains('audio') ||
          text.contains('audio') ||
          text.contains('wasapi')) {
        debugPrint(
          'My Why media_kit native: level=${log.level} prefix=${log.prefix} message=${log.text.trim()}',
        );
      }
    });
    debugPrint(
      'My Why media_kit diagnostic: Player created playing=${player.state.playing} completed=${player.state.completed} durationMs=${player.state.duration.inMilliseconds} positionMs=${player.state.position.inMilliseconds} volume=${player.state.volume}; errors are reported by player.stream.error',
    );
    return player;
  }

  void _handleVoicePlaybackError(Object error) {
    debugPrint('My Why voice playback error: $error');
    if (!mounted) return;
    const message = 'Voice playback failed. Please try again.';
    setState(() => _error = message);
    _message(message);
  }

  Future<void> _seekVoice(
    MyWhyVoiceRecording recording,
    double milliseconds,
  ) async {
    if (_activeVoiceId != recording.id) return;
    final position = Duration(milliseconds: milliseconds.round());
    if (Platform.isWindows) {
      await _windowsVoicePlayer?.seek(position);
    } else {
      await _audioPlayer?.seek(position);
    }
    if (mounted) {
      setState(() {
        _voicePosition = position;
        _voiceSeeking = false;
      });
    }
  }

  Future<void> _setVoiceVolume(double volume) async {
    final normalized = volume.clamp(0.0, 1.0);
    if (mounted) setState(() => _voiceVolume = normalized);
    if (_activeVoiceId == null) return;
    if (Platform.isWindows) {
      await _windowsVoicePlayer?.setVolume(normalized * 100);
    } else {
      await _audioPlayer?.setVolume(normalized);
    }
  }

  Future<void> _deleteVoice(MyWhyVoiceRecording recording) async {
    await _run(() async {
      if (_activeVoiceId == recording.id) {
        if (Platform.isWindows) {
          await _windowsVoicePlayer?.stop();
        } else {
          await _audioPlayer?.stop();
        }
        await _service.clearPlaybackFiles();
        _activeVoiceId = null;
        _voicePosition = Duration.zero;
        _voiceDuration = Duration.zero;
        _voicePlaying = false;
      }
      await _service.deleteVoiceRecording(recording);
      _voiceRecordings = _voiceRecordings
          .where((item) => item.id != recording.id)
          .toList();
      if (recording.isLegacyEntryVoice) {
        final state = await _service.load();
        _entry = state.entry;
      }
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

  Future<void> _deleteVideo() async {
    await _run(() async => _entry = await _service.deleteVideo());
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
      _voiceRecordings = const [];
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
      if (mounted) setState(() => _error = null);
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
      if (mounted) setState(() => _error = null);
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
        error is MyWhyRecoveryException ||
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
        _voiceRecordings.isNotEmpty ||
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
                  : 'Add Voice',
              onPressed: () => _guard(_toggleRecording),
            ),
            _actionCard(
              icon: Icons.videocam_outlined,
              label: _entry?.hasVideo == true ? 'Replace Video' : 'Video',
              onPressed: () => _guard(_recordVideo),
            ),
          ],
        ),
        if (_voiceRecordings.isNotEmpty) ...[
          const SizedBox(height: 16),
          ..._voiceRecordings.map(_voiceRecordingCard),
        ],
        if (_entry?.hasVideo == true) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (_entry?.hasVideo == true) ...[
                TextButton.icon(
                  onPressed: _playVideo,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Play Video'),
                ),
                TextButton(
                  onPressed: _deleteVideo,
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
          'New My Why content is encrypted with account recovery. Legacy V1 content can be migrated only from the original installation.',
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

  Widget _voiceRecordingCard(MyWhyVoiceRecording recording) {
    final isActive = _activeVoiceId == recording.id;
    final total = isActive && _voiceDuration > Duration.zero
        ? _voiceDuration
        : recording.duration;
    final position = isActive ? _voicePosition : Duration.zero;
    final maxMilliseconds = total.inMilliseconds > 0
        ? total.inMilliseconds.toDouble()
        : 1.0;
    final value = position.inMilliseconds
        .clamp(0, maxMilliseconds.toInt())
        .toDouble();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: AppTheme.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Voice • ${_formatRecordingDate(recording.createdAt)}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  IconButton(
                    tooltip: isActive && _voicePlaying ? 'Pause' : 'Play',
                    onPressed: _busy ? null : () => _playVoice(recording),
                    icon: Icon(
                      isActive && _voicePlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                    ),
                  ),
                  Expanded(
                    child: Slider(
                      value: value,
                      max: maxMilliseconds,
                      onChangeStart: isActive && total > Duration.zero
                          ? (_) => setState(() => _voiceSeeking = true)
                          : null,
                      onChanged: isActive && total > Duration.zero
                          ? (next) => setState(
                              () => _voicePosition = Duration(
                                milliseconds: next.round(),
                              ),
                            )
                          : null,
                      onChangeEnd: isActive && total > Duration.zero
                          ? (next) => _seekVoice(recording, next)
                          : null,
                    ),
                  ),
                  SizedBox(
                    width: 24,
                    height: 60,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 2,
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 5,
                              disabledThumbRadius: 4,
                            ),
                            overlayShape: const RoundSliderOverlayShape(
                              overlayRadius: 9,
                            ),
                          ),
                          child: RotatedBox(
                            quarterTurns: 3,
                            child: Slider(
                              value: _voiceVolume,
                              onChanged: isActive ? _setVoiceVolume : null,
                            ),
                          ),
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Icon(
                            _voiceVolume == 0
                                ? Icons.volume_off_rounded
                                : Icons.volume_up_rounded,
                            size: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(left: 48),
                child: Text(
                  '${_formatDuration(position)} / ${_formatDuration(total)}',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ),
              TextButton(
                onPressed: _busy ? null : () => _deleteVoice(recording),
                child: const Text('Delete'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatRecordingDate(DateTime value) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final local = value.toLocal();
    return '${months[local.month - 1]} ${local.day}, ${local.year}';
  }

  String _formatDuration(Duration value) {
    final minutes = value.inMinutes;
    final seconds = (value.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
