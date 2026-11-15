/**
 * firestore.rules for the community (posts, likes, comments, replies, saved,
 * follows, reports), run against the Firestore emulator:
 *
 *   firebase emulators:exec --only firestore --project demo-calligro \
 *     "cd functions && npx jest test/community_rules.test.js"
 *
 * Every write the Flutter data layer (lib/features/community/data) makes is
 * tested as ALLOWED, and every abuse as DENIED.
 */
const fs = require('fs');
const path = require('path');
const { assertFails, assertSucceeds, initializeTestEnvironment } = require('@firebase/rules-unit-testing');
const { doc, setDoc, updateDoc, deleteDoc, getDoc, writeBatch, deleteField, increment, serverTimestamp } =
  require('firebase/firestore');

let env;

const post = (extra = {}) => ({
  userId: 'author', userName: 'Author', userImageUrl: '', userRole: 'student',
  caption: 'Naskh', imageUrls: [], timestamp: new Date(), likesCount: 1, commentsCount: 1,
  likes: { fan: true }, ...extra,
});
const comment = (userId, extra = {}) => ({ userId, userName: userId, userPhotoUrl: '', userRole: 'student', text: 'hi', timestamp: new Date(), ...extra });

const as = (uid) => env.authenticatedContext(uid).firestore();
const guest = () => env.unauthenticatedContext().firestore();

beforeAll(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-calligro-community',
    firestore: { host: '127.0.0.1', port: 8080, rules: fs.readFileSync(path.join(__dirname, '../../firestore.rules'), 'utf8') },
  });
});
afterAll(() => env.cleanup());

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'users/admin'), { role: 'admin', name: 'Admin' });
    await setDoc(doc(db, 'users/author'), { role: 'student', name: 'Author', postCount: 1, followerCount: 0, followingCount: 0 });
    await setDoc(doc(db, 'users/fan'), { role: 'student', name: 'Fan', followerCount: 0, followingCount: 0 });
    await setDoc(doc(db, 'users/stranger'), { role: 'student', name: 'Stranger' });
    await setDoc(doc(db, 'users/teach'), { role: 'teacher', name: 'Teacher', totalStars: 10, reviewCount: 2 });
    await setDoc(doc(db, 'teachers/teach'), { role: 'teacher', totalStars: 10, reviewCount: 2 });
    await setDoc(doc(db, 'students/author'), { role: 'student', postCount: 1 });
    await setDoc(doc(db, 'community_posts/p1'), post());
    await setDoc(doc(db, 'community_posts/p1/comments/c1'), comment('fan', { replyCount: 1 }));
    await setDoc(doc(db, 'community_posts/p1/comments/c1/replies/r1'), comment('stranger'));
    await setDoc(doc(db, 'users/author/saved_posts/p1'), { timestamp: new Date() });
  });
});

describe('posts: create', () => {
  const fresh = (uid, extra = {}) => ({
    userId: uid, userName: 'X', userImageUrl: '', userRole: 'student', caption: 'new', imageUrls: [],
    timestamp: serverTimestamp(), likesCount: 0, commentsCount: 0, likes: {}, ...extra,
  });

  it('a user creates their own post (as the app writes it)', () =>
    assertSucceeds(setDoc(doc(as('fan'), 'community_posts/new'), fresh('fan'))));
  it('cannot post as someone else', () =>
    assertFails(setDoc(doc(as('fan'), 'community_posts/new'), fresh('author'))));
  it('guests cannot post', () =>
    assertFails(setDoc(doc(guest(), 'community_posts/new'), fresh(''))));
  it('cannot start with fake likes or counts', async () => {
    await assertFails(setDoc(doc(as('fan'), 'community_posts/a'), fresh('fan', { likesCount: 500 })));
    await assertFails(setDoc(doc(as('fan'), 'community_posts/b'), fresh('fan', { commentsCount: 9 })));
    await assertFails(setDoc(doc(as('fan'), 'community_posts/c'), fresh('fan', { likes: { x: true } })));
  });
  it('only admins create pinned / hidden / link posts', async () => {
    await assertFails(setDoc(doc(as('fan'), 'community_posts/a'), fresh('fan', { isPinned: true })));
    await assertFails(setDoc(doc(as('fan'), 'community_posts/b'), fresh('fan', { isHidden: true })));
    await assertFails(setDoc(doc(as('fan'), 'community_posts/c'), fresh('fan', { linkUrl: 'https://evil.example' })));
    await assertSucceeds(setDoc(doc(as('admin'), 'community_posts/d'),
      fresh('admin', { isPinned: true, isHidden: true, linkUrl: 'https://calligroacademy.com', linkTitle: 'Visit' })));
  });
  it('the post-count bump in the same transaction is allowed', () =>
    assertSucceeds(updateDoc(doc(as('author'), 'users/author'), { postCount: increment(1) })));
});

