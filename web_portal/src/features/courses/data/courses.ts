import { collection, doc, getDoc, getDocs, limit, onSnapshot, orderBy, query, where, type Firestore } from "firebase/firestore";
import { newestFirst } from "../domain/coursePolicy";

/** A course document with its id (the fields the pages already read). */
export type CourseDoc = { id: string; [field: string]: any };

const withId = (d: { id: string; data(): any }): CourseDoc => ({ id: d.id, ...d.data() });

/** Course reads in the browser (courses are public). Every watch returns its stop function. */
export async function getCourse(db: Firestore, courseId: string): Promise<CourseDoc | null> {
  if (!courseId) return null;
  const snap = await getDoc(doc(db, "courses", courseId));
  return snap.exists() ? withId(snap) : null;
}

export function watchCourse(db: Firestore, courseId: string, onChange: (course: CourseDoc | null) => void): () => void {
  return onSnapshot(doc(db, "courses", courseId), (snap) => onChange(snap.exists() ? withId(snap) : null));
}

/** Every course, newest first (the catalog). */
export function watchCatalog(db: Firestore, onChange: (courses: CourseDoc[]) => void): () => void {
  return onSnapshot(query(collection(db, "courses"), orderBy("createdAt", "desc")), (snap) => onChange(snap.docs.map(withId)));
}

/** A few courses for the home page slider. */
export async function getFeaturedCourses(db: Firestore, count = 6): Promise<CourseDoc[]> {
  return (await getDocs(query(collection(db, "courses"), limit(count)))).docs.map(withId);
}

/** One teacher's courses (all of them, once). */
export async function getTeacherCourses(db: Firestore, teacherId: string): Promise<CourseDoc[]> {
  return (await getDocs(query(collection(db, "courses"), where("teacherId", "==", teacherId)))).docs.map(withId);
}

/** One teacher's courses, newest first, live. */
export function watchTeacherCourses(db: Firestore, teacherId: string, onChange: (courses: CourseDoc[]) => void): () => void {
  return onSnapshot(query(collection(db, "courses"), where("teacherId", "==", teacherId)), (snap) =>
    onChange(newestFirst(snap.docs.map(withId))),
  );
}

/** How many courses a teacher has, live. */
export function watchTeacherCourseCount(db: Firestore, teacherId: string, onChange: (count: number) => void): () => void {
  return onSnapshot(query(collection(db, "courses"), where("teacherId", "==", teacherId)), (snap) => onChange(snap.size));
}
