const { initializeTestEnvironment, assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const fs = require('fs');

async function main() {
  const testEnv = await initializeTestEnvironment({
    projectId: 'maarg-527b0',
    firestore: {
      rules: fs.readFileSync('../firestore.rules', 'utf8'),
      host: '127.0.0.1',
      port: 8080
    }
  });

  const truckOwnerAuth = { uid: 'truck456', token: { phone_number: '+918888888888' } };
  const providerAuth = { uid: 'prov123', token: { phone_number: '+919999999999' } };
  
  const truckContext = testEnv.authenticatedContext('truck456', truckOwnerAuth);
  const providerContext = testEnv.authenticatedContext('prov123', providerAuth);
  
  const bookingId = 'load1_truck456';

  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await db.collection('loads').doc('load1').set({ status: 'open', providerUid: 'prov123' });
  });

  let passCount = 0;
  let failCount = 0;

  function report(name, isSuccess) {
    if (isSuccess) {
      console.log(`PASS: ${name}`);
      passCount++;
    } else {
      console.log(`FAIL: ${name}`);
      failCount++;
    }
  }

  const truckDb = truckContext.firestore();
  const provDb = providerContext.firestore();

  // Test 1: First-time requestBooking() can create the contact exchange atomically
  // The SDK simulates the atomic getAfter validation via batches
  const batch = truckDb.batch();
  batch.set(truckDb.collection('bookings').doc(bookingId), {
    status: 'pending',
    truckOwnerUid: 'truck456',
    providerUid: 'prov123',
    loadId: 'load1'
  });
  batch.set(truckDb.collection('contact_exchanges').doc(bookingId), {
    bookingId: bookingId,
    loadId: 'load1',
    truckOwnerUid: 'truck456',
    truckOwnerPhone: '+918888888888',
    providerUid: 'prov123',
    status: 'pending'
  });
  try { await assertSucceeds(batch.commit()); report('1. Truck Owner creates exchange atomically', true); }
  catch(e) { report('1. Truck Owner creates exchange atomically', false); console.log(e); }

  // Test 2: Pending exchange cannot be read by Provider
  try { await assertFails(provDb.collection('contact_exchanges').doc(bookingId).get()); report('2. Provider cannot read pending', true); }
  catch(e) { report('2. Provider cannot read pending', false); console.log(e); }

  // Test 3: Truck Owner cannot forge phone
  const badBatch1 = truckDb.batch();
  badBatch1.set(truckDb.collection('bookings').doc('b2'), { status: 'pending', truckOwnerUid: 'truck456', providerUid: 'prov123', loadId: 'load2' });
  badBatch1.set(truckDb.collection('contact_exchanges').doc('b2'), {
    bookingId: 'b2', loadId: 'load2', truckOwnerUid: 'truck456', truckOwnerPhone: '+910000000000', providerUid: 'prov123', status: 'pending'
  });
  try { await assertFails(badBatch1.commit()); report('3. Truck Owner cannot forge phone', true); }
  catch(e) { report('3. Truck Owner cannot forge phone', false); console.log(e); }

  // Test 4: Provider cannot forge phone during acceptance
  const badBatch2 = provDb.batch();
  badBatch2.update(provDb.collection('bookings').doc(bookingId), { status: 'accepted' });
  badBatch2.update(provDb.collection('contact_exchanges').doc(bookingId), {
    status: 'accepted',
    providerPhone: '+910000000000',
    truckOwnerUid: 'truck456',
    truckOwnerPhone: '+918888888888',
    bookingId: bookingId,
    loadId: 'load1',
    providerUid: 'prov123'
  });
  try { await assertFails(badBatch2.commit()); report('4. Provider cannot forge phone', true); }
  catch(e) { report('4. Provider cannot forge phone', false); console.log(e); }

  // Test 5: Valid Provider acceptance works
  const goodBatch = provDb.batch();
  goodBatch.update(provDb.collection('bookings').doc(bookingId), { status: 'accepted' });
  goodBatch.update(provDb.collection('contact_exchanges').doc(bookingId), {
    status: 'accepted',
    providerPhone: '+919999999999',
    truckOwnerUid: 'truck456',
    truckOwnerPhone: '+918888888888',
    bookingId: bookingId,
    loadId: 'load1',
    providerUid: 'prov123'
  });
  try { await assertSucceeds(goodBatch.commit()); report('5. Provider valid acceptance', true); }
  catch(e) { report('5. Provider valid acceptance', false); console.log(e); }

  // Test 6: Correct participants can read accepted exchange
  try { await assertSucceeds(provDb.collection('contact_exchanges').doc(bookingId).get()); report('6. Provider can read accepted', true); }
  catch(e) { report('6. Provider can read accepted', false); console.log(e); }

  // Test 7: Immutable fields cannot be modified
  try { 
    await assertFails(provDb.collection('contact_exchanges').doc(bookingId).update({
      truckOwnerPhone: '+911111111111'
    })); 
    report('7. Immutable fields protected', true); 
  }
  catch(e) { report('7. Immutable fields protected', false); console.log(e); }

  // Test 8: Invalid state transition blocked
  try {
    await assertFails(truckDb.collection('contact_exchanges').doc(bookingId).update({
      status: 'withdrawn' // already accepted, transition from pending only
    }));
    report('8. Invalid state transition blocked', true);
  }
  catch(e) { report('8. Invalid state transition blocked', false); console.log(e); }

  console.log(`\nTests finished. ${passCount} passed, ${failCount} failed.`);
  
  // Cleanup test env
  await testEnv.cleanup();
}

main().catch(console.error);
