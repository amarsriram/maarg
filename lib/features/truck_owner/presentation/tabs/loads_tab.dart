import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/models/load_model.dart';
import '../../../../core/models/load_request_state.dart';
import '../../../../core/repositories/load_repository.dart';
import '../../../../core/repositories/booking_repository.dart';
import '../../../../core/models/booking_model.dart';
import '../../../../core/services/trip_operations_service.dart';
import '../../../../core/utils/load_formatters.dart';
import '../../../../core/marketplace/marketplace_engine.dart';
import '../../../auth/data/auth_repository.dart';

// ─────────────────────────────────────────────────────────────────────────────
// LOADS TAB
// ─────────────────────────────────────────────────────────────────────────────

class _DateBridge {
  static final _fmt = DateFormat('yyyy-MM-dd');

  static (DateTime? from, DateTime? to) toRange(Set<String> keys) {
    if (keys.isEmpty) return (null, null);
    final dates = <DateTime>[];
    for (final k in keys) {
      try {
        dates.add(_fmt.parse(k));
      } catch (_) {}
    }
    if (dates.isEmpty) return (null, null);
    dates.sort();
    final from = dates.first;
    final to = DateTime(dates.last.year, dates.last.month, dates.last.day, 23, 59, 59);
    return (from, to);
  }

  static Set<String> fromState(LoadFilterState state, List<String> allKeys) {
    if (!state.hasDate) return const {};
    return allKeys.where((k) {
      try {
        final d = _fmt.parse(k);
        if (state.pickupFrom != null && d.isBefore(state.pickupFrom!)) return false;
        final dayEnd = DateTime(d.year, d.month, d.day, 23, 59, 59);
        if (state.pickupTo != null && dayEnd.isAfter(state.pickupTo!)) return false;
        return true;
      } catch (_) {
        return false;
      }
    }).toSet();
  }
}

class LoadsTab extends ConsumerStatefulWidget {
  const LoadsTab({super.key});

  @override
  ConsumerState<LoadsTab> createState() => _LoadsTabState();
}

class _LoadsTabState extends ConsumerState<LoadsTab> {
  LoadFilterState _filters = const LoadFilterState();
  LoadSortMode _sort = LoadSortMode.recent;

  void _clearAll() {
    setState(() {
      _filters = const LoadFilterState();
      _sort = LoadSortMode.recent;
    });
  }

