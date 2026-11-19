/** True when [uid] is enrolled in [course] (its enrolledStudents list). */
export function isEnrolled(course: Record<string, unknown> | null | undefined, uid: string | null | undefined): boolean {
  if (!course || !uid) return false;
  return Array.isArray(course.enrolledStudents) && course.enrolledStudents.includes(uid);
}
