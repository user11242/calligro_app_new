const fs = require('fs');
const { assertFails, assertSucceeds, initializeTestEnvironment } = require('@firebase/rules-unit-testing');

// We use the firestore.rules file from the parent directory
let testEnv;

describe('Domain 7: Security Rules Testing', () => {
  beforeAll(async () => {
    testEnv = await initializeTestEnvironment({
      projectId: 'calligro-security-test',
      firestore: {
        host: '127.0.0.1',
        port: 8080,
        rules: fs.readFileSync('../firestore.rules', 'utf8'),
      },
    });
  });

  afterAll(async () => {
    await testEnv.cleanup();
  });

  beforeEach(async () => {
    await testEnv.clearFirestore();
  });

  it('Test Case: A student cannot elevate themselves to admin or teacher', async () => {
    // 1. Setup a test user who is a student
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection('users').doc('student_123').set({
        role: 'student',
        status: 'approved'
      });
    });

    // 2. Authenticate as the student
    const studentContext = testEnv.authenticatedContext('student_123');
    const studentDb = studentContext.firestore();

    // 3. Mathematical proof that the security rule blocks elevation
    const elevationAttempt = studentDb.collection('users').doc('student_123').update({
      role: 'admin' // Attempting to hack the database
    });

    // This MUST fail according to the rules
    await assertFails(elevationAttempt);
  });

  it('Test Case: A teacher cannot change their own commissionRate', async () => {
    // 1. Setup a teacher with a 60% standard rate
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection('users').doc('teacher_123').set({
        role: 'teacher',
        commissionRate: 0.60
      });
    });

    // 2. Authenticate as the teacher
    const teacherContext = testEnv.authenticatedContext('teacher_123');
    const teacherDb = teacherContext.firestore();

    // 3. Mathematical proof that the security rule blocks commission manipulation
    const hackAttempt = teacherDb.collection('users').doc('teacher_123').update({
      commissionRate: 0.99 // Attempting to steal 99% of course sales
    });

    // This MUST fail according to the rules
    await assertFails(hackAttempt);
  });
});
