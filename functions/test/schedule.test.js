/**
 * Moving the next class (server). The rule part runs the SAME cases as the app
 * (test/fixtures/schedule_cases.json); the operations run on the Firestore emulator:
 *   firebase emulators:exec --only firestore --project demo-calligro \
 *     "cd functions && npx jest test/schedule.test.js"
 */
process.env.FIRESTORE_EMULATOR_HOST = process.env.FIRESTORE_EMULATOR_HOST || '127.0.0.1:8080';
const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');
const { scheduleOf, sessions, rescheduleWindow, planMove, rescheduleNext, cancelNextReschedule } = require('../schedule');

const cases = JSON.parse(fs.readFileSync(path.join(__dirname, '../../test/fixtures/schedule_cases.json'), 'utf8'));
const t = (iso) => Date.parse(iso);
const c = cases.course;
const fixtureCourse = (extra = {}) => ({
  selectedDays: c.selectedDays,
  startDate: c.startDate,
  endDate: c.endDate,
  startTime: c.startTime,
  endTime: c.endTime,
  scheduleUtcOffsetMinutes: c.offsetMinutes,
  ...extra,
});

describe('the schedule rule (same answers as the app)', () => {
  test('the regular classes', () => {
    const s = sessions(scheduleOf(fixtureCourse(), 0));
    expect(s.map((x) => x.start)).toEqual(cases.sessions.regular.map(t));
    expect(s.every((x) => x.end - x.start === 90 * 60 * 1000)).toBe(true);
  });

  describe('time zones: every viewer gets the TEACHER\'s class times (shared with the app)', () => {
    for (const k of cases.timeZones.cases) {
      test(k.name, () => {
        const s = scheduleOf(k.course, k.viewerOffsetMinutes);
        expect(s.offset).toBe(k.offsetMinutes);
        expect(sessions(s).map((x) => new Date(x.start).toISOString())).toEqual(k.regular.map((x) => new Date(x).toISOString()));
      });
    }
  });

  for (const w of cases.windows) {
    test(`window: ${w.name}`, () => {
      const win = rescheduleWindow(scheduleOf(fixtureCourse(), 0), t(w.now));
      if (w.next == null) return expect(win).toBeNull();
      expect(win.session.start).toBe(t(w.next));
      expect(win.isFirst).toBe(w.isFirst);
      expect(win.isLast).toBe(w.isLast);
      expect(win.earliest).toBe(t(w.earliest));
      expect(win.latestDay).toBe(w.latestDay);
    });
  }

  for (const m of cases.moves) {
    test(`move: ${m.name}`, () => {
      const r = planMove(scheduleOf(fixtureCourse(), 0), { now: t(m.now), newStart: t(m.newStart), newEnd: t(m.newEnd) });
      if (m.ok) {
        expect(r.error).toBeUndefined();
        expect(r.startDate).toBe(t(m.startDate));
        expect(r.endDate).toBe(t(m.endDate));
      } else {
        expect(r.error).toBe(m.error);
      }
    });
  }
});

