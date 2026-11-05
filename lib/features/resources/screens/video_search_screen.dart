import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vitanet/data/services/voice_service.dart';
import 'package:vitanet/shared/widgets/vn_kit.dart';

import '../models/clinical_video.dart';
import '../widgets/resource_media.dart';
import '../widgets/video_engagement.dart';
import '../widgets/video_widgets.dart';
import 'video_player_screen.dart';
import 'video_shorts_screen.dart';

/// YouTube-style search results for VitaNet Learn.
class VideoSearchScreen extends ConsumerStatefulWidget {
  final String initialQuery;

  const VideoSearchScreen({super.key, this.initialQuery = ''});

  @override
  ConsumerState<VideoSearchScreen> createState() => _VideoSearchScreenState();
}

class _VideoSearchScreenState extends ConsumerState<VideoSearchScreen> {
  late final TextEditingController _controller;
  final _focus = FocusNode();
  final _store = VideoEngagementStore.instance;
  Timer? _debounce;

  static const _filters = ['All', 'Shorts', 'Under 4 minutes', 'Clinician verified', 'Diet'];
  String _filter = 'All';
  String _query = '';
  bool _loading = false;
  List<ClinicalVideo> _results = [];

  static const _related = <String, List<String>>{
    'Cardio & Vitals': ['blood pressure chart by age', 'white coat hypertension', 'lower bp naturally'],
    'First Aid & CPR': ['recovery position', 'choking first aid', 'how to use an AED'],
    'Trauma': ['severe bleeding', 'burn first aid', 'fracture care'],
    'Physical Therapy': ['lower back pain', 'neck pain exercises', 'sciatica relief'],
    'Guided Breathing': ['box breathing', 'panic attack help', 'vagus nerve'],
    'Nutrition & Sleep': ['sleep hygiene', 'gut health', 'melatonin'],
  };

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery);
    _query = widget.initialQuery.trim();
    if (_query.isNotEmpty) {
      _runSearch();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focus.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      setState(() => _query = value.trim());
      _runSearch();
    });
  }

  void _submit(String value) {
    _debounce?.cancel();
    setState(() => _query = value.trim());
    _runSearch();
  }

  Future<void> _runSearch() async {
    final q = _query;
    if (q.isEmpty) {
      setState(() => _results = []);
      return;
    }
    setState(() => _loading = true);
    List<ClinicalVideo> videos = [];
    try {
      final res = await ClinicalVideoRepository.fetchMasterclasses(
        pageIndex: 0,
        pageSize: 20,
        searchQuery: q,
      );
      videos = List.of(res.videos);
    } catch (_) {}
    final lower = q.toLowerCase();
    final shorts = ClinicalVideoRepository.verifiedShorts.where((v) =>
        v.title.toLowerCase().contains(lower) ||
        v.channelName.toLowerCase().contains(lower) ||
        v.category.toLowerCase().contains(lower) ||
        v.keyTakeaways.any((k) => k.toLowerCase().contains(lower)));
    final seen = <String>{};
    final merged = [...videos, ...shorts].where((v) => seen.add('${v.youtubeId}_${v.isShort}')).toList();
    if (!mounted || q != _query) return;
    setState(() {
      _results = merged;
      _loading = false;
    });
  }

  List<ClinicalVideo> get _visible {
    final base = _results.where((v) => !_store.isHidden(v.youtubeId));
    switch (_filter) {
      case 'Shorts':
        return base.where((v) => v.isShort).toList();
      case 'Under 4 minutes':
        return base.where((v) => v.durationSeconds > 0 && v.durationSeconds < 240).toList();
      case 'Clinician verified':
        return base.where((v) => v.isVerifiedChannel).toList();
      case 'Diet':
        return base.where((v) {
          final t = '${v.title} ${v.category} ${v.keyTakeaways.join(' ')}'.toLowerCase();
          return t.contains('diet') || t.contains('nutrition') || t.contains('gut') || t.contains('food');
        }).toList();
      default:
        return base.toList();
    }
  }

  Future<void> _voiceSearch() async {
    final voice = ref.read(voiceServiceProvider);
    if (voice.isListening) {
      await voice.stopListening();
      return;
    }
    final ok = await voice.initializeSpeech();
    if (!ok) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Voice search is not available on this device')),
        );
      }
      return;
    }
    await voice.startListening((words) {
      if (!mounted) return;
      _controller.text = words;
      _controller.selection = TextSelection.collapsed(offset: words.length);
      _onChanged(words);
    });
  }

  void _open(ClinicalVideo v, List<ClinicalVideo> list) {
    if (v.isShort) {
      final shorts = list.where((s) => s.isShort).toList();
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => VideoShortsScreen(shorts: shorts, initialIndex: shorts.indexOf(v).clamp(0, shorts.length)),
      ));
      return;
    }
    VideoPlayerScreen.openClinical(context, v, related: list);
  }

  void _useSuggestion(String s) {
    _controller.text = s;
    _submit(s);
  }

  @override
  Widget build(BuildContext context) {
    final p = VnPalette.of(context);
    final listening = ref.watch(voiceServiceProvider).isListening;
    return Scaffold(
      backgroundColor: p.surface,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _store,
          builder: (context, _) {
            final visible = _visible;
            return Column(
              children: [
                SizedBox(
                  height: 56,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      children: [
                        VnIconButton(
                          icon: Icons.chevron_left_rounded,
                          tooltip: 'Back',
                          iconSize: 26,
                          onPressed: () => Navigator.of(context).maybePop(),
                        ),
                        const SizedBox(width: 6),
                        Expanded(child: _searchField(p)),
                        const SizedBox(width: 6),
                        Tooltip(
                          message: listening ? 'Stop listening' : 'Voice search',
                          child: Semantics(
                            button: true,
                            label: listening ? 'Stop listening' : 'Voice search',
                            child: Material(
                              color: listening ? p.brandTint : p.surfaceAlt,
                              shape: const CircleBorder(),
                              clipBehavior: Clip.antiAlias,
                              child: InkWell(
                                onTap: _voiceSearch,
                                child: SizedBox(
                                  width: 44,
                                  height: 44,
                                  child: Icon(
                                    listening ? Icons.mic_rounded : Icons.mic_none_rounded,
                                    size: 20,
                                    color: listening ? p.brand : p.ink,
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
                SizedBox(
                  height: 50,
                  child: VnChipRow(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 14),
                    children: [
                      for (final f in _filters)
                        VnInkChip(
                          label: f,
                          selected: f == _filter,
                          flat: true,
                          height: 32,
                          radius: 8,
                          fontSize: 13,
                          onTap: () => setState(() => _filter = f),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1000),
                      child: _body(p, visible),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _searchField(VnPalette p) {
    return Container(
      height: 40,
      padding: const EdgeInsets.only(left: 14),
      decoration: BoxDecoration(color: p.surfaceAlt, borderRadius: BorderRadius.circular(20)),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focus,
              onChanged: _onChanged,
              onSubmitted: _submit,
              textInputAction: TextInputAction.search,
              style: VnText.body(15, color: p.ink),
              decoration: InputDecoration(
                hintText: 'Search VitaNet Learn',
                hintStyle: VnText.body(15, color: p.muted),
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (_controller.text.isNotEmpty)
            VnIconButton(
              icon: Icons.close_rounded,
              tooltip: 'Clear search',
              size: 40,
              iconSize: 18,
              radius: 20,
              foreground: p.muted,
              onPressed: () {
                _controller.clear();
                _submit('');
                _focus.requestFocus();
              },
            ),
        ],
      ),
    );
  }

  Widget _body(VnPalette p, List<ClinicalVideo> visible) {
    if (_query.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
        children: [
          Text('Popular topics', style: VnText.body(14, weight: FontWeight.w700, color: p.ink)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in const ['CPR', 'blood pressure', 'choking', 'box breathing', 'back pain', 'sleep'])
                _SuggestionChip(label: s, onTap: () => _useSuggestion(s)),
            ],
          ),
        ],
      );
    }
    if (_loading && _results.isEmpty) {
      return Center(child: CircularProgressIndicator(strokeWidth: 2, color: p.brand));
    }
    if (visible.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_off_rounded, size: 40, color: p.faint),
              const SizedBox(height: 10),
              Text('No videos found for "$_query"',
                  textAlign: TextAlign.center,
                  style: VnText.body(15, weight: FontWeight.w600, color: p.ink)),
              const SizedBox(height: 4),
              Text('Try another word or clear the filter.',
                  textAlign: TextAlign.center, style: VnText.body(13, color: p.muted)),
            ],
          ),
        ),
      );
    }

    final channelCounts = <String, int>{};
    for (final v in visible) {
      channelCounts[v.channelName] = (channelCounts[v.channelName] ?? 0) + 1;
    }
    final topChannelEntry = channelCounts.entries.reduce((a, b) => b.value > a.value ? b : a);
    final channelVideo = visible.firstWhere((v) => v.channelName == topChannelEntry.key);
    final suggestions = _related[visible.first.category] ??
        const ['first aid basics', 'heart health', 'stress relief'];

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics()),
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        if (topChannelEntry.value >= 2)
          _ChannelResult(
            video: channelVideo,
            count: topChannelEntry.value,
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(
            children: [
              for (final v in visible) ...[
                VideoListRow(
                  video: v,
                  showBadge: true,
                  onTap: () => _open(v, visible),
                  onMore: () => showVideoOptionsSheet(context, v),
                ),
                const SizedBox(height: 16),
              ],
            ],
          ),
        ),
        Container(
          margin: const EdgeInsets.fromLTRB(12, 4, 12, 0),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: p.surfaceSoft,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: p.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('People also search for', style: VnText.body(14, weight: FontWeight.w700, color: p.ink)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in suggestions) _SuggestionChip(label: s, onTap: () => _useSuggestion(s)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _SuggestionChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = VnPalette.of(context);
    return Material(
      color: p.surface,
      shape: StadiumBorder(side: BorderSide(color: p.line)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_rounded, size: 14, color: p.ink),
              const SizedBox(width: 6),
              Text(label, style: VnText.body(13, color: p.ink)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChannelResult extends StatelessWidget {
  final ClinicalVideo video;
  final int count;
  const _ChannelResult({required this.video, required this.count});

  @override
  Widget build(BuildContext context) {
    final p = VnPalette.of(context);
    final store = VideoEngagementStore.instance;
    final subscribed = store.isSubscribed(video.channelName);
    final handle = '@${video.channelName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '')}';
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.line))),
      child: Row(
        children: [
          ChannelAvatar(channel: video.channelName, code: video.channelAvatarUrl, size: 72, fontSize: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(video.channelName, style: VnText.body(16, weight: FontWeight.w700, color: p.ink)),
                const SizedBox(height: 2),
                Text('$handle · $count videos here', style: VnText.body(12, color: p.muted)),
                Text(video.category, style: VnText.body(12, color: p.muted)),
              ],
            ),
          ),
          SubscribeButton(
            subscribed: subscribed,
            onTap: () => store.toggleSubscribe(video.channelName),
            fontSize: 13,
          ),
        ],
      ),
    );
  }
}

/// Dark pill "Subscribe" / soft "Subscribed" toggle.
class SubscribeButton extends StatelessWidget {
  final bool subscribed;
  final VoidCallback onTap;
  final double fontSize;
  const SubscribeButton({super.key, required this.subscribed, required this.onTap, this.fontSize = 14});

  @override
  Widget build(BuildContext context) {
    final p = VnPalette.of(context);
    return Semantics(
      button: true,
      toggled: subscribed,
      child: Material(
        color: subscribed ? p.surfaceAlt : p.ink,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.center,
            child: Text(
              subscribed ? 'Subscribed' : 'Subscribe',
              style: VnText.body(fontSize, weight: FontWeight.w700, color: subscribed ? p.ink : p.surface),
            ),
          ),
        ),
      ),
    );
  }
}
