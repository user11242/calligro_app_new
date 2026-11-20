/**
 * Stateful fake of the LiveKit server APIs used by functions/livekit.js
 * (RoomServiceClient + EgressClient). Rooms, participants, tracks and egresses
 * are real objects that the calls mutate, so tests can assert the resulting
 * server state ("the student is gone", "the room was deleted", "egress stopped").
 *
 * Errors mimic LiveKit: unknown participant → not_found.
 */

const EgressStatus = { STARTING: 0, ACTIVE: 1, ENDING: 2, COMPLETE: 3, FAILED: 4, ABORTED: 5, LIMIT_REACHED: 6 };
const TrackType = { AUDIO: 0, VIDEO: 1 };

class FakeLiveKitServer {
  constructor() {
    this.rooms = new Map(); // roomName -> Map(identity -> participant)
    this.egresses = []; // { egressId, roomName, status, kind, args }
    this.calls = []; // [method, ...args]
    this.failNext = {}; // method -> Error (thrown once)
    this.failAlways = {}; // method -> Error (thrown every time)
    this.rejectSegments = false; // true: an older recorder that refuses live-piece outputs
    this._egressSeq = 0;
  }

  // ── test helpers ──────────────────────────────────────────────────────
  addParticipant(roomName, { identity, role = "participant", teacherId = "T1", tracks }) {
    if (!this.rooms.has(roomName)) this.rooms.set(roomName, new Map());
    const p = {
      identity,
      name: identity,
      metadata: JSON.stringify({ role, teacherId, uid: identity.replace(/_mobile$/, "") }),
      tracks: tracks || [
        { sid: `${identity}_mic`, type: TrackType.AUDIO, muted: false },
        { sid: `${identity}_cam`, type: TrackType.VIDEO, muted: false },
      ],
    };
    this.rooms.get(roomName).set(identity, p);
    return p;
  }
  addEgress(roomName, status = EgressStatus.ACTIVE, egressId = `EG_seed_${++this._egressSeq}`) {
    const e = { egressId, roomName, status, kind: "seed" };
    this.egresses.push(e);
    if (status <= EgressStatus.ENDING) this._recorderJoins(e);
    return e;
  }
  /**
   * The recorder process is killed (crash, restart): it leaves the class but LiveKit
   * keeps listing the egress as ACTIVE, exactly like the real server does.
   */
  crashEgress(egressId, startedAtMs) {
    const e = this.egresses.find((x) => x.egressId === egressId);
    if (startedAtMs) e.startedAt = BigInt(startedAtMs) * 1000000n;
    this.rooms.get(e.roomName)?.delete(egressId);
  }
  /** Like the real recorder: a hidden participant named after its egress id. */
  _recorderJoins(e) {
    if (!this.rooms.has(e.roomName)) this.rooms.set(e.roomName, new Map());
    this.rooms.get(e.roomName).set(e.egressId, {
      identity: e.egressId, name: "", metadata: "", tracks: [], permission: { hidden: true, recorder: true },
    });
  }
  participant(roomName, identity) { return this.rooms.get(roomName)?.get(identity); }
  callsTo(method) { return this.calls.filter((c) => c[0] === method); }
  _record(method, args) {
    this.calls.push([method, ...args]);
    if (this.failAlways[method]) throw this.failAlways[method];
    if (this.failNext[method]) {
      const err = this.failNext[method];
      delete this.failNext[method];
      throw err;
    }
  }

  // ── RoomServiceClient ────────────────────────────────────────────────
  async listParticipants(roomName) {
    this._record("listParticipants", [roomName]);
    return [...(this.rooms.get(roomName)?.values() || [])].map((p) => ({ ...p, tracks: p.tracks.map((t) => ({ ...t })) }));
  }
  async getParticipant(roomName, identity) {
    this._record("getParticipant", [roomName, identity]);
    const p = this.participant(roomName, identity);
    if (!p) {
      const err = new Error("participant not found");
      err.code = "not_found";
      throw err;
    }
    return { ...p, tracks: p.tracks.map((t) => ({ ...t })) };
  }
  async mutePublishedTrack(roomName, identity, trackSid, muted) {
    this._record("mutePublishedTrack", [roomName, identity, trackSid, muted]);
    const track = this.participant(roomName, identity)?.tracks.find((t) => t.sid === trackSid);
    if (!track) throw new Error("track not found");
    track.muted = muted;
    return track;
  }
  async removeParticipant(roomName, identity) {
    this._record("removeParticipant", [roomName, identity]);
    if (!this.participant(roomName, identity)) throw new Error("participant not found");
    this.rooms.get(roomName).delete(identity);
  }
  async deleteRoom(roomName) {
    this._record("deleteRoom", [roomName]);
    if (!this.rooms.has(roomName)) throw new Error("room not found");
    this.rooms.delete(roomName);
  }

  // ── EgressClient ─────────────────────────────────────────────────────
  async listEgress({ roomName, egressId }) {
    this._record("listEgress", [roomName || egressId]);
    return this.egresses
      .filter((e) => (egressId ? e.egressId === egressId : e.roomName === roomName))
      .map((e) => ({ ...e }));
  }
  async stopEgress(egressId) {
    this._record("stopEgress", [egressId]);
    const e = this.egresses.find((x) => x.egressId === egressId);
    if (!e) throw new Error("egress not found");
    e.status = EgressStatus.ENDING;
    this.rooms.get(e.roomName)?.delete(egressId);
    return { ...e };
  }
  async startParticipantEgress(roomName, identity, output, opts) {
    this._record("startParticipantEgress", [roomName, identity, output, opts]);
    if (this.rejectSegments && output.segments) throw new Error("multiple outputs not supported");
    if (!this.participant(roomName, identity)) throw new Error(`participant ${identity} not in room`);
    const e = { egressId: `EG_part_${++this._egressSeq}`, roomName, status: EgressStatus.STARTING, kind: "participant" };
    this.egresses.push(e);
    this._recorderJoins(e);
    return { ...e };
  }
  async startTrackCompositeEgress(roomName, output, opts) {
    this._record("startTrackCompositeEgress", [roomName, output, opts]);
    if (this.rejectSegments && output.segments) throw new Error("multiple outputs not supported");
    const e = { egressId: `EG_track_${++this._egressSeq}`, roomName, status: EgressStatus.STARTING, kind: "track" };
    this.egresses.push(e);
    this._recorderJoins(e);
    return { ...e };
  }
}

module.exports = { FakeLiveKitServer, EgressStatus, TrackType };
