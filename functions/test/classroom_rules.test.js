/**
 * firestore.rules inside a course: assignments, submissions, announcements, chat.
 *   firebase emulators:exec --only firestore --project demo-calligro \
 *     "cd functions && npx jest test/classroom_rules.test.js"
 */
const fs = require('fs');
const path = require('path');
const { assertFails, assertSucceeds, initializeTestEnvironment } = require('@firebase/rules-unit-testing');
const { doc, setDoc, getDoc, getDocs, updateDoc, deleteDoc, addDoc, collection, serverTimestamp, Timestamp, increment, writeBatch } = require('firebase/firestore');

let env;
const as = (uid) => env.authenticatedContext(uid).firestore();
const future = () => Timestamp.fromDate(new Date(Date.now() + 3 * 864e5));
const past = () => Timestamp.fromDate(new Date(Date.now() - 864e5));
const A = 'courses/c1/assignments';

beforeAll(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-calligro-classroom',
    firestore: { host: '127.0.0.1', port: 8080, rules: fs.readFileSync(path.join(__dirname, '../../firestore.rules'), 'utf8') },
  });
});
afterAll(() => env.cleanup());

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'users/admin'), { role: 'admin', name: 'Platform Admin' });
    await setDoc(doc(db, 'users/teach'), { role: 'teacher', status: 'approved', name: 'Ustadh Ali', fullName: 'Ali Hassan', photoUrl: 'https://img/ali.jpg' });
    await setDoc(doc(db, 'users/teach2'), { role: 'teacher', status: 'approved' });
    await setDoc(doc(db, 'users/student'), { role: 'student', name: 'Sara', photoUrl: 'https://img/sara.jpg' });
    await setDoc(doc(db, 'users/outsider'), { role: 'student' });
    await setDoc(doc(db, 'courses/c1'), { teacherId: 'teach', enrolledStudents: ['student'], enrolledCount: 1 });
    await setDoc(doc(db, `${A}/open`), { title: 'Alif', dueDate: future(), submissionCount: 0 });
    await setDoc(doc(db, `${A}/closed`), { title: 'Ba', dueDate: past() });
    await setDoc(doc(db, `${A}/open/submissions/student`), {
      note: 'v1', fileUrl: 'u', fileName: 'f', submittedAt: Timestamp.now(), studentName: 'Sara', studentImage: null, studentId: 'student',
    });
    await setDoc(doc(db, `${A}/closed/submissions/student`), { note: 'v1', studentId: 'student', submittedAt: Timestamp.now() });
    await setDoc(doc(db, 'courses/c1/announcements/n1'), { message: 'Welcome' });
    await setDoc(doc(db, 'courses/c1/recordings/r1'), { title: 'Lesson', videoUrl: 'https://r2/x.mp4', status: 'completed' });
  });
});

// Exactly what FirestoreAssignmentRepository writes.
const work = (over = {}) => ({
  note: 'done', fileUrl: 'u', fileName: 'f.jpg', submittedAt: serverTimestamp(), studentName: 'Sara', studentImage: null, studentId: 'student', ...over,
});
const change = (over = {}) => ({ note: 'v2', fileUrl: 'u', fileName: 'f.jpg', submittedAt: serverTimestamp(), studentName: 'Sara', studentImage: null, ...over });

describe('assignments', () => {
  it('members read them; outsiders do not (paid content)', async () => {
    await assertSucceeds(getDocs(collection(as('student'), A)));
    await assertSucceeds(getDocs(collection(as('teach'), A)));
    await assertFails(getDocs(collection(as('outsider'), A)));
  });
  it('only this course\'s teacher (or an admin) creates them, with a title and a due date', async () => {
    await assertSucceeds(addDoc(collection(as('teach'), A), { title: 'Ta', instructions: '', dueDate: future(), createdAt: serverTimestamp() }));
    await assertSucceeds(addDoc(collection(as('admin'), A), { title: 'Tha', dueDate: future() }));
    await assertFails(addDoc(collection(as('teach2'), A), { title: 'x', dueDate: future() }));
    await assertFails(addDoc(collection(as('student'), A), { title: 'x', dueDate: future() }));
    await assertFails(addDoc(collection(as('teach'), A), { title: '', dueDate: future() }));
    await assertFails(addDoc(collection(as('teach'), A), { title: 'no date' }));
  });
  it('nobody else can touch the submission count any more (THE "any signed-in user" HOLE)', async () => {
    await assertFails(updateDoc(doc(as('outsider'), `${A}/open`), { submissionCount: 9999 }));
    await assertFails(updateDoc(doc(as('student'), `${A}/open`), { submissionCount: increment(1) }));
  });
});

