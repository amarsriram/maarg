# Phase 3A — Payment V1 Audit Report
**Focus:** Cash Settlement Tracking (Read-Only Audit)

## 1. Current Architecture Relevant to Payments
The existing system relies on three main collections for a trip's lifecycle: `loads`, `bookings`, and `trips`.
- **Relationship Establishment:** The Provider-Truck Owner relationship is cemented via atomic transactions in `TripOperationsService.acceptBooking`, generating a deterministic `bookingId` (`{loadId}_{truckOwnerUid}`) and assigning the `truckOwnerUid` to the `loads` document.
- **Trip Lifecycle:** The operational state (e.g., `in_transit`, `delivered`) is tracked in `loads/{loadId}` via the `status` field, driven by the Truck Owner in `TripsTab`.
- **Security Context:** Currently, `firestore.rules` heavily protects `contact_exchanges`, but `loads`, `bookings`, and `trips` operate on a wide-open authenticated basis (`allow read, write: if request.auth != null;`). 

## 2. Authoritative Trip-Delivered State
The source of truth for the "Delivered" state is the **`loads/{loadId}`** document, specifically when its `status` field equals `"delivered"`. This is enforced by `TripStatusExtension.fromString(status) == TripStatus.delivered`.

## 3. Authoritative Agreed Amount
The agreed trip amount is authored as the **`budget`** field (a String) on the **`loads/{loadId}`** document. While this is duplicated onto the `bookings/{bookingId}` document during the request phase, the `loads` document remains the authoritative source that both parties reference post-acceptance.

## 4. Recommended Payment Document/Schema
**Decision:** A dedicated `payments/{loadId}` document is absolutely the correct approach, strongly preferred over adding fields to `loads` or `bookings`.
**Why:** Because the existing `loads` and `bookings` collections are currently open to any authenticated user. Adding financial data there would violate the constraint that "Amount and payment method must not be arbitrarily modified". A dedicated `payments` collection allows us to implement strict, isolated RBAC (Role-Based Access Control) without disrupting legacy logic.

**Proposed Schema (`payments/{loadId}`):**
```json
{
  "paymentId": "{loadId}",
  "loadId": "{loadId}",
  "providerUid": "...",
  "truckOwnerUid": "...",
  "amount": "8000",       // Copied securely from loads/{loadId}.budget
  "currency": "INR",
  "paymentMethod": "CASH",
  "status": "marked_paid",// Transitions: marked_paid -> confirmed | disputed
  "markedPaidAt": "timestamp",
  "markedPaidBy": "uid",
  "confirmedAt": null,
  "confirmedBy": null,
  "disputedAt": null,
  "disputedBy": null
}
```

## 5. Recommended Repository/Provider Architecture
- Create `lib/core/repositories/payment_repository.dart`.
- Expose a `paymentStreamProvider(String loadId)` to provide real-time UI updates.
- The repository will implement `markAsPaid()`, `confirmPayment()`, and `disputePayment()` using Firestore `runTransaction` blocks to ensure atomic updates and prevent race conditions.

## 6. Recommended Security-Rule Structure
We must append a new `match /payments/{paymentId}` block to `firestore.rules`.
- **Read:** `allow read: if request.auth != null && request.auth.uid in [resource.data.providerUid, resource.data.truckOwnerUid];` (Prevents collection-wide scraping).
- **Create (Provider):** `allow create: if request.auth.uid == request.resource.data.providerUid && get(/databases/$(database)/documents/loads/$(paymentId)).data.status == 'delivered' && request.resource.data.status == 'marked_paid' && request.resource.data.paymentMethod == 'CASH';`
- **Update (Truck Owner):** `allow update: if request.auth.uid == resource.data.truckOwnerUid && resource.data.status == 'marked_paid' && (request.resource.data.status == 'confirmed' || request.resource.data.status == 'disputed') && request.resource.data.amount == resource.data.amount;` (Prevents forging, amount tampering, and illegal state transitions).

## 7. Exact Provider UI Integration Point
**File:** `lib/features/dashboard/presentation/load_detail_screen.dart`
**Location:** Directly below the `TripProgressTimeline` widget.
**Logic:** Conditionally render a new `PaymentActionCard` if `load.tripStatus == TripStatus.delivered` (or `completed`). The card watches `paymentStreamProvider(load.loadId)`. If no document exists (the "pending" state), it displays the "Mark as Paid (Cash)" action button.

## 8. Exact Truck Owner UI Integration Point
**File:** `lib/features/truck_owner/presentation/tabs/trips_tab.dart`
**Location:** Inside `_ActiveTripWorkspace`.
**Logic:** The workspace currently determines actions via `_currentActionState`. After delivery, `_currentActionState` yields `null`. We will inject a `PaymentConfirmationCard` at the bottom of the workspace that listens to `paymentStreamProvider(activeTrip.loadId)`. When the state is `marked_paid`, it renders the "Confirm Payment Received" and "Report Payment Issue" buttons.

## 9. Notification Integration Point
Reusing the existing `NotificationModel` and `notifications` collection is trivial and robust. Inside the `PaymentRepository` transactions, we will add batched writes:
- `markAsPaid` -> Sends `PAYMENT_MARKED_PAID` notification to Truck Owner.
- `confirmPayment` -> Sends `PAYMENT_CONFIRMED` notification to Provider.
- `disputePayment` -> Sends `PAYMENT_DISPUTED` notification to Provider.

## 10. Required State-Transition Transaction Design
Since we **cannot** modify the existing booking acceptance logic, the payment lifecycle cannot be physically instantiated as `pending` upon booking. 
- **Virtual Pending State:** The absence of a `payments/{loadId}` document equates to "pending".
- **Transition 1 (Provider marks paid):** A Firestore transaction verifies the `loads` document is `delivered`, then `set()` creates the `payments` document with status `marked_paid`.
- **Transition 2 (Truck Owner confirms):** A Firestore transaction verifies the payment is `marked_paid`, then `update()` changes it to `confirmed`.

## 11. Required Tests and Security Cases
- **Logic Tests (`test/core/payments/payment_repository_test.dart`):** Verify `markAsPaid` throws if trip isn't delivered; verify `confirmPayment` throws if not `marked_paid`.
- **Security Simulator Tests:**
  - Provider CANNOT confirm their own payment.
  - Truck Owner CANNOT mark as paid.
  - Provider CANNOT mark as paid before `TripStatus.delivered`.
  - Neither party can change the `amount` field during an update.
  - Unrelated authenticated users CANNOT read the payment document.

## 12. Architectural Risks & Ambiguities Discovered
1. **Implicit Trust in `loads` Status:** Because `loads/{loadId}` currently has `allow read, write: if request.auth != null`, a malicious user could artificially advance the trip status to `delivered` or change the `budget`, bypassing our payment timing checks. Re-securing `loads` is critical technical debt, though technically out-of-scope for Payment V1.
2. **Decoupled Completion:** Currently, the Provider explicitly confirms trip completion (`TripStatus.completed`) in `TripOperationsService`. The requirements do not specify if `TripStatus.completed` should be blocked until payment is `confirmed`. I recommend treating them as independent for V1 (allow trip completion even if payment is disputed) to avoid breaking existing lifecycle logic constraints.
3. **Dispute Resolution:** The prompt requires that `marked_paid -> disputed` is valid, and "A disputed payment must not silently become confirmed." However, there is no specified mechanism for resolving a dispute. I recommend that a `disputed` state is terminal for V1, requiring manual support intervention, to avoid scope creep.