describe('posts: author edits', () => {
  it('caption / images / edited flag', () =>
    assertSucceeds(updateDoc(doc(as('author'), 'community_posts/p1'), { caption: 'new', imageUrls: [], isEdited: true })));
  it('profile sync of name / photo', () =>
    assertSucceeds(updateDoc(doc(as('author'), 'community_posts/p1'), { userName: 'New name', userImageUrl: 'x' })));
  it('the author cannot pin, hide, or fake likes on their own post', async () => {
    await assertFails(updateDoc(doc(as('author'), 'community_posts/p1'), { isPinned: true }));
    await assertFails(updateDoc(doc(as('author'), 'community_posts/p1'), { isHidden: false }));
    await assertFails(updateDoc(doc(as('author'), 'community_posts/p1'), { likesCount: 999 }));
    await assertFails(updateDoc(doc(as('author'), 'community_posts/p1'), { userId: 'fan' }));
  });
  it('others cannot edit', () =>
    assertFails(updateDoc(doc(as('stranger'), 'community_posts/p1'), { caption: 'hacked' })));
  it('admins can pin and hide', async () => {
    await assertSucceeds(updateDoc(doc(as('admin'), 'community_posts/p1'), { isPinned: true }));
    await assertSucceeds(updateDoc(doc(as('admin'), 'community_posts/p1'), { isHidden: true }));
  });
});

describe('posts: likes', () => {
  const like = (uid, on, delta) => updateDoc(doc(as(uid), 'community_posts/p1'),
    { [`likes.${uid}`]: on ? true : deleteField(), likesCount: increment(delta) });

  it('like (+1) and unlike (-1) your own like', async () => {
    await assertSucceeds(like('stranger', true, 1));
    await assertSucceeds(like('stranger', false, -1));
  });
  it('the author may like their own post', () => assertSucceeds(like('author', true, 1)));
  it('cannot touch someone else\'s like', async () => {
    await assertFails(updateDoc(doc(as('stranger'), 'community_posts/p1'), { 'likes.fan': deleteField(), likesCount: increment(-1) }));
    await assertFails(updateDoc(doc(as('stranger'), 'community_posts/p1'), { 'likes.ghost': true, likesCount: increment(1) }));
  });
  it('cannot swap someone else\'s like for your own in one write', () =>
    assertFails(updateDoc(doc(as('stranger'), 'community_posts/p1'),
      { 'likes.stranger': true, 'likes.fan': deleteField(), likesCount: increment(1) })));
  it('the count must match the like', async () => {
    await assertFails(like('stranger', true, 2));
    await assertFails(like('stranger', true, 0));
    await assertFails(updateDoc(doc(as('stranger'), 'community_posts/p1'), { likesCount: increment(1) }));
    await assertFails(like('fan', true, 1)); // fan already liked → re-like must not add a count
  });
  it('guests cannot like', () =>
    assertFails(updateDoc(doc(guest(), 'community_posts/p1'), { likesCount: increment(1) })));
});

describe('posts: comment counter', () => {
  it('moves by exactly one', async () => {
    await assertSucceeds(updateDoc(doc(as('stranger'), 'community_posts/p1'), { commentsCount: increment(1) }));
    await assertFails(updateDoc(doc(as('stranger'), 'community_posts/p1'), { commentsCount: increment(5) }));
  });
  it('never below zero', async () => {
    await assertSucceeds(updateDoc(doc(as('stranger'), 'community_posts/p1'), { commentsCount: increment(-1) }));
    await assertFails(updateDoc(doc(as('stranger'), 'community_posts/p1'), { commentsCount: increment(-1) }));
  });
});

