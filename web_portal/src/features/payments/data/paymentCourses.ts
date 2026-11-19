import { doc, getDoc, onSnapshot, type Firestore } from "firebase/firestore";

/** A course document with its id (the fields the pages already read). */
export type CourseDoc = { id: string; [field: string]: any };

/** Reads for buying a course, in the browser (courses and profiles are public). */
export async function getCourse(db: Firestore, courseId: string): Promise<CourseDoc | null> {
  if (!courseId) return null;
  const snap = await getDoc(doc(db, "courses", courseId));
  return snap.exists() ? { id: snap.id, ...snap.data() } : null;
}

export async function getTeacher(db: Firestore, teacherId: string): Promise<Record<string, any> | null> {
  if (!teacherId) return null;
  const snap = await getDoc(doc(db, "users", teacherId));
  return snap.exists() ? snap.data() : null;
}

/** Live course updates (null when it does not exist). Returns the stop function. */
export function watchCourse(db: Firestore, courseId: string, onChange: (course: CourseDoc | null) => void): () => void {
  return onSnapshot(doc(db, "courses", courseId), (snap) => onChange(snap.exists() ? { id: snap.id, ...snap.data() } : null));
}
