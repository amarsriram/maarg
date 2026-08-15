enum TruckStatus {
  available,
  booked,
  completed,
}

class TruckRoute {
  final String id;
  final String ownerId;
  final String ownerName;
  final String companyName;
  final String source;
  final String destination;
  final DateTime date;
  final String truckType;
  final double capacity; // in tons
  final double price; // rate in INR or local currency
  final String vehicleNumber;
  final String contactNumber;
  final TruckStatus status;

  const TruckRoute({
    required this.id,
    required this.ownerId,
    required this.ownerName,
    required this.companyName,
    required this.source,
    required this.destination,
    required this.date,
    required this.truckType,
    required this.capacity,
    required this.price,
    required this.vehicleNumber,
    required this.contactNumber,
    this.status = TruckStatus.available,
  });

  TruckRoute copyWith({
    String? id,
    String? ownerId,
    String? ownerName,
    String? companyName,
    String? source,
    String? destination,
    DateTime? date,
    String? truckType,
    double? capacity,
    double? price,
    String? vehicleNumber,
    String? contactNumber,
    TruckStatus? status,
  }) {
    return TruckRoute(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      ownerName: ownerName ?? this.ownerName,
      companyName: companyName ?? this.companyName,
      source: source ?? this.source,
      destination: destination ?? this.destination,
      date: date ?? this.date,
      truckType: truckType ?? this.truckType,
      capacity: capacity ?? this.capacity,
      price: price ?? this.price,
      vehicleNumber: vehicleNumber ?? this.vehicleNumber,
      contactNumber: contactNumber ?? this.contactNumber,
      status: status ?? this.status,
    );
  }
}
