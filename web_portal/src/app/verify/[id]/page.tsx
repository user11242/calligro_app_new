"use client";

import { useEffect, useState } from "react";
import { useParams } from "next/navigation";
import { db } from "@/lib/firebase";
import { doc, getDoc } from "firebase/firestore";
import Navbar from "@/components/Navbar";

export default function VerifyCertificatePage() {
  const params = useParams();
  const id = params.id as string;
  
  const [loading, setLoading] = useState(true);
  const [certificate, setCertificate] = useState<any>(null);
  const [error, setError] = useState("");

  useEffect(() => {
    async function fetchCertificate() {
      if (!id) return;
      try {
        const docRef = doc(db, "certificates", id);
        const docSnap = await getDoc(docRef);

        if (docSnap.exists()) {
          setCertificate({ id: docSnap.id, ...docSnap.data() });
        } else {
          setError("Certificate not found. This ID is invalid.");
        }
      } catch (err) {
        console.error(err);
        setError("Error verifying certificate.");
      } finally {
        setLoading(false);
      }
    }

    fetchCertificate();
  }, [id]);

  return (
    <div className="min-h-screen bg-gray-50 flex flex-col">
      <Navbar />
      
      <main className="flex-grow flex items-center justify-center p-6">
        <div className="max-w-2xl w-full bg-white rounded-2xl shadow-xl overflow-hidden">
          <div className="bg-[#1E1E1E] p-8 text-center text-white">
            <h1 className="text-3xl font-bold mb-2">Certificate Verification</h1>
            <p className="text-gray-400">Verify the authenticity of a Calligro certificate</p>
          </div>
          
          <div className="p-10 text-center">
            {loading ? (
              <div className="flex justify-center items-center py-12">
                <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-[#D4AF37]"></div>
              </div>
            ) : error ? (
              <div className="py-8">
                <div className="mx-auto w-16 h-16 bg-red-100 rounded-full flex items-center justify-center mb-4">
                  <svg className="w-8 h-8 text-red-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M6 18L18 6M6 6l12 12"></path>
                  </svg>
                </div>
                <h2 className="text-2xl font-bold text-gray-800 mb-2">Invalid Certificate</h2>
                <p className="text-gray-600">{error}</p>
                <div className="mt-8 p-4 bg-gray-100 rounded-lg text-sm text-gray-500 font-mono">
                  Searched ID: {id}
                </div>
              </div>
            ) : certificate ? (
              <div className="py-4">
                <div className="mx-auto w-20 h-20 bg-green-100 rounded-full flex items-center justify-center mb-6 shadow-sm border border-green-200">
                  <svg className="w-10 h-10 text-green-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="3" d="M5 13l4 4L19 7"></path>
                  </svg>
                </div>
                
                <h2 className="text-3xl font-bold text-gray-800 mb-2">Valid Certificate</h2>
                <p className="text-green-600 font-medium mb-10 flex items-center justify-center gap-2">
                  <svg className="w-5 h-5" fill="currentColor" viewBox="0 0 20 20"><path fillRule="evenodd" d="M2.166 4.999A11.954 11.954 0 0010 1.944 11.954 11.954 0 0017.834 5c.11.65.166 1.32.166 2.001 0 5.225-3.34 9.67-8 11.317C5.34 16.67 2 12.225 2 7c0-.682.057-1.35.166-2.001zm11.541 3.708a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clipRule="evenodd"></path></svg>
                  Verified Authentic
                </p>
                
                <div className="bg-gray-50 rounded-xl border border-gray-200 p-6 space-y-4 text-left shadow-inner">
                  <div>
                    <p className="text-xs text-gray-500 uppercase font-semibold tracking-wider mb-1">Student Name</p>
                    <p className="text-xl font-bold text-gray-900">{certificate.studentName}</p>
                  </div>
                  
                  <div className="pt-4 border-t border-gray-200">
                    <p className="text-xs text-gray-500 uppercase font-semibold tracking-wider mb-1">Course Completed</p>
                    <p className="text-lg font-semibold text-[#D4AF37]">{certificate.courseName}</p>
                  </div>
                  
                  <div className="pt-4 border-t border-gray-200 flex flex-col md:flex-row gap-4 md:gap-12">
                    <div>
                      <p className="text-xs text-gray-500 uppercase font-semibold tracking-wider mb-1">Issue Date</p>
                      <p className="text-gray-800 font-medium">
                        {certificate.issueDate?.toDate().toLocaleDateString(undefined, {
                          year: 'numeric',
                          month: 'long',
                          day: 'numeric'
                        }) || "Unknown"}
                      </p>
                    </div>
                    <div>
                      <p className="text-xs text-gray-500 uppercase font-semibold tracking-wider mb-1">Credential ID</p>
                      <p className="text-gray-800 font-mono font-medium">{certificate.id}</p>
                    </div>
                  </div>
                </div>
              </div>
            ) : null}
          </div>
        </div>
      </main>
    </div>
  );
}
