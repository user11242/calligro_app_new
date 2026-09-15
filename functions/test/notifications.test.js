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

  it('notifyStudentsOnReschedule works', async () => {
    const event = {
      params: { courseId: 'c1' },
      data: {
        before: { data: () => ({ rescheduledSession: { newStartTime: { isEqual: () => false } } }) },
        after: { data: () => ({ rescheduledSession: { newStartTime: { isEqual: () => false } }, enrolledStudents: ['s1'], title: 'Course' }) }
      }
    };
    await notifications.notifyStudentsOnReschedule(event);
    expect(admin.mockSend).toHaveBeenCalled();
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
        before: { data: () => ({ likes: [] }) },
        after: { data: () => ({ likes: ['u2'], authorId: 'u1' }) }
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
});
