/**
 * Moving the next class (rescheduling) is done HERE, never by the app.
 *
 * The schedule rule mirrors lib/features/courses/domain/course_schedule.dart;
 * both run the same cases (test/fixtures/schedule_cases.json), so the app and
 * the server always agree on which classes exist and what may move.
 *
 * Rules (decided with the owner):
 *  - only the NEXT class (the first that has not started) can be moved;
 *  - from now (and not on the previous class's day) until the day before the
 *    following class; the last class up to 7 days after the end date;
 *  - same day start and end (no crossing midnight), at most 6 hours;
 *  - moving the FIRST class moves the course start date with it; moving the
 *    LAST class later pushes the end date (never earlier) — so selling,
 *    rating pop-ups, reviews and teacher payouts follow the real classes.
 *
 * The regular classes are always counted in the ORIGINAL date range
 * (scheduleStartDate / scheduleEndDate, kept by the server the first time a move
 * changes the public dates; apps cannot write them), so a moved first/last
 * class never makes its own slot vanish or adds a phantom class, and undo just
 * works the dates out again from the originals.
 */
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");

const MIN = 60 * 1000;
const DAY = 24 * 60 * MIN;
const LAST_CLASS_GRACE_DAYS = 7;
const MAX_CLASS = 6 * 60 * MIN;
const DEFAULT_LENGTH = 90 * MIN;
const MAX_DAYS = 800;
const MAX_NOTE = 300;
const DAY_NAMES = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"];

const ms = (v) => {
  if (v == null) return null;
  if (typeof v.toMillis === "function") return v.toMillis();
  if (v instanceof Date) return v.getTime();
  if (typeof v === "number") return v;
  if (typeof v === "string") { const t = Date.parse(v); return Number.isNaN(t) ? null : t; }
  return null;
};

// ── Days in the course's time zone: "local" = a UTC-ms number shifted by the offset ──
const toLocal = (t, off) => t + off * MIN;
const fromLocal = (l, off) => l - off * MIN;
const dayOf = (local) => Math.floor(local / DAY) * DAY; // local midnight (as local ms)
const dayKey = (localDay) => new Date(localDay).toISOString().slice(0, 10);
const weekdayOf = (localDay) => ((new Date(localDay).getUTCDay() + 6) % 7) + 1; // 1 = Monday

/** The schedule of a course document (moves from sessionMoves + rescheduledSession). */
function scheduleOf(course, fallbackOffsetMinutes) {
  const off = typeof course.scheduleUtcOffsetMinutes === "number" ? course.scheduleUtcOffsetMinutes : fallbackOffsetMinutes;
  const moves = [];
  for (const m of Array.isArray(course.sessionMoves) ? course.sessionMoves : []) {
    const mv = readMove(m, off);
    if (mv) moves.push(mv);
  }
  if (course.rescheduledSession) {
    const mv = readMove(course.rescheduledSession, off);
    if (mv) moves.push(mv);
  }
  return {
    weekdays: new Set((course.selectedDays || []).map((n) => DAY_NAMES.indexOf(String(n)) + 1).filter((d) => d > 0)),
    startDate: ms(course.startDate),
    endDate: ms(course.endDate),
    rangeStart: ms(course.scheduleStartDate) ?? ms(course.startDate),
    rangeEnd: ms(course.scheduleEndDate) ?? ms(course.endDate),
    startTime: ms(course.startTime) ?? ms(course.selectedTime),
    endTime: ms(course.endTime),
    offset: off,
    moves,
  };
}

function readMove(m, off) {
  if (!m) return null;
  const newStart = ms(m.newStart) ?? ms(m.newStartTime);
  const newEnd = ms(m.newEnd) ?? ms(m.newEndTime);
  if (newStart == null || newEnd == null) return null;
  const exact = ms(m.originalStart) ?? ms(m.originalStartTime);
  const day = ms(m.originalDate);
  if (exact == null && day == null) return null;
  return {
    originalStart: exact,
    originalDay: exact == null ? dayKey(dayOf(toLocal(day, off))) : null,
    newStart,
    newEnd,
    note: typeof m.note === "string" ? m.note : "",
  };
}

function lengthOf(s) {
  if (s.startTime == null || s.endTime == null) return DEFAULT_LENGTH;
  const a = new Date(toLocal(s.startTime, s.offset)), b = new Date(toLocal(s.endTime, s.offset));
  let d = (b.getUTCHours() - a.getUTCHours()) * 60 * MIN + (b.getUTCMinutes() - a.getUTCMinutes()) * MIN;
  if (d < 0) d += DAY;
  if (d <= 0 || d > MAX_CLASS) return DEFAULT_LENGTH;
  return d;
}

