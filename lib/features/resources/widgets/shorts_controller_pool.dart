import 'package:flutter/foundation.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../models/clinical_video.dart';

typedef ShortsControllerFactory = YoutubePlayerController Function(String videoId);

/// One YouTube player for the whole Shorts feed.
///
/// Each embedded player is a full iframe/WebView that downloads YouTube's
/// player code, so creating one per clip made every swipe slow and kept
/// several heavy views alive. Instead one player stays mounted and each clip
/// is loaded into it with `loadVideoById` when its page becomes current.
class ShortsPlayback {
  final List<ClinicalVideo> shorts;
  final YoutubePlayerController controller;
  int _loadedIndex;

  ShortsPlayback({
    required this.shorts,
    required int initialIndex,
    ShortsControllerFactory? controllerFactory,
  })  : _loadedIndex = initialIndex,
        controller = (controllerFactory ?? _defaultController)(
          shorts.isEmpty ? '' : shorts[initialIndex % shorts.length].youtubeId,
        );

  static YoutubePlayerController _defaultController(String videoId) => YoutubePlayerController.fromVideoId(
        videoId: videoId,
        autoPlay: true,
        params: const YoutubePlayerParams(
          showControls: false,
          showFullscreenButton: false,
          showVideoAnnotations: false,
          mute: true,
          privacyEnhancedMode: true,
          strictRelatedVideos: true,
          origin: 'https://www.youtube-nocookie.com',
        ),
      );

  int get loadedIndex => _loadedIndex;

  ClinicalVideo videoAt(int index) => shorts[index % shorts.length];

  /// Loads the clip for page [index] unless it is already loaded.
  void show(int index) {
    if (shorts.isEmpty || index == _loadedIndex) return;
    _loadedIndex = index;
    _run(() => controller.loadVideoById(videoId: videoAt(index).youtubeId));
  }

  void play() => _run(controller.playVideo);
  void pause() => _run(controller.pauseVideo);
  void setMuted(bool muted) => _run(muted ? controller.mute : controller.unMute);

  /// Shorts loop: start the clip again when it ends.
  void replay() => _run(() async {
        await controller.seekTo(seconds: 0, allowSeekAhead: true);
        await controller.playVideo();
      });

  void dispose() => _run(controller.close);

  static void _run(Future<void> Function() call) {
    try {
      call().catchError((Object e) => debugPrint('Shorts player: $e'));
    } catch (e) {
      debugPrint('Shorts player: $e');
    }
  }
}
