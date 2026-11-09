import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:vitanet/core/network/backend.dart';
import 'package:vitanet/data/providers/providers.dart';
import 'package:vitanet/features/portal/data/portal_providers.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

typedef SocketConnector = WebSocketChannel Function(Uri uri);

/// Keeps the portal live: a WebSocket to `/portal/ws` delivers small "this
/// changed" events and the matching providers refetch. While the socket is
/// down it retries with backoff and refreshes every minute so nothing goes
/// stale.
class PortalLive {
  PortalLive(this._ref, {SocketConnector? connect, Future<String?> Function()? token})
      : _connect = connect ?? ((uri) => WebSocketChannel.connect(uri)),
        _token = token ?? BackendConfig.idToken;

  final Ref _ref;
  final SocketConnector _connect;
  final Future<String?> Function() _token;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _sub;
  Timer? _retry;
  Timer? _fallback;
  int _attempt = 0;
  bool _disposed = false;

  static Uri socketUri(String baseUrl) {
    final base = Uri.parse(baseUrl.endsWith('/') ? baseUrl : '$baseUrl/');
    return base.replace(scheme: base.scheme == 'https' ? 'wss' : 'ws').resolve('portal/ws');
  }

  void start() {
    _startFallback();
    _open();
  }

  Future<void> _open() async {
    if (_disposed) return;
    try {
      final token = await _token();
      if (_disposed) return;
      final channel = _connect(socketUri(BackendConfig.baseUrl));
      _channel = channel;
      _sub = channel.stream.listen(_onMessage, onDone: _onClosed, onError: (_) => _onClosed(), cancelOnError: true);
      channel.sink.add(jsonEncode({'token': token ?? ''}));
    } catch (e) {
      debugPrint('PortalLive: $e');
      _onClosed();
    }
  }

  void _onMessage(dynamic raw) {
    Map<String, dynamic> msg;
    try {
      msg = Map<String, dynamic>.from(jsonDecode(raw as String) as Map);
    } catch (_) {
      return;
    }
    final type = msg['type'] as String?;
    if (type == null || type == 'ping') return;
    if (type == 'ready') {
      _attempt = 0;
      _setConnected(true);
      // Catch up on anything missed while disconnected.
      for (final t in const ['referral', 'case', 'alert', 'capacity', 'team']) {
        invalidateForEvent(_ref, t, null);
      }
      return;
    }
    invalidateForEvent(_ref, type, msg['id'] as String?);
  }

  void _onClosed() {
    _sub?.cancel();
    _sub = null;
    _channel = null;
    _setConnected(false);
    if (_disposed) return;
    final seconds = [2, 4, 8, 15, 30][_attempt.clamp(0, 4)];
    _attempt++;
    _retry?.cancel();
    _retry = Timer(Duration(seconds: seconds), _open);
  }

  void _startFallback() {
    _fallback = Timer.periodic(const Duration(seconds: 60), (_) {
      if (_ref.read(portalLiveConnectedProvider)) return;
      for (final t in const ['referral', 'case', 'alert']) {
        invalidateForEvent(_ref, t, null);
      }
    });
  }

  void _setConnected(bool v) {
    if (_disposed) return;
    final n = _ref.read(portalLiveConnectedProvider.notifier);
    if (n.state != v) n.state = v;
  }

  void dispose() {
    _disposed = true;
    _retry?.cancel();
    _fallback?.cancel();
    _sub?.cancel();
    _channel?.sink.close();
  }
}

/// Watched by the portal shell: live while the portal is open.
final portalLiveProvider = Provider.autoDispose<PortalLive>((ref) {
  final live = PortalLive(ref)..start();
  ref.onDispose(live.dispose);
  return live;
});

/// "Announce new patients aloud" (Me screen). Speaks on this device while the
/// portal is open; stored per device.
class AnnounceNewPatientsNotifier extends Notifier<bool> {
  static const _key = 'portal_announce_new_patients';

  @override
  bool build() => ref.watch(sharedPreferencesProvider)?.getBool(_key) ?? true;

  Future<void> set(bool on) async {
    state = on;
    await ref.read(sharedPreferencesProvider)?.setBool(_key, on);
  }
}

final announceNewPatientsProvider =
    NotifierProvider<AnnounceNewPatientsNotifier, bool>(AnnounceNewPatientsNotifier.new);

/// Speaks short announcements ("Urgent patient incoming…").
class Announcer {
  FlutterTts? _tts;

  Future<void> say(String text) async {
    try {
      _tts ??= FlutterTts();
      await _tts!.stop();
      await _tts!.speak(text);
    } catch (e) {
      debugPrint('Announcer: $e');
    }
  }
}

final announcerProvider = Provider<Announcer>((ref) => Announcer());