function regular(s) {
  if (s.startTime == null || s.rangeStart == null || s.weekdays.size === 0) return [];
  const t = new Date(toLocal(s.startTime, s.offset));
  const timeOfDay = (t.getUTCHours() * 60 + t.getUTCMinutes()) * MIN;
  const first = dayOf(toLocal(s.rangeStart, s.offset));
  const last = s.rangeEnd == null ? first + MAX_DAYS * DAY : dayOf(toLocal(s.rangeEnd, s.offset));
  const len = lengthOf(s);
  const out = [];
  for (let day = first, i = 0; day <= last && i < MAX_DAYS; day += DAY, i++) {
    if (!s.weekdays.has(weekdayOf(day))) continue;
    const start = fromLocal(day + timeOfDay, s.offset);
    out.push({ start, end: start + len });
  }
  return out;
}

/** Every class, moves applied, oldest first. */
function sessions(s) {
  const out = regular(s).map((slot) => {
    let move = null;
    for (const m of s.moves) {
      const hit = m.originalStart != null ? m.originalStart === slot.start : m.originalDay === dayKey(dayOf(toLocal(slot.start, s.offset)));
      if (hit) move = m;
    }
    return move
      ? { start: move.newStart, end: move.newEnd, originalStart: slot.start, originalEnd: slot.end, note: move.note }
      : slot;
  });
  return out.sort((a, b) => a.start - b.start);
}

const slotStart = (session) => session.originalStart ?? session.start;

function rescheduleWindow(s, now) {
  const all = sessions(s);
  const i = all.findIndex((x) => x.start > now);
  if (i < 0) return null;
  const session = all[i];
  const prev = i > 0 ? all[i - 1] : null;
  const following = i + 1 < all.length ? all[i + 1] : null;
  let earliest = now;
  if (prev) {
    const dayAfterPrev = fromLocal(dayOf(toLocal(prev.start, s.offset)) + DAY, s.offset);
    if (dayAfterPrev > earliest) earliest = dayAfterPrev;
  }
  let latestDay;
  if (following) latestDay = dayOf(toLocal(following.start, s.offset)) - DAY;
  else {
    const end = s.rangeEnd == null ? dayOf(toLocal(slotStart(session), s.offset)) : dayOf(toLocal(s.rangeEnd, s.offset));
    latestDay = end + LAST_CLASS_GRACE_DAYS * DAY;
  }
  return {
    session,
    isFirst: i === 0,
    isLast: !following,
    earliest,
    latestDay: dayKey(latestDay),
    latestEnd: fromLocal(latestDay + DAY, s.offset),
  };
}

function planMove(s, { now, newStart, newEnd }) {
  const w = rescheduleWindow(s, now);
  if (!w) return { error: "noNextSession" };
  if (!(newEnd > newStart)) return { error: "endBeforeStart", window: w };
  if (newEnd - newStart > MAX_CLASS) return { error: "tooLong", window: w };
  const startDay = dayOf(toLocal(newStart, s.offset));
  if (startDay !== dayOf(toLocal(newEnd - 1, s.offset))) return { error: "crossesMidnight", window: w };
  if (newStart < w.earliest) return { error: "beforeWindow", window: w };
  if (newStart >= w.latestEnd) return { error: "afterWindow", window: w };

  // Always from the ORIGINAL range: re-moves and undo never drift.
  let startDate = s.startDate;
  if (w.isFirst && s.rangeStart != null) {
    startDate = s.rangeStart + (startDay - dayOf(toLocal(slotStart(w.session), s.offset)));
  }
  let endDate = s.endDate;
  if (w.isLast && s.rangeEnd != null) {
    const shift = startDay - dayOf(toLocal(s.rangeEnd, s.offset));
    endDate = shift > 0 ? s.rangeEnd + shift : s.rangeEnd;
  }
  return { window: w, startDate, endDate };
}

// ─────────────────────────────────────────────────────────────────────────────
// Server operations
// ─────────────────────────────────────────────────────────────────────────────

const ts = (t) => admin.firestore.Timestamp.fromMillis(t);

function validOffset(v) {
  return Number.isInteger(v) && v >= -14 * 60 && v <= 14 * 60 ? v : null;
}

/** Keeps moves that still matter (their old or new time is less than a day ago), one per slot. */
function keptMoves(course, s, now, dropSlot) {
  const bySlot = new Map();
  for (const m of Array.isArray(course.sessionMoves) ? course.sessionMoves : []) {
    const o = ms(m.originalStart), n = ms(m.newEnd);
    if (o == null || n == null || o === dropSlot) continue;
    if (Math.max(o, n) < now - DAY) continue;
    bySlot.set(o, m);
  }
  return [...bySlot.values()];
}

async function loadOwned(tx, db, uid, courseId) {
  if (typeof courseId !== "string" || !courseId) throw new HttpsError("invalid-argument", "Missing course.");
  const ref = db.collection("courses").doc(courseId);
  const snap = await tx.get(ref);
  if (!snap.exists) throw new HttpsError("not-found", "Course not found.");
  const course = snap.data();
  if (course.teacherId !== uid) throw new HttpsError("permission-denied", "Only the course's teacher can change its classes.");
  return { ref, course };
}

