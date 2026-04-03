"use client";

import { useState, useEffect } from "react";
import { UserCheck, Search, Loader2, Save, TrendingUp, ShieldCheck } from "lucide-react";
import { financeService, Teacher } from "@/lib/financeService";
import { motion } from "framer-motion";

export default function AdminCommissions() {
  const [teachers, setTeachers] = useState<Teacher[]>([]);
  const [loading, setLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState("");

  useEffect(() => {
    const unsub = financeService.getTeachers((data) => {
      setTeachers(data);
      setLoading(false);
    });
    return () => unsub();
  }, []);

  const filteredTeachers = teachers.filter(t => 
    t.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
    t.email.toLowerCase().includes(searchQuery.toLowerCase())
  );

  if (loading) {
    return (
      <div className="min-h-[400px] flex items-center justify-center">
        <Loader2 className="w-8 h-8 animate-spin text-black" />
      </div>
    );
  }

  return (
    <div className="space-y-8 animate-in fade-in duration-700 pb-20 text-left">
      <div className="flex justify-between items-end">
        <div>
          <h1 className="text-3xl font-black tracking-tight text-gray-900 font-outfit uppercase">Teacher Commissions</h1>
          <p className="text-gray-400 font-bold text-xs mt-1 uppercase tracking-[3px]">Manage Global Earning Splits & Tiers</p>
        </div>
        <div className="relative">
          <Search className="absolute left-4 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
          <input 
            type="text"
            placeholder="Search teachers..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="pl-12 pr-6 py-3 bg-white border border-gray-100 rounded-2xl outline-none focus:border-black transition-all text-xs font-bold w-64 shadow-sm"
          />
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-4 gap-8">
        <div className="lg:col-span-3 bg-white rounded-[40px] border border-gray-100 shadow-sm overflow-hidden">
          <div className="p-10 border-b border-gray-50 flex justify-between items-center bg-gray-50/30">
            <h3 className="text-sm font-black uppercase tracking-widest">Active Teacher Tiers</h3>
            <UserCheck className="w-4 h-4 text-gray-400" />
          </div>
          
          <div className="overflow-x-auto">
            <table className="w-full text-left">
              <thead>
                <tr className="bg-gray-50/50">
                  <th className="px-10 py-5 text-[10px] font-black uppercase tracking-widest text-gray-400">Teacher</th>
                  <th className="px-10 py-5 text-[10px] font-black uppercase tracking-widest text-gray-400">Current Split</th>
                  <th className="px-10 py-5 text-[10px] font-black uppercase tracking-widest text-gray-400">Tier Status</th>
                  <th className="px-10 py-5 text-right text-[10px] font-black uppercase tracking-widest text-gray-400">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-50">
                {filteredTeachers.map((teacher) => {
                  const rate = teacher.commissionRate || 0.6;
                  const isSenior = rate >= 0.8;
                  
                  return (
                    <tr key={teacher.uid} className="hover:bg-gray-50/30 transition-colors group">
                      <td className="px-10 py-6">
                        <div className="flex items-center gap-4">
                          <div className="w-12 h-12 rounded-2xl bg-gray-100 border border-gray-50 overflow-hidden flex-shrink-0 shadow-sm">
                            {teacher.photoUrl ? (
                              <img src={teacher.photoUrl} alt="" className="w-full h-full object-cover" />
                            ) : (
                              <div className="w-full h-full bg-black text-white flex items-center justify-center text-xs font-black">
                                {teacher.name[0]}
                              </div>
                            )}
                          </div>
                          <div>
                            <p className="text-sm font-black text-gray-900">{teacher.name}</p>
                            <p className="text-[10px] font-bold text-gray-400 uppercase tracking-tighter">{teacher.email}</p>
                          </div>
                        </div>
                      </td>
                      <td className="px-10 py-6">
                        <div className="flex items-center gap-2">
                          <div className="relative">
                            <input 
                              type="number" 
                              min="0" 
                              max="100"
                              defaultValue={Math.round(rate * 100)}
                              onBlur={async (e) => {
                                const newPct = parseFloat(e.target.value);
                                if (!isNaN(newPct) && newPct >= 0 && newPct <= 100) {
                                  await financeService.setTeacherCommission(teacher.uid, newPct / 100);
                                  await financeService.logAdminAction("Update Commission", `${teacher.name}: ${newPct}%`);
                                }
                              }}
                              className="w-24 px-4 py-2 bg-gray-50 border border-gray-100 rounded-xl outline-none focus:bg-white focus:border-black transition-all text-sm font-black text-center"
                            />
                            <span className="absolute right-4 top-1/2 -translate-y-1/2 text-[10px] font-black text-gray-400 pointer-events-none">%</span>
                          </div>
                        </div>
                      </td>
                      <td className="px-10 py-6">
                        <span className={`px-4 py-1.5 rounded-full text-[9px] font-black uppercase tracking-widest ${
                          isSenior ? "bg-amber-50 text-amber-600 border border-amber-100" : "bg-blue-50 text-blue-600 border border-blue-100"
                        }`}>
                          {isSenior ? "Senior Partner (80%+)" : "Standard Tier"}
                        </span>
                      </td>
                      <td className="px-10 py-6 text-right">
                         <button className="p-2 text-gray-300 hover:text-black transition-colors">
                            <Save className="w-4 h-4" />
                         </button>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        </div>

        <div className="space-y-8">
          <div className="bg-black rounded-[40px] p-10 text-white shadow-xl shadow-black/20">
            <TrendingUp className="w-8 h-8 text-white/20 mb-6" />
            <h3 className="text-lg font-black uppercase tracking-tighter mb-2">Commission Strategy</h3>
            <p className="text-white/40 text-[10px] font-medium leading-relaxed uppercase tracking-[2px]">
              Set custom rates for each partner. Higher rates incentivize senior teachers and drive quality.
              Changes take effect immediately on all future student enrollments.
            </p>
          </div>

          <div className="bg-white rounded-[40px] p-10 border border-gray-100 shadow-sm relative overflow-hidden group">
            <div className="absolute -right-4 -bottom-4 opacity-[0.03] group-hover:scale-110 transition-transform duration-700">
               <ShieldCheck className="w-32 h-32" />
            </div>
            <h3 className="text-xs font-black uppercase tracking-widest mb-4">Audit Transparency</h3>
            <p className="text-gray-400 text-[10px] font-bold leading-relaxed uppercase tracking-widest">
              Every commission adjustment is recorded in the Administrative Audit Trail for 100% transparency.
            </p>
          </div>
        </div>
      </div>
    </div>
  );
}
