const { onDocumentCreated, onDocumentUpdated } = require("firebase-functions/v2/firestore");

// Mocking Firebase Admin and Functions
jest.mock('firebase-functions/v2/firestore', () => ({
  onDocumentCreated: jest.fn((...args) => args.length === 2 ? args[1] : args[0]),
  onDocumentUpdated: jest.fn((...args) => args.length === 2 ? args[1] : args[0])
}));

jest.mock('firebase-functions/v2/https', () => ({
  onCall: jest.fn((...args) => args.length === 2 ? args[1] : args[0]),
  HttpsError: class extends Error {
    constructor(code, msg) { super(msg); this.code = code; }
  }
}));

jest.mock('firebase-functions/params', () => ({
  defineSecret: jest.fn(() => ({ value: () => 'fake_brevo_key' }))
}));

// Mock brevo api
const brevo = {
  TransactionalEmailsApi: class {
    constructor() {}
    sendTransacEmail() { return Promise.resolve(); }
  },
  ApiClient: { instance: { authentications: { 'api-key': {} } } },
  SendSmtpEmail: class {}
};
jest.mock('sib-api-v3-sdk', () => brevo);

jest.mock('firebase-admin', () => {
  const getMock = jest.fn();
  const whereMock = jest.fn().mockReturnThis();
  const getDocsMock = jest.fn();
  const updateMock = jest.fn();
  
  const db = {
    collection: () => db,
    doc: () => db,
    get: getMock,
    where: whereMock,
    update: updateMock,
    limit: jest.fn().mockReturnThis(),
    startAfter: jest.fn().mockReturnValue({ get: jest.fn().mockResolvedValue({ empty: true }) }),
    add: jest.fn(),
    create: jest.fn(),
  };
  
  const mockSend = jest.fn().mockResolvedValue({ successCount: 1, failureCount: 0 });
  const mockSendEachForMulticast = jest.fn().mockResolvedValue({ successCount: 1, failureCount: 0, responses: [{success: true}] });
  
  return {
    firestore: Object.assign(() => db, {
      FieldValue: { serverTimestamp: jest.fn(() => 'timestamp') }
    }),
    messaging: () => ({
      send: mockSend,
      sendEachForMulticast: mockSendEachForMulticast
    }),
    getMock,
    getDocsMock,
    mockSend,
    mockSendEachForMulticast
  };
});

// Load the file so it runs its initialization
const notifications = require('../notifications.js');
const admin = require('firebase-admin');