/** Moves the next class of [courseId] to [newStart]–[newEnd] (ms). */
async function rescheduleNext(db, uid, { courseId, newStart, newEnd, note, utcOffsetMinutes }, now = Date.now()) {
  if (typeof newStart !== "number" || typeof newEnd !== "number") throw new HttpsError("invalid-argument", "Missing the new time.");
  const cleanNote = typeof note === "string" ? note.trim().slice(0, MAX_NOTE) : "";
  return db.runTransaction(async (tx) => {
    const { ref, course } = await loadOwned(tx, db, uid, courseId);
    const offset = typeof course.scheduleUtcOffsetMinutes === "number" ? course.scheduleUtcOffsetMinutes : validOffset(utcOffsetMinutes) ?? 0;
    const s = scheduleOf(course, offset);
    const plan = planMove(s, { now, newStart, newEnd });
    if (plan.error) throw new HttpsError("failed-precondition", `Cannot move the class: ${plan.error}`, { reason: plan.error });

    const slot = slotStart(plan.window.session);
    const slotEnd = plan.window.session.originalEnd ?? plan.window.session.end;
    const moves = keptMoves(course, s, now, slot);
    moves.push({ originalStart: ts(slot), newStart: ts(newStart), newEnd: ts(newEnd), note: cleanNote });

    const update = {
      sessionMoves: moves,
      scheduleUtcOffsetMinutes: offset,
      // Same keys older app versions read (they show "today's" reschedule).
      rescheduledSession: {
        originalDate: ts(slot),
        originalStartTime: ts(slot),
        originalEndTime: ts(slotEnd),
        newStartTime: ts(newStart),
        newEndTime: ts(newEnd),
        note: cleanNote,
        utcOffsetMinutes: offset,
        changedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
    };
    if (plan.startDate != null && plan.startDate !== s.startDate) update.startDate = ts(plan.startDate);
    if (plan.endDate != null && plan.endDate !== s.endDate) update.endDate = ts(plan.endDate);
    // The original range, kept once (the regular classes are always counted in it).
    if (course.scheduleStartDate == null && course.startDate != null) update.scheduleStartDate = course.startDate;
    if (course.scheduleEndDate == null && course.endDate != null) update.scheduleEndDate = course.endDate;

    tx.update(ref, update);
    return {
      originalStart: slot,
      newStart,
      newEnd,
      startDate: update.startDate ? plan.startDate : null,
      endDate: update.endDate ? plan.endDate : null,
    };
  });
}

/** Puts the next class (when it was moved, and its usual time is still ahead) back at its usual time. */
async function cancelNextReschedule(db, uid, { courseId }, now = Date.now()) {
  return db.runTransaction(async (tx) => {
    const { ref, course } = await loadOwned(tx, db, uid, courseId);
    const s = scheduleOf(course, course.scheduleUtcOffsetMinutes ?? 0);
    const w = rescheduleWindow(s, now);
    if (!w || !w.session.originalStart) throw new HttpsError("failed-precondition", "The next class was not moved.", { reason: "notRescheduled" });
    const slot = w.session.originalStart;
    if (slot <= now) throw new HttpsError("failed-precondition", "Its usual time has already passed.", { reason: "originalPassed" });

    const update = { sessionMoves: keptMoves(course, s, now, slot) };
    const current = readMove(course.rescheduledSession, s.offset);
    const currentSlot = current && (current.originalStart ?? null);
    if (course.rescheduledSession && (currentSlot === slot || currentSlot == null)) {
      update.rescheduledSession = admin.firestore.FieldValue.delete();
    }
    // Back to the original dates when this was the first / last class.
    if (w.isFirst && course.scheduleStartDate != null) update.startDate = course.scheduleStartDate;
    if (w.isLast && course.scheduleEndDate != null) update.endDate = course.scheduleEndDate;
    tx.update(ref, update);
    return { originalStart: slot };
  });
}

function callable(fn) {
  return onCall(async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Sign in first.");
    try {
      return await fn(admin.firestore(), request.auth.uid, request.data || {});
    } catch (e) {
      if (e instanceof HttpsError) throw e;
      console.error("schedule change failed", e);
      throw new HttpsError("internal", "Could not change the class.");
    }
  });
}

exports.rescheduleNextSession = callable(rescheduleNext);
exports.cancelNextSessionReschedule = callable(cancelNextReschedule);

exports.scheduleOf = scheduleOf;
exports.sessions = sessions;
exports.rescheduleWindow = rescheduleWindow;
exports.planMove = planMove;
exports.readMove = readMove;
exports.rescheduleNext = rescheduleNext;
exports.cancelNextReschedule = cancelNextReschedule;
