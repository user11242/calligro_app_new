"use server";
import { db } from "@/lib/firebase";
import { doc, getDoc, runTransaction, setDoc, collection, serverTimestamp } from "firebase/firestore";

export async function checkPaymentStatus(resourcePath: string, courseId: string, userId: string) {
  const ACCESS_TOKEN = "OGFjN2E0Yzc3MDkyODkyOTAxNzA5NDAzMzI4ZTM1MzJ8SjJmNzlWdU43Ng==";
  const URL = `https://test.oppwa.com${resourcePath}`;

  try {
    const response = await fetch(URL, {
      method: "GET",
      headers: {
        Authorization: `Bearer ${ACCESS_TOKEN}`,
      },
    });

    const result = await response.json();
    
    // HyperPay Success codes start with 000.000, 000.100, etc.
    const successPattern = /^(000\.000\.|000\.100\.1|000\.[36])/;
    if (successPattern.test(result.result.code)) {
      // Grant Access via TRANSACTION to match Security Rules & Mobile App
      await runTransaction(db, async (transaction) => {
        const courseRef = doc(db, "courses", courseId);
        const transactionRef = doc(collection(db, "transactions"));

        const courseSnap = await transaction.get(courseRef);
        if (!courseSnap.exists()) throw new Error("Course not found");
        
        const courseData = courseSnap.data()!;
        const enrolledStudents = Array.isArray(courseData.enrolledStudents) ? [...courseData.enrolledStudents] : [];

        if (!enrolledStudents.includes(userId)) {
          enrolledStudents.push(userId);
          
          // 1. Update Course (Students + Count)
          transaction.update(courseRef, {
            enrolledStudents: enrolledStudents,
            enrolledCount: enrolledStudents.length
          });

          // 2. Record Financial Transaction (EXACT fields from App)
          const grossAmount = Number(result.amount) || 0;
          transaction.set(transactionRef, {
            studentId: userId,
            studentName: 'Student', // Default for sync bridge
            teacherId: courseData.teacherId || '',
            teacherName: courseData.teacherName || 'Unknown Teacher',
            courseId: courseId,
            courseName: courseData.courseName || courseData.courseTitle || 'Untitled Course',
            amount: grossAmount,
            currency: result.currency || 'USD',
            source: 'web_portal',
            status: 'completed',
            createdAt: serverTimestamp(),
            transactionId: result.id,
            paymentBrand: result.paymentBrand,
            // Calculated Shares (60/15/25)
            teacherShare: grossAmount * 0.60,
            academyProfit: grossAmount * 0.25,
            storeFee: grossAmount * 0.15,
          });
        }
      });

      return { success: true };
    }

    return { success: false, message: result.result.description };
  } catch (error) {
    console.error("Status check error:", error);
    throw error;
  }
}
