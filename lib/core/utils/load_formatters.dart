import 'package:intl/intl.dart';

class ParsedLocation {
  final String city;
  final String state;
  final String stateCode;

  const ParsedLocation({
    required this.city,
    required this.state,
    required this.stateCode,
  });
}

class LoadFormatters {
  // ── Location ────────────────────────────────────────────────────────────

  /// Canonical location parser that understands Mappls addresses of varying depth.
  /// Parses from the end: country (ignored) -> state -> city.
  static ParsedLocation parseLocation(String address) {
    if (address.isEmpty) {
      return const ParsedLocation(city: 'Unknown', state: '', stateCode: '');
    }

    final rawParts = address.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (rawParts.isEmpty) {
      return const ParsedLocation(city: 'Unknown', state: '', stateCode: '');
    }

    // Strip digits (e.g. pin codes) and remove any resulting empty parts
    final parts = rawParts.map((e) => e.replaceAll(RegExp(r'\d+'), '').trim()).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) {
      return const ParsedLocation(city: 'Unknown', state: '', stateCode: '');
    }

    // Ignore country if it is 'India' at the end of a multi-part string
    if (parts.length > 1 && parts.last.toLowerCase() == 'india') {
      parts.removeLast();
    }

    String city = 'Unknown';
    String state = '';

    if (parts.length >= 2) {
      state = parts.last;
      city = parts[parts.length - 2];
    } else if (parts.length == 1) {
      city = parts.first;
    }