describe('submissions', () => {
  it('an enrolled student hands in before the due date', () =>
    env.withSecurityRulesDisabled((ctx) => deleteDoc(doc(ctx.firestore(), `${A}/open/submissions/student`)))
      .then(() => assertSucceeds(setDoc(doc(as('student'), `${A}/open/submissions/student`), work()))));
  it('not after the due date, not for someone else, not without enrolment', async () => {
    await env.withSecurityRulesDisabled((ctx) => deleteDoc(doc(ctx.firestore(), `${A}/closed/submissions/student`)));
    await assertFails(setDoc(doc(as('student'), `${A}/closed/submissions/student`), work()));
    await assertFails(setDoc(doc(as('student'), `${A}/open/submissions/outsider`), work({ studentId: 'outsider' })));
    await assertFails(setDoc(doc(as('outsider'), `${A}/open/submissions/outsider`), work({ studentId: 'outsider' })));
  });
  it('a student cannot hand in a pre-graded or pre-reviewed submission', async () => {
    await env.withSecurityRulesDisabled((ctx) => deleteDoc(doc(ctx.firestore(), `${A}/open/submissions/student`)));
    await assertFails(setDoc(doc(as('student'), `${A}/open/submissions/student`), work({ status: 'graded', points: 100 })));
    await assertFails(setDoc(doc(as('student'), `${A}/open/submissions/student`), work({ seenByTeacher: true })));
    await assertFails(setDoc(doc(as('student'), `${A}/open/submissions/student`), work({ submittedAt: Timestamp.fromDate(new Date('2020-01-01')) })));
  });
  it('a student changes their work before the due date, but never grades it (THE SELF-GRADING HOLE)', async () => {
    const mine = doc(as('student'), `${A}/open/submissions/student`);
    await assertSucceeds(updateDoc(mine, change()));
    await assertFails(updateDoc(mine, { points: 100 }));
    await assertFails(updateDoc(mine, { status: 'graded', feedback: 'Perfect' }));
    await assertFails(updateDoc(mine, { seenByTeacher: true }));
  });
  it('after the due date the work is locked (no change, no withdrawal)', async () => {
    await assertFails(updateDoc(doc(as('student'), `${A}/closed/submissions/student`), change()));
    await assertFails(deleteDoc(doc(as('student'), `${A}/closed/submissions/student`)));
  });
  it('withdrawing before the due date', () => assertSucceeds(deleteDoc(doc(as('student'), `${A}/open/submissions/student`))));
  it('the teacher marks and grades, but cannot rewrite the student\'s work', async () => {
    const theirs = doc(as('teach'), `${A}/open/submissions/student`);
    await assertSucceeds(updateDoc(theirs, { seenByTeacher: true }));
    await assertSucceeds(updateDoc(theirs, { status: 'graded', points: 9, feedback: 'Lovely', gradedAt: Timestamp.now() }));
    await assertFails(updateDoc(theirs, { note: 'edited by teacher' }));
    await assertFails(updateDoc(doc(as('teach2'), `${A}/open/submissions/student`), { seenByTeacher: true }));
  });
  it('only the student, the teacher and admins read it', async () => {
    await assertSucceeds(getDoc(doc(as('student'), `${A}/open/submissions/student`)));
    await assertSucceeds(getDoc(doc(as('teach'), `${A}/open/submissions/student`)));
    await assertFails(getDoc(doc(as('outsider'), `${A}/open/submissions/student`)));
    await assertFails(getDoc(doc(as('teach2'), `${A}/open/submissions/student`)));
  });
});

describe('announcements', () => {
  it('members read them; outsiders do not', async () => {
    await assertSucceeds(getDoc(doc(as('student'), 'courses/c1/announcements/n1')));
    await assertFails(getDoc(doc(as('outsider'), 'courses/c1/announcements/n1')));
  });
});

