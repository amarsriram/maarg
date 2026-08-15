enum BookingStatus {
  pending,
  confirmed,
  completed,
  cancelled,
}

extension BookingStatusExtension on BookingStatus {
  String get displayName {
    switch (this) {
      case BookingStatus.pending:
        return 'Pending Approval';
      case BookingStatus.confirmed:
        return 'Confirmed / Booked';
      case BookingStatus.completed:
        return 'Trip Completed';
      case BookingStatus.cancelled:
        return 'Cancelled';
    }
  }
}

class Booking {
  final String id;
  final String truckRouteId;
  final String supplierId;
  final String supplierName;
  final String supplierCompanyName;
  final String companyName; // Truck owner company
  final String source;
  final String destination;
  final DateTime date;
  final double price; // Base Freight
  final double brokerCommission; // 5% fee
  final BookingStatus status;
  final String vehicleNumber;
  final DateTime bookingDate;

  const Booking({
    required this.id,
    required this.truckRouteId,
    required this.supplierId,
    required this.supplierName,
    required this.supplierCompanyName,
    required this.companyName,
    required this.source,
    required this.destination,
    required this.date,
    required this.price,
    required this.brokerCommission,
    required this.status,
    required this.vehicleNumber,
    required this.bookingDate,
  });

  Booking copyWith({
    String? id,
    String? truckRouteId,
    String? supplierId,
    String? supplierName,
    String? supplierCompanyName,
    String? companyName,
    String? source,
    String? destination,
    DateTime? date,
    double? price,
    double? brokerCommission,
    BookingStatus? status,
    String? vehicleNumber,
    DateTime? bookingDate,
  }) {
    return Booking(
      id: id ?? this.id,
      truckRouteId: truckRouteId ?? this.truckRouteId,
      supplierId: supplierId ?? this.supplierId,
      supplierName: supplierName ?? this.supplierName,
      supplierCompanyName: supplierCompanyName ?? this.supplierCompanyName,
      companyName: companyName ?? this.companyName,
      source: source ?? this.source,
      destination: destination ?? this.destination,
      date: date ?? this.date,
      price: price ?? this.price,
      brokerCommission: brokerCommission ?? this.brokerCommission,
      status: status ?? this.status,
      vehicleNumber: vehicleNumber ?? this.vehicleNumber,
      bookingDate: bookingDate ?? this.bookingDate,
    );
  }
}