describe('Domain 5: Notifications & Cloud Triggers (Cloud Functions)', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    admin.getMock.mockImplementation(() => {
      const result = {
        exists: true,
        empty: false,
        docs: [{
          id: 'u1',
          data: () => ({ fcmToken: 't1', fcmTokens: ['t1'], language: 'en' })
        }],
        forEach: function(cb) { this.docs.forEach(cb); },
        data: () => ({ 
          fcmTokens: ['token1', 'token2'],
          fcmToken: 'token1',
          title: 'Title',
          teacherId: 't1',
          authorId: 'u1',
          userId: 'u1',
          enrolledStudents: ['s1'],
          language: 'en',
          status: 'pending',
          role: 'admin'
        })
      };
      console.log('getMock called, returning:', result.exists);
      return Promise.resolve(result);
    });
  });

  it('notifyTeacherOnEnrollment works', async () => {
    const event = {
      params: { courseId: 'c1' },
      data: {
        before: { data: () => ({ enrolledStudents: [] }) },
        after: { data: () => ({ enrolledStudents: ['s1'], teacherId: 't1', title: 'Course' }) }
      }
    };
    await notifications.notifyTeacherOnEnrollment(event);
    expect(admin.mockSend).toHaveBeenCalled();
  });

  it('notifyStudentsOnAnnouncement works', async () => {
    const event = {
      params: { courseId: 'c1' },
      data: { data: () => ({ message: 'Hello' }) }
    };
    await notifications.notifyStudentsOnAnnouncement(event);
    expect(admin.mockSend).toHaveBeenCalled();
  });

  it('notifyStudentsOnAssignment works', async () => {
    const event = {
      params: { courseId: 'c1' },
      data: { data: () => ({ title: 'Asgn1' }) }
    };
    await notifications.notifyStudentsOnAssignment(event);
    expect(admin.mockSend).toHaveBeenCalled();
  });

  it('notifyStudentsOnReschedule: a moved class is announced to the students', async () => {
    const move = {
      originalDate: new Date('2030-11-30T15:00:00Z'), originalStartTime: new Date('2030-11-30T15:00:00Z'),
      newStartTime: new Date('2030-12-01T16:00:00Z'), newEndTime: new Date('2030-12-01T17:30:00Z'), utcOffsetMinutes: 180,
    };
    const event = {
      id: 'evt-reschedule-1',
      params: { courseId: 'c1' },
      data: {
        before: { data: () => ({}) },
        after: { data: () => ({ rescheduledSession: move, enrolledStudents: ['s1'], courseName: 'Course' }) }
      }
    };
    await notifications.notifyStudentsOnReschedule(event);
    expect(admin.mockSend).toHaveBeenCalled();
    // The exact moments travel with the notification (the app shows them in local time).
    const sent = admin.mockSend.mock.calls[admin.mockSend.mock.calls.length - 1][0];
    expect(sent.data).toMatchObject({
      classChange: 'moved',
      oldStart: String(Date.parse('2030-11-30T15:00:00Z')),
      newStart: String(Date.parse('2030-12-01T16:00:00Z')),
      newEnd: String(Date.parse('2030-12-01T17:30:00Z')),
    });
  });

  it('notifyStudentsOnReschedule: nothing about the class changed → nothing sent', async () => {
    const move = { originalStartTime: new Date('2030-11-30T15:00:00Z'), newStartTime: new Date('2030-12-01T16:00:00Z'), newEndTime: new Date('2030-12-01T17:30:00Z') };
    admin.mockSend.mockClear();
    await notifications.notifyStudentsOnReschedule({
      id: 'evt-reschedule-2',
      params: { courseId: 'c1' },
      data: { before: { data: () => ({ rescheduledSession: move }) }, after: { data: () => ({ rescheduledSession: move, enrolledStudents: ['s1'] }) } },
    });
    expect(admin.mockSend).not.toHaveBeenCalled();
  });

  it('notifyAuthorOnComment works', async () => {
    const event = {
      params: { postId: 'p1' },
      data: { data: () => ({ userId: 'u2', text: 'Hello' }) }
    };
    await notifications.notifyAuthorOnComment(event);
    expect(admin.mockSend).toHaveBeenCalled();
  });

  it('notifyAuthorOnLike works', async () => {
    const event = {
      params: { postId: 'p1' },
      data: {
        // Real shape: likes is a map { likerId: true }, the author is userId.
        before: { data: () => ({ likes: {}, userId: 'u1' }) },
        after: { data: () => ({ likes: { u2: true }, userId: 'u1' }) }
      }
    };
    await notifications.notifyAuthorOnLike(event);
    expect(admin.mockSend).toHaveBeenCalled();
  });

  it('notifyTeacherOnSubmission works', async () => {
    const event = {
      params: { courseId: 'c1', assignmentId: 'a1' },
      data: { data: () => ({ studentId: 's1' }) }
    };
    await notifications.notifyTeacherOnSubmission(event);
    expect(admin.mockSend).toHaveBeenCalled();
  });

  it('notifyTeacherOnApproval works', async () => {
    const event = {
      params: { uid: 'u1' },
      data: {
        before: { data: () => ({ status: 'pending' }) },
        after: { data: () => ({ status: 'approved', role: 'teacher', fcmToken: 'tok1', email: 'a@a.com', name: 'A' }) }
      }
    };
    await notifications.notifyTeacherOnApproval(event);
    expect(admin.mockSend).toHaveBeenCalled();
  });

  it('notifyUsersOnBroadcast works', async () => {
    const event = {
      params: { broadcastId: 'b1' },
      data: { data: () => ({ title: 'B1', message: 'M1', targetAudience: 'all' }), ref: { update: jest.fn() } }
    };
    await notifications.notifyUsersOnBroadcast(event);
    expect(admin.mockSendEachForMulticast).toHaveBeenCalled();
  });

  it('notifyUserOnFollow works', async () => {
    const event = {
      params: { targetId: 'u1', followerId: 'u2' },
      data: { data: () => ({}) }
    };
    await notifications.notifyUserOnFollow(event);
    expect(admin.mockSend).toHaveBeenCalled();
  });

  describe('sendAdminDirectMessage (admin → one user)', () => {
    const req = { auth: { uid: 'admin1' }, data: { targetUserId: 'u1', title: 'T', body: 'M' } };
    const adminDoc = { exists: true, data: () => ({ role: 'admin' }) };

    it('saves to the inbox and pushes; reports the push', async () => {
      admin.getMock.mockResolvedValueOnce(adminDoc).mockResolvedValueOnce({ exists: true, data: () => ({ fcmToken: 'tok' }) });
      await expect(notifications.sendAdminDirectMessage(req)).resolves.toEqual({ success: true, push: 'sent' });
    });

    it('a failed push (e.g. an expired phone token) does NOT fail the send: the inbox copy is there', async () => {
      admin.getMock.mockResolvedValueOnce(adminDoc).mockResolvedValueOnce({ exists: true, data: () => ({ fcmToken: 'old' }) });
      admin.mockSend.mockRejectedValueOnce(Object.assign(new Error('Requested entity was not found.'), { code: 'messaging/registration-token-not-registered' }));
      await expect(notifications.sendAdminDirectMessage(req)).resolves.toEqual({ success: true, push: 'failed' });
    });

    it('no phone registered → inbox only', async () => {
      admin.getMock.mockResolvedValueOnce(adminDoc).mockResolvedValueOnce({ exists: true, data: () => ({}) });
      await expect(notifications.sendAdminDirectMessage(req)).resolves.toEqual({ success: true, push: 'none' });
    });

    it('only admins; unknown user → not-found', async () => {
      admin.getMock.mockResolvedValueOnce({ exists: true, data: () => ({ role: 'teacher' }) }).mockResolvedValueOnce({ exists: true, data: () => ({}) });
      await expect(notifications.sendAdminDirectMessage(req)).rejects.toMatchObject({ code: 'permission-denied' });
      admin.getMock.mockResolvedValueOnce(adminDoc).mockResolvedValueOnce({ exists: false });
      await expect(notifications.sendAdminDirectMessage(req)).rejects.toMatchObject({ code: 'not-found' });
    });
  });

  it('sendAdminDirectMessage works', async () => {
    const req = { auth: { uid: 'admin1' }, data: { targetUserId: 'u1', title: 'T', body: 'M' } };
    admin.getMock.mockResolvedValue({ exists: true, data: () => ({ role: 'admin', fcmTokens: ['tok1'] }) });
    const res = await notifications.sendAdminDirectMessage(req);
    expect(res.success).toBe(true);
  });

  it('notifyCommenterOnReply works', async () => {
    const event = {
      params: { postId: 'p1', commentId: 'c1', replyId: 'r1' },
      data: { data: () => ({ userId: 'u2' }) }
    };
    await notifications.notifyCommenterOnReply(event);
    expect(admin.mockSend).toHaveBeenCalled();
  });

  describe('notifyCourseChatMembers (Group Chat)', () => {
    it('notifies all enrolled students and excludes the teacher when teacher sends a message', async () => {
      admin.getMock.mockImplementation(() => Promise.resolve({
        exists: true,
        data: () => ({
          courseName: 'Thuluth Basics',
          teacherId: 'teacher_1',
          enrolledStudents: ['student_1', 'student_2'],
          fcmToken: 'tok_user',
          preferredLanguage: 'en',
        }),
      }));

      const event = {
        params: { courseId: 'course_1', messageId: 'msg_1' },
        data: {
          data: () => ({
            senderId: 'teacher_1',
            senderName: 'Master Ali',
            senderRole: 'teacher',
            text: 'Practice the Alif stroke before class!',
          }),
        },
      };

      await notifications.notifyCourseChatMembers(event);

      // Should send to student_1 and student_2 (2 recipients), NOT teacher_1
      expect(admin.mockSend).toHaveBeenCalledTimes(2);
      expect(admin.mockSend).toHaveBeenCalledWith(
        expect.objectContaining({
          notification: {
            title: '💬 Thuluth Basics',
            body: 'Master Ali: Practice the Alif stroke before class!',
          },
          data: expect.objectContaining({
            type: 'course_chat',
            route: '/courseChat',
            courseId: 'course_1',
            courseName: 'Thuluth Basics',
            teacherId: 'teacher_1',
          }),
        })
      );
    });

    it('notifies teacher and other students (excluding sender) when a student sends a message', async () => {
      admin.getMock.mockImplementation(() => Promise.resolve({
        exists: true,
        data: () => ({
          courseName: 'Naskh',
          teacherId: 'teacher_1',
          enrolledStudents: ['student_1', 'student_2'],
          fcmToken: 'tok_user',
          preferredLanguage: 'en',
        }),
      }));

      const event = {
        params: { courseId: 'course_1', messageId: 'msg_2' },
        data: {
          data: () => ({
            senderId: 'student_1',
            senderName: 'Sara',
            senderRole: 'student',
            text: 'Is my slant angle correct?',
          }),
        },
      };

      await notifications.notifyCourseChatMembers(event);

      // Should notify teacher_1 and student_2 (2 recipients), NOT student_1
      expect(admin.mockSend).toHaveBeenCalledTimes(2);
    });

    it('uses a localized photo label when image-only message is sent and skips empty messages', async () => {
      admin.getMock.mockImplementation(() => Promise.resolve({
        exists: true,
        data: () => ({
          courseName: 'Naskh',
          teacherId: 'teacher_1',
          enrolledStudents: ['student_1'],
          fcmToken: 'tok_user',
          preferredLanguage: 'ar',
        }),
      }));

      await notifications.notifyCourseChatMembers({
        params: { courseId: 'course_1', messageId: 'msg_3' },
        data: {
          data: () => ({
            senderId: 'student_1',
            senderName: 'سارة',
            text: '',
            imageUrl: 'https://example.com/img.jpg',
          }),
        },
      });

      expect(admin.mockSend).toHaveBeenCalledTimes(1);
      expect(admin.mockSend).toHaveBeenCalledWith(
        expect.objectContaining({
          notification: {
            title: '💬 Naskh',
            body: 'سارة: 📷 أرسل صورة',
          },
        })
      );

      jest.clearAllMocks();

      // Empty message without image should do nothing
      await notifications.notifyCourseChatMembers({
        params: { courseId: 'course_1', messageId: 'msg_empty' },
        data: { data: () => ({ senderId: 'student_1', senderName: 'Sara', text: '   ' }) },
      });
      expect(admin.mockSend).not.toHaveBeenCalled();
    });
  });
});
