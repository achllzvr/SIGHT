import 'package:flutter/material.dart';

import '../services/temporary_access_service.dart';
import '../theme/lumi_theme.dart';
import '../widgets/arcade/arcade.dart';
import 'guardian/child_dashboard/shared_widgets.dart';

/// Parent-facing doctor viewing history (one child or all linked children).
class GuardianAccessAuditScreen extends StatefulWidget {
  final int? childId;
  final String? childName;
  final bool allChildren;
  final List<int> childIds;
  final Map<int, String> childNames;

  const GuardianAccessAuditScreen({
    super.key,
    this.childId,
    this.childName,
    this.allChildren = false,
    this.childIds = const [],
    this.childNames = const {},
  }) : assert(allChildren || childId != null);

  @override
  State<GuardianAccessAuditScreen> createState() => _GuardianAccessAuditScreenState();
}

enum _StatusFilter { all, active, ended, expired }

enum _RangeFilter { all, days7, days30, days90 }

class _GuardianAccessAuditScreenState extends State<GuardianAccessAuditScreen> {
  static const int _pageSize = 10;

  bool _loading = true;
  bool _filtersOpen = false;
  String? _error;
  List<Map<String, dynamic>> _logs = const [];

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  DateTime? _specificDate;

  _StatusFilter _status = _StatusFilter.all;
  _RangeFilter _range = _RangeFilter.all;
  int? _filterChildId; // null = all children
  int _page = 0;

