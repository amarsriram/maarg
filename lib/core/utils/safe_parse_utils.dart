class SafeParse {
  /// Safely converts any dynamic value to a String with a fallback.
  /// Handles null, empty strings, or literal "null" strings gracefully.
  static String safeString(dynamic value, String fallback) {
    if (value == null) return fallback;
    final str = value.toString().trim();
    if (str.isEmpty || str.toLowerCase() == 'null') return fallback;
    return str;
  }

  /// Safely converts any dynamic value to a double with a fallback.
  static double safeDouble(dynamic value, double fallback) {
    if (value == null) return fallback;
    if (value is num) return value.toDouble();
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty || trimmed.toLowerCase() == 'null') return fallback;
      return double.tryParse(trimmed) ?? fallback;
    }
    return fallback;
  }

  /// Safely converts any dynamic value to an int with a fallback.
  static int safeInt(dynamic value, int fallback) {
    if (value == null) return fallback;
    if (value is num) return value.toInt();
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty || trimmed.toLowerCase() == 'null') return fallback;
      return int.tryParse(trimmed) ?? fallback;
    }
    return fallback;
  }

  /// Safely converts any dynamic value to a bool with a fallback.
  static bool safeBool(dynamic value, bool fallback) {
    if (value == null) return fallback;
    if (value is bool) return value;
    if (value is String) {
      final str = value.toLowerCase().trim();
      if (str == 'true' || str == '1') return true;
      if (str == 'false' || str == '0') return false;
    }
    if (value is num) return value != 0;
    return fallback;
  }

  /// Phase 6: Validate truck fields exist safely before rendering
  static bool isValidTruck(Map<String, dynamic> data) {
    final driverName = data['driverName'] ?? data['driver'];
    final currentLocation = data['currentLocation'] ?? data['from'];
    final destination = data['destination'] ?? data['to'];
    final truckType = data['truckType'] ?? data['type'];
    final rating = data['rating'];
    final price = data['price'];
    final capacity = data['capacity'];
    final available = data['available'];
    final createdAt = data['createdAt'];
    final userId = data['userId'] ?? data['ownerId'];

    return driverName != null &&
        currentLocation != null &&
        destination != null &&
        truckType != null &&
        rating != null &&
        price != null &&
        capacity != null &&
        available != null &&
        createdAt != null &&
        userId != null;
  }

  /// Phase 6: Validate load fields exist safely before rendering
  static bool isValidLoad(Map<String, dynamic> data) {
    final pickupLocation = data['pickupLocation'] ?? data['from'];
    final dropLocation = data['dropLocation'] ?? data['to'];
    final truckType = data['truckType'] ?? data['type'];
    final price = data['price'];
    final status = data['status'];
    final createdAt = data['createdAt'];
    final userId = data['userId'];

    return pickupLocation != null &&
        dropLocation != null &&
        truckType != null &&
        price != null &&
        status != null &&
        createdAt != null &&
        userId != null;
  }

  /// Phase 6: Validate booking fields exist safely before rendering
  static bool isValidBooking(Map<String, dynamic> data) {
    final status = data['status'];
    final price = data['price'];
    final fromLoc = data['from'] ?? data['pickupLocation'];
    final toLoc = data['to'] ?? data['dropLocation'];
    final createdAt = data['createdAt'];

    return status != null &&
        price != null &&
        fromLoc != null &&
        toLoc != null &&
        createdAt != null;
  }
}