describe('course chat', () => {
  // Exactly what CourseChatService.sendMessage writes (store app 1.0.24 writes the same).
  const names = { student: 'Sara', teach: 'Ali Hassan', admin: 'Platform Admin', outsider: 'Member' };
  const photos = { student: 'https://img/sara.jpg', teach: 'https://img/ali.jpg' };
  const msg = (uid, role, over = {}) => ({
    senderId: uid, senderName: names[uid] || 'Member', senderPhotoUrl: photos[uid] || null, senderRole: role,
    text: 'hi', imageUrl: null, createdAt: serverTimestamp(), ...over,
  });
  const img = (uid, course = 'c1') =>
    `https://firebasestorage.googleapis.com/v0/b/calligro.appspot.com/o/course_chats%2F${course}%2F${uid}_1700000000.jpg?alt=media&token=t`;
  it('members post with their true badge', async () => {
    await assertSucceeds(addDoc(collection(as('student'), 'courses/c1/messages'), msg('student', 'student')));
    await assertSucceeds(addDoc(collection(as('teach'), 'courses/c1/messages'), msg('teach', 'teacher')));
    await assertSucceeds(addDoc(collection(as('admin'), 'courses/c1/messages'), msg('admin', 'admin')));
  });
  it('a student cannot wear the teacher or admin badge (impersonation)', async () => {
    await assertFails(addDoc(collection(as('student'), 'courses/c1/messages'), msg('student', 'teacher')));
    await assertFails(addDoc(collection(as('student'), 'courses/c1/messages'), msg('student', 'admin')));
  });
  it('no back-dated messages, no outsiders, no posting as someone else', async () => {
    await assertFails(addDoc(collection(as('student'), 'courses/c1/messages'), msg('student', 'student', { createdAt: Timestamp.fromDate(new Date('2020-01-01')) })));
    await assertFails(addDoc(collection(as('outsider'), 'courses/c1/messages'), msg('outsider', 'student')));
    await assertFails(addDoc(collection(as('student'), 'courses/c1/messages'), msg('teach', 'teacher')));
  });
  it('an image message with the sender\'s own chat image is accepted; text may be empty then', async () => {
    await assertSucceeds(addDoc(collection(as('student'), 'courses/c1/messages'), msg('student', 'student', { text: '', imageUrl: img('student') })));
  });
  it('the name must be the sender\'s own (full name, else name) — no posting as "Teacher"', async () => {
    await assertFails(addDoc(collection(as('student'), 'courses/c1/messages'), msg('student', 'student', { senderName: 'Ustadh Ali' })));
    await assertSucceeds(addDoc(collection(as('teach'), 'courses/c1/messages'), msg('teach', 'teacher', { senderName: 'Ali Hassan' })));
    await assertSucceeds(addDoc(collection(as('teach'), 'courses/c1/messages'), msg('teach', 'teacher', { senderName: 'Ustadh Ali' })));
  });
  it('the photo must be the sender\'s own profile photo (or none)', async () => {
    await assertFails(addDoc(collection(as('student'), 'courses/c1/messages'), msg('student', 'student', { senderPhotoUrl: 'https://img/ali.jpg' })));
    await assertSucceeds(addDoc(collection(as('student'), 'courses/c1/messages'), msg('student', 'student', { senderPhotoUrl: null })));
  });
  it('images only from this course\'s chat folder, uploaded by the sender (no outside links)', async () => {
    for (const bad of ['https://evil.example.com/x.jpg', img('teach'), img('student', 'other-course'), 'javascript:alert(1)']) {
      await assertFails(addDoc(collection(as('student'), 'courses/c1/messages'), msg('student', 'student', { imageUrl: bad })), bad);
    }
  });
  it('length: up to 4000 characters; no empty message; no extra fields', async () => {
    await assertSucceeds(addDoc(collection(as('student'), 'courses/c1/messages'), msg('student', 'student', { text: 'x'.repeat(4000) })));
    await assertFails(addDoc(collection(as('student'), 'courses/c1/messages'), msg('student', 'student', { text: 'x'.repeat(4001) })));
    await assertFails(addDoc(collection(as('student'), 'courses/c1/messages'), msg('student', 'student', { text: '' })));
    await assertFails(addDoc(collection(as('student'), 'courses/c1/messages'), msg('student', 'student', { pinned: true })));
  });
  it('reporting a message (as the app writes it) is accepted; reporting as someone else is not', async () => {
    const report = (by) => ({ type: 'course_chat_message', courseId: 'c1', messageId: 'm1', reportedUserId: 'teach', reportedByUserId: by, reason: 'spam', messageText: 'hi', createdAt: serverTimestamp() });
    await assertSucceeds(addDoc(collection(as('student'), 'reports'), report('student')));
    await assertFails(addDoc(collection(as('student'), 'reports'), report('teach')));
  });
});

describe('recordings', () => {
  it('the teacher renames, but cannot repoint the video or status', async () => {
    await assertSucceeds(updateDoc(doc(as('teach'), 'courses/c1/recordings/r1'), { title: 'Alif' }));
    await assertFails(updateDoc(doc(as('teach'), 'courses/c1/recordings/r1'), { videoUrl: 'https://evil/x.mp4' }));
    await assertFails(updateDoc(doc(as('student'), 'courses/c1/recordings/r1'), { title: 'x' }));
  });
});

describe('moving a session (FirestoreBoardRepository.reschedule)', () => {
  const batchFor = (uid, notify) => {
    const db = as(uid);
    const b = writeBatch(db);
    b.update(doc(db, 'courses/c1'), { rescheduledSession: { newStartTime: Timestamp.now(), newEndTime: Timestamp.now() } });
    for (const s of notify) {
      b.set(doc(collection(db, `users/${s}/notifications`)), {
        title: 'Moved', message: 'x', createdAt: serverTimestamp(), isRead: false, type: 'reschedule', courseId: 'c1',
      });
    }
    return b.commit();
  };
  it('the teacher moves it (the server notifies the students)', () => assertSucceeds(batchFor('teach', [])));
  it('the app can no longer write the notices itself (they arrived twice)', () => assertFails(batchFor('teach', ['student'])));
  it('another teacher cannot', () => assertFails(batchFor('teach2', [])));
});
