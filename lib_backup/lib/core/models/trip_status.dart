enum TripStatus {
  open,
  requested,
  assigned,
  en_route_pickup,
  loaded,
  in_transit,
  delivered,
  completed,
  cancelled,
  disputed
}

extension TripStatusExtension on TripStatus {
  String get displayName {
    switch (this) {
      case TripStatus.open:
        return 'Open';
      case TripStatus.requested:
        return 'Requested';
      case TripStatus.assigned:
        return 'Assigned';
      case TripStatus.en_route_pickup:
        return 'En Route to Pickup';
      case TripStatus.loaded:
        return 'Loaded';
      case TripStatus.in_transit:
        return 'In Transit';
      case TripStatus.delivered:
        return 'Delivered';
      case TripStatus.completed:
        return 'Completed';
      case TripStatus.cancelled:
        return 'Cancelled';
      case TripStatus.disputed:
        return 'Disputed';
    }
  }

  String get firestoreKey {
    return name;
  }

  static TripStatus fromString(String? statusStr) {
    switch (statusStr) {
      case 'open':
        return TripStatus.open;
      case 'requested':
        return TripStatus.requested;
      case 'assigned':
      case 'booked': // Keep backwards compatibility with old data
        return TripStatus.assigned;
      case 'en_route_pickup':
      case 'dispatched': // Backwards compatibility
        return TripStatus.en_route_pickup;
      case 'loaded':
        return TripStatus.loaded;
      case 'in_transit':
        return TripStatus.in_transit;
      case 'delivered':
      case 'arrived': // Backwards compatibility
      case 'unloading': // Backwards compatibility
        return TripStatus.delivered;
      case 'completed':
        return TripStatus.completed;
      case 'cancelled':
        return TripStatus.cancelled;
      case 'disputed':
        return TripStatus.disputed;
      default:
        return TripStatus.open;
    }
  }

  bool canTransitionTo(TripStatus nextStatus) {
    // Defines the valid state machine transitions
    switch (this) {
      case TripStatus.open:
        return nextStatus == TripStatus.requested || nextStatus == TripStatus.assigned || nextStatus == TripStatus.cancelled;
      case TripStatus.requested:
        return nextStatus == TripStatus.assigned || nextStatus == TripStatus.open || nextStatus == TripStatus.cancelled;
      case TripStatus.assigned:
        return nextStatus == TripStatus.en_route_pickup || nextStatus == TripStatus.cancelled;
      case TripStatus.en_route_pickup:
        return nextStatus == TripStatus.loaded || nextStatus == TripStatus.cancelled || nextStatus == TripStatus.disputed;
      case TripStatus.loaded:
        return nextStatus == TripStatus.in_transit || nextStatus == TripStatus.disputed;
      case TripStatus.in_transit:
        return nextStatus == TripStatus.delivered || nextStatus == TripStatus.disputed;
      case TripStatus.delivered:
        return nextStatus == TripStatus.completed || nextStatus == TripStatus.disputed;
      case TripStatus.completed:
        return false; // Terminal state
      case TripStatus.cancelled:
        return false; // Terminal state
      case TripStatus.disputed:
        // Disputed could theoretically transition back to a previous state or completed after resolution
        return nextStatus == TripStatus.completed || nextStatus == TripStatus.cancelled;
    }
  }
}