describe('moving the next class (Firestore)', () => {
  const app = admin.initializeApp({ projectId: 'demo-calligro-schedule' }, 'schedule-test');
  const db = app.firestore();
  const T = (iso) => admin.firestore.Timestamp.fromDate(new Date(iso));
  const course = () => db.doc('courses/c1').get().then((d) => d.data());
  const ms = (v) => (v && v.toMillis ? v.toMillis() : v);

  beforeEach(async () => {
    await db.doc('courses/c1').delete();
    await db.doc('courses/c1').set({
      teacherId: 't1',
      courseName: 'Thuluth',
      selectedDays: c.selectedDays,
      startDate: T(c.startDate),
      endDate: T(c.endDate),
      startTime: T(c.startTime),
      endTime: T(c.endTime),
      enrolledStudents: ['s1'],
    });
  });
  afterAll(() => app.delete());

  test('moves the next class; the course gets the move, the time zone, and the old-app field', async () => {
    const r = await rescheduleNext(db, 't1', {
      courseId: 'c1', newStart: t('2026-12-01T15:00:00Z'), newEnd: t('2026-12-01T16:30:00Z'), note: '  Travelling  ', utcOffsetMinutes: 180,
    }, t('2026-11-25T09:00:00Z'));
    expect(r.originalStart).toBe(t('2026-11-30T15:00:00Z'));
    const d = await course();
    expect(d.scheduleUtcOffsetMinutes).toBe(180);
    expect(d.sessionMoves).toHaveLength(1);
    expect(ms(d.sessionMoves[0].newStart)).toBe(t('2026-12-01T15:00:00Z'));
    expect(d.rescheduledSession.note).toBe('Travelling');
    expect(ms(d.rescheduledSession.originalDate)).toBe(t('2026-11-30T15:00:00Z'));
    expect(ms(d.rescheduledSession.newStartTime)).toBe(t('2026-12-01T15:00:00Z'));
  });

  test('the FIRST class moved later: the start date follows (selling stops at the real first class)', async () => {
    await rescheduleNext(db, 't1', { courseId: 'c1', newStart: t('2026-12-01T15:00:00Z'), newEnd: t('2026-12-01T16:30:00Z'), utcOffsetMinutes: 180 }, t('2026-11-25T09:00:00Z'));
    const d = await course();
    expect(ms(d.startDate)).toBe(t('2026-11-30T21:00:00Z'));
    expect(ms(d.scheduleStartDate)).toBe(t(c.startDate)); // the original range is kept
    // THE BUG this guards: the moved first class must still exist (its slot is before the new start date).
    const all = sessions(scheduleOf(d, 0));
    expect(all).toHaveLength(6);
    expect(all[0]).toMatchObject({ start: t('2026-12-01T15:00:00Z'), originalStart: t('2026-11-30T15:00:00Z') });
  });

  test('the LAST class moved to the next Monday: no phantom extra Monday class appears', async () => {
    await rescheduleNext(db, 't1', { courseId: 'c1', newStart: t('2026-12-21T15:00:00Z'), newEnd: t('2026-12-21T16:30:00Z'), utcOffsetMinutes: 180 }, t('2026-12-15T09:00:00Z'));
    const d = await course();
    expect(ms(d.endDate)).toBe(t('2026-12-20T21:00:00Z'));
    const all = sessions(scheduleOf(d, 0));
    expect(all).toHaveLength(6);
    expect(all[5]).toMatchObject({ start: t('2026-12-21T15:00:00Z') });
  });

  test('moving the first class twice: the start date is worked out from the original (no drift)', async () => {
    const before = t('2026-11-25T09:00:00Z');
    await rescheduleNext(db, 't1', { courseId: 'c1', newStart: t('2026-12-01T15:00:00Z'), newEnd: t('2026-12-01T16:30:00Z'), utcOffsetMinutes: 180 }, before);
    await rescheduleNext(db, 't1', { courseId: 'c1', newStart: t('2026-11-28T15:00:00Z'), newEnd: t('2026-11-28T16:30:00Z') }, before);
    expect(ms((await course()).startDate)).toBe(t('2026-11-27T21:00:00Z'));
  });

  test('the LAST class moved after the end: the end date follows (ratings and payouts wait for it)', async () => {
    await rescheduleNext(db, 't1', { courseId: 'c1', newStart: t('2026-12-19T15:00:00Z'), newEnd: t('2026-12-19T16:30:00Z'), utcOffsetMinutes: 180 }, t('2026-12-15T09:00:00Z'));
    expect(ms((await course()).endDate)).toBe(t('2026-12-18T21:00:00Z'));
  });

  test('a refused move changes nothing and says why', async () => {
    await expect(rescheduleNext(db, 't1', { courseId: 'c1', newStart: t('2026-12-09T09:00:00Z'), newEnd: t('2026-12-09T10:00:00Z'), utcOffsetMinutes: 180 }, t('2026-12-03T09:00:00Z')))
      .rejects.toMatchObject({ code: 'failed-precondition', details: { reason: 'afterWindow' } });
    const d = await course();
    expect(d.sessionMoves).toBeUndefined();
    expect(d.rescheduledSession).toBeUndefined();
  });

  test('only the course\'s teacher', async () => {
    await expect(rescheduleNext(db, 'other', { courseId: 'c1', newStart: t('2026-12-01T15:00:00Z'), newEnd: t('2026-12-01T16:30:00Z') }, t('2026-11-25T09:00:00Z')))
      .rejects.toMatchObject({ code: 'permission-denied' });
  });

  test('moving the same class again replaces its move; an earlier class\'s move is kept', async () => {
    // Move class 1 (Mon 30 Nov) to Tue 1 Dec; it happens; then class 2 is next.
    await rescheduleNext(db, 't1', { courseId: 'c1', newStart: t('2026-12-01T15:00:00Z'), newEnd: t('2026-12-01T16:30:00Z'), utcOffsetMinutes: 180 }, t('2026-11-25T09:00:00Z'));
    // Wed 2 Dec: move it twice.
    const now = t('2026-12-01T18:00:00Z');
    await rescheduleNext(db, 't1', { courseId: 'c1', newStart: t('2026-12-03T15:00:00Z'), newEnd: t('2026-12-03T16:00:00Z') }, now);
    await rescheduleNext(db, 't1', { courseId: 'c1', newStart: t('2026-12-04T15:00:00Z'), newEnd: t('2026-12-04T16:00:00Z') }, now);
    const d = await course();
    expect(d.sessionMoves.map((m) => ms(m.originalStart)).sort()).toEqual([t('2026-11-30T15:00:00Z'), t('2026-12-02T15:00:00Z')]);
    const all = sessions(scheduleOf(d, 0));
    expect(all.filter((x) => x.originalStart).map((x) => x.start)).toEqual([t('2026-12-01T15:00:00Z'), t('2026-12-04T15:00:00Z')]);
    expect(all).toHaveLength(6);
  });

  test('undo puts the class back AND restores the dates the move changed', async () => {
    await rescheduleNext(db, 't1', { courseId: 'c1', newStart: t('2026-12-19T15:00:00Z'), newEnd: t('2026-12-19T16:30:00Z'), utcOffsetMinutes: 180 }, t('2026-12-15T09:00:00Z'));
    await cancelNextReschedule(db, 't1', { courseId: 'c1' }, t('2026-12-15T10:00:00Z'));
    const d = await course();
    expect(ms(d.endDate)).toBe(t(c.endDate));
    expect(d.rescheduledSession).toBeUndefined();
    expect(d.sessionMoves).toEqual([]);
  });

  test('undo is refused when the usual time has already passed (it would put the class in the past)', async () => {
    // Mon 7 Dec 18:00 moved to Tue 8 Dec; on Tue morning the Monday slot is gone.
    await rescheduleNext(db, 't1', { courseId: 'c1', newStart: t('2026-12-08T15:00:00Z'), newEnd: t('2026-12-08T16:00:00Z'), utcOffsetMinutes: 180 }, t('2026-12-03T09:00:00Z'));
    await expect(cancelNextReschedule(db, 't1', { courseId: 'c1' }, t('2026-12-08T06:00:00Z')))
      .rejects.toMatchObject({ details: { reason: 'originalPassed' } });
  });

  test('undo when nothing was moved: refused', async () => {
    await expect(cancelNextReschedule(db, 't1', { courseId: 'c1' }, t('2026-12-03T09:00:00Z')))
      .rejects.toMatchObject({ details: { reason: 'notRescheduled' } });
  });

  test('older app versions (only originalDate) are still understood', async () => {
    await db.doc('courses/c1').update({
      scheduleUtcOffsetMinutes: 180,
      rescheduledSession: { originalDate: T('2026-12-07T06:00:00Z'), newStartTime: T('2026-12-07T17:00:00Z'), newEndTime: T('2026-12-07T18:00:00Z') },
    });
    const all = sessions(scheduleOf(await course(), 0));
    expect(all.find((x) => x.originalStart === t('2026-12-07T15:00:00Z')).start).toBe(t('2026-12-07T17:00:00Z'));
  });
});
