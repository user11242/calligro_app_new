"use server";

/**
 * Certificate server actions (public POST endpoints in Next.js). Each one first
 * proves who is calling (the Firebase ID token), then runs the checked logic in
 * features/certificates/data/certificates.server.ts. They used to use the admin
 * key with no check at all.
 */
import { adminAuth, adminDb } from "@/shared/firebase/admin.server";
import {
  CertificateRefused,
  callerFromToken,
  issueAllPendingCertificates,
  issueCertificate,
  loadTeacherCertificates,
  type IssueCertificateParams,
} from "@/features/certificates/server/certificates.server";

export type { IssueCertificateParams } from "@/features/certificates/server/certificates.server";

// Results keep the shape the pages already read: { success, error?, ... }.
async function run<T extends object>(
  idToken: string,
  label: string,
  fn: (caller: Awaited<ReturnType<typeof callerFromToken>>) => Promise<T>,
): Promise<(T & { error?: string }) | { success: false; error: string }> {
  try {
    const caller = await callerFromToken(adminAuth, adminDb, idToken);
    return await fn(caller);
  } catch (error: any) {
    if (!(error instanceof CertificateRefused)) console.error(`${label} error:`, error);
    return { success: false as const, error: error?.message || "Failed." };
  }
}

/** Issues or returns the certificate of a student in a course (the student themselves, the teacher or an admin). */
export async function issueCertificateAction(idToken: string, params: IssueCertificateParams) {
  return run(idToken, "issueCertificateAction", (caller) => issueCertificate(adminDb, caller, params));
}

/** Issues certificates for all enrolled students without one (the course's teacher or an admin). */
export async function issueAllPendingCertificatesAction(idToken: string, courseId: string) {
  return run(idToken, "issueAllPendingCertificatesAction", (caller) => issueAllPendingCertificates(adminDb, caller, courseId));
}

/** Courses, certificates and enrolled students of [teacherId] (that teacher or an admin). */
export async function getTeacherCertificatesDataAction(idToken: string, teacherId: string) {
  return run(idToken, "getTeacherCertificatesDataAction", (caller) => loadTeacherCertificates(adminDb, caller, teacherId));
}
