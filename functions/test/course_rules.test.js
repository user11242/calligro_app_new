/**
 * firestore.rules for courses: who sees paid materials, who may create a
 * course, and who may write money records. Emulator:
 *   firebase emulators:exec --only firestore --project demo-calligro \
 *     "cd functions && npx jest test/course_rules.test.js"
 */
const fs = require('fs');
const path = require('path');
const { assertFails, assertSucceeds, initializeTestEnvironment } = require('@firebase/rules-unit-testing');
const { doc, setDoc, getDoc, updateDoc, addDoc, collection, arrayUnion, serverTimestamp } = require('firebase/firestore');

let env;
const as = (uid) => env.authenticatedContext(uid).firestore();
const guest = () => env.unauthenticatedContext().firestore();

beforeAll(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-calligro-courses',
    firestore: { host: '127.0.0.1', port: 8080, rules: fs.readFileSync(path.join(__dirname, '../../firestore.rules'), 'utf8') },
  });
});
afterAll(() => env.cleanup());

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'users/admin'), { role: 'admin' });
    await setDoc(doc(db, 'users/teach'), { role: 'teacher', status: 'approved' });
    await setDoc(doc(db, 'users/legacyTeach'), { role: 'teacher', approved: true });
    await setDoc(doc(db, 'users/pending'), { role: 'teacher', status: 'pending' });
    await setDoc(doc(db, 'users/student'), { role: 'student' });
    await setDoc(doc(db, 'users/outsider'), { role: 'student' });
    await setDoc(doc(db, 'courses/c1'), { teacherId: 'teach', price: 100, enrolledStudents: ['student'], enrolledCount: 1 });
    await setDoc(doc(db, 'courses/c1/materials/m1'), { title: 'Week 1', files: [{ fileUrl: 'https://storage/secret.pdf' }] });
  });
});

const newCourse = (teacherId) => ({ teacherId, courseName: 'New', price: 50, enrolledStudents: [], enrolledCount: 0 });

describe('paid course materials', () => {
  it('enrolled students, the teacher and admins can read them', async () => {
    await assertSucceeds(getDoc(doc(as('student'), 'courses/c1/materials/m1')));
    await assertSucceeds(getDoc(doc(as('teach'), 'courses/c1/materials/m1')));
    await assertSucceeds(getDoc(doc(as('admin'), 'courses/c1/materials/m1')));
  });
  it('people who did not buy the course cannot (THE LEAK)', async () => {
    await assertFails(getDoc(doc(as('outsider'), 'courses/c1/materials/m1')));
    await assertFails(getDoc(doc(guest(), 'courses/c1/materials/m1')));
  });
  it('only the teacher (or an admin) manages them', async () => {
    await assertSucceeds(setDoc(doc(as('teach'), 'courses/c1/materials/m2'), { title: 'Week 2' }));
    await assertFails(setDoc(doc(as('student'), 'courses/c1/materials/m3'), { title: 'spam' }));
  });
});

describe('creating courses', () => {
  it('approved teachers can (including older "approved: true" accounts)', async () => {
    await assertSucceeds(setDoc(doc(as('teach'), 'courses/n1'), newCourse('teach')));
    await assertSucceeds(setDoc(doc(as('legacyTeach'), 'courses/n2'), newCourse('legacyTeach')));
  });
  it('students and not-yet-approved teachers cannot', async () => {
    await assertFails(setDoc(doc(as('student'), 'courses/n3'), newCourse('student')));
    await assertFails(setDoc(doc(as('pending'), 'courses/n4'), newCourse('pending')));
  });
  it('nobody creates a course for someone else, or pre-filled with students', async () => {
    await assertFails(setDoc(doc(as('teach'), 'courses/n5'), newCourse('legacyTeach')));
    await assertFails(setDoc(doc(as('teach'), 'courses/n6'), { ...newCourse('teach'), enrolledStudents: ['student'], enrolledCount: 1 }));
  });
});

describe('enrolment and money records are server-only', () => {
  it('a student cannot add themselves to a course', () =>
    assertFails(updateDoc(doc(as('outsider'), 'courses/c1'), { enrolledStudents: arrayUnion('outsider') })));
  it('a signed-in user cannot write a fake transaction (THE "admin_bypass" HOLE)', () =>
    assertFails(addDoc(collection(as('outsider'), 'transactions'), {
      studentId: 'outsider', teacherId: 'teach', amount: 99999, status: 'completed', source: 'admin_bypass', createdAt: serverTimestamp(),
    })));
  it('admins still can (development "join for free" button)', () =>
    assertSucceeds(addDoc(collection(as('admin'), 'transactions'), { studentId: 'admin', amount: 0, source: 'admin_bypass', status: 'completed' })));
  it('nobody writes orders from a client', () =>
    assertFails(setDoc(doc(as('student'), 'orders/x'), { uid: 'student', courseId: 'c1' })));
});
