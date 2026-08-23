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
  const unrelatedAuth = { uid: 'evil789', token: { phone_number: '+910000000000' } };

  const truckContext = testEnv.authenticatedContext('truck456', truckOwnerAuth);
  const providerContext = testEnv.authenticatedContext('prov123', providerAuth);
  const unrelatedContext = testEnv.authenticatedContext('evil789', unrelatedAuth);

  const bookingId = 'load1_truck456';
  
  // Need to bypass rules to set up the load and booking for test
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await db.collection('loads').doc('load1').set({ status: 'open', providerUid: 'prov123' });
    // To test getAfter, we should actually perform a batch in the test context.
    // Wait, getAfter evaluates the batch.
  });

  console.log("Setup complete");
  // 1. Fake truckOwnerPhone
  let dbTruck = truckContext.firestore();
  let p1 = assertFails(dbTruck.collection('contact_exchanges').doc(bookingId).set({
    bookingId: bookingId,
    loadId: 'load1',
    truckOwnerUid: 'truck456',
    truckOwnerPhone: '+910000000000', // Fake
    providerUid: 'prov123',
    status: 'pending'
  }));

  try { await p1; console.log("1 PASS"); } catch (e) { console.log("1 FAIL", e); }

  console.log("Tests finished.");
  process.exit(0);
}

main().catch(console.error);
