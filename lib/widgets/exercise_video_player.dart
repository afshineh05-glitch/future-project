import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'package:future_project/services/exercise_video_service.dart';
import 'package:future_project/theme/app_theme.dart';

class ExerciseVideoPlayer extends StatefulWidget {
  final String exerciseName;
  final String? existingVideoUrl;

  const ExerciseVideoPlayer({
    super.key,
    required this.exerciseName,
    this.existingVideoUrl,
  });

  @override
  State<ExerciseVideoPlayer> createState() =>
      _ExerciseVideoPlayerState();
}

class _ExerciseVideoPlayerState
    extends State<ExerciseVideoPlayer> {
  final ExerciseVideoService _videoService =
      ExerciseVideoService();

  VideoPlayerController? _controller;
  ExerciseVideoSource? _source;
  bool _loading = true;
  String? _playerError;

  @override
  void initState() {
    super.initState();
    _loadVideo();
  }

  @override
  void didUpdateWidget(
    covariant ExerciseVideoPlayer oldWidget,
  ) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.exerciseName != widget.exerciseName ||
        oldWidget.existingVideoUrl != widget.existingVideoUrl) {
      _disposeController();
      _loadVideo();
    }
  }

  Future<void> _loadVideo() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _playerError = null;
      });
    }

    final source = await _videoService.resolveVideo(
      exerciseName: widget.exerciseName,
      existingVideoUrl: widget.existingVideoUrl,
    );

    if (!mounted) return;

    _source = source;

    if (!source.isReady) {
      setState(() {
        _loading = false;
      });
      return;
    }

    try {
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(source.url!),
      );

      await controller.initialize();
      await controller.setLooping(true);

      if (!mounted) {
        await controller.dispose();
        return;
      }

      _controller = controller;

      setState(() {
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _loading = false;
        _playerError =
            'The exercise video could not be loaded.';
      });
    }
  }

  void _togglePlayback() {
    final controller = _controller;
    if (controller == null ||
        !controller.value.isInitialized) {
      return;
    }

    setState(() {
      if (controller.value.isPlaying) {
        controller.pause();
      } else {
        controller.play();
      }
    });
  }

  Future<void> _disposeController() async {
    final controller = _controller;
    _controller = null;

    if (controller != null) {
      await controller.dispose();
    }
  }

  @override
  void dispose() {
    _disposeController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return _shell(
        child: const SizedBox(
          height: 230,
          child: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    if (_playerError != null) {
      return _placeholder(
        icon: Icons.error_outline_rounded,
        title: 'Video unavailable',
        message: _playerError!,
      );
    }

    final source = _source;

    if (source == null || !source.isReady) {
      return _placeholder(
        icon: Icons.play_circle_outline_rounded,
        title: 'Exercise video coming soon',
        message:
            source?.message ??
            'The video system is ready. MoveKit will be connected when API access and licensing are available.',
      );
    }

    final controller = _controller;

    if (controller == null ||
        !controller.value.isInitialized) {
      return _placeholder(
        icon: Icons.play_circle_outline_rounded,
        title: 'Video unavailable',
        message:
            'A video URL exists, but the player could not initialize it.',
      );
    }

    final aspectRatio =
        controller.value.aspectRatio > 0
            ? controller.value.aspectRatio
            : 16 / 9;

    return _shell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: AspectRatio(
              aspectRatio: aspectRatio,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  VideoPlayer(controller),
                  Positioned.fill(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _togglePlayback,
                        child: Center(
                          child: AnimatedOpacity(
                            opacity:
                                controller.value.isPlaying
                                    ? 0
                                    : 1,
                            duration:
                                const Duration(
                                  milliseconds: 180,
                                ),
                            child: Container(
                              width: 62,
                              height: 62,
                              decoration: BoxDecoration(
                                color: Colors.black
                                    .withValues(alpha: .55),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 38,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              IconButton.filledTonal(
                onPressed: _togglePlayback,
                icon: Icon(
                  controller.value.isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: VideoProgressIndicator(
                  controller,
                  allowScrubbing: true,
                  padding:
                      const EdgeInsets.symmetric(
                        vertical: 12,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            source.provider == 'stored'
                ? 'Licensed exercise video'
                : 'MoveKit exercise video',
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return _shell(
      child: SizedBox(
        height: 250,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 56,
                  color: AppTheme.primaryGreen,
                ),
                const SizedBox(height: 14),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _shell({
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.border,
        ),
      ),
      child: child,
    );
  }
}