describe('comments', () => {
  it('write your own (with the post counter, as one batch)', () => {
    const db = as('stranger');
    const b = writeBatch(db);
    b.set(doc(db, 'community_posts/p1/comments/new'), comment('stranger'));
    b.update(doc(db, 'community_posts/p1'), { commentsCount: increment(1) });
    return assertSucceeds(b.commit());
  });
  it('cannot comment as someone else', () =>
    assertFails(setDoc(doc(as('stranger'), 'community_posts/p1/comments/x'), comment('fan'))));
  it('the author edits text; cannot change who wrote it', async () => {
    await assertSucceeds(updateDoc(doc(as('fan'), 'community_posts/p1/comments/c1'), { text: 'edited', isEdited: true }));
    await assertFails(updateDoc(doc(as('fan'), 'community_posts/p1/comments/c1'), { userId: 'stranger' }));
  });
  it('others cannot edit', () =>
    assertFails(updateDoc(doc(as('stranger'), 'community_posts/p1/comments/c1'), { text: 'hacked' })));
  it('reply counter moves by exactly one, never below zero', async () => {
    await assertSucceeds(updateDoc(doc(as('stranger'), 'community_posts/p1/comments/c1'), { replyCount: increment(1) }));
    await assertFails(updateDoc(doc(as('stranger'), 'community_posts/p1/comments/c1'), { replyCount: 100 }));
    await assertSucceeds(updateDoc(doc(as('stranger'), 'community_posts/p1/comments/c1'), { replyCount: increment(-1) }));
    await assertSucceeds(updateDoc(doc(as('stranger'), 'community_posts/p1/comments/c1'), { replyCount: increment(-1) }));
    await assertFails(updateDoc(doc(as('stranger'), 'community_posts/p1/comments/c1'), { replyCount: increment(-1) }));
  });
  it('deleted by its author, the post author, or an admin — not others', async () => {
    await assertFails(deleteDoc(doc(as('stranger'), 'community_posts/p1/comments/c1')));
    await assertSucceeds(deleteDoc(doc(as('author'), 'community_posts/p1/comments/c1')));
  });
  it('guests can read comments', () => assertSucceeds(getDoc(doc(guest(), 'community_posts/p1/comments/c1'))));
});

describe('replies', () => {
  const reply = 'community_posts/p1/comments/c1/replies/r1';
  it('guests can read replies (like comments)', () => assertSucceeds(getDoc(doc(guest(), reply))));
  it('nobody can take over a reply by rewriting its userId', () =>
    assertFails(updateDoc(doc(as('fan'), reply), { userId: 'fan', text: 'mine now' })));
  it('the reply author edits text only', async () => {
    await assertSucceeds(updateDoc(doc(as('stranger'), reply), { text: 'edited', isEdited: true }));
    await assertFails(updateDoc(doc(as('stranger'), reply), { userId: 'fan' }));
  });
  it('cannot reply as someone else', () =>
    assertFails(setDoc(doc(as('fan'), 'community_posts/p1/comments/c1/replies/x'), comment('stranger'))));
  it('deleted by its author, the comment author, the POST author, or an admin', async () => {
    await assertFails(deleteDoc(doc(as('teach'), reply)));
    await assertSucceeds(deleteDoc(doc(as('author'), reply)));
  });
});

describe('deleting a whole post (as the app does it)', () => {
  const deleteEverything = async (db) => {
    const b = writeBatch(db);
    b.delete(doc(db, 'community_posts/p1/comments/c1/replies/r1'));
    b.delete(doc(db, 'community_posts/p1/comments/c1'));
    await b.commit();
    const b2 = writeBatch(db);
    b2.delete(doc(db, 'community_posts/p1'));
    b2.delete(doc(db, 'users/author/saved_posts/p1'));
    b2.update(doc(db, 'users/author'), { postCount: increment(-1) });
    b2.update(doc(db, 'students/author'), { postCount: increment(-1) });
    await b2.commit();
  };
  it('the author can delete it even when others commented and replied', () => assertSucceeds(deleteEverything(as('author'))));
  it('an admin can delete anyone\'s post with its cleanup', () => assertSucceeds(deleteEverything(as('admin'))));
  it('others cannot', () => assertFails(deleteDoc(doc(as('stranger'), 'community_posts/p1'))));
});

describe('saved posts', () => {
  it('only the owner saves / unsaves', async () => {
    await assertSucceeds(setDoc(doc(as('fan'), 'users/fan/saved_posts/p1'), { timestamp: serverTimestamp() }));
    await assertFails(setDoc(doc(as('stranger'), 'users/fan/saved_posts/p1'), { timestamp: serverTimestamp() }));
    await assertFails(getDoc(doc(as('stranger'), 'users/fan/saved_posts/p1')));
  });
});

