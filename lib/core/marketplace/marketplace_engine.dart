// lib/core/marketplace/marketplace_engine.dart
//
// Pure-Dart marketplace filter + sort + facet engine.
// NO Flutter imports. NO Firestore imports. NO BuildContext.
//
// This is the single source of truth for marketplace discovery logic.
// UI state contracts remain unchanged when the data source moves from
// local filtering to server-side Firestore querying.

import 'package:intl/intl.dart';
import '../models/load_model.dart';
import '../utils/load_formatters.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FILTER STATE
// Immutable. Represents committed marketplace constraints.
// ─────────────────────────────────────────────────────────────────────────────

class LoadFilterState {
  /// Cities to include (OR within group, AND across groups).
  final Set<String> pickupCities;
  final Set<String> dropCities;

  /// Exact truckType values — provider terminology preserved verbatim.
  final Set<String> vehicles;

  /// Exact materialType values — provider terminology preserved verbatim.
  final Set<String> cargo;

  /// Pickup date range. Both nullable → no date constraint.
  final DateTime? pickupFrom;
  final DateTime? pickupTo;

  const LoadFilterState({
    this.pickupCities = const {},
    this.dropCities = const {},
    this.vehicles = const {},
    this.cargo = const {},
    this.pickupFrom,
    this.pickupTo,
  });

  bool get hasPickup => pickupCities.isNotEmpty;
  bool get hasDrop => dropCities.isNotEmpty;
  bool get hasVehicle => vehicles.isNotEmpty;
  bool get hasCargo => cargo.isNotEmpty;
  bool get hasDate => pickupFrom != null || pickupTo != null;
  bool get isActive => hasPickup || hasDrop || hasVehicle || hasCargo || hasDate;

  LoadFilterState copyWith({
    Set<String>? pickupCities,
    Set<String>? dropCities,
    Set<String>? vehicles,
    Set<String>? cargo,
    Object? pickupFrom = _kUnset,
    Object? pickupTo = _kUnset,
  }) {
    return LoadFilterState(
      pickupCities: pickupCities ?? this.pickupCities,
      dropCities: dropCities ?? this.dropCities,
      vehicles: vehicles ?? this.vehicles,
      cargo: cargo ?? this.cargo,
      pickupFrom: pickupFrom == _kUnset ? this.pickupFrom : (pickupFrom as DateTime?),
      pickupTo: pickupTo == _kUnset ? this.pickupTo : (pickupTo as DateTime?),
    );
  }

  LoadFilterState clearPickup() => copyWith(pickupCities: const {});
  LoadFilterState clearDrop() => copyWith(dropCities: const {});
  LoadFilterState clearVehicle() => copyWith(vehicles: const {});
  LoadFilterState clearCargo() => copyWith(cargo: const {});
  LoadFilterState clearDate() => copyWith(pickupFrom: null, pickupTo: null);
  LoadFilterState clearAll() => const LoadFilterState();

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! LoadFilterState) return false;
    return _setEq(pickupCities, other.pickupCities) &&
        _setEq(dropCities, other.dropCities) &&
        _setEq(vehicles, other.vehicles) &&
        _setEq(cargo, other.cargo) &&
        pickupFrom == other.pickupFrom &&
        pickupTo == other.pickupTo;
  }

  @override
  int get hashCode => Object.hash(
        Object.hashAll(pickupCities),
        Object.hashAll(dropCities),
        Object.hashAll(vehicles),
        Object.hashAll(cargo),
        pickupFrom,
        pickupTo,
      );

  static bool _setEq(Set<String> a, Set<String> b) =>
      a.length == b.length && a.containsAll(b);
}

const _kUnset = Object();

// ─────────────────────────────────────────────────────────────────────────────
// SORT MODE
// ─────────────────────────────────────────────────────────────────────────────

enum LoadSortMode {
  /// Default. Preserves Firestore stream order (createdAt descending).
  recent,

  /// Descending by parsed budget. Invalid/missing → bottom.
  highestPayout,

  /// Ascending by pickupDate. Invalid/missing → bottom.
  earliestPickup,
}

