import { collection, doc, getDoc, getDocs, limit, onSnapshot, query, where, type Firestore } from "firebase/firestore";
import { getTeacherCourses } from "@/features/courses/data/courses";
import { teacherStudentCount } from "@/features/courses/domain/coursePolicy";

/** A teacher's public profile with its uid. */
export type TeacherDoc = { uid: string; [field: string]: any };

/** Teacher reads in the browser (profiles are public). */
export async function getTeacher(db: Firestore, teacherId: string): Promise<TeacherDoc | null> {
  if (!teacherId) return null;
  const snap = await getDoc(doc(db, "users", teacherId));
  return snap.exists() ? { uid: snap.id, ...snap.data() } : null;
}

/** Everyone with the teacher role, live. */
export function watchTeachers(db: Firestore, onChange: (teachers: TeacherDoc[]) => void): () => void {
  return onSnapshot(query(collection(db, "users"), where("role", "==", "teacher")), (snap) =>
    onChange(snap.docs.map((d) => ({ uid: d.id, ...d.data() }))),
  );
}

/** A few teachers for the home page, each with how many students they teach. */
export async function getFeaturedTeachers(db: Firestore, count = 3): Promise<Array<{ id: string; studentsCount: number; [field: string]: any }>> {
  const snap = await getDocs(query(collection(db, "users"), where("role", "==", "teacher"), limit(count)));
  return Promise.all(
    snap.docs.map(async (d) => {
      let studentsCount = 0;
      try {
        studentsCount = teacherStudentCount(await getTeacherCourses(db, d.id));
      } catch (e) {
        console.error("Error fetching courses for teacher:", e);
      }
      return { id: d.id, ...d.data(), studentsCount };
    }),
  );
}
