const admin = require('firebase-admin');

// Initialize with default credentials
admin.initializeApp();
const db = admin.firestore();

async function backfillCertificates() {
  console.log('Starting Certificate Backfill Process...');
  let totalCreated = 0;
  let totalSkipped = 0;

  try {
    const coursesSnapshot = await db.collection('courses').get();
    
    for (const courseDoc of coursesSnapshot.docs) {
      const courseId = courseDoc.id;
      const courseData = courseDoc.data();
      
      const enrolledStudents = courseData.enrolledStudents;
      if (!Array.isArray(enrolledStudents) || enrolledStudents.length === 0) {
        continue;
      }

      console.log(`Checking Course: ${courseId} (${courseData.courseName || courseData.title}) - ${enrolledStudents.length} students`);

      for (const studentId of enrolledStudents) {
        // Check if certificate already exists
        const certSnapshot = await db.collection('certificates')
          .where('studentId', '==', studentId)
          .where('courseId', '==', courseId)
          .limit(1)
          .get();

        if (!certSnapshot.empty) {
          totalSkipped++;
          continue;
        }

        // Generate missing certificate
        // Fetch student name
        let studentName = 'Student';
        const userDoc = await db.collection('users').doc(studentId).get();
        if (userDoc.exists) {
          studentName = userDoc.data().name || userDoc.data().displayName || 'Student';
        }

        const newCertRef = db.collection('certificates').doc();
        await newCertRef.set({
          studentId: studentId,
          studentName: studentName,
          courseId: courseId,
          courseName: courseData.courseName || courseData.title || 'Course',
          teacherId: courseData.teacherId || '',
          issueDate: admin.firestore.Timestamp.now()
        });

        console.log(`Created certificate for ${studentName} in course ${courseId}`);
        totalCreated++;
      }
    }
    
    console.log(`\nBackfill Complete!`);
    console.log(`Created: ${totalCreated}`);
    console.log(`Skipped (already exists): ${totalSkipped}`);
    process.exit(0);

  } catch (error) {
    console.error('Error during backfill:', error);
    process.exit(1);
  }
}

backfillCertificates();
