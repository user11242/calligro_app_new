/**
 * One-off: move teachers' bank / CliQ details OFF the public user documents.
 *
 * Old app versions saved `payoutSettings` (IBAN, address, CliQ alias) on
 * users/{uid} and teachers/{uid}, which anyone can read. This copies it to
 * users/{uid}/private/payout (owner + admins only) and deletes the public copies.
 *
 *   Dry run (changes nothing, prints what it would do):
 *     node migrations/migrate_payout_private.js
 *   Apply:
 *     node migrations/migrate_payout_private.js --apply
 *
 *   COPY ONLY (while old app versions are still in use): adds --keep-public, so the
 *   private copy is created and the public copies are left in place (the old app only
 *   opens "Add Course" when they exist). Run the full move after the forced update.
 *     node migrations/migrate_payout_private.js --keep-public            (dry run)
 *     node migrations/migrate_payout_private.js --keep-public --apply
 *
 * Safe to run more than once. If a private payout document already exists
 * (saved by the new app), it is kept and only the public copies are removed.
 * Uses the Admin SDK (bypasses rules): run with credentials for the project,
 * e.g. `gcloud auth application-default login` + GOOGLE_CLOUD_PROJECT=<id>.
 */
const admin = require('firebase-admin');

async function migratePayoutToPrivate(db, { apply = false, keepPublic = false, log = console.log } = {}) {
  const { FieldValue } = admin.firestore;
  const report = { checked: 0, moved: 0, keptExisting: 0, cleaned: 0 };

  // Every uid that has payoutSettings on either public document.
  const legacy = new Map(); // uid → payoutSettings (users copy preferred)
  const holders = new Map(); // uid → refs that still carry the field
  for (const collection of ['users', 'teachers']) {
    const snap = await db.collection(collection).get();
    for (const doc of snap.docs) {
      report.checked++;
      const payout = doc.get('payoutSettings');
      if (payout === undefined) continue;
      if (!legacy.has(doc.id) || collection === 'users') {
        if (payout !== null) legacy.set(doc.id, payout);
      }
      holders.set(doc.id, [...(holders.get(doc.id) || []), doc.ref]);
    }
  }

  for (const [uid, refs] of holders) {
    const privateRef = db.doc(`users/${uid}/private/payout`);
    const existing = await privateRef.get();
    const payout = legacy.get(uid);
    const action = existing.exists ? 'keep private copy' : payout ? (keepPublic ? 'copy to private' : 'move to private') : 'nothing to move';
    const publicPart = keepPublic ? 'public copy kept' : `remove public copy from ${refs.map((r) => r.parent.id).join(' + ')}`;
    log(`${uid}: ${action}; ${publicPart}`);

    if (!apply) continue;
    const batch = db.batch();
    if (!existing.exists && payout) {
      batch.set(privateRef, { ...payout, migratedAt: FieldValue.serverTimestamp() });
    }
    if (!keepPublic) {
      for (const ref of refs) batch.update(ref, { payoutSettings: FieldValue.delete() });
    }
    await batch.commit();

    if (existing.exists) report.keptExisting++;
    else if (payout) report.moved++;
    if (!keepPublic) report.cleaned += refs.length;
  }

  log(`${apply ? 'APPLIED' : 'DRY RUN'}${keepPublic ? ' (copy only)' : ''}: ${holders.size} teacher(s) with public payout data; ` +
    `${keepPublic ? 'copied' : 'moved'} ${report.moved}, kept existing ${report.keptExisting}, public copies removed ${report.cleaned}`);
  return { ...report, found: holders.size };
}

module.exports = { migratePayoutToPrivate };

if (require.main === module) {
  admin.initializeApp();
  const apply = process.argv.includes('--apply');
  const keepPublic = process.argv.includes('--keep-public');
  migratePayoutToPrivate(admin.firestore(), { apply, keepPublic })
    .then(() => process.exit(0))
    .catch((e) => {
      console.error(e);
      process.exit(1);
    });
}
