/**
 * firestore.rules for editing your own profile (the writes
 * lib/features/profile/data/firestore_profile_editor.dart makes), on the emulator.
 */
const fs = require('fs');
const path = require('path');
const { assertFails, assertSucceeds, initializeTestEnvironment } = require('@firebase/rules-unit-testing');
const { doc, setDoc, updateDoc, deleteDoc, writeBatch, serverTimestamp } = require('firebase/firestore');

let env;
const as = (uid) => env.authenticatedContext(uid).firestore();

beforeAll(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-calligro-profile',
    firestore: { host: '127.0.0.1', port: 8080, rules: fs.readFileSync(path.join(__dirname, '../../firestore.rules'), 'utf8') },
  });
});
afterAll(() => env.cleanup());

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'users/t1'), { name: 'Ali Hassan', role: 'teacher', status: 'approved', commissionRate: 0.6 });
    await setDoc(doc(db, 'teachers/t1'), { role: 'teacher', status: 'approved' });
    await setDoc(doc(db, 'users/s1'), { name: 'Old Student', role: 'student' });
    await setDoc(doc(db, 'students/s1'), { role: 'student' });
    await setDoc(doc(db, 'locked_usernames/ali hassan'), { uid: 't1' });
    await setDoc(doc(db, 'locked_usernames/taken'), { uid: 'someone' });
    await setDoc(doc(db, 'locked_phones/+962791234567'), { uid: 't1' });
  });
});

const profile = (extra = {}) => ({ name: 'Omar', name_lower: 'omar', bio: 'Hi', phone: '+962791234567', photoUrl: 'p.jpg', updatedAt: serverTimestamp(), ...extra });

describe('saving your profile (as the app does it)', () => {
  it('rename: profile + role doc + move the name reservation, in one batch', () => {
    const db = as('t1');
    const b = writeBatch(db);
    b.set(doc(db, 'users/t1'), profile(), { merge: true });
    b.set(doc(db, 'teachers/t1'), profile(), { merge: true });
    b.delete(doc(db, 'locked_usernames/ali hassan'));
    b.set(doc(db, 'locked_usernames/omar'), { uid: 't1', createdAt: serverTimestamp() });
    return assertSucceeds(b.commit());
  });

  it('an older account with no reservation: claiming the new name alone works', () => {
    const db = as('s1');
    const b = writeBatch(db);
    b.set(doc(db, 'users/s1'), profile({ name: 'New Student', name_lower: 'new student', phone: '' }), { merge: true });
    b.set(doc(db, 'students/s1'), profile({ name: 'New Student', name_lower: 'new student', phone: '' }), { merge: true });
    b.set(doc(db, 'locked_usernames/new student'), { uid: 's1', createdAt: serverTimestamp() });
    return assertSucceeds(b.commit());
  });

  it('…but deleting a reservation that does not exist is refused (why the app skips it)', () =>
    assertFails(deleteDoc(doc(as('s1'), 'locked_usernames/old student'))));

  it('a phone change moves the phone reservation', () => {
    const db = as('t1');
    const b = writeBatch(db);
    b.set(doc(db, 'users/t1'), profile({ phone: '+962795555555' }), { merge: true });
    b.delete(doc(db, 'locked_phones/+962791234567'));
    b.set(doc(db, 'locked_phones/+962795555555'), { uid: 't1', createdAt: serverTimestamp() });
    return assertSucceeds(b.commit());
  });
});

describe('what you can never do', () => {
  it('take a name someone else reserved', () =>
    assertFails(setDoc(doc(as('t1'), 'locked_usernames/taken'), { uid: 't1', createdAt: serverTimestamp() })));
  it('release someone else\'s reservation', () => assertFails(deleteDoc(doc(as('t1'), 'locked_usernames/taken'))));
  it('reserve a name in someone else\'s name', () =>
    assertFails(setDoc(doc(as('t1'), 'locked_usernames/free'), { uid: 's1' })));
  it('edit someone else\'s profile', () => assertFails(updateDoc(doc(as('s1'), 'users/t1'), { name: 'Hacked' })));
  it('change your own role, status or commission while editing', async () => {
    await assertFails(setDoc(doc(as('t1'), 'users/t1'), profile({ role: 'admin' }), { merge: true }));
    await assertFails(setDoc(doc(as('t1'), 'users/t1'), profile({ commissionRate: 0.99 }), { merge: true }));
    await assertFails(setDoc(doc(as('t1'), 'users/t1'), profile({ status: 'approved', role: 'teacher', commissionRate: 0.1 }), { merge: true }));
  });
});
