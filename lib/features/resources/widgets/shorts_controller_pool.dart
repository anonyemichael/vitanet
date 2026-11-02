import 'package:flutter/foundation.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../models/clinical_video.dart';

typedef ShortsControllerFactory = YoutubePlayerController Function(String videoId, bool autoPlay);

/// High-performance sliding-window preload pool that maintains a maximum of 3
/// active controllers in memory at any time:
/// - currentIndex: actively playing
/// - currentIndex + 1: pre-initialized and paused at 0:00 for instant swipe-down
/// - currentIndex - 1: paused in memory for instant back-swipe
/// - All controllers with (index - currentIndex).abs() > 1 are strictly disposed (controller.close())
class ShortsControllerPool {
  final List<ClinicalVideo> shorts;
  final Map<int, YoutubePlayerController> _pool = {};
  final ShortsControllerFactory? _controllerFactory;
  int _currentIndex = 0;

  ShortsControllerPool({
    required this.shorts,
    required int initialIndex,
    ShortsControllerFactory? controllerFactory,
  }) : _controllerFactory = controllerFactory {
    _currentIndex = initialIndex;
    _updateWindow(initialIndex);
  }

  int get currentIndex => _currentIndex;

  YoutubePlayerController? getController(int index) => _pool[index];

  void onPageChanged(int newIndex) {
    _currentIndex = newIndex;
    _updateWindow(newIndex);
  }

  void _updateWindow(int current) {
    final activeRange = {current - 1, current, current + 1}
        .where((idx) => idx >= 0 && idx < shorts.length)
        .toSet();

    // 1. Strictly dispose and close any controller where (index - current).abs() > 1
    final outOfWindow = _pool.keys.where((idx) => (idx - current).abs() > 1).toList();
    for (final idx in outOfWindow) {
      final ctrl = _pool.remove(idx);
      try {
        ctrl?.pauseVideo();
        ctrl?.close();
      } catch (e) {
        debugPrint('ShortsControllerPool dispose error at $idx: $e');
      }
    }

    // 2. Pre-initialize missing controllers within window [current - 1, current, current + 1]
    for (final idx in activeRange) {
      if (!_pool.containsKey(idx)) {
        final video = shorts[idx];
        final isCurrent = idx == current;
        if (_controllerFactory != null) {
          _pool[idx] = _controllerFactory(video.youtubeId, isCurrent);
        } else {
          _pool[idx] = YoutubePlayerController.fromVideoId(
            videoId: video.youtubeId,
            autoPlay: isCurrent,
            params: const YoutubePlayerParams(
              showControls: false,
              showFullscreenButton: false,
              showVideoAnnotations: false,
              mute: false,
              loop: true,
              strictRelatedVideos: true,
              origin: 'https://www.youtube.com',
            ),
          );
        }
      }
    }

    // 3. Play current active video, pause others at 0:00 for instant zero-latency start
    for (final entry in _pool.entries) {
      final ctrl = entry.value;
      if (entry.key == current) {
        try {
          ctrl.playVideo();
        } catch (_) {}
      } else {
        try {
          ctrl.pauseVideo();
          ctrl.seekTo(seconds: 0.0);
        } catch (_) {}
      }
    }
  }

  void dispose() {
    for (final ctrl in _pool.values) {
      try {
        ctrl.pauseVideo();
        ctrl.close();
      } catch (e) {
        debugPrint('ShortsControllerPool pool dispose error: $e');
      }
    }
    _pool.clear();
  }
}