  void _applySanitized(StaleDetectionResult stale) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _filters = stale.sanitize(_filters));
    });
  }

  void _openSelector(
    String title,
    List<String> options,
    Set<String> initialSelected,
    Map<String, String>? labels,
    ValueChanged<Set<String>> onApply,
    {bool showSearch = true}
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _FilterSelectorSheet(
        title: title,
        options: options,
        initialSelected: initialSelected,
        labels: labels,
        showSearch: showSearch,
        onApply: (sel) {
          onApply(sel);
          Navigator.pop(ctx);
        },
      ),
    );
  }

  void _openSortSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final bg = isDark ? AppColors.darkSurface : Colors.white;
        final textCol = isDark ? Colors.white : Colors.black87;
        return Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('SORT LOADS',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: textCol,
                      letterSpacing: 1.0)),
              const SizedBox(height: 16),
              ...LoadSortMode.values.map((m) {
                final active = _sort == m;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(m.label,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight:
                              active ? FontWeight.w700 : FontWeight.w500,
                          color:
                              active ? AppColors.primaryBlue : textCol)),
                  trailing: active
                      ? const Icon(Icons.check, color: AppColors.primaryBlue)
                      : null,
                  onTap: () {
                    setState(() => _sort = m);
                    Navigator.pop(ctx);
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBg : const Color(0xFFF2F4F8);
    final textPrimary = isDark ? Colors.white : Colors.black87;
    final textTertiary =
        isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary;

    final auth = ref.watch(authStateProvider);
    if (auth.isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primaryBlue));
    }
    if (auth.value == null) return const SizedBox.shrink();

    // Bottom padding computation to clear the persistent bottom navigation cleanly
    final bottomScrollPadding = 100.0 + MediaQuery.of(context).padding.bottom + 24.0;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        toolbarHeight: 60,
        title: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text('Available Loads',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                  color: textPrimary)),
        ),
      ),
      body: ref.watch(availableLoadsProvider).when(
        data: (allLoads) {
          if (allLoads.isEmpty) return _GlobalEmpty(isDark: isDark);

          final globalVocab = MarketplaceVocab.from(allLoads);

          final stale = MarketplaceVocab.detectStale(_filters, globalVocab);
          if (stale.hasStale) {
            _applySanitized(stale);
          }

          final ctxPickups =
              MarketplaceFacets.getContextualPickups(allLoads, _filters);
          final ctxDrops =
              MarketplaceFacets.getContextualDrops(allLoads, _filters);
          final ctxVehicles =
              MarketplaceFacets.getContextualVehicles(allLoads, _filters);
          final ctxCargo =
              MarketplaceFacets.getContextualCargo(allLoads, _filters);
          final ctxDateVocab =
              MarketplaceFacets.getContextualDateVocab(allLoads, _filters);

          final filtered = MarketplaceEngine.apply(allLoads, _filters);
          final sorted = MarketplaceEngine.sort(filtered, _sort);

          final activeDateKeys =
              _DateBridge.fromState(_filters, globalVocab.dateKeys);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Scrollable Primary Filter Bar ──────────────────────────────
              Container(
                height: 40,
                margin: const EdgeInsets.only(bottom: 12),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _FilterTriggerBtn(
                      'Pickup',
                      _filters.pickupCities,
                      globalVocab.pickupCities,
                      isDark,
                      () => _openSelector(
                        'PICKUP LOCATION',
                        ctxPickups,
                        _filters.pickupCities,
                        null,
                        (s) => setState(
                            () => _filters = _filters.copyWith(pickupCities: s)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _FilterTriggerBtn(
                      'Drop',
                      _filters.dropCities,
                      globalVocab.dropCities,
                      isDark,
                      () => _openSelector(
                        'DROP LOCATION',
                        ctxDrops,
                        _filters.dropCities,
                        null,
                        (s) => setState(
                            () => _filters = _filters.copyWith(dropCities: s)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _FilterTriggerBtn(
                      'Vehicle',
                      _filters.vehicles,
                      globalVocab.vehicles,
                      isDark,
                      () => _openSelector(
                        'VEHICLE',
                        ctxVehicles,
                        _filters.vehicles,
                        null,
                        (s) => setState(
                            () => _filters = _filters.copyWith(vehicles: s)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _FilterTriggerBtn(
                      'Cargo',
                      _filters.cargo,
                      globalVocab.cargo,
                      isDark,
                      () => _openSelector(
                        'CARGO',
                        ctxCargo,
                        _filters.cargo,
                        null,
                        (s) => setState(
                            () => _filters = _filters.copyWith(cargo: s)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _FilterTriggerBtn(
                      'Pickup Date',
                      _filters.hasDate ? activeDateKeys : {},
                      globalVocab.dateKeys,
                      isDark,
                      () => _openSelector(
                        'PICKUP DATE',
                        ctxDateVocab.dateKeys,
                        activeDateKeys,
                        ctxDateVocab.dateLabels,
                        (s) {
                          final (from, to) = _DateBridge.toRange(s);
                          setState(() => _filters = _filters.copyWith(
                              pickupFrom: from, pickupTo: to));
                        },
                        showSearch: false,
                      ),
                    ),
                  ],
                ),
              ),

              // ── Active Chips Row ───────────────────────────────────────────
              if (_filters.isActive)
                Container(
                  height: 32,
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      if (_filters.hasPickup)
                        _ActiveChip(
                            'Pickup',
                            _filters.pickupCities,
                            isDark,
                            () => setState(
                                () => _filters = _filters.clearPickup())),
                      if (_filters.hasDrop)
                        _ActiveChip(
                            'Drop',
                            _filters.dropCities,
                            isDark,
                            () => setState(
                                () => _filters = _filters.clearDrop())),
                      if (_filters.hasVehicle)
                        _ActiveChip(
                            'Vehicle',
                            _filters.vehicles,
                            isDark,
                            () => setState(
                                () => _filters = _filters.clearVehicle())),
                      if (_filters.hasCargo)
                        _ActiveChip(
                            'Cargo',
                            _filters.cargo,
                            isDark,
                            () => setState(
                                () => _filters = _filters.clearCargo())),
                      if (_filters.hasDate)
                        _ActiveChip(
                            'Date',
                            activeDateKeys,
                            isDark,
                            () => setState(
                                () => _filters = _filters.clearDate())),
                    ],
                  ),
                ),

              // ── Count & Sort Row ───────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${sorted.length} load${sorted.length == 1 ? '' : 's'} available',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: textTertiary),
                    ),
                    GestureDetector(
                      onTap: _openSortSelector,
                      child: Row(
                        children: [
                          Text(_sort.label,
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: textPrimary)),
                          const SizedBox(width: 4),
                          Icon(Icons.keyboard_arrow_down,
                              size: 16, color: textPrimary),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── Feed / Zero Match Workspace ────────────────────────────────
              Expanded(
                child: sorted.isEmpty
                    ? _ZeroMatch(
                        filters: _filters,
                        allLoads: allLoads,
                        isDark: isDark,
                        onClearAll: _clearAll,
                        onRelax: (label) => setState(() {
                          if (label == 'Remove Pickup') {
                            _filters = _filters.clearPickup();
                          } else if (label == 'Remove Drop') {
                            _filters = _filters.clearDrop();
                          } else if (label == 'Remove Vehicle') {
                            _filters = _filters.clearVehicle();
                          } else if (label == 'Remove Cargo') {
                            _filters = _filters.clearCargo();
                          } else if (label == 'Remove Date') {
                            _filters = _filters.clearDate();
                          }
                        }),
                      )
                    : ListView.separated(
                        padding: EdgeInsets.fromLTRB(16, 0, 16, bottomScrollPadding),
                        itemCount: sorted.length,
                        separatorBuilder: (ctx, idx) =>
                            const SizedBox(height: 10),
                        itemBuilder: (_, i) =>
                            _MarketplaceCard(load: sorted[i], isDark: isDark),
                      ),
              ),
            ],
          );
        },
        loading: () =>
            const Center(child: CircularProgressIndicator(color: AppColors.primaryBlue)),
        error: (e, _) => Center(
            child: Text('Error loading marketplace.\n$e',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.error))),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FILTER SELECTOR SHEET (KEYBOARD SAFETY INCLUDED)
// ─────────────────────────────────────────────────────────────────────────────

class _FilterSelectorSheet extends StatefulWidget {
  final String title;
  final List<String> options;
  final Set<String> initialSelected;
  final Map<String, String>? labels;
  final bool showSearch;
  final ValueChanged<Set<String>> onApply;

  const _FilterSelectorSheet({
    required this.title,
    required this.options,
    required this.initialSelected,
    this.labels,
    this.showSearch = true,
    required this.onApply,
  });

  @override
  State<_FilterSelectorSheet> createState() => _FilterSelectorSheetState();
}

class _FilterSelectorSheetState extends State<_FilterSelectorSheet> {
  late Set<String> _tempSelected;
  String _search = '';
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tempSelected = Set<String>.from(widget.initialSelected);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkSurface : Colors.white;
    final textCol = isDark ? Colors.white : Colors.black87;
    final titleCol = isDark ? Colors.white : Colors.black87;
    final hintCol = isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final primary = AppColors.primaryBlue;

    final trimmedSearch = _search.trim().toLowerCase();
    final filteredOptions = trimmedSearch.isEmpty
        ? widget.options
        : widget.options.where((o) {
            final lbl = widget.labels?[o] ?? o;
            return lbl.toLowerCase().contains(trimmedSearch);
          }).toList();

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: titleCol,
                      letterSpacing: 1.0,
                    ),
                  ),
                  TextButton(
                    onPressed: _tempSelected.isEmpty ? null : () => setState(() => _tempSelected.clear()),
                    style: TextButton.styleFrom(
                      foregroundColor: primary,
                      disabledForegroundColor: hintCol,
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(50, 30),
                      alignment: Alignment.centerRight,
                    ),
                    child: const Text(
                      'Clear',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (widget.showSearch)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                      color: isDark ? AppColors.darkBg : const Color(0xFFF4F6FA),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: border)),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (v) => setState(() => _search = v),
                    style: TextStyle(fontSize: 14, color: textCol, fontWeight: FontWeight.w500),
                    decoration: InputDecoration(
                      hintText: 'Search...',
                      hintStyle: TextStyle(fontSize: 13, color: hintCol, fontWeight: FontWeight.w500),
                      prefixIcon: Icon(Icons.search, size: 18, color: hintCol),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 11),
                    ),
                  ),
                ),
              ),
            Flexible(
              child: filteredOptions.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 36),
                      child: Center(
                        child: Text(
                          'No options found',
                          style: TextStyle(color: hintCol, fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      shrinkWrap: true,
                      itemCount: filteredOptions.length,
                      itemBuilder: (ctx, i) {
                        final opt = filteredOptions[i];
                        final lbl = widget.labels?[opt] ?? opt;
                        final sel = _tempSelected.contains(opt);
                        return Theme(
                          data: Theme.of(context).copyWith(
                            checkboxTheme: CheckboxThemeData(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                              side: BorderSide(color: isDark ? Colors.white30 : Colors.black.withValues(alpha: 0.30), width: 1.5),
                            )
                          ),
                          child: CheckboxListTile(
                            value: sel,
                            activeColor: primary,
                            checkColor: Colors.white,
                            title: Text(
                              lbl,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: sel ? FontWeight.w800 : FontWeight.w600,
                                color: sel ? primary : textCol,
                              ),
                            ),
                            onChanged: (val) {
                              setState(() {
                                if (val == true) {
                                  _tempSelected.add(opt);
                                } else {
                                  _tempSelected.remove(opt);
                                }
                              });
                            },
                            controlAffinity: ListTileControlAffinity.leading,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                            visualDensity: VisualDensity.compact,
                          ),
                        );
                      },
                    ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: border)),
                  color: bg,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          side: BorderSide(color: border)),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: textCol,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () => widget.onApply(_tempSelected),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0),
                      child: const Text(
                        'Apply',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
// ─────────────────────────────────────────────────────────────────────────────
// FILTER TRIGGER BUTTON (STATE-AWARE & DISCOVERABLE)
// ─────────────────────────────────────────────────────────────────────────────

class _FilterTriggerBtn extends StatelessWidget {
  const _FilterTriggerBtn(
    this.label,
    this.selectedValues,
    this.globalOptions,
    this.isDark,
    this.onTap,
  );
  final String label;
  final Set<String> selectedValues;
  final List<String> globalOptions;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final active = selectedValues.isNotEmpty;
    final hasData = globalOptions.isNotEmpty;

    Color bg;
    Color border;
    Color text;

    if (!hasData) {
      bg = isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.03);
      border = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08);
      text = isDark ? Colors.white.withValues(alpha: 0.30) : Colors.black87.withValues(alpha: 0.40);
    } else if (active) {
      bg = AppColors.primaryBlue.withValues(alpha: 0.12);
      border = AppColors.primaryBlue;
      text = AppColors.primaryBlue;
    } else {
      bg = isDark ? AppColors.darkSurface : Colors.white;
      border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
      text = isDark ? Colors.white : Colors.black87;
    }

    final displayText = active
        ? (selectedValues.length == 1
            ? '$label · ${selectedValues.first}'
            : '$label · ${selectedValues.length} selected')
        : label;

    return Center(
      child: GestureDetector(
        onTap: hasData ? onTap : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                displayText,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                  color: text,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.keyboard_arrow_down,
                size: 16,
                color: text,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ACTIVE CHIP
// ─────────────────────────────────────────────────────────────────────────────

class _ActiveChip extends StatelessWidget {
  const _ActiveChip(this.prefix, this.values, this.isDark, this.onRemove);
  final String prefix;
  final Set<String> values;
  final bool isDark;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final vList = values.toList();
    final display = vList.length == 1
        ? '$prefix: ${vList.first}'
        : '$prefix: ${vList.first} +${vList.length - 1}';

    return Center(
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              display,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: onRemove,
              child: Icon(
                Icons.close,
                size: 14,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EMPTY STATES
// ─────────────────────────────────────────────────────────────────────────────

class _GlobalEmpty extends StatelessWidget {
  const _GlobalEmpty({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.inventory_2_outlined,
            size: 52,
            color: isDark ? Colors.white24 : Colors.black26),
        const SizedBox(height: 20),
        Text('NO LOADS AVAILABLE',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.4,
                color: isDark ? Colors.white60 : Colors.black54)),
        const SizedBox(height: 10),
        Text("There aren't any open loads right now.",
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: isDark
                    ? AppColors.darkTextTertiary
                    : AppColors.lightTextTertiary)),
      ]),
    );
  }
}

