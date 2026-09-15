const { HttpsError } = require("firebase-functions/v2/https");

// Mocking Firebase Admin and Functions
jest.mock('firebase-functions/v2/https', () => ({
  onCall: jest.fn((options, handler) => handler),
  onRequest: jest.fn((options, handler) => handler),
  HttpsError: class extends Error {
    constructor(code, message) {
      super(message);
      this.code = code;
    }
  }
}));

jest.mock('firebase-admin', () => {
  const setMock = jest.fn();
  const getMock = jest.fn();
  const addMock = jest.fn();
  return {
    firestore: () => {
      const db = {
        collection: () => db,
        doc: () => db,
        get: getMock,
        set: setMock,
        add: addMock,
        update: jest.fn(),
        collectionGroup: function() { return this; },
        where: function() { return this; },
        limit: function() { return this; },
      };
      return db;
    },
    getMock,
    setMock,
    addMock,
  };
});
admin = require('firebase-admin');
admin.firestore.FieldValue = { serverTimestamp: jest.fn(() => 'timestamp') };

jest.mock('firebase-functions/params', () => ({
  defineSecret: jest.fn(() => ({ value: () => 'fake_secret' }))
}));

jest.mock('livekit-server-sdk', () => {
  return {
    AccessToken: class {
      constructor() { this.addGrant = jest.fn(); }
      toJwt() { return 'fake_jwt'; }
    },
    EgressClient: class {
      listEgress() { return Promise.resolve([{ status: 1, egressId: 'eg1' }]); }
      stopEgress() { return Promise.resolve(); }
      startRoomCompositeEgress() { return Promise.resolve({ egressId: 'eg1' }); }
    },
    RoomServiceClient: class {
      removeParticipant() { return Promise.resolve(); }
      getParticipant() { return Promise.resolve({ tracks: [{type: 0, sid: 't_a'}, {type: 1, sid: 't_v'}] }); }
      mutePublishedTrack() { return Promise.resolve(); }
    },
    EncodingOptionsPreset: { H264_720P_30: 1 },
    WebhookReceiver: class {
      receive() { 
        return Promise.resolve({
          event: 'egress_ended',
          egressInfo: { egressId: 'eg1', status: 3, startedAt: 0, endedAt: 1000 }
        });
      }
    }
  };
});

const { S3Client, PutObjectCommand } = require('@aws-sdk/client-s3');
jest.mock('@aws-sdk/client-s3', () => ({
  S3Client: class {},
  PutObjectCommand: class {}
}));

jest.mock('@aws-sdk/s3-request-presigner', () => ({
  getSignedUrl: jest.fn(() => Promise.resolve('https://fake_presigned_url'))
}));

const { generateLiveKitToken, moderateParticipant, startAutomatedRecording, generateR2UploadUrl, saveRecordingMetadata, livekitWebhook } = require('../livekit.js');

