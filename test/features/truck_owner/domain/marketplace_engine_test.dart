import 'package:flutter_test/flutter_test.dart';
import 'package:maarg/core/models/load_model.dart';
import 'package:maarg/features/truck_owner/presentation/tabs/loads_tab.dart';

void main() {
  group('Marketplace Engine & Filter Logic', () {
    // ── MOCK DATA ────────────────────────────────────────────────────────────

    final load1 = LoadModel(
      loadId: '1',
      pickupLocation: 'Bengaluru, Karnataka',
      dropLocation: 'Visakhapatnam, Andhra Pradesh',
      truckType: 'Mini Truck',
      materialType: 'Cement',
      weight: '2 Tons',
      budget: '₹5000',
      pickupDate: '2026-10-15T10:00:00Z',
      createdAt: '2026-08-01T10:00:00Z',
      status: 'open',
      providerId: 'p1',
      companyName: 'Company A',
      companyRating: 4.5,
      materialImage: '',
      specialInstructions: '',
    );

    final load2 = LoadModel(
      loadId: '2',
      pickupLocation: 'bengaluru, KA ', // Test normalization
      dropLocation: 'Visakhapatnam, AP',
      truckType: '14 ft Open Body',     // Custom string preservation
      materialType: 'Steel',
      weight: '5 Tons',
      budget: '₹8000',
      pickupDate: '2026-10-16T10:00:00Z',
      createdAt: '2026-08-02T10:00:00Z',
      status: 'open',
      providerId: 'p2',
      companyName: 'Company B',
      companyRating: 4.0,
      materialImage: '',
      specialInstructions: '',
    );

    final load3 = LoadModel(
      loadId: '3',
      pickupLocation: 'Chennai, Tamil Nadu',
      dropLocation: 'Hyderabad, Telangana',
      truckType: 'Mini Truck',
      materialType: 'Cement',
      weight: '1 Ton',
      budget: '', // Missing budget
      pickupDate: '', // Missing date
      createdAt: '2026-08-03T10:00:00Z',
      status: 'open',
      providerId: 'p3',
      companyName: 'Company C',
      companyRating: 4.8,
      materialImage: '',
      specialInstructions: '',
    );
    
    final load4 = LoadModel(
      loadId: '4',
      pickupLocation: 'Bengaluru, Karnataka',
      dropLocation: 'Hyderabad, Telangana',
      truckType: 'Heavy Truck',
      materialType: 'Wood',
      weight: '10 Tons',
      budget: 'invalid_budget_string', // Invalid budget
      pickupDate: 'invalid_date_string', // Invalid date
      createdAt: '2026-08-04T10:00:00Z',
      status: 'open',
      providerId: 'p4',
      companyName: 'Company D',
      companyRating: 3.5,
      materialImage: '',
      specialInstructions: '',
    );

    final allLoads = [load1, load2, load3, load4];

    // ── FILTERING TESTS ──────────────────────────────────────────────────────
    
    test('A. No filters -> all open loads returned', () {
      final state = LoadFilterState();
      final result = MarketplaceEngine.apply(allLoads, state);
      expect(result.length, 4);
    });

    test('B. Pickup filter -> only matching pickup', () {
      final state = LoadFilterState(pickupCities: {'Bengaluru'});
      final result = MarketplaceEngine.apply(allLoads, state);
      expect(result.length, 3); // load1, load2, load4
    });

    test('C. Drop filter -> only matching drop', () {
      final state = LoadFilterState(dropCities: {'Visakhapatnam'});
      final result = MarketplaceEngine.apply(allLoads, state);
      expect(result.length, 2); // load1, load2
    });

    test('D. Vehicle filter -> exact vehicle matching', () {
      final state = LoadFilterState(vehicles: {'14 ft Open Body'});
      final result = MarketplaceEngine.apply(allLoads, state);
      expect(result.length, 1);
      expect(result.first.loadId, '2');
    });

    test('E. Multiple vehicles -> OR semantics', () {
      final state = LoadFilterState(vehicles: {'Mini Truck', '14 ft Open Body'});
      final result = MarketplaceEngine.apply(allLoads, state);
      expect(result.length, 3); // load1, load2, load3
    });

    test('F. Multiple cargo values -> OR semantics', () {
      final state = LoadFilterState(cargo: {'Cement', 'Wood'});
      final result = MarketplaceEngine.apply(allLoads, state);
      expect(result.length, 3); // load1, load3, load4
    });

    test('G. Pickup + Drop -> AND semantics', () {
      final state = LoadFilterState(pickupCities: {'Bengaluru'}, dropCities: {'Hyderabad'});
      final result = MarketplaceEngine.apply(allLoads, state);
      expect(result.length, 1);
      expect(result.first.loadId, '4');
    });

    test('H. Pickup + Vehicle + Cargo -> AND across groups', () {
      final state = LoadFilterState(
        pickupCities: {'Bengaluru'},
        vehicles: {'Mini Truck'},
        cargo: {'Cement'}
      );
      final result = MarketplaceEngine.apply(allLoads, state);
      expect(result.length, 1);
      expect(result.first.loadId, '1');
    });

    test('I. Invalid/missing data -> no crashes', () {
      // load3 has empty date, load4 has invalid date
      final state = LoadFilterState(pickupDates: {'2026-10-15'});
      final result = MarketplaceEngine.apply(allLoads, state);
      expect(result.length, 1); // load1
    });

    test('T. Multiple simultaneous filters & X. Case/whitespace normalization', () {
      // test case insensitivity and whitespace normalization handled natively by the engine matching
      final state = LoadFilterState(pickupCities: {'bengaluru'}, dropCities: {'visakhapatnam'});
      final result = MarketplaceEngine.apply(allLoads, state);
      expect(result.length, 2); // load1, load2
    });

    // ── SORTING TESTS ────────────────────────────────────────────────────────

    test('J. Highest Payout -> numeric descending & L. Missing budget sorted last', () {
      final sorted = MarketplaceEngine.sort(allLoads, LoadSortMode.highestPayout);
      expect(sorted[0].loadId, '2'); // 8000
      expect(sorted[1].loadId, '1'); // 5000
      // 3 and 4 have invalid/missing, should be at bottom
      expect(['3', '4'].contains(sorted[2].loadId), true);
      expect(['3', '4'].contains(sorted[3].loadId), true);
    });

    test('K. Earliest Pickup -> chronological ascending & M. Missing pickupDate sorted last', () {
      final sorted = MarketplaceEngine.sort(allLoads, LoadSortMode.earliestPickup);
      expect(sorted[0].loadId, '1'); // Oct 15
      expect(sorted[1].loadId, '2'); // Oct 16
      expect(['3', '4'].contains(sorted[2].loadId), true);
      expect(['3', '4'].contains(sorted[3].loadId), true);
    });

    test('N. Recent -> preserves original stream order', () {
      final sorted = MarketplaceEngine.sort(allLoads, LoadSortMode.recent);
      expect(sorted[0].loadId, '1');
      expect(sorted[1].loadId, '2');
      expect(sorted[2].loadId, '3');
      expect(sorted[3].loadId, '4');
    });

    // ── FACET TESTS ──────────────────────────────────────────────────────────

    test('O. Facet calculation -> excludes its own active constraint', () {
      final state = LoadFilterState(pickupCities: {'Chennai'}); // normally excludes Bengaluru loads
      
      // If we ask for available Pickups, it should IGNORE the Pickup constraint
      // so it should return ALL pickups available across the dataset.
      final pickups = MarketplaceFacets.getContextualPickups(allLoads, state);
      expect(pickups.contains('Bengaluru'), true);
      expect(pickups.contains('Chennai'), true);
      
      // But if we ask for Drops, it SHOULD apply the Pickup constraint (Chennai)
      // Chennai only drops in Hyderabad
      final drops = MarketplaceFacets.getContextualDrops(allLoads, state);
      expect(drops, ['Hyderabad']); 
    });

    test('P. Contextual Drop options after Pickup selection', () {
      final state = LoadFilterState(pickupCities: {'Bengaluru'});
      final drops = MarketplaceFacets.getContextualDrops(allLoads, state);
      // Bengaluru drops in Visakhapatnam and Hyderabad
      expect(drops.length, 2);
      expect(drops.contains('Visakhapatnam'), true);
      expect(drops.contains('Hyderabad'), true);
    });

    test('Q. Contextual Vehicle options after Pickup + Drop', () {
      final state = LoadFilterState(pickupCities: {'Bengaluru'}, dropCities: {'Visakhapatnam'});
      final vehicles = MarketplaceFacets.getContextualVehicles(allLoads, state);
      expect(vehicles.length, 2);
      expect(vehicles.contains('Mini Truck'), true);
      expect(vehicles.contains('14 ft Open Body'), true);
    });

    test('R. Contextual Cargo options after Pickup + Drop + Vehicle', () {
      final state = LoadFilterState(
        pickupCities: {'Bengaluru'}, 
        dropCities: {'Visakhapatnam'},
        vehicles: {'14 ft Open Body'}
      );
      final cargo = MarketplaceFacets.getContextualCargo(allLoads, state);
      expect(cargo, ['Steel']); // Only Steel is carried by 14ft open body from BLR to VZG
    });

    test('V. Custom vehicle value exactly preserved & W. Deduplication', () {
      final vocab = MarketplaceVocab.from(allLoads);
      expect(vocab.vehicles.contains('14 ft Open Body'), true);
      expect(vocab.vehicles.length, 3); // Mini Truck (duplicated in data but deduped here), 14 ft Open Body, Heavy Truck
    });

    // ── ZERO MATCH RELAXATION ────────────────────────────────────────────────

    test('S. Zero-match relaxation', () {
      // Impossible combination
      final state = LoadFilterState(
        pickupCities: {'Chennai'},
        vehicles: {'14 ft Open Body'}
      );
      
      final results = MarketplaceEngine.apply(allLoads, state);
      expect(results.isEmpty, true);

      final relaxation = MarketplaceEngine.relaxationAnalysis(allLoads, state);
      // Removing Chennai -> leaves 14ft Open Body -> which has 1 match (load2)
      // Removing 14ft Open Body -> leaves Chennai -> which has 1 match (load3)
      expect(relaxation.containsKey('Remove Pickup'), true);
      expect(relaxation['Remove Pickup'], 1);
      
      expect(relaxation.containsKey('Remove Vehicle'), true);
      expect(relaxation['Remove Vehicle'], 1);
    });

  });
}
