/**
 * Course rules shared by the catalog, the teacher page and the home page (they
 * each had their own copy). Pure TypeScript: course documents in, answers out.
 */
type Course = Record<string, any>;

/** A Firestore Timestamp, a Date, an ISO string or a number → Date (null if unreadable). */
export function toDate(value: unknown): Date | null {
  if (value == null) return null;
  const v: any = value;
  const d = typeof v.toDate === "function" ? v.toDate() : new Date(v);
  return d instanceof Date && !isNaN(d.getTime()) ? d : null;
}

function enrolled(course: Course, uid: string | null | undefined): boolean {
  return !!uid && Array.isArray(course.enrolledStudents) && course.enrolledStudents.includes(uid);
}

/** Courses that already started are hidden from people who are not in them (same as the app). */
export function isVisibleInCatalog(course: Course, uid: string | null | undefined, now: Date = new Date()): boolean {
  const start = toDate(course.startDate);
  if (!start) return true;
  return !(now.getTime() > start.getTime() && !enrolled(course, uid));
}

/** The catalog search: name, title, teacher, level and description, ignoring case. */
export function matchesSearch(course: Course, term: string): boolean {
  const t = term.toLowerCase();
  return ["courseName", "courseTitle", "teacherName", "selectedCategory", "courseDescription"].some(
    (f) => typeof course[f] === "string" && course[f].toLowerCase().includes(t),
  );
}

/** "All", "MyCourses" (enrolled only) or a level such as "Beginner". */
export function matchesCategory(course: Course, category: string, uid: string | null | undefined): boolean {
  if (category === "All") return true;
  if (category === "MyCourses") return enrolled(course, uid);
  return course.selectedCategory === category;
}

/** Newest created first (missing dates last). */
export function newestFirst<T extends Course>(courses: T[]): T[] {
  return [...courses].sort((a, b) => (b.createdAt?.seconds || 0) - (a.createdAt?.seconds || 0));
}

/** Students of a teacher, as the home page counts them: enrolled lists + the old studentsEnrolled number. */
export function teacherStudentCount(courses: Course[]): number {
  return courses.reduce(
    (n, c) => n + (Array.isArray(c.enrolledStudents) ? c.enrolledStudents.length : 0) + (c.studentsEnrolled ? Number(c.studentsEnrolled) : 0),
    0,
  );
}