describe('Domain 4: LiveKit & Video (Cloud Functions)', () => {
  const originalSetTimeout = global.setTimeout;

  beforeEach(() => {
    jest.clearAllMocks();
    admin.getMock.mockReset();
    global.setTimeout = (cb) => cb(); // bypass 5s delay
  });
  
  afterEach(() => {
    global.setTimeout = originalSetTimeout;
  });

  // --- generateLiveKitToken ---
  it('generateLiveKitToken rejects if unauthenticated', async () => {
    await expect(generateLiveKitToken({ auth: null, data: { courseId: 'c1' } })).rejects.toThrow('You must be logged in');
  });

  it('generateLiveKitToken rejects if courseId missing', async () => {
    await expect(generateLiveKitToken({ auth: { uid: 'u1' }, data: {} })).rejects.toThrow('Course ID is required');
  });
  
  it('generateLiveKitToken rejects if course not found', async () => {
    admin.getMock.mockResolvedValueOnce({ exists: true, data: () => ({ role: 'student' }) });
    admin.getMock.mockResolvedValueOnce({ exists: false });
    await expect(generateLiveKitToken({ auth: { uid: 'u1' }, data: { courseId: 'c1' } })).rejects.toThrow('Course not found.');
  });

  it('generateLiveKitToken generates token for teacher', async () => {
    admin.getMock.mockResolvedValueOnce({ exists: true, data: () => ({ role: 'teacher', name: 'T' }) });
    admin.getMock.mockResolvedValueOnce({ exists: true, data: () => ({ teacherId: 'u1', enrolledStudents: [] }) });
    const res = await generateLiveKitToken({ auth: { uid: 'u1' }, data: { courseId: 'c1' } });
    expect(res.token).toBe('fake_jwt');
  });

  // --- moderateParticipant ---
  it('moderateParticipant rejects if unauthenticated', async () => {
    await expect(moderateParticipant({ auth: null, data: {} })).rejects.toThrow();
  });

  it('moderateParticipant rejects if not teacher', async () => {
    admin.getMock.mockResolvedValueOnce({ exists: true, data: () => ({ teacherId: 't1' }) });
    await expect(moderateParticipant({ auth: { uid: 's1' }, data: { courseId: 'c1', action: 'stop_recording' } })).rejects.toThrow('Only the teacher can moderate participants.');
  });

  it('moderateParticipant stops recording', async () => {
    admin.getMock.mockResolvedValueOnce({ exists: true, data: () => ({ teacherId: 't1' }) });
    admin.getMock.mockResolvedValueOnce({ exists: true, data: () => ({ r2FilePath: 'p', egressId: 'e', startedAt: 0 }) });
    await moderateParticipant({ auth: { uid: 't1' }, data: { courseId: 'c1', action: 'stop_recording' } });
    expect(admin.setMock).toHaveBeenCalled();
  });

  it('moderateParticipant kick', async () => {
    admin.getMock.mockResolvedValueOnce({ exists: true, data: () => ({ teacherId: 't1' }) });
    await moderateParticipant({ auth: { uid: 't1' }, data: { courseId: 'c1', action: 'kick', targetIdentity: 's1' } });
  });

  it('moderateParticipant mute_mic', async () => {
    admin.getMock.mockResolvedValueOnce({ exists: true, data: () => ({ teacherId: 't1' }) });
    await moderateParticipant({ auth: { uid: 't1' }, data: { courseId: 'c1', action: 'mute_mic', targetIdentity: 's1' } });
  });

  it('moderateParticipant mute_camera', async () => {
    admin.getMock.mockResolvedValueOnce({ exists: true, data: () => ({ teacherId: 't1' }) });
    await moderateParticipant({ auth: { uid: 't1' }, data: { courseId: 'c1', action: 'mute_camera', targetIdentity: 's1' } });
  });

  // --- startAutomatedRecording ---
  it('startAutomatedRecording works', async () => {
    admin.getMock.mockResolvedValueOnce({ exists: true, data: () => ({ teacherId: 't1' }) });
    admin.getMock.mockResolvedValueOnce({ empty: true });
    const res = await startAutomatedRecording({ auth: { uid: 't1' }, data: { courseId: 'c1', audioTrackId: 'a1', videoTrackId: 'v1', orientation: 'landscape' } });
    expect(res.egressId).toBe('eg1');
  });

  // --- livekitWebhook ---
  it('livekitWebhook works for egress_ended', async () => {
    admin.getMock.mockResolvedValueOnce({ 
      empty: false, 
      docs: [{ 
        ref: { parent: { parent: { id: 'course123' } }, update: jest.fn() },
        data: () => ({ startedAt: { toMillis: () => Date.now() - 60000 }, r2FilePath: 'a' })
      }] 
    });

    const req = { 
      rawBody: 'test', 
      headers: { authorization: 'Bearer token' } 
    };
    const res = { send: jest.fn(), status: jest.fn().mockReturnThis() };

    jest.mock('livekit-server-sdk', () => ({
      ...jest.requireActual('livekit-server-sdk'),
      WebhookReceiver: class {
        receive() { 
          return Promise.resolve({
            event: 'egress_ended',
            egressInfo: { egressId: 'eg1', status: 3, startedAt: 0, endedAt: 1000 }
          });
        }
      }
    }), { virtual: true });

    await livekitWebhook(req, res);
    expect(res.status).toHaveBeenCalledWith(200);
  });

  // --- generateR2UploadUrl ---
  it('generateR2UploadUrl works', async () => {
    admin.getMock.mockResolvedValueOnce({ exists: true, data: () => ({ teacherId: 't1' }) });
    const res = await generateR2UploadUrl({ auth: { uid: 't1' }, data: { courseId: 'c1', fileName: 'f1.mp4' } });
    expect(res.uploadUrl).toBe('https://fake_presigned_url');
  });

  // --- saveRecordingMetadata ---
  it('saveRecordingMetadata works', async () => {
    admin.getMock.mockResolvedValueOnce({ exists: true, data: () => ({ teacherId: 't1' }) });
    await saveRecordingMetadata({ auth: { uid: 't1' }, data: { courseId: 'c1', fileName: 'f1.mp4', r2FilePath: 'path' } });
    expect(admin.addMock).toHaveBeenCalled();
  });
});