extension LoadSortModeLabel on LoadSortMode {
  String get label {
    switch (this) {
      case LoadSortMode.recent:
        return 'Recent';
      case LoadSortMode.highestPayout:
        return 'Highest Payout';
      case LoadSortMode.earliestPickup:
        return 'Earliest Pickup';
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// VOCABULARY
// Derived from a snapshot of loads. Read-only. Never mutated.
// ─────────────────────────────────────────────────────────────────────────────

class MarketplaceVocab {
  final List<String> pickupCities;
  final List<String> dropCities;
  final List<String> vehicles;
  final List<String> cargo;
  final List<String> dateKeys;
  final Map<String, String> dateLabels;
  final DateTime? earliestPickup;
  final DateTime? latestPickup;

  const MarketplaceVocab({
    required this.pickupCities,
    required this.dropCities,
    required this.vehicles,
    required this.cargo,
    required this.dateKeys,
    required this.dateLabels,
    this.earliestPickup,
    this.latestPickup,
  });

  static final _dateKeyFmt = DateFormat('yyyy-MM-dd');
  static final _dateLabelFmt = DateFormat('d MMM, yyyy');

  static MarketplaceVocab from(List<LoadModel> loads) {
    final pSet = <String>{};
    final dSet = <String>{};
    final vSet = <String>{};
    final cSet = <String>{};
    final dtKeySet = <String>{};
    final dtLabels = <String, String>{};
    DateTime? earliest;
    DateTime? latest;

    for (final l in loads) {
      final pLoc = LoadFormatters.parseLocation(l.pickupLocation);
      if (pLoc.city.isNotEmpty && pLoc.city != 'Unknown') {
        pSet.add(pLoc.city);
      }
      final dLoc = LoadFormatters.parseLocation(l.dropLocation);
      if (dLoc.city.isNotEmpty && dLoc.city != 'Unknown') {
        dSet.add(dLoc.city);
      }
      final v = l.truckType.trim();
      if (v.isNotEmpty) vSet.add(v);
      final c = l.materialType.trim();
      if (c.isNotEmpty) cSet.add(c);

      final dt = _parseDate(l.pickupDate);
      if (dt != null) {
        final key = _dateKeyFmt.format(dt.toLocal());
        dtKeySet.add(key);
        dtLabels[key] = _dateLabelFmt.format(dt.toLocal());
        if (earliest == null || dt.isBefore(earliest)) earliest = dt;
        if (latest == null || dt.isAfter(latest)) latest = dt;
      }
    }

    return MarketplaceVocab(
      pickupCities: pSet.toList()..sort(),
      dropCities: dSet.toList()..sort(),
      vehicles: vSet.toList()..sort(),
      cargo: cSet.toList()..sort(),
      dateKeys: dtKeySet.toList()..sort(),
      dateLabels: dtLabels,
      earliestPickup: earliest,
      latestPickup: latest,
    );
  }

  static DateTime? _parseDate(String raw) {
    if (raw.isEmpty) return null;
    try {
      return DateTime.parse(raw);
    } catch (_) {
      return null;
    }
  }

  /// Detects which committed selections no longer exist in this vocabulary.
  static StaleDetectionResult detectStale(
    LoadFilterState committed,
    MarketplaceVocab global,
  ) {
    return StaleDetectionResult(
      stalePickups: committed.pickupCities.where((c) => !global.pickupCities.contains(c)).toSet(),
      staleDrops: committed.dropCities.where((c) => !global.dropCities.contains(c)).toSet(),
      staleVehicles: committed.vehicles.where((c) => !global.vehicles.contains(c)).toSet(),
      staleCargo: committed.cargo.where((c) => !global.cargo.contains(c)).toSet(),
    );
  }
}

class StaleDetectionResult {
  final Set<String> stalePickups;
  final Set<String> staleDrops;
  final Set<String> staleVehicles;
  final Set<String> staleCargo;

  const StaleDetectionResult({
    required this.stalePickups,
    required this.staleDrops,
    required this.staleVehicles,
    required this.staleCargo,
  });

  bool get hasStale =>
      stalePickups.isNotEmpty || staleDrops.isNotEmpty ||
      staleVehicles.isNotEmpty || staleCargo.isNotEmpty;

  LoadFilterState sanitize(LoadFilterState state) {
    return state.copyWith(
      pickupCities: state.pickupCities.difference(stalePickups),
      dropCities: state.dropCities.difference(staleDrops),
      vehicles: state.vehicles.difference(staleVehicles),
      cargo: state.cargo.difference(staleCargo),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FACETED VOCABULARY
// Each facet ignores its own constraint when deriving options.
// ─────────────────────────────────────────────────────────────────────────────

class MarketplaceFacets {
  static List<String> getContextualPickups(List<LoadModel> all, LoadFilterState current) =>
      MarketplaceVocab.from(MarketplaceEngine.apply(all, current.clearPickup())).pickupCities;

  static List<String> getContextualDrops(List<LoadModel> all, LoadFilterState current) =>
      MarketplaceVocab.from(MarketplaceEngine.apply(all, current.clearDrop())).dropCities;

  static List<String> getContextualVehicles(List<LoadModel> all, LoadFilterState current) =>
      MarketplaceVocab.from(MarketplaceEngine.apply(all, current.clearVehicle())).vehicles;

  static List<String> getContextualCargo(List<LoadModel> all, LoadFilterState current) =>
      MarketplaceVocab.from(MarketplaceEngine.apply(all, current.clearCargo())).cargo;

  static MarketplaceVocab getContextualDateVocab(List<LoadModel> all, LoadFilterState current) =>
      MarketplaceVocab.from(MarketplaceEngine.apply(all, current.clearDate()));
}

// ─────────────────────────────────────────────────────────────────────────────
// ENGINE
// Pure, side-effect-free. Deterministic. No Flutter/Firestore dependencies.
// ─────────────────────────────────────────────────────────────────────────────

class MarketplaceEngine {
  static String _n(String s) => s.trim().toLowerCase();

  static DateTime? _parseDate(String raw) {
    if (raw.isEmpty) return null;
    try {
      return DateTime.parse(raw);
    } catch (_) {
      return null;
    }
  }

  static bool _matches(LoadModel l, LoadFilterState f) {
    if (f.hasPickup) {
      final city = LoadFormatters.parseLocation(l.pickupLocation).city;
      if (!f.pickupCities.any((c) => _n(c) == _n(city))) return false;
    }
    if (f.hasDrop) {
      final city = LoadFormatters.parseLocation(l.dropLocation).city;
      if (!f.dropCities.any((c) => _n(c) == _n(city))) return false;
    }
    if (f.hasVehicle) {
      final v = l.truckType.trim();
      if (!f.vehicles.any((c) => _n(c) == _n(v))) return false;
    }
    if (f.hasCargo) {
      final c = l.materialType.trim();
      if (!f.cargo.any((x) => _n(x) == _n(c))) return false;
    }
    if (f.hasDate) {
      final dt = _parseDate(l.pickupDate);
      if (dt == null) return false;
      if (f.pickupFrom != null && dt.isBefore(f.pickupFrom!)) return false;
      if (f.pickupTo != null && dt.isAfter(f.pickupTo!)) return false;
    }
    return true;
  }

  /// Filter loads by committed state. Returns new list, never mutates original.
  /// O(n). AND across groups, OR within groups.
  static List<LoadModel> apply(List<LoadModel> loads, LoadFilterState state) {
    if (!state.isActive) return loads;
    return loads.where((l) => _matches(l, state)).toList(growable: false);
  }

  /// Sort loads by mode. Never mutates original list.
  /// Recent: returns same reference (no copy, no overhead).
  static List<LoadModel> sort(List<LoadModel> list, LoadSortMode mode) {
    if (mode == LoadSortMode.recent) return list;
    final r = List<LoadModel>.of(list);
    if (mode == LoadSortMode.highestPayout) {
      r.sort((a, b) {
        final ba = LoadFormatters.parseBudgetString(a.budget);
        final bb = LoadFormatters.parseBudgetString(b.budget);
        if (ba == 0 && bb == 0) return 0;
        if (ba == 0) return 1;
        if (bb == 0) return -1;
        return bb.compareTo(ba);
      });
    } else if (mode == LoadSortMode.earliestPickup) {
      r.sort((a, b) {
        final da = _parseDate(a.pickupDate);
        final db = _parseDate(b.pickupDate);
        if (da == null && db == null) return 0;
        if (da == null) return 1;
        if (db == null) return -1;
        return da.compareTo(db);
      });
    }
    return r;
  }

  /// Zero-match relaxation analysis.
  /// Removes one constraint at a time and reports how many loads would appear.
  /// Returns label -> count, sorted by count descending.
  /// Only returns entries where count > 0.
  static Map<String, int> relaxationAnalysis(
    List<LoadModel> all,
    LoadFilterState state,
  ) {
    final results = <String, int>{};
    void check(String label, LoadFilterState relaxed) {
      final c = apply(all, relaxed).length;
      if (c > 0) results[label] = c;
    }
    if (state.hasPickup) check('Remove Pickup', state.clearPickup());
    if (state.hasDrop) check('Remove Drop', state.clearDrop());
    if (state.hasVehicle) check('Remove Vehicle', state.clearVehicle());
    if (state.hasCargo) check('Remove Cargo', state.clearCargo());
    if (state.hasDate) check('Remove Date', state.clearDate());
    final sorted = results.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return Map.fromEntries(sorted);
  }
}