class _ZeroMatch extends StatelessWidget {
  const _ZeroMatch({
    required this.filters,
    required this.allLoads,
    required this.isDark,
    required this.onClearAll,
    required this.onRelax,
  });
  final LoadFilterState filters;
  final List<LoadModel> allLoads;
  final bool isDark;
  final VoidCallback onClearAll;
  final ValueChanged<String> onRelax;

  @override
  Widget build(BuildContext context) {
    final tertiary =
        isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary;
    final surface = isDark ? AppColors.darkSurface : Colors.white;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final textCol = isDark ? Colors.white : Colors.black87;

    final recs = MarketplaceEngine.relaxationAnalysis(allLoads, filters);
    final bottomPadding = 100.0 + MediaQuery.of(context).padding.bottom + 24.0;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(24, 36, 24, bottomPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded,
              size: 48,
              color: isDark ? Colors.white24 : Colors.black26),
          const SizedBox(height: 16),
          Text('NO MATCHING LOADS',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: textCol)),
          const SizedBox(height: 10),
          Text('Nothing currently matches your selected requirements.',
              textAlign: TextAlign.center,
              style:
                  TextStyle(fontSize: 13, height: 1.5, color: tertiary)),
          if (recs.isNotEmpty) ...[
            const SizedBox(height: 36),
            Align(
                alignment: Alignment.centerLeft,
                child: Text('TRY RELAXING A FILTER',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                        color: tertiary))),
            const SizedBox(height: 12),
            ...recs.entries.map((e) => GestureDetector(
                  onTap: () => onRelax(e.key),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                        color: surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: border)),
                    child: Row(children: [
                      Expanded(
                          child: Text(e.key,
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: textCol))),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                            color: AppColors.primaryBlue
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20)),
                        child: Text(
                            '${e.value} load${e.value == 1 ? '' : 's'}',
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primaryBlue)),
                      ),
                    ]),
                  ),
                )),
          ],
          const SizedBox(height: 24),
          TextButton(
              onPressed: onClearAll,
              child: const Text('Clear All Filters',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryBlue))),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARKETPLACE CARD