    return ParsedLocation(
      city: city,
      state: state,
      stateCode: state.isNotEmpty ? stateCode(state) : '',
    );
  }

  /// Extracts the City from the location string using the canonical parser.
  static String extractCity(String address) => parseLocation(address).city;

  /// Extracts the full State name from the location string using the canonical parser.
  static String extractState(String address) => parseLocation(address).state;

  /// Maps a full Indian state name to its standard 2-letter code.
  /// Falls back to the first 2 uppercase characters of the state name.
  static String stateCode(String stateName) {
    const codes = <String, String>{
      'andhra pradesh': 'AP',
      'arunachal pradesh': 'AR',
      'assam': 'AS',
      'bihar': 'BR',
      'chhattisgarh': 'CG',
      'goa': 'GA',
      'gujarat': 'GJ',
      'haryana': 'HR',
      'himachal pradesh': 'HP',
      'jharkhand': 'JH',
      'karnataka': 'KA',
      'kerala': 'KL',
      'madhya pradesh': 'MP',
      'maharashtra': 'MH',
      'manipur': 'MN',
      'meghalaya': 'ML',
      'mizoram': 'MZ',
      'nagaland': 'NL',
      'odisha': 'OD',
      'punjab': 'PB',
      'rajasthan': 'RJ',
      'sikkim': 'SK',
      'tamil nadu': 'TN',
      'telangana': 'TS',
      'tripura': 'TR',
      'uttar pradesh': 'UP',
      'uttarakhand': 'UK',
      'west bengal': 'WB',
      'delhi': 'DL',
      'jammu and kashmir': 'JK',
      'ladakh': 'LA',
      'puducherry': 'PY',
      'chandigarh': 'CH',
    };

    final key = stateName.trim().toLowerCase();
    final mapped = codes[key];
    if (mapped != null) return mapped;

    // Fallback: first 2 chars uppercased
    if (stateName.length >= 2) {
      return stateName.substring(0, 2).toUpperCase();
    }
    return stateName.toUpperCase();
  }

  /// Returns the abbreviated state-to-state route summary shown in the top-right.
  ///   Karnataka → Andhra Pradesh  →  "KA → AP"
  ///   Same state                  →  "KA"
  ///   Unknown                     →  "—"
  static String formatStateCodeSummary(String pickup, String drop) {
    final pickupLoc = parseLocation(pickup);
    final dropLoc = parseLocation(drop);

    if (pickupLoc.stateCode.isEmpty && dropLoc.stateCode.isEmpty) return '—';

    final pickupCode = pickupLoc.stateCode;
    final dropCode = dropLoc.stateCode;

    if (pickupCode.isEmpty) return dropCode;
    if (dropCode.isEmpty) return pickupCode;

    if (pickupCode == dropCode) return pickupCode;

    return '$pickupCode → $dropCode';
  }

  // Kept for backward compatibility. New code should use formatStateCodeSummary.
  static String formatStateSummary(String pickup, String drop) =>
      formatStateCodeSummary(pickup, drop);

  // ── Date ────────────────────────────────────────────────────────────────

  /// Safely formats a pickup date string to "7 Aug • 12:08 AM".
  /// Returns "Not scheduled" when unavailable.
  static String formatPickupDate(String dateStr) {
    if (dateStr.isEmpty) return 'Not scheduled';

    try {
      final date = DateTime.parse(dateStr).toLocal();
      return DateFormat('d MMM • h:mm a').format(date);
    } catch (_) {
      // Best-effort cleanup for non-ISO strings
      return dateStr.replaceAll(',', ' •').replaceAll('  ', ' ').trim();
    }
  }

  // ── Compatibility ────────────────────────────────────────────────────────

  /// "Steel Rods • 2 Tons • Open Body"
  static String formatCompatibilityLine(
      String cargo, String weight, String vehicle) {
    final parts = <String>[
      if (cargo.isNotEmpty) cargo,
      if (weight.isNotEmpty) weight,
      if (vehicle.isNotEmpty) vehicle,
    ];
    return parts.isEmpty ? 'Details unavailable' : parts.join(' • ');
  }

  // ── Currency ──────────────────────────────────────────────────────────────

  /// Parses a raw budget string from Firestore into an integer rupee amount.
  ///
  /// Handles formats stored by the app:
  ///   "110000"      → 110000
  ///   "1,10,000"    → 110000   (Indian comma-separated)
  ///   "₹1.1L"       → 110000   (already-formatted legacy value)
  ///   "8500.50"     → 8500     (fractional → truncated)
  ///   ""  / null    → 0
  static int parseBudgetString(String? raw) {
    if (raw == null || raw.trim().isEmpty) return 0;

    final s = raw.trim();

    // Already compact Indian notation — parse it back to int
    final compactMatch = RegExp(
      r'^₹?([\d.]+)\s*(Cr|L|K)$',
      caseSensitive: false,
    ).firstMatch(s);
    if (compactMatch != null) {
      final num = double.tryParse(compactMatch.group(1) ?? '') ?? 0;
      final suffix = compactMatch.group(2)!.toLowerCase();
      if (suffix == 'cr') return (num * 10000000).round();
      if (suffix == 'l') return (num * 100000).round();
      if (suffix == 'k') return (num * 1000).round();
    }

    // Strip currency symbol, commas, and spaces, then parse
    final cleaned = s.replaceAll(RegExp(r'[₹,\s]'), '');
    return (double.tryParse(cleaned) ?? 0).truncate();
  }

  /// Formats an integer rupee amount into compact Indian notation.
  ///
  /// Thresholds:
  ///   ≥ ₹1 Crore  (₹1,00,00,000)  → Cr suffix, up to 2 decimals
  ///   ≥ ₹1 Lakh   (₹1,00,000)     → L suffix,  up to 2 decimals
  ///   ≥ ₹1,000    (₹1,000)        → K suffix,  up to 1 decimal
  ///   < ₹1,000                    → plain ₹amount
  ///
  /// Examples:
  ///   0           → ₹0
  ///   500         → ₹500
  ///   8500        → ₹8.5K
  ///   25000       → ₹25K
  ///   99999       → ₹100K      (rounds up from 99.999K → 100K)
  ///   100000      → ₹1L
  ///   110000      → ₹1.1L
  ///   125000      → ₹1.25L
  ///   250000      → ₹2.5L
  ///   1000000     → ₹10L
  ///   10000000    → ₹1Cr
  ///   12500000    → ₹1.25Cr
  static String formatCompactInr(int amount) {
    if (amount == 0) return '₹0';
    if (amount < 0) return '-${formatCompactInr(-amount)}';

    const crore = 10000000;  // 1,00,00,000
    const lakh = 100000;     // 1,00,000
    const thousand = 1000;

    if (amount >= crore) {
      final val = amount / crore;
      final str = val == val.truncateToDouble()
          ? val.toInt().toString()
          : val.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '');
      return '₹${str}Cr';
    }
    if (amount >= lakh) {
      final val = amount / lakh;
      final str = val == val.truncateToDouble()
          ? val.toInt().toString()
          : val.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '');
      return '₹${str}L';
    }
    if (amount >= thousand) {
      final val = amount / thousand;
      final str = val == val.truncateToDouble()
          ? val.toInt().toString()
          : val.toStringAsFixed(1).replaceAll(RegExp(r'\.?0+$'), '');
      return '₹${str}K';
    }
    return '₹$amount';
  }

  /// Convenience method for display sites.
  /// Parses the raw Firestore budget string and returns compact Indian notation.
  ///   "110000"  → "₹1.1L"
  ///   "8500"    → "₹8.5K"
  ///   ""        → "₹0"
  static String formatBudget(String raw) => formatCompactInr(parseBudgetString(raw));
}
