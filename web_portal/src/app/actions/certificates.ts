"use server";

import { adminDb } from "@/lib/firebaseAdmin";
import { FieldValue } from "firebase-admin/firestore";

export interface IssueCertificateParams {
  courseId: string;
  studentId: string;
  studentName?: string;
  teacherId?: string;
  courseName?: string;
}

/**
 * Issues or retrieves a certificate for a student in a course using adminDb.
 * This completely prevents client-side Firestore security rule rejections.
 */
export async function issueCertificateAction({
  courseId,
  studentId,
  studentName,
  teacherId,
  courseName,
}: IssueCertificateParams) {
  try {
    if (!courseId || !studentId) {
      return { success: false, error: "Course ID and Student ID are required." };
    }

    // Check if certificate already exists
    const existingSnap = await adminDb
      .collection("certificates")
      .where("courseId", "==", courseId)
      .where("studentId", "==", studentId)
      .limit(1)
      .get();

    if (!existingSnap.empty) {
      const docSnap = existingSnap.docs[0];
      const data = docSnap.data();
      return {
        success: true,
        isNew: false,
        certificate: {
          id: docSnap.id,
          ...data,
          issueDate: data.issueDate?.toDate ? data.issueDate.toDate().toISOString() : new Date().toISOString(),
        },
      };
    }

    // Resolve missing course/student details if needed
    let finalCourseName = courseName;
    let finalTeacherId = teacherId;
    if (!finalCourseName || !finalTeacherId) {
      const courseDoc = await adminDb.collection("courses").doc(courseId).get();
      if (courseDoc.exists) {
        const cData = courseDoc.data()!;
        finalCourseName = finalCourseName || cData.courseName || cData.courseTitle || cData.title || "Course";
        finalTeacherId = finalTeacherId || cData.teacherId || "";
      }
    }

    let finalStudentName = studentName;
    if (!finalStudentName) {
      const userDoc = await adminDb.collection("users").doc(studentId).get();
      if (userDoc.exists) {
        const uData = userDoc.data()!;
        finalStudentName = uData.name || uData.displayName || uData.email?.split("@")[0] || "Student";
      } else {
        finalStudentName = "Student";
      }
    }

    const newRef = adminDb.collection("certificates").doc();
    const certData = {
      studentId,
      studentName: finalStudentName,
      courseId,
      courseName: finalCourseName || "Course",
      teacherId: finalTeacherId || "",
      issueDate: FieldValue.serverTimestamp(),
    };

    await newRef.set(certData);

    return {
      success: true,
      isNew: true,
      certificate: {
        id: newRef.id,
        ...certData,
        issueDate: new Date().toISOString(),
      },
    };
  } catch (error: any) {
    console.error("issueCertificateAction error:", error);
    return { success: false, error: error?.message || "Failed to issue certificate." };
  }
}

/**
 * Issues certificates for all enrolled students in a course who don't have one yet.
 */
export async function issueAllPendingCertificatesAction(courseId: string, teacherId?: string) {
  try {
    if (!courseId) return { success: false, error: "Course ID is required." };

    const courseDoc = await adminDb.collection("courses").doc(courseId).get();
    if (!courseDoc.exists) return { success: false, error: "Course not found." };

    const courseData = courseDoc.data()!;
    const enrolledUids: string[] = Array.isArray(courseData.enrolledStudents)
      ? courseData.enrolledStudents
      : [];

    if (enrolledUids.length === 0) {
      return { success: true, count: 0, certificates: [] };
    }

    // Get existing certificates
    const existingSnap = await adminDb
      .collection("certificates")
      .where("courseId", "==", courseId)
      .get();

    const existingStudentIds = new Set(existingSnap.docs.map((d) => d.data().studentId));
    const pendingUids = enrolledUids.filter((uid) => !existingStudentIds.has(uid));

    if (pendingUids.length === 0) {
      return { success: true, count: 0, certificates: [] };
    }

    const cName = courseData.courseName || courseData.courseTitle || courseData.title || "Course";
    const tId = teacherId || courseData.teacherId || "";

    const createdCerts: any[] = [];
    const batch = adminDb.batch();

    for (const uid of pendingUids) {
      let sName = "Student";
      try {
        const uDoc = await adminDb.collection("users").doc(uid).get();
        if (uDoc.exists) {
          const u = uDoc.data()!;
          sName = u.name || u.displayName || u.email?.split("@")[0] || "Student";
        }
      } catch {
        // Fallback name
      }

      const newRef = adminDb.collection("certificates").doc();
      batch.set(newRef, {
        studentId: uid,
        studentName: sName,
        courseId,
        courseName: cName,
        teacherId: tId,
        issueDate: FieldValue.serverTimestamp(),
      });

      createdCerts.push({
        id: newRef.id,
        studentId: uid,
        studentName: sName,
        courseId,
        courseName: cName,
        teacherId: tId,
        issueDate: new Date().toISOString(),
      });
    }

    await batch.commit();

    return {
      success: true,
      count: createdCerts.length,
      certificates: createdCerts,
    };
  } catch (error: any) {
    console.error("issueAllPendingCertificatesAction error:", error);
    return { success: false, error: error?.message || "Failed to issue certificates." };
  }
}

/**
 * Loads all course, certificate, and enrolled student data for a teacher.
 * Runs on the server with adminDb to avoid any client Firestore security rule
 * or indexing failures.
 */
export async function getTeacherCertificatesDataAction(teacherId: string) {
  try {
    if (!teacherId) return { success: false, error: "Teacher ID is required." };

    // 1. Fetch courses owned by this teacher
    const coursesSnap = await adminDb
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

    const teacherCertsSnap = await adminDb
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
        const cSnap = await adminDb
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
          const uDoc = await adminDb.collection("users").doc(uid).get();
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
      success: true,
      courses,
      certificates,
      studentsByCourse,
    };
  } catch (error: any) {
    console.error("getTeacherCertificatesDataAction error:", error);
    return { success: false, error: error?.message || "Failed to load certificates data." };
  }
}