// ─────────────────────────────────────────────────────────────────────────────

class _MarketplaceCard extends ConsumerStatefulWidget {
  const _MarketplaceCard({required this.load, required this.isDark});
  final LoadModel load;
  final bool isDark;

  @override
  ConsumerState<_MarketplaceCard> createState() => _MarketplaceCardState();
}

class _MarketplaceCardState extends ConsumerState<_MarketplaceCard> {
  bool _requesting = false;

  Future<void> _requestLoad() async {
    final user = ref.read(authStateProvider).value;
    if (user == null) return;
    setState(() => _requesting = true);
    try {
      await ref
          .read(tripOperationsServiceProvider)
          .requestBooking(widget.load, user)
          .timeout(const Duration(seconds: 8));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Load requested!'),
            backgroundColor: AppColors.success));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Error requesting load.'),
            backgroundColor: AppColors.error));
      }
    } finally {
      if (mounted) setState(() => _requesting = false);
    }
  }

  Future<void> _withdraw(BookingModel booking) async {
    final user = ref.read(authStateProvider).value;
    if (user == null) return;
    setState(() => _requesting = true);
    try {
      await ref
          .read(tripOperationsServiceProvider)
          .withdrawBooking(booking, user)
          .timeout(const Duration(seconds: 8));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Request withdrawn.'),
            backgroundColor: AppColors.success));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Error withdrawing.'),
            backgroundColor: AppColors.error));
      }
    } finally {
      if (mounted) setState(() => _requesting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final load = widget.load;
    final isDark = widget.isDark;

    final user = ref.watch(authStateProvider).value;
    final key = user != null ? '${user.id}|${load.loadId}' : '';
    final bkgState = user != null
        ? ref.watch(truckOwnerBookingForLoadProvider(key))
        : null;
    final existing = bkgState?.value;

    LoadRequestState reqState = LoadRequestState.none;
    VoidCallback onCta = _requestLoad;
    if (_requesting) onCta = () {};
    if (existing != null) {
      switch (existing.status) {
        case 'pending':
          reqState = LoadRequestState.pending;
          onCta = _requesting ? () {} : () => _withdraw(existing);
          break;
        case 'accepted':
          reqState = LoadRequestState.accepted;
          onCta = () {};
          break;
        case 'rejected':
          reqState = LoadRequestState.rejected;
          onCta = _requesting ? () {} : _requestLoad;
          break;
        case 'withdrawn':
          reqState = LoadRequestState.withdrawn;
          onCta = _requesting ? () {} : _requestLoad;
          break;
      }
    }

    final pickup = LoadFormatters.parseLocation(load.pickupLocation);
    final drop = LoadFormatters.parseLocation(load.dropLocation);
    final corridor = LoadFormatters.formatStateCodeSummary(
        load.pickupLocation, load.dropLocation);
    final budgetRaw = LoadFormatters.parseBudgetString(load.budget);
    final budgetStr = budgetRaw > 0
        ? LoadFormatters.formatBudget(load.budget)
        : 'Budget not set';
    final pickupDate = LoadFormatters.formatPickupDate(load.pickupDate);

    final primaryText = isDark ? Colors.white : Colors.black87;
    final secondaryText =
        isDark ? const Color(0xFFB0BAD3) : Colors.black54;
    final tertiaryText =
        isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary;
    final surface = isDark ? AppColors.darkSurface : Colors.white;
    final borderColor =
        isDark ? AppColors.darkBorder : AppColors.lightBorder;

    final showStates = pickup.state.isNotEmpty || drop.state.isNotEmpty;

    Color ctaBg, ctaFg;
    BorderSide ctaSide;
    String ctaLabel;
    if (reqState == LoadRequestState.accepted) {
      ctaBg = AppColors.success.withValues(alpha: 0.2);
      ctaFg = AppColors.success;
      ctaSide =
          BorderSide(color: AppColors.success.withValues(alpha: 0.4));
      ctaLabel = 'Assigned';
    } else if (reqState == LoadRequestState.pending) {
      ctaBg = Colors.transparent;
      ctaFg = AppColors.error;
      ctaSide =
          BorderSide(color: AppColors.error.withValues(alpha: 0.5));
      ctaLabel = 'Withdraw';
    } else {
      ctaBg = AppColors.primaryBlue;
      ctaFg = Colors.white;
      ctaSide = BorderSide.none;
      ctaLabel = 'Request Load';
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: AppColors.primaryBlue.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4)),
                  child: Text(load.status.toUpperCase(),
                      style: const TextStyle(
                          color: AppColors.primaryBlue,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6)),
                ),
                if (corridor != '—')
                  Text(corridor,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: tertiaryText)),
              ]),
          const SizedBox(height: 6),
          Text('${pickup.city}  \u2192  ${drop.city}',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: primaryText,
                  letterSpacing: -0.2),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          if (showStates) ...[
            const SizedBox(height: 2),
            Text('${pickup.state}  \u2192  ${drop.state}',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: tertiaryText),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ],
          const SizedBox(height: 8),
          _MetaRow('Pickup', pickupDate,
              load.pickupDate.isEmpty ? tertiaryText : primaryText,
              tertiaryText),
          const SizedBox(height: 3),
          _MetaRow(
              'Cargo',
              load.materialType.isNotEmpty ? load.materialType : '—',
              secondaryText,
              tertiaryText),
          const SizedBox(height: 3),
          _MetaRow(
              'Weight',
              load.weight.isNotEmpty ? load.weight : '—',
              secondaryText,
              tertiaryText),
          const SizedBox(height: 3),
          _MetaRow(
              'Vehicle',
              load.truckType.isNotEmpty ? load.truckType : '—',
              secondaryText,
              tertiaryText),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('Budget',
                      style:
                          TextStyle(fontSize: 10, color: tertiaryText)),
                  const SizedBox(height: 1),
                  Text(budgetStr,
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: primaryText),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ])),
            const SizedBox(width: 12),
            SizedBox(
              width: 130,
              height: 38,
              child: ElevatedButton(
                onPressed:
                    reqState == LoadRequestState.accepted ? null : onCta,
                style: ElevatedButton.styleFrom(
                    backgroundColor: ctaBg,
                    foregroundColor: ctaFg,
                    disabledBackgroundColor:
                        AppColors.success.withValues(alpha: 0.15),
                    disabledForegroundColor: AppColors.success,
                    elevation: 0,
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: ctaSide)),
                child: _requesting
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: ctaFg))
                    : Text(ctaLabel,
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow(this.label, this.value, this.valueColor, this.labelColor);
  final String label, value;
  final Color valueColor, labelColor;

  @override
  Widget build(BuildContext context) => Row(children: [
        SizedBox(
            width: 56,
            child: Text(label,
                style: TextStyle(fontSize: 11, color: labelColor))),
        Expanded(
            child: Text(value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: valueColor))),
      ]);
}
