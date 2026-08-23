import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/data/auth_repository.dart';
import '../models/contact_exchange_model.dart';
import '../utils/logger_service.dart';

// ── Riverpod Providers ────────────────────────────────────────────────────────

final contactExchangeRepositoryProvider = Provider<ContactExchangeRepository>((ref) {
  final logger = ref.watch(loggerProvider);
  return ContactExchangeRepository(FirebaseFirestore.instance, logger);
});

/// Streams the Contact Exchange document for a given [bookingId].
///
/// Returns:
///   - `null`  — document does not exist (first-time or already deleted)
///   - non-null — decoded [ContactExchangeModel]
///
/// Access is gated by Firestore security rules:
///   - Truck Owner can watch their own exchange at any status.
///   - Provider can only watch after status == 'accepted'.
///   - Any other UID receives permission-denied (surfaced as an AsyncError).
///
/// The provider uses `authStateProvider` to short-circuit if the user is
/// unauthenticated, returning an empty stream rather than hitting Firestore.
final contactExchangeProvider =
    StreamProvider.autoDispose.family<ContactExchangeModel?, String>((ref, bookingId) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return const Stream.empty();

  final repo = ref.watch(contactExchangeRepositoryProvider);
  return repo.watchContactExchange(bookingId).handleError((Object e, StackTrace st) {
    if (kDebugMode) {
      debugPrint('STREAM ERROR [contactExchangeProvider/$bookingId]: $e');
    }
  });
});

// ── Repository ────────────────────────────────────────────────────────────────

class ContactExchangeRepository {
  final FirebaseFirestore _firestore;
  final LoggerService _logger;

  ContactExchangeRepository(this._firestore, this._logger);

  CollectionReference get _exchanges => _firestore.collection('contact_exchanges');

  /// Watches a single [contact_exchanges/{bookingId}] document in realtime.
  ///
  /// This is a point-read — it never queries the entire collection.
  /// Firestore security rules enforce who is permitted to receive data.
  ///
  /// Emits `null` when the document does not exist (e.g. before the Truck
  /// Owner's first booking request is committed, or after deletion).
  Stream<ContactExchangeModel?> watchContactExchange(String bookingId) {
    _logger.debug(
      'Attaching realtime listener to contact_exchanges/$bookingId',
      tag: 'ContactExchangeRepository',
    );

    return _exchanges.doc(bookingId).snapshots().map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) {
        _logger.debug(
          'contact_exchanges/$bookingId does not exist — emitting null',
          tag: 'ContactExchangeRepository',
        );
        return null;
      }

      try {
        final model = ContactExchangeModel.fromJson(
          snapshot.data()! as Map<String, dynamic>,
          snapshot.id,
        );
        _logger.debug(
          'contact_exchanges/$bookingId received — status: ${model.status}',
          tag: 'ContactExchangeRepository',
        );
        return model;
      } catch (e, st) {
        _logger.error(
          'Failed to deserialize contact_exchanges/$bookingId',
          tag: 'ContactExchangeRepository',
          error: e,
          stackTrace: st,
        );
        // Return null on deserialization failure rather than crashing the stream.
        return null;
      }
    });
  }
}
