import 'package:flutter/material.dart';
import 'package:vitanet/shared/widgets/vn_kit.dart';

/// Content types that search results can be filtered by.
enum SearchContentType { articles, videos, medicines, firstAid, myChecks }

extension SearchContentTypeLabel on SearchContentType {
  String get label => switch (this) {
        SearchContentType.articles => 'Articles',
        SearchContentType.videos => 'Videos',
        SearchContentType.medicines => 'Medicines',
        SearchContentType.firstAid => 'First aid',
        SearchContentType.myChecks => 'My checks',
      };
}

enum SearchSort { relevant, newest, reviewed }

extension SearchSortLabel on SearchSort {
  String get label => switch (this) {
        SearchSort.relevant => 'Most relevant',
        SearchSort.newest => 'Newest first',
        SearchSort.reviewed => 'Clinician reviewed only',
      };
}

/// Filter state shared between the search screen and the sheet.
class SearchFilters {
  final Set<SearchContentType> types;
  final String? bodyArea;
  final SearchSort sort;

  const SearchFilters({
    this.types = const {},
    this.bodyArea,
    this.sort = SearchSort.relevant,
  });

  bool get isDefault => types.isEmpty && bodyArea == null && sort == SearchSort.relevant;
}

/// Opens the filter sheet and resolves with the applied filters
/// (or null when dismissed).
Future<SearchFilters?> showFilterBottomSheet(
  BuildContext context, {
  required SearchFilters initial,
  required int Function(SearchFilters) countFor,
}) {
  return showVnSheet<SearchFilters>(
    context,
    builder: (_) => FilterBottomSheet(initial: initial, countFor: countFor),
  );
}

class FilterBottomSheet extends StatefulWidget {
  final SearchFilters initial;
  final int Function(SearchFilters)? countFor;

  const FilterBottomSheet({
    super.key,
    this.initial = const SearchFilters(),
    this.countFor,
  });

  @override
  State<FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<FilterBottomSheet> {
  static const _areas = ['Head', 'Chest', 'Stomach', 'Skin', 'Joints', 'Mental'];

  late Set<SearchContentType> _types = {...widget.initial.types};
  late String? _area = widget.initial.bodyArea;
  late SearchSort _sort = widget.initial.sort;

  SearchFilters get _current => SearchFilters(types: _types, bodyArea: _area, sort: _sort);

  @override
  Widget build(BuildContext context) {
    final p = VnPalette.of(context);
    final count = widget.countFor?.call(_current);
    Text label(String s) =>
        Text(s, style: VnText.body(13, weight: FontWeight.w700, color: p.inkSoft));

    return VnSheet(
      gap: 20,
      children: [
        Row(
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text('Filter', style: VnText.heading(20, color: p.ink)),
              ),
            ),
            VnLink(
              label: 'Reset',
              weight: FontWeight.w700,
              onTap: () => setState(() {
                _types = {};
                _area = null;
                _sort = SearchSort.relevant;
              }),
            ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            label('Content type'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in SearchContentType.values)
                  VnChip(
                    label: t.label,
                    height: 38,
                    selected: _types.contains(t),
                    icon: _types.contains(t) ? Icons.check_rounded : null,
                    onTap: () => setState(() =>
                        _types.contains(t) ? _types.remove(t) : _types.add(t)),
                  ),
              ],
            ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            label('Body area'),
            const SizedBox(height: 10),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              mainAxisExtent: 44,
              children: [
                for (final a in _areas)
                  Semantics(
                    button: true,
                    selected: _area == a,
                    child: Material(
                      color: _area == a ? p.brandTint : p.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: _area == a ? p.brand : p.line),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => setState(() => _area = _area == a ? null : a),
                        child: Center(
                          child: Text(a,
                              style: VnText.body(14,
                                  weight: _area == a ? FontWeight.w700 : FontWeight.w600,
                                  color: _area == a ? p.brandDeep : p.ink)),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            label('Sort by'),
            const SizedBox(height: 4),
            RadioGroup<SearchSort>(
              groupValue: _sort,
              onChanged: (v) => setState(() => _sort = v ?? _sort),
              child: Column(
                children: [
                  for (final s in SearchSort.values)
                    InkWell(
                      onTap: () => setState(() => _sort = s),
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        height: 44,
                        child: Row(
                          children: [
                            Radio<SearchSort>(
                              value: s,
                              activeColor: p.brand,
                            ),
                            const SizedBox(width: 4),
                            Text(s.label, style: VnText.body(15, color: p.ink)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        VnButton(
          label: count == null ? 'Show results' : 'Show $count result${count == 1 ? '' : 's'}',
          onPressed: () => Navigator.of(context).pop(_current),
        ),
      ],
    );
  }
}
