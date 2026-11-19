/**
 * Certificates with the admin key — SERVER ONLY (never import this from a
 * "use client" file; tests/guardrails enforce it).
 *
 * Every function takes the verified [caller]: the server actions used to skip
 * that, so anyone could issue any certificate or read a teacher's students.
 * Names, course and teacher always come from Firestore, never from the browser.
 */
import { FieldValue, type Firestore } from "firebase-admin/firestore";
import {
  canIssue,
  canIssueAll,
  canLoadTeacherData,
  courseDisplayName,
  studentDisplayName,
  type Caller,
  type CourseFacts,
} from "../domain/certificatePolicy";

export type { Caller } from "../domain/certificatePolicy";

export class CertificateRefused extends Error {
  constructor(message: string) {
    super(message);
    this.name = "CertificateRefused";
  }
}

export interface IssueCertificateParams {
  courseId: string;
  studentId: string;
}

/** The signed-in user behind [idToken] (and whether they are an admin). */
export async function callerFromToken(
  auth: { verifyIdToken(token: string): Promise<{ uid: string }> },
  db: Firestore,
  idToken: string,
): Promise<Caller> {
  if (!idToken) throw new CertificateRefused("Sign in first.");
  let uid: string;
  try {
    uid = (await auth.verifyIdToken(idToken)).uid;
  } catch {
    throw new CertificateRefused("Your session has expired. Please sign in again.");
  }
  const profile = (await db.collection("users").doc(uid).get()).data();
  return { uid, isAdmin: profile?.role === "admin" };
}

function facts(course: Record<string, any>): CourseFacts {
  return {
    teacherId: String(course.teacherId || ""),
    enrolledStudents: Array.isArray(course.enrolledStudents) ? course.enrolledStudents.map(String) : [],
  };
}

async function loadCourse(db: Firestore, courseId: string) {
  if (!courseId) throw new CertificateRefused("Course ID is required.");
  const snap = await db.collection("courses").doc(courseId).get();
  if (!snap.exists) throw new CertificateRefused("Course not found.");
  return snap.data()!;
}

/** Issues (or returns the existing) certificate of [studentId] in [courseId]. */
export async function issueCertificate(db: Firestore, caller: Caller, { courseId, studentId }: IssueCertificateParams) {
  if (!courseId || !studentId) throw new CertificateRefused("Course ID and Student ID are required.");
  const course = await loadCourse(db, courseId);
  if (!canIssue(caller, facts(course), studentId)) {
    throw new CertificateRefused("You cannot issue this certificate.");
  }

  const existingSnap = await db
    .collection("certificates")
    .where("courseId", "==", courseId)
    .where("studentId", "==", studentId)
    .limit(1)
    .get();
  if (!existingSnap.empty) {
    const docSnap = existingSnap.docs[0];
    const data = docSnap.data();
    return {
      success: true as const,
      isNew: false,
      certificate: {
        id: docSnap.id,
        ...data,
        issueDate: data.issueDate?.toDate ? data.issueDate.toDate().toISOString() : new Date().toISOString(),
      },
    };
  }

  const userDoc = await db.collection("users").doc(studentId).get();
  const certData = {
    studentId,
    studentName: studentDisplayName(userDoc.exists ? userDoc.data() : undefined),
    courseId,
    courseName: courseDisplayName(course),
    teacherId: String(course.teacherId || ""),
    issueDate: FieldValue.serverTimestamp(),
  };
  const newRef = db.collection("certificates").doc();
  await newRef.set(certData);
  return {
    success: true as const,
    isNew: true,
    certificate: { id: newRef.id, ...certData, issueDate: new Date().toISOString() },
  };
}

/** Issues certificates for every enrolled student of [courseId] who does not have one yet. */
export async function issueAllPendingCertificates(db: Firestore, caller: Caller, courseId: string) {
  const course = await loadCourse(db, courseId);
  const f = facts(course);
  if (!canIssueAll(caller, f)) throw new CertificateRefused("Only the course's teacher can issue these certificates.");
  if (f.enrolledStudents.length === 0) return { success: true as const, count: 0, certificates: [] as any[] };

  const existingSnap = await db.collection("certificates").where("courseId", "==", courseId).get();
  const existingStudentIds = new Set(existingSnap.docs.map((d) => d.data().studentId));
  const pendingUids = f.enrolledStudents.filter((uid) => !existingStudentIds.has(uid));
  if (pendingUids.length === 0) return { success: true as const, count: 0, certificates: [] as any[] };

  const cName = courseDisplayName(course);
  const tId = f.teacherId;
  const createdCerts: any[] = [];
  const batch = db.batch();
  for (const uid of pendingUids) {
    let sName = "Student";
    try {
      const uDoc = await db.collection("users").doc(uid).get();
      if (uDoc.exists) sName = studentDisplayName(uDoc.data());
    } catch {
      // Fallback name
    }
    const newRef = db.collection("certificates").doc();
    batch.set(newRef, {
      studentId: uid,
      studentName: sName,
      courseId,
      courseName: cName,
      teacherId: tId,
      issueDate: FieldValue.serverTimestamp(),
    });
    createdCerts.push({ id: newRef.id, studentId: uid, studentName: sName, courseId, courseName: cName, teacherId: tId, issueDate: new Date().toISOString() });
  }
  await batch.commit();
  return { success: true as const, count: createdCerts.length, certificates: createdCerts };
}

