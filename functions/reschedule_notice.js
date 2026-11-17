/**
 * What students are told when the next class moves (or goes back to its usual
 * time), with the old and new day/time written in each student's own language
 * and time zone. Pure functions; notifications.js sends them.
 */
const { readMove } = require("./schedule.js");

const MIN = 60 * 1000;

/**
 * Compares the course's rescheduledSession before / after an update.
 * Returns null (nothing to tell), or:
 *  { kind: "moved", oldStart, newStart, newEnd, note, offset }
 *  { kind: "back",  oldStart, offset }   (the move was undone and the usual time is still ahead)
 */
function rescheduleNotice(before, after, now = Date.now()) {
  const offOf = (r) => (r && Number.isInteger(r.utcOffsetMinutes) ? r.utcOffsetMinutes : null);
  const b = before ? readMove(before, offOf(before) ?? 0) : null;
  const a = after ? readMove(after, offOf(after) ?? 0) : null;
  const oldStartOf = (r, m) => (m.originalStart ?? (r.originalDate && r.originalDate.toMillis ? r.originalDate.toMillis() : null));

  if (a) {
    const same = b && b.newStart === a.newStart && b.newEnd === a.newEnd && b.note === a.note &&
      oldStartOf(before, b) === oldStartOf(after, a);
    if (same) return null;
    return { kind: "moved", oldStart: oldStartOf(after, a), newStart: a.newStart, newEnd: a.newEnd, note: a.note, offset: offOf(after) };
  }
  if (b && b.originalStart != null && b.originalStart > now) {
    return { kind: "back", oldStart: b.originalStart, offset: offOf(before) };
  }
  return null;
}

const LOCALES = { en: "en-GB", ar: "ar-u-nu-latn", tr: "tr" };

/** "Mon 30 Nov, 18:00" in [lang], at UTC+[offsetMinutes]; labelled "(UTC+3)" when [label]. */
function formatClassTime(t, lang, offsetMinutes, { label = false } = {}) {
  if (t == null) return "";
  const off = Number.isInteger(offsetMinutes) ? offsetMinutes : 0;
  const shifted = new Date(t + off * MIN);
  const text = new Intl.DateTimeFormat(LOCALES[lang] || LOCALES.en, {
    weekday: "short", day: "numeric", month: "short", hour: "2-digit", minute: "2-digit", hourCycle: "h23", timeZone: "UTC",
  }).format(shifted);
  if (!label) return text;
  const h = Math.trunc(Math.abs(off) / 60), m = Math.abs(off) % 60;
  return `${text} (UTC${off < 0 ? "-" : "+"}${h}${m ? ":" + String(m).padStart(2, "0") : ""})`;
}

/**
 * The params for one student: times in THEIR time zone when the app has saved it
 * (users/{uid}.utcOffsetMinutes), otherwise in the course's, labelled with it.
 */
function noticeParams(notice, user, courseName) {
  const own = user && Number.isInteger(user.utcOffsetMinutes) ? user.utcOffsetMinutes : null;
  const offset = own ?? notice.offset ?? 0;
  const label = own == null;
  const lang = (user && user.preferredLanguage) || "en";
  return {
    courseName,
    oldTime: formatClassTime(notice.oldStart, lang, offset, { label }),
    newTime: notice.newStart == null ? "" : formatClassTime(notice.newStart, lang, offset, { label }),
    note: notice.note || "",
  };
}

module.exports = { rescheduleNotice, formatClassTime, noticeParams };
