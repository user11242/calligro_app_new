/**
 * Who may do what with certificates (pure rules; the server applies them).
 *  - a student: only their own certificate, for a course they are enrolled in;
 *  - the course's teacher or an admin: certificates for enrolled students,
 *    "issue all", and (teacher: their own) certificates overview.
 */
export type Caller = { uid: string; isAdmin: boolean };
export type CourseFacts = { teacherId: string; enrolledStudents: string[] };

export function canIssue(caller: Caller, course: CourseFacts, studentId: string): boolean {
  if (!course.enrolledStudents.includes(studentId)) return false;
  return caller.isAdmin || caller.uid === course.teacherId || caller.uid === studentId;
}

export function canIssueAll(caller: Caller, course: CourseFacts): boolean {
  return caller.isAdmin || caller.uid === course.teacherId;
}

export function canLoadTeacherData(caller: Caller, teacherId: string): boolean {
  return caller.isAdmin || caller.uid === teacherId;
}

/** The name printed on a certificate: name → displayName → email prefix → "Student" (as before). */
export function studentDisplayName(user: Record<string, any> | undefined): string {
  if (!user) return "Student";
  return user.name || user.displayName || (typeof user.email === "string" ? user.email.split("@")[0] : "") || "Student";
}

export function courseDisplayName(course: Record<string, any>, fallback = "Course"): string {
  return course.courseName || course.courseTitle || course.title || fallback;
}
