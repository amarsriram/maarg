enum UserRole {
  truckOwner,
  provider, // Displayed as "Load Provider" in UI
  none,
}

extension UserRoleExtension on UserRole {
  String get displayName {
    switch (this) {
      case UserRole.truckOwner:
        return 'Truck Owner';
      case UserRole.provider:
        return 'Load Provider';
      case UserRole.none:
        return 'Not Selected';
    }
  }

  String get description {
    switch (this) {
      case UserRole.truckOwner:
        return 'Find loads and manage active trips efficiently';
      case UserRole.provider:
        return 'Post and manage shipments across India';
      case UserRole.none:
        return 'Select role';
    }
  }

  /// Firestore-safe string key for the role.
  String get firestoreKey {
    switch (this) {
      case UserRole.truckOwner:
        return 'truckOwner';
      case UserRole.provider:
        return 'provider';
      case UserRole.none:
        return 'none';
    }
  }

  /// Parse a Firestore string back into a [UserRole].
  static UserRole fromString(String? value) {
    switch (value) {
      case 'truckOwner':
        return UserRole.truckOwner;
      case 'provider':
        return UserRole.provider;
      default:
        return UserRole.none;
    }
  }
}

class AppUser {
  final String id;
  final String email;
  final String? name;
  final UserRole role;
  final String? phoneNumber;
  final String? companyName;
  final String? operatingRegion;
  final bool profileCompleted;

  String get displayName => (name?.trim().isNotEmpty ?? false) ? name! : 'User';
  
  String get providerDisplayName => (companyName?.trim().isNotEmpty ?? false) 
      ? companyName! 
      : (name?.trim().isNotEmpty ?? false) ? name! : 'Verified Provider';

  String get driverDisplayName => (name?.trim().isNotEmpty ?? false) ? name! : 'Truck Driver';

  const AppUser({
    required this.id,
    required this.email,
    this.name,
    required this.role,
    this.phoneNumber,
    this.companyName,
    this.operatingRegion,
    this.profileCompleted = false,
  });

  AppUser copyWith({
    String? id,
    String? email,
    String? name,
    UserRole? role,
    String? phoneNumber,
    String? companyName,
    String? operatingRegion,
    bool? profileCompleted,
  }) {
    return AppUser(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      role: role ?? this.role,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      companyName: companyName ?? this.companyName,
      operatingRegion: operatingRegion ?? this.operatingRegion,
      profileCompleted: profileCompleted ?? this.profileCompleted,
    );
  }
}
