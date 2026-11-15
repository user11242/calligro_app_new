/**
 * syncProfileCopies against the Firestore emulator:
 *   firebase emulators:exec --only firestore --project demo-calligro \
 *     "cd functions && npx jest test/profile_sync.test.js"
 */
process.env.FIRESTORE_EMULATOR_HOST = process.env.FIRESTORE_EMULATOR_HOST || '127.0.0.1:8080';
const admin = require('firebase-admin');
const { syncProfileCopies, profileCopyChanged } = require('../profile_sync');

const app = admin.initializeApp({ projectId: 'demo-calligro-sync' }, 'profile-sync-test');
const db = app.firestore();

async function wipe() {
  const deleteTree = async (ref) => {
    const cols = await ref.listCollections();
    for (const c of cols) {
      const docs = await c.listDocuments();
      for (const d of docs) {
        await deleteTree(d);
        await d.delete();
      }
    }
  };
  await deleteTree(db);
}

beforeEach(async () => {
  await wipe();
  await db.doc('courses/c1').set({ teacherId: 't1', teacherName: 'Old', teacherProfilePic: 'old.jpg' });
  await db.doc('courses/c2').set({ teacherId: 'other', teacherName: 'Other' });
  await db.doc('community_posts/p1').set({ userId: 't1', userName: 'Old', userImageUrl: 'old.jpg' });
  await db.doc('community_posts/p2').set({ userId: 's9', userName: 'Someone' });
  await db.doc('community_posts/p2/comments/c1').set({ userId: 't1', userName: 'Old', userPhotoUrl: 'old.jpg' });
  await db.doc('community_posts/p2/comments/c1/replies/r1').set({ userId: 't1', userName: 'Old', userPhotoUrl: 'old.jpg' });
  await db.doc('community_posts/p2/comments/c2').set({ userId: 's9', userName: 'Someone' });
});
afterAll(() => app.delete());

test('name / photo changes are detected; other edits are ignored', () => {
  expect(profileCopyChanged({ name: 'A', photoUrl: 'x' }, { name: 'B', photoUrl: 'x' })).toBe(true);
  expect(profileCopyChanged({ name: 'A', photoUrl: 'x' }, { name: 'A', photoUrl: 'y' })).toBe(true);
  expect(profileCopyChanged({ name: 'A', photoUrl: 'x', bio: '1' }, { name: 'A', photoUrl: 'x', bio: '2' })).toBe(false);
  expect(profileCopyChanged({ name: 'A' }, { name: 'A', followerCount: 3 })).toBe(false);
});

test('updates the user\'s courses, posts, comments AND replies; nobody else\'s', async () => {
  const counts = await syncProfileCopies(db, 't1', { name: 'New Name', photoUrl: 'new.jpg' });
  expect(counts).toEqual({ courses: 1, posts: 1, comments: 1, replies: 1 });

  expect((await db.doc('courses/c1').get()).data()).toMatchObject({ teacherName: 'New Name', teacherProfilePic: 'new.jpg' });
  expect((await db.doc('community_posts/p1').get()).data()).toMatchObject({ userName: 'New Name', userImageUrl: 'new.jpg' });
  expect((await db.doc('community_posts/p2/comments/c1').get()).data())
    .toMatchObject({ userName: 'New Name', userPhotoUrl: 'new.jpg' });
  expect((await db.doc('community_posts/p2/comments/c1/replies/r1').get()).data())
    .toMatchObject({ userName: 'New Name', userPhotoUrl: 'new.jpg' });

  expect((await db.doc('courses/c2').get()).get('teacherName')).toBe('Other');
  expect((await db.doc('community_posts/p2').get()).get('userName')).toBe('Someone');
  expect((await db.doc('community_posts/p2/comments/c2').get()).get('userName')).toBe('Someone');
});

test('no 500-write limit: hundreds of copies are all updated', async () => {
  const w = db.bulkWriter();
  for (let i = 0; i < 620; i++) w.set(db.doc(`community_posts/bulk${i}`), { userId: 't1', userName: 'Old' });
  await w.close();
  const counts = await syncProfileCopies(db, 't1', { name: 'Renamed', photoUrl: '' });
  expect(counts.posts).toBe(621);
  const stale = await db.collection('community_posts').where('userId', '==', 't1').where('userName', '==', 'Old').get();
  expect(stale.size).toBe(0);
});

test('a missing photo is written as an empty string, never undefined', async () => {
  await syncProfileCopies(db, 't1', { name: 'No Photo' });
  expect((await db.doc('community_posts/p1').get()).get('userImageUrl')).toBe('');
});