/** All course, certificate and enrolled-student data for [teacherId]'s certificates page. */
export async function loadTeacherCertificates(db: Firestore, caller: Caller, teacherId: string) {
  if (!teacherId) throw new CertificateRefused("Teacher ID is required.");
  if (!canLoadTeacherData(caller, teacherId)) throw new CertificateRefused("You can only see your own certificates.");
  // 1. Fetch courses owned by this teacher
  const coursesSnap = await db
    .collection("courses")
    .where("teacherId", "==", teacherId)
    .get();

  const courses = coursesSnap.docs.map((d) => {
    const data = d.data();
    return {
      id: d.id,
      courseName: data.courseName || data.courseTitle || data.title || "Untitled Course",
      enrolledStudents: Array.isArray(data.enrolledStudents) ? data.enrolledStudents : [],
      ...data,
    };
  });

  const courseIds = courses.map((c) => c.id);

  // 2. Fetch certificates belonging to this teacher or to any of the teacher's courses
  const certMap = new Map<string, any>();

  const teacherCertsSnap = await db
    .collection("certificates")
    .where("teacherId", "==", teacherId)
    .get();

  teacherCertsSnap.docs.forEach((docSnap) => {
    const data = docSnap.data();
    certMap.set(docSnap.id, {
      id: docSnap.id,
      ...data,
      issueDate: data.issueDate?.toDate ? data.issueDate.toDate().toISOString() : data.issueDate || null,
    });
  });

  // Also catch certificates by courseId in chunks of 30 (in case legacy certs had no teacherId)
  for (let i = 0; i < courseIds.length; i += 30) {
    const chunk = courseIds.slice(i, i + 30);
    if (chunk.length > 0) {
      const cSnap = await db
        .collection("certificates")
        .where("courseId", "in", chunk)
        .get();
      cSnap.docs.forEach((docSnap) => {
        if (!certMap.has(docSnap.id)) {
          const data = docSnap.data();
          certMap.set(docSnap.id, {
            id: docSnap.id,
            ...data,
            issueDate: data.issueDate?.toDate ? data.issueDate.toDate().toISOString() : data.issueDate || null,
          });
        }
      });
    }
  }

  const certificates = Array.from(certMap.values());

  // 3. Resolve student details for all enrolled students
  const allStudentIds = new Set<string>();
  courses.forEach((c) => {
    (c.enrolledStudents || []).forEach((uid: string) => allStudentIds.add(uid));
  });
  certificates.forEach((cert) => {
    if (cert.studentId) allStudentIds.add(cert.studentId);
  });

  const studentList = Array.from(allStudentIds);
  const userDetailsMap: Record<string, any> = {};

  await Promise.all(
    studentList.map(async (uid) => {
      try {
        const uDoc = await db.collection("users").doc(uid).get();
        if (uDoc.exists) {
          const u = uDoc.data()!;
          userDetailsMap[uid] = {
            id: uid,
            name: u.name || u.displayName || u.email?.split("@")[0] || "Student",
            email: u.email || "",
            photoUrl: u.photoUrl || u.profilePic || u.avatarUrl || null,
          };
        } else {
          userDetailsMap[uid] = { id: uid, name: "Student", email: "" };
        }
      } catch {
        userDetailsMap[uid] = { id: uid, name: "Student", email: "" };
      }
    })
  );

  const studentsByCourse: Record<string, any[]> = {};
  courses.forEach((c) => {
    studentsByCourse[c.id] = (c.enrolledStudents || []).map(
      (uid: string) => userDetailsMap[uid] || { id: uid, name: "Student", email: "" }
    );
  });

  return {
    success: true as const,
    courses,
    certificates,
    studentsByCourse,
  };
}