describe('follows and public counters', () => {
  it('follow = follower entry + following entry + both counters ±1', () => {
    const db = as('fan');
    const b = writeBatch(db);
    b.set(doc(db, 'users/author/followers/fan'), { timestamp: serverTimestamp() });
    b.set(doc(db, 'users/fan/following/author'), { timestamp: serverTimestamp() });
    b.update(doc(db, 'users/author'), { followerCount: increment(1) });
    b.update(doc(db, 'users/fan'), { followingCount: increment(1) });
    return assertSucceeds(b.commit());
  });
  it('cannot set someone\'s follower count to anything', async () => {
    await assertFails(updateDoc(doc(as('stranger'), 'users/author'), { followerCount: 1000 }));
    await assertFails(updateDoc(doc(as('stranger'), 'users/author'), { followerCount: -1 }));
  });
  it('cannot add followers in someone else\'s name', () =>
    assertFails(setDoc(doc(as('stranger'), 'users/author/followers/fan'), {})));
  it('nobody adds or removes stars from the app: the server computes rating totals (functions/ratings.js)', async () => {
    await assertFails(updateDoc(doc(as('stranger'), 'teachers/teach'), { totalStars: increment(4), reviewCount: increment(1) }));
    await assertFails(updateDoc(doc(as('stranger'), 'users/teach'), { totalStars: increment(4), reviewCount: increment(1) }));
    await assertFails(updateDoc(doc(as('teach'), 'users/teach'), { totalStars: 500, reviewCount: 100 }));
    await assertFails(updateDoc(doc(as('teach'), 'teachers/teach'), { totalStars: 500 }));
    await assertFails(updateDoc(doc(as('stranger'), 'teachers/teach'), { totalStars: 5000, reviewCount: 1000 }));
    await assertFails(updateDoc(doc(as('stranger'), 'users/teach'), { totalStars: increment(50) }));
    await assertFails(updateDoc(doc(as('stranger'), 'teachers/teach'), { totalStars: increment(-50), reviewCount: increment(-1) }));
  });
});

describe('reports and blocking', () => {
  it('report in your own name only', async () => {
    const r = (by) => ({ postId: 'p1', reportedUserId: 'author', reportedByUserId: by, timestamp: serverTimestamp(), status: 'pending' });
    await assertSucceeds(setDoc(doc(as('fan'), 'reports/r1'), r('fan')));
    await assertFails(setDoc(doc(as('fan'), 'reports/r2'), r('stranger')));
    await assertFails(getDoc(doc(as('fan'), 'reports/r1')));
  });
  it('block / unblock is your own list', async () => {
    await assertSucceeds(updateDoc(doc(as('fan'), 'users/fan'), { blockedUsers: ['author'] }));
    await assertFails(updateDoc(doc(as('stranger'), 'users/fan'), { blockedUsers: [] }));
  });
});

describe('teacher payout details (bank / CliQ) are private', () => {
  const payout = { selectedMethod: 'bankTransfer', bankTransfer: { iban: 'JO94CBJO0010000000000131000302' }, cliq: null };

  beforeEach(() => env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'users/teach/private/payout'), payout);
  }));

  it('only the teacher and admins can read them', async () => {
    await assertSucceeds(getDoc(doc(as('teach'), 'users/teach/private/payout')));
    await assertSucceeds(getDoc(doc(as('admin'), 'users/teach/private/payout')));
    await assertFails(getDoc(doc(as('stranger'), 'users/teach/private/payout')));
    await assertFails(getDoc(doc(guest(), 'users/teach/private/payout')));
  });
  it('only the teacher writes them', async () => {
    await assertSucceeds(setDoc(doc(as('teach'), 'users/teach/private/payout'), payout));
    await assertFails(setDoc(doc(as('stranger'), 'users/teach/private/payout'), payout));
  });
  it('can never be put on the public users / teachers documents (old app versions)', async () => {
    await assertFails(setDoc(doc(as('teach'), 'users/teach'), { payoutSettings: payout }, { merge: true }));
    await assertFails(setDoc(doc(as('teach'), 'teachers/teach'), { payoutSettings: payout }, { merge: true }));
    await assertFails(setDoc(doc(as('admin'), 'users/teach'), { payoutSettings: payout }, { merge: true }));
    await assertFails(setDoc(doc(as('newbie'), 'users/newbie'), { role: 'student', payoutSettings: payout }));
  });
  it('a teacher whose old document still has payoutSettings can keep editing other fields', async () => {
    await env.withSecurityRulesDisabled((ctx) =>
      setDoc(doc(ctx.firestore(), 'users/teach'), { payoutSettings: payout }, { merge: true }));
    await assertSucceeds(updateDoc(doc(as('teach'), 'users/teach'), { bio: 'Calligrapher' }));
  });
});

