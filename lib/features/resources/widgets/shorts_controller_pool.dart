import 'package:flutter/foundation.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../models/clinical_video.dart';

typedef ShortsControllerFactory = YoutubePlayerController Function(String videoId);

/// Two YouTube players for the whole Shorts feed: one on screen, one loading the next clip.
///
/// Each embedded player is a full iframe/WebView that downloads YouTube's player code, so creating one per clip
/// made every swipe slow. Two long-lived players are reused instead (`loadVideoById`). While clip N plays, the
/// hidden player loads clip N+1 muted and pauses it as soon as it starts, so its first seconds are already
/// buffered. Swiping down swaps the players: the next clip starts at once, and the freed player loads the one after.
class ShortsPlayback {
  /// The feed. It may grow while the screen is open (more shorts are appended as you scroll).
  final List<ClinicalVideo> shorts;
  final List<YoutubePlayerController> players;
  final List<int?> _holds; // page index loaded in each player
  int _active = 0;

  ShortsPlayback({
    required this.shorts,
    required int initialIndex,
    ShortsControllerFactory? controllerFactory,
  })  : players = [],
        _holds = [initialIndex, null] {
    final make = controllerFactory ?? _defaultController;
    players.add(make(shorts.isEmpty ? '' : videoAt(initialIndex).youtubeId));
    if (shorts.length > 1) {
      players.add(make(videoAt(initialIndex + 1).youtubeId)); // starts muted; paused by onPlayerState
      _holds[1] = initialIndex + 1;
    }
  }

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

  /// The player on screen.
  YoutubePlayerController get controller => players[_active];
  int get activePlayer => _active;
  int get loadedIndex => _holds[_active]!;

  ClinicalVideo videoAt(int index) => shorts[index % shorts.length];

  int get _idle => 1 - _active;

  /// Makes page [index] the playing clip: swaps to the preloaded player when it already holds that clip,
  /// otherwise loads it, then preloads the clip after it in the other player.
  void show(int index) {
    if (shorts.isEmpty || _holds[_active] == index) return;
    final old = _active;
    if (players.length > 1 && _holds[_idle] == index) {
      _active = _idle;
      _run(controller.playVideo);
    } else {
      _holds[_active] = index;
      _run(() => controller.loadVideoById(videoId: videoAt(index).youtubeId));
    }
    if (players.length > 1) {
      final idle = players[_idle];
      if (old != _active) {
        _run(idle.mute);
        _run(idle.pauseVideo);
      }
      _preload(index + 1);
    }
  }

  void _preload(int index) {
    if (players.length < 2 || _holds[_idle] == index) return;
    _holds[_idle] = index;
    final idle = players[_idle];
    _run(idle.mute);
    _run(() => idle.loadVideoById(videoId: videoAt(index).youtubeId)); // paused again in onPlayerState
  }

  /// Feed this every state change of player [player]. A hidden player that starts playing (it was loading the
  /// next clip) is paused at the start, keeping what it buffered.
  void onPlayerState(int player, PlayerState state) {
    if (player != _active && player < players.length && state == PlayerState.playing) {
      final p = players[player];
      _run(p.pauseVideo);
      _run(() => p.seekTo(seconds: 0, allowSeekAhead: true));
    }
  }

  void play() => _run(controller.playVideo);
  void pause() => _run(controller.pauseVideo);
  void setMuted(bool muted) => _run(muted ? controller.mute : controller.unMute);

  /// Shorts loop: start the clip again when it ends.
  void replay() => _run(() async {
        await controller.seekTo(seconds: 0, allowSeekAhead: true);
        await controller.playVideo();
      });

  void dispose() {
    for (final p in players) {
      _run(p.close);
    }
  }

  static void _run(Future<void> Function() call) {
    try {
      call().catchError((Object e) => debugPrint('Shorts player: $e'));
    } catch (e) {
      debugPrint('Shorts player: $e');
    }
  }
}
