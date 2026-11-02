import 'package:flutter/foundation.dart';

import '../models/clinical_video.dart';

/// Session-wide engagement state for the VitaNet Learn video section:
/// likes, subscriptions, saved / watch-later lists, the play-next queue,
/// hidden videos and real watch progress reported by the player.
class VideoEngagementStore extends ChangeNotifier {
  VideoEngagementStore._();
  static final VideoEngagementStore instance = VideoEngagementStore._();

  final Set<String> _liked = {};
  final Set<String> _disliked = {};
  final Set<String> _subscribed = {};
  final Map<String, ClinicalVideo> _saved = {};
  final Map<String, ClinicalVideo> _watchLater = {};
  final Map<String, ClinicalVideo> _downloads = {};
  final List<ClinicalVideo> _queue = [];
  final Set<String> _hidden = {};
  final Set<String> _reported = {};
  final Map<String, double> _progress = {};
  bool notificationsSeen = false;

  bool isLiked(String id) => _liked.contains(id);
  bool isDisliked(String id) => _disliked.contains(id);
  bool isSubscribed(String channel) => _subscribed.contains(channel);
  bool isSaved(String id) => _saved.containsKey(id);
  bool isInWatchLater(String id) => _watchLater.containsKey(id);
  bool isDownloaded(String id) => _downloads.containsKey(id);
  bool isHidden(String id) => _hidden.contains(id);
  bool isReported(String id) => _reported.contains(id);
  double progressOf(String id) => _progress[id] ?? 0;

  List<ClinicalVideo> get saved => _saved.values.toList().reversed.toList();
  List<ClinicalVideo> get watchLater => _watchLater.values.toList().reversed.toList();
  List<ClinicalVideo> get downloads => _downloads.values.toList().reversed.toList();
  List<ClinicalVideo> get queue => List.unmodifiable(_queue);
  Set<String> get subscribedChannels => Set.unmodifiable(_subscribed);

  void toggleLike(String id) {
    if (!_liked.remove(id)) {
      _liked.add(id);
      _disliked.remove(id);
    }
    notifyListeners();
  }

  void toggleDislike(String id) {
    if (!_disliked.remove(id)) {
      _disliked.add(id);
      _liked.remove(id);
    }
    notifyListeners();
  }

  void toggleSubscribe(String channel) {
    if (!_subscribed.remove(channel)) _subscribed.add(channel);
    notifyListeners();
  }

  /// Returns true when the video is now saved.
  bool toggleSaved(ClinicalVideo v) {
    final nowSaved = _saved.remove(v.youtubeId) == null;
    if (nowSaved) _saved[v.youtubeId] = v;
    notifyListeners();
    return nowSaved;
  }

  bool toggleWatchLater(ClinicalVideo v) {
    final added = _watchLater.remove(v.youtubeId) == null;
    if (added) _watchLater[v.youtubeId] = v;
    notifyListeners();
    return added;
  }

  bool toggleDownload(ClinicalVideo v) {
    final added = _downloads.remove(v.youtubeId) == null;
    if (added) _downloads[v.youtubeId] = v;
    notifyListeners();
    return added;
  }

  void enqueue(ClinicalVideo v) {
    _queue.removeWhere((q) => q.youtubeId == v.youtubeId);
    _queue.insert(0, v);
    notifyListeners();
  }

  ClinicalVideo? takeNextQueued({String? excludingId}) {
    final idx = _queue.indexWhere((q) => q.youtubeId != excludingId);
    if (idx < 0) return null;
    final v = _queue.removeAt(idx);
    notifyListeners();
    return v;
  }

  void hide(String id) {
    _hidden.add(id);
    notifyListeners();
  }

  void unhide(String id) {
    _hidden.remove(id);
    notifyListeners();
  }

  void report(String id) {
    _reported.add(id);
    _hidden.add(id);
    notifyListeners();
  }

  void setProgress(String id, double fraction) {
    final clamped = fraction.clamp(0.0, 1.0);
    if ((progressOf(id) - clamped).abs() < 0.01) return;
    _progress[id] = clamped;
    notifyListeners();
  }

  void markNotificationsSeen() {
    if (notificationsSeen) return;
    notificationsSeen = true;
    notifyListeners();
  }
}
