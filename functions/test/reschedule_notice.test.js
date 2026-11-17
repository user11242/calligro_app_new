/** What students are told when the next class moves (pure). */
const admin = require('firebase-admin');
const { rescheduleNotice, formatClassTime, noticeParams } = require('../reschedule_notice');

const T = (iso) => admin.firestore.Timestamp.fromDate(new Date(iso));
const t = (iso) => Date.parse(iso);
const moved = (o = {}) => ({
  originalDate: T('2026-11-30T15:00:00Z'), originalStartTime: T('2026-11-30T15:00:00Z'),
  newStartTime: T('2026-12-01T16:00:00Z'), newEndTime: T('2026-12-01T17:30:00Z'), note: 'Travelling', utcOffsetMinutes: 180, ...o,
});
const NOW = t('2026-11-25T09:00:00Z');

describe('rescheduleNotice: what changed', () => {
  test('a new move → "moved" with the old and new time and the note', () => {
    expect(rescheduleNotice(null, moved(), NOW)).toEqual({
      kind: 'moved', oldStart: t('2026-11-30T15:00:00Z'), newStart: t('2026-12-01T16:00:00Z'), newEnd: t('2026-12-01T17:30:00Z'), note: 'Travelling', offset: 180,
    });
  });
  test('moved again to another time → told again', () => {
    expect(rescheduleNotice(moved(), moved({ newStartTime: T('2026-12-01T17:00:00Z') }), NOW).newStart).toBe(t('2026-12-01T17:00:00Z'));
  });
  test('only the note changed → told (the note is news)', () => {
    expect(rescheduleNotice(moved(), moved({ note: 'Bring ink' }), NOW).note).toBe('Bring ink');
  });
  test('nothing about the move changed (e.g. another course field was edited) → silent', () => {
    expect(rescheduleNotice(moved(), moved(), NOW)).toBeNull();
    expect(rescheduleNotice(null, null, NOW)).toBeNull();
  });
  test('undone while the usual time is still ahead → "back"', () => {
    expect(rescheduleNotice(moved(), null, NOW)).toEqual({ kind: 'back', oldStart: t('2026-11-30T15:00:00Z'), offset: 180 });
  });
  test('cleared after the usual time passed → silent (nothing to go back to)', () => {
    expect(rescheduleNotice(moved(), null, t('2026-12-02T00:00:00Z'))).toBeNull();
  });
  test('older app versions (only originalDate, no zone) are still announced', () => {
    const old = { originalDate: T('2026-11-30T06:00:00Z'), newStartTime: T('2026-11-30T17:00:00Z'), newEndTime: T('2026-11-30T18:00:00Z') };
    expect(rescheduleNotice(null, old, NOW)).toMatchObject({ kind: 'moved', newStart: t('2026-11-30T17:00:00Z') });
  });
});

describe('the times students read', () => {
  test('in each language, at the right local time', () => {
    expect(formatClassTime(t('2026-11-30T15:00:00Z'), 'en', 180)).toBe('Mon 30 Nov, 18:00');
    expect(formatClassTime(t('2026-11-30T15:00:00Z'), 'tr', 180)).toMatch(/30 Kas.*18:00/);
    expect(formatClassTime(t('2026-11-30T15:00:00Z'), 'ar', 180)).toMatch(/30.*18:00/);
  });
  test('a student whose time zone the app saved sees their own time; others get the course time, labelled', () => {
    const n = rescheduleNotice(null, moved(), NOW);
    expect(noticeParams(n, { preferredLanguage: 'en', utcOffsetMinutes: 60 }, 'Thuluth')).toEqual({
      courseName: 'Thuluth', oldTime: 'Mon 30 Nov, 16:00', newTime: 'Tue 1 Dec, 17:00', note: 'Travelling',
    });
    expect(noticeParams(n, { preferredLanguage: 'en' }, 'Thuluth').newTime).toBe('Tue 1 Dec, 19:00 (UTC+3)');
  });
});
