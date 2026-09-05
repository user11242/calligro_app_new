"use client";

import { useState, useEffect } from "react";
import { financeService } from "../../../lib/financeService";
import Link from "next/link";

export default function AccountingMasterPage() {
  const [ledgers, setLedgers] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const unsub = financeService.getTeacherLedgers((data) => {
      setLedgers(data);
      setLoading(false);
    });
    return () => unsub();
  }, []);

  if (loading) {
    return <div className="p-8 flex justify-center text-gray-500">Loading accounting data...</div>;
  }

  return (
    <div className="p-8 max-w-7xl mx-auto">
      <div className="flex justify-between items-end mb-8">
        <div>
          <h1 className="text-4xl font-black uppercase tracking-tight">Master Ledger</h1>
          <p className="text-sm text-gray-500 uppercase tracking-widest mt-1">Academy Financial Liabilities & Teacher Payouts</p>
        </div>
      </div>

      <div className="bg-white rounded-2xl border border-gray-100 overflow-hidden shadow-sm">
        <table className="w-full text-left">
          <thead className="bg-gray-50/50 border-b border-gray-100">
            <tr>
              <th className="py-4 px-6 text-xs font-semibold text-gray-500 uppercase tracking-widest">Teacher</th>
              <th className="py-4 px-6 text-xs font-semibold text-gray-500 uppercase tracking-widest text-right">Available Balance</th>
              <th className="py-4 px-6 text-xs font-semibold text-gray-500 uppercase tracking-widest text-right">Locked Balance</th>
              <th className="py-4 px-6 text-xs font-semibold text-gray-500 uppercase tracking-widest text-right">Lifetime Paid</th>
              <th className="py-4 px-6 text-xs font-semibold text-gray-500 uppercase tracking-widest text-right">Action</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-50">
            {ledgers.map((ledger) => (
              <tr key={ledger.id} className="hover:bg-gray-50/50 transition-colors">
                <td className="py-4 px-6">
                  <div className="flex items-center gap-3">
                    {ledger.photoUrl ? (
                      <img src={ledger.photoUrl} alt="" className="w-10 h-10 rounded-full object-cover border border-gray-100" />
                    ) : (
                      <div className="w-10 h-10 rounded-full bg-gray-100 flex items-center justify-center text-gray-400 font-medium">
                        {ledger.name.charAt(0)}
                      </div>
                    )}
                    <div>
                      <div className="font-bold text-gray-900">{ledger.name}</div>
                      <div className="text-xs text-gray-500">{ledger.email}</div>
                    </div>
                  </div>
                </td>
                <td className="py-4 px-6 text-right">
                  <span className={`font-mono font-bold text-lg ${ledger.availableBalance > 0 ? 'text-green-600' : 'text-gray-400'}`}>
                    ${ledger.availableBalance.toFixed(2)}
                  </span>
                </td>
                <td className="py-4 px-6 text-right">
                  <span className="font-mono font-medium text-amber-600">
                    ${ledger.lockedBalance.toFixed(2)}
                  </span>
                </td>
                <td className="py-4 px-6 text-right font-mono text-gray-500">
                  ${ledger.lifetimePaid.toFixed(2)}
                </td>
                <td className="py-4 px-6 text-right">
                  <Link 
                    href={`/admin/accounting/${ledger.id}`} 
                    className="inline-block px-4 py-2 bg-black text-white text-xs font-bold uppercase tracking-wider rounded-lg hover:bg-gray-800 transition-colors"
                  >
                    View Ledger
                  </Link>
                </td>
              </tr>
            ))}
            {ledgers.length === 0 && (
              <tr>
                <td colSpan={5} className="py-12 text-center text-gray-500">
                  No teachers found in the system.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}
