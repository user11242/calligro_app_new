"use client";

import { useState, useEffect } from "react";
import { financeService } from "../../../../lib/financeService";
import { useParams, useRouter } from "next/navigation";
import Link from "next/link";

export default function TeacherLedgerPage() {
  const params = useParams();
  const router = useRouter();
  const teacherId = params.id as string;

  const [ledger, setLedger] = useState<any>(null);
  const [loading, setLoading] = useState(true);
  const [isProcessing, setIsProcessing] = useState(false);

  useEffect(() => {
    if (!teacherId) return;
    const unsub = financeService.getTeacherLedgers((ledgers) => {
      const found = ledgers.find(l => l.id === teacherId);
      setLedger(found);
      setLoading(false);
    });
    return () => unsub();
  }, [teacherId]);

  const handleIssuePayout = async () => {
    if (!ledger || ledger.availableBalance <= 0) return;
    const confirmed = confirm(`Are you sure you want to issue a payout of $${ledger.availableBalance.toFixed(2)} to ${ledger.name}?`);
    if (!confirmed) return;

    setIsProcessing(true);
    try {
      // Creating a withdrawal request and marking it as completed to represent a payout
      const payoutId = `payout_${Date.now()}`;
      const { doc, setDoc, serverTimestamp } = await import("firebase/firestore");
      const { db } = await import("../../../../lib/firebase");
      
      await setDoc(doc(db, "withdrawal_requests", payoutId), {
        teacherId: ledger.id,
        teacherName: ledger.name,
        amount: ledger.availableBalance,
        status: "completed",
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp()
      });

      // Log the admin expense for global accounting
      await financeService.addExpense(
        ledger.availableBalance,
        `Ledger Payout to ${ledger.name}`,
        new Date().toISOString().split("T")[0],
        "payout"
      );
      
      alert("Payout issued successfully! The ledger will now reflect the new balance.");
    } catch (e) {
      console.error(e);
      alert("Failed to issue payout.");
    }
    setIsProcessing(false);
  };

  if (loading) return <div className="p-8 flex justify-center text-gray-500">Loading ledger...</div>;
  if (!ledger) return <div className="p-8 flex justify-center text-gray-500">Teacher not found.</div>;

  return (
    <div className="p-8 max-w-7xl mx-auto space-y-8">
      {/* Header */}
      <div className="flex justify-between items-center">
        <div className="flex items-center gap-4">
          <Link href="/admin/accounting" className="text-gray-400 hover:text-black transition-colors">
            <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M10 19l-7-7m0 0l7-7m-7 7h18" />
            </svg>
          </Link>
          <div>
            <h1 className="text-4xl font-black uppercase tracking-tight">{ledger.name}&apos;s Ledger</h1>
            <p className="text-sm text-gray-500 uppercase tracking-widest mt-1">{ledger.email}</p>
          </div>
        </div>
        <button 
          onClick={handleIssuePayout}
          disabled={ledger.availableBalance <= 0 || isProcessing}
          className={`px-6 py-3 rounded-xl font-bold uppercase tracking-wider text-sm transition-all shadow-sm ${ledger.availableBalance > 0 ? 'bg-green-600 text-white hover:bg-green-700' : 'bg-gray-100 text-gray-400 cursor-not-allowed'}`}
        >
          {isProcessing ? 'Processing...' : `Settle $${ledger.availableBalance.toFixed(2)}`}
        </button>
      </div>

      {/* Financial Overview Cards */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        <div className="bg-white p-6 rounded-2xl border border-gray-100 shadow-sm">
          <p className="text-xs font-bold text-gray-400 uppercase tracking-widest mb-1">Available Balance</p>
          <h3 className="text-4xl font-black text-green-600">${ledger.availableBalance.toFixed(2)}</h3>
          <p className="text-xs text-gray-500 mt-2">Ready for immediate payout.</p>
        </div>
        <div className="bg-white p-6 rounded-2xl border border-gray-100 shadow-sm">
          <p className="text-xs font-bold text-gray-400 uppercase tracking-widest mb-1">Locked Balance</p>
          <h3 className="text-4xl font-black text-amber-600">${ledger.lockedBalance.toFixed(2)}</h3>
          <p className="text-xs text-gray-500 mt-2">Pending course completion.</p>
        </div>
        <div className="bg-white p-6 rounded-2xl border border-gray-100 shadow-sm">
          <p className="text-xs font-bold text-gray-400 uppercase tracking-widest mb-1">Lifetime Paid</p>
          <h3 className="text-4xl font-black text-gray-900">${ledger.lifetimePaid.toFixed(2)}</h3>
          <p className="text-xs text-gray-500 mt-2">Total money sent to bank.</p>
        </div>
      </div>

      {/* Statement of Account (Transactions) */}
      <div className="bg-white rounded-2xl border border-gray-100 overflow-hidden shadow-sm">
        <div className="px-6 py-4 border-b border-gray-100 bg-gray-50/50">
          <h3 className="font-bold text-gray-900 uppercase tracking-wide">Statement of Account</h3>
        </div>
        <table className="w-full text-left">
          <thead className="bg-gray-50/50 border-b border-gray-100">
            <tr>
              <th className="py-4 px-6 text-xs font-semibold text-gray-500 uppercase tracking-widest">Date</th>
              <th className="py-4 px-6 text-xs font-semibold text-gray-500 uppercase tracking-widest">Course</th>
              <th className="py-4 px-6 text-xs font-semibold text-gray-500 uppercase tracking-widest">Student</th>
              <th className="py-4 px-6 text-xs font-semibold text-gray-500 uppercase tracking-widest">Status</th>
              <th className="py-4 px-6 text-xs font-semibold text-gray-500 uppercase tracking-widest text-right">Teacher Share</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-50">
            {ledger.transactions?.sort((a: any, b: any) => b.createdAt?.toMillis() - a.createdAt?.toMillis()).map((tx: any, idx: number) => (
              <tr key={idx} className="hover:bg-gray-50/50">
                <td className="py-4 px-6 text-sm text-gray-500 font-mono">
                  {tx.createdAt?.toDate ? tx.createdAt.toDate().toLocaleDateString() : 'Unknown'}
                </td>
                <td className="py-4 px-6">
                  <div className="font-bold text-gray-900">{tx.courseName}</div>
                  <div className="text-xs text-gray-500">Unlocks: {tx.payoutDate ? tx.payoutDate.toLocaleDateString() : 'Unknown'}</div>
                </td>
                <td className="py-4 px-6 text-sm text-gray-700">{tx.studentName}</td>
                <td className="py-4 px-6">
                  <span className={`px-2 py-1 rounded-md text-[10px] font-bold uppercase tracking-wider ${
                    tx.courseStatus === 'ready' ? 'bg-green-100 text-green-700' : 'bg-amber-100 text-amber-700'
                  }`}>
                    {tx.courseStatus}
                  </span>
                </td>
                <td className="py-4 px-6 text-right font-mono font-bold text-gray-900">
                  +${(tx.teacherShare || 0).toFixed(2)}
                </td>
              </tr>
            ))}
            {(!ledger.transactions || ledger.transactions.length === 0) && (
              <tr>
                <td colSpan={5} className="py-12 text-center text-gray-500">
                  No transactions found for this teacher.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}