  @override
  void initState() {
    super.initState();
    if (!widget.allChildren) {
      _filterChildId = widget.childId;
    }
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final AccessLogsResult result;
      if (widget.allChildren) {
        result = await TemporaryAccessService.instance.getGuardianAccessLogs(
          childIds: widget.childIds,
        );
      } else {
        result = await TemporaryAccessService.instance.getAccessLogs(widget.childId!);
      }
      if (!mounted) return;
      setState(() {
        _logs = result.logs;
        _error = result.logs.isEmpty ? result.error : null;
        _loading = false;
        _page = 0;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceAll('Exception: ', '');
        _logs = const [];
        _page = 0;
      });
    }
  }

  bool get _hasActiveFilters {
    final childFiltered = widget.allChildren && _filterChildId != null;
    return _status != _StatusFilter.all ||
        _range != _RangeFilter.all ||
        childFiltered ||
        _searchQuery.isNotEmpty ||
        _specificDate != null;
  }

  List<String> get _activeFilterLabels {
    final labels = <String>[];
    if (_searchQuery.isNotEmpty) {
      labels.add('“$_searchQuery”');
    }
    switch (_status) {
      case _StatusFilter.active:
        labels.add('Active');
      case _StatusFilter.ended:
        labels.add('Ended');
      case _StatusFilter.expired:
        labels.add('Expired');
      case _StatusFilter.all:
        break;
    }
    if (_specificDate != null) {
      labels.add(formatReadableDate(_specificDate!));
    } else {
      switch (_range) {
        case _RangeFilter.days7:
          labels.add('7 days');
        case _RangeFilter.days30:
          labels.add('30 days');
        case _RangeFilter.days90:
          labels.add('90 days');
        case _RangeFilter.all:
          break;
      }
    }
    if (widget.allChildren && _filterChildId != null) {
      labels.add(_childOptions[_filterChildId] ?? 'Child');
    }
    return labels;
  }

  List<Map<String, dynamic>> get _filteredLogs {
    final now = DateTime.now();
    final DateTime? since = _specificDate != null
        ? null
        : switch (_range) {
            _RangeFilter.days7 => now.subtract(const Duration(days: 7)),
            _RangeFilter.days30 => now.subtract(const Duration(days: 30)),
            _RangeFilter.days90 => now.subtract(const Duration(days: 90)),
            _RangeFilter.all => null,
          };
    final query = _searchQuery.trim().toLowerCase();

    return _logs.where((log) {
      if (_status != _StatusFilter.all) {
        final status = (log['status']?.toString() ?? '').toLowerCase();
        if (status != _status.name) return false;
      }

      if (widget.allChildren && _filterChildId != null) {
        final childId = (log['child_id'] as num?)?.toInt();
        if (childId != _filterChildId) return false;
      }

      final accessed = DateTime.tryParse(log['accessed_at']?.toString() ?? '');
      if (_specificDate != null) {
        if (accessed == null) return false;
        final local = accessed.toLocal();
        if (local.year != _specificDate!.year ||
            local.month != _specificDate!.month ||
            local.day != _specificDate!.day) {
          return false;
        }
      } else if (since != null) {
        if (accessed == null || accessed.toLocal().isBefore(since)) return false;
      }

      if (query.isNotEmpty) {
        final haystack = [
          log['clinician_name'],
          log['child_name'],
          log['status'],
          log['ended_by'],
        ].map((v) => v?.toString().toLowerCase() ?? '').join(' ');
        if (!haystack.contains(query)) return false;
      }

      return true;
    }).toList(growable: false);
  }

  List<Map<String, dynamic>> get _pageLogs {
    final filtered = _filteredLogs;
    if (filtered.isEmpty) return const [];
    final start = (_page * _pageSize).clamp(0, filtered.length);
    final end = (start + _pageSize).clamp(0, filtered.length);
    return filtered.sublist(start, end);
  }

  int get _totalPages {
    final count = _filteredLogs.length;
    if (count == 0) return 1;
    return ((count - 1) ~/ _pageSize) + 1;
  }

  void _setFilter(VoidCallback update) {
    setState(() {
      update();
      _page = 0;
    });
  }

  void _clearFilters() {
    _setFilter(() {
      _status = _StatusFilter.all;
      _range = _RangeFilter.all;
      _filterChildId = widget.allChildren ? null : widget.childId;
      _searchQuery = '';
      _searchController.clear();
      _specificDate = null;
    });
  }

  Future<void> _pickSpecificDate() async {
    final picked = await LumiTheme.pickDate(
      context,
      initialDate: _specificDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: 'FILTER BY DATE',
    );
    if (picked == null || !mounted) return;
    _setFilter(() {
      _specificDate = DateTime(picked.year, picked.month, picked.day);
      _range = _RangeFilter.all;
    });
  }

  String _formatWhen(dynamic raw) {
    if (raw == null) return '—';
    final parsed = DateTime.tryParse(raw.toString());
    if (parsed == null) return raw.toString();
    return formatReadableDateTime(parsed);
  }

  String _prettyStatus(dynamic raw) {
    final value = (raw?.toString() ?? '').trim();
    if (value.isEmpty) return '—';
    return value[0].toUpperCase() + value.substring(1).toLowerCase();
  }

  String _prettyEndedBy(dynamic raw) {
    final value = (raw?.toString() ?? '').trim().toLowerCase();
    switch (value) {
      case 'guardian':
        return 'Parent';
      case 'clinician':
        return 'Doctor';
      case 'system':
        return 'System';
      case '':
        return '—';
      default:
        return value[0].toUpperCase() + value.substring(1);
    }
  }

  Map<int, String> get _childOptions {
    if (widget.childNames.isNotEmpty) return widget.childNames;
    final fromLogs = <int, String>{};
    for (final log in _logs) {
      final id = (log['child_id'] as num?)?.toInt();
      if (id == null || id <= 0) continue;
      final name = log['child_name']?.toString();
      if (name == null || name.isEmpty) continue;
      fromLogs.putIfAbsent(id, () => name);
    }
    return fromLogs;
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = widget.allChildren
        ? 'Doctors who viewed your children’s data with a temporary share code.'
        : 'Doctors who viewed ${widget.childName ?? 'this child'}\'s data with a temporary share code.';
    final filtered = _filteredLogs;
    final pageLogs = _pageLogs;
    final totalPages = _totalPages;
    final filterSummary = _activeFilterLabels.join(' · ');

    return Scaffold(
      backgroundColor: LumiColors.scaffoldMint,
      appBar: AppBar(
        title: Text(
          LumiTheme.caps('Access History'),
          style: LumiTheme.joyful(20, color: LumiColors.primaryPurple),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: LumiColors.textDark,
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh, color: LumiColors.primaryPurple),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(LumiSpacing.lg, 0, LumiSpacing.lg, LumiSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: LumiTheme.clanRegular(14, color: LumiColors.textMuted, height: 1.45),
            ),
            const SizedBox(height: LumiSpacing.md),
            if (!_loading) ...[
              _CollapsibleFilters(
                open: _filtersOpen,
                hasActiveFilters: _hasActiveFilters,
                summary: filterSummary.isEmpty ? 'All events' : filterSummary,
                onToggle: () => setState(() => _filtersOpen = !_filtersOpen),
                onClear: _hasActiveFilters ? _clearFilters : null,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _FilterSearchField(
                      controller: _searchController,
                      onChanged: (value) => _setFilter(() => _searchQuery = value.trim()),
                    ),
                    const SizedBox(height: LumiSpacing.sm),
                    _SpecificDateBar(
                      dateLabel: _specificDate == null ? null : formatReadableDate(_specificDate!),
                      onPick: _pickSpecificDate,
                      onClear: _specificDate == null
                          ? null
                          : () => _setFilter(() => _specificDate = null),
                    ),
                    const SizedBox(height: LumiSpacing.sm),
                    _CompactChipRow(
                      options: const [
                        ('All', _StatusFilter.all),
                        ('Active', _StatusFilter.active),
                        ('Ended', _StatusFilter.ended),
                        ('Expired', _StatusFilter.expired),
                      ],
                      selected: _status,
                      onSelected: (value) => _setFilter(() => _status = value),
                    ),
                    const SizedBox(height: LumiSpacing.sm),
                    _CompactChipRow(
                      options: const [
                        ('Any time', _RangeFilter.all),
                        ('7d', _RangeFilter.days7),
                        ('30d', _RangeFilter.days30),
                        ('90d', _RangeFilter.days90),
                      ],
                      selected: _specificDate != null ? _RangeFilter.all : _range,
                      onSelected: (value) => _setFilter(() {
                        _range = value;
                        _specificDate = null;
                      }),
                    ),
                    if (widget.allChildren && _childOptions.isNotEmpty) ...[
                      const SizedBox(height: LumiSpacing.sm),
                      _CompactChipRow<int?>(
                        options: [
                          ('All kids', null),
                          ..._childOptions.entries.map((e) => (e.value, e.key)),
                        ],
                        selected: _filterChildId,
                        onSelected: (value) => _setFilter(() => _filterChildId = value),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: LumiSpacing.sm),
              Text(
                filtered.isEmpty
                    ? '0 results'
                    : 'Showing ${(_page * _pageSize) + 1}–${(_page * _pageSize) + pageLogs.length} of ${filtered.length}',
                textAlign: TextAlign.center,
                style: LumiTheme.clanRegular(12, color: LumiColors.textMuted),
              ),
              const SizedBox(height: LumiSpacing.sm),
            ],
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: LumiColors.primaryPurple))
                  : _error != null && _logs.isEmpty
                      ? Center(
                          child: Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: LumiTheme.clanRegular(14, color: LumiColors.redAlert),
                          ),
                        )
                      : filtered.isEmpty
                          ? Center(
                              child: Text(
                                _logs.isEmpty
                                    ? 'No doctor access events yet.'
                                    : 'No access events match these filters.',
                                textAlign: TextAlign.center,
                                style: LumiTheme.clanRegular(14, color: LumiColors.textMuted),
                              ),
                            )
                          : ListView.separated(
                              itemCount: pageLogs.length,
                              separatorBuilder: (_, __) => const SizedBox(height: LumiSpacing.md),
                              itemBuilder: (_, i) {
                                final log = pageLogs[i];
                                final childLabel = log['child_name']?.toString();
                                return ArcadeCard(
                                  padding: const EdgeInsets.all(LumiSpacing.lg),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        LumiTheme.caps(log['clinician_name']?.toString() ?? 'Doctor'),
                                        style: LumiTheme.joyful(17, color: LumiColors.textDark),
                                      ),
                                      if (widget.allChildren &&
                                          childLabel != null &&
                                          childLabel.isNotEmpty) ...[
                                        const SizedBox(height: LumiSpacing.xs),
                                        Text(
                                          'Patient: $childLabel',
                                          style: LumiTheme.clanMedium(13, color: LumiColors.primaryPurple),
                                        ),
                                      ],
                                      const SizedBox(height: LumiSpacing.sm),
                                      Text(
                                        'Accessed: ${_formatWhen(log['accessed_at'])}',
                                        style: LumiTheme.clanRegular(13, color: LumiColors.textMuted, height: 1.5),
                                      ),
                                      Text(
                                        'Ended: ${_formatWhen(log['ended_at'])}',
                                        style: LumiTheme.clanRegular(13, color: LumiColors.textMuted, height: 1.5),
                                      ),
                                      Text(
                                        'Status: ${_prettyStatus(log['status'])} · Ended by: ${_prettyEndedBy(log['ended_by'])}',
                                        style: LumiTheme.clanRegular(13, color: LumiColors.textMuted, height: 1.5),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
            ),
            if (!_loading && filtered.isNotEmpty) ...[
              const SizedBox(height: LumiSpacing.md),
              _PaginationBar(
                page: _page,
                totalPages: totalPages,
                onPrev: _page > 0 ? () => setState(() => _page -= 1) : null,
                onNext: _page < totalPages - 1 ? () => setState(() => _page += 1) : null,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FilterSearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _FilterSearchField({
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      style: LumiTheme.clanMedium(13, color: LumiColors.textDark),
      decoration: InputDecoration(
        isDense: true,
        hintText: 'Search doctor or child…',
        hintStyle: LumiTheme.clanRegular(13, color: LumiColors.textMuted),
        prefixIcon: const Icon(Icons.search_rounded, size: 18, color: LumiColors.textMuted),
        prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Clear search',
                onPressed: () {
                  controller.clear();
                  onChanged('');
                },
                icon: const Icon(Icons.close_rounded, size: 16, color: LumiColors.textMuted),
              ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        filled: true,
        fillColor: LumiColors.scaffoldMint,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: const BorderSide(color: LumiColors.outline, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: const BorderSide(color: LumiColors.primaryPurple, width: 1.5),
        ),
      ),
    );
  }
}

class _SpecificDateBar extends StatelessWidget {
  final String? dateLabel;
  final VoidCallback onPick;
  final VoidCallback? onClear;

  const _SpecificDateBar({
    required this.dateLabel,
    required this.onPick,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final hasDate = dateLabel != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPick,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          decoration: BoxDecoration(
            color: hasDate ? LumiColors.secondaryPurple : LumiColors.scaffoldMint,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: hasDate ? LumiColors.primaryPurple : LumiColors.outline,
              width: 1.5,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  size: 16,
                  color: hasDate ? LumiColors.primaryPurple : LumiColors.textMuted,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    hasDate ? dateLabel! : 'Specific date',
                    style: LumiTheme.clanMedium(
                      12,
                      color: hasDate ? LumiColors.primaryPurple : LumiColors.textDark,
                    ),
                  ),
                ),
                if (onClear != null)
                  IconButton(
                    tooltip: 'Clear date',
                    onPressed: onClear,
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    icon: const Icon(Icons.close_rounded, size: 16, color: LumiColors.textMuted),
                  )
                else
                  const Icon(Icons.expand_more_rounded, size: 18, color: LumiColors.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CollapsibleFilters extends StatelessWidget {
  final bool open;
  final bool hasActiveFilters;
  final String summary;
  final VoidCallback onToggle;
  final VoidCallback? onClear;
  final Widget child;

  const _CollapsibleFilters({
    required this.open,
    required this.hasActiveFilters,
    required this.summary,
    required this.onToggle,
    required this.onClear,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: LumiColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: LumiColors.outline, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
              child: Row(
                children: [
                  Icon(
                    Icons.tune_rounded,
                    size: 18,
                    color: hasActiveFilters ? LumiColors.primaryPurple : LumiColors.textMuted,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Filters',
                          style: LumiTheme.clanMedium(13, color: LumiColors.textDark),
                        ),
                        Text(
                          summary,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: LumiTheme.clanRegular(12, color: LumiColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  if (onClear != null)
                    TextButton(
                      onPressed: onClear,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'Clear',
                        style: LumiTheme.clanMedium(12, color: LumiColors.primaryPurple),
                      ),
                    ),
                  Icon(
                    open ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                    color: LumiColors.textMuted,
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: child,
            ),
            crossFadeState: open ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 180),
            sizeCurve: Curves.easeOutCubic,
          ),
        ],
      ),
    );
  }
}

class _CompactChipRow<T> extends StatelessWidget {
  final List<(String label, T value)> options;
  final T selected;
  final ValueChanged<T> onSelected;

  const _CompactChipRow({
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < options.length; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            _FilterChip(
              label: options[i].$1,
              selected: selected == options[i].$2,
              onTap: () => onSelected(options[i].$2),
            ),
          ],
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? LumiColors.secondaryPurple : LumiColors.scaffoldMint,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? LumiColors.primaryPurple : LumiColors.outline,
              width: 1.5,
            ),
          ),
          child: Text(
            label,
            style: LumiTheme.clanMedium(
              12,
              color: selected ? LumiColors.primaryPurple : LumiColors.textDark,
            ),
          ),
        ),
      ),
    );
  }
}

class _PaginationBar extends StatelessWidget {
  final int page;
  final int totalPages;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  const _PaginationBar({
    required this.page,
    required this.totalPages,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ArcadeButton(
            text: 'Previous',
            variant: ArcadeButtonVariant.outline,
            onTap: onPrev,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: LumiSpacing.md),
          child: Text(
            'Page ${page + 1} of $totalPages',
            style: LumiTheme.clanMedium(13, color: LumiColors.textDark),
          ),
        ),
        Expanded(
          child: ArcadeButton(
            text: 'Next',
            variant: ArcadeButtonVariant.outline,
            onTap: onNext,
          ),
        ),
      ],
    );
  }
}
