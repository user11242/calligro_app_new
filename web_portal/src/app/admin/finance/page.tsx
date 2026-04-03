"use client";

import { useState, useEffect } from "react";
import { 
  ArrowUpRight, 
  Plus, 
  Calendar, 
  Clock,
  TrendingUp as TrendingUpIcon,
  Loader2,
  Search
} from "lucide-react";
import { motion, AnimatePresence } from "framer-motion";
import { financeService, Transaction, Expense } from "@/lib/financeService";

export default function AdminFinance() {
  const [transactions, setTransactions] = useState<Transaction[]>([]);
  const [expenses, setExpenses] = useState<Expense[]>([]);
  const [payoutEligibility, setPayoutEligibility] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [showAddExpense, setShowAddExpense] = useState(false);
  
  // New Expense Form State
  const [expAmount, setExpAmount] = useState("");
  const [expNote, setExpNote] = useState("");
  const [expDate, setExpDate] = useState(new Date().toISOString().split("T")[0]);

  useEffect(() => {
    const unsubTxs = financeService.getTransactions(setTransactions);
    const unsubExps = financeService.getExpenses(setExpenses);
    const unsubEligibility = financeService.getPayoutEligibility((data) => {
      setPayoutEligibility(data);
      setLoading(false);
    });

    return () => {
      unsubTxs();
      unsubExps();
      unsubEligibility();
    };
  }, []);

  const totalIncome = transactions.reduce((sum, tx) => sum + (tx.amount || 0), 0);
  const totalTeacherShare = transactions.reduce((sum, tx) => sum + (tx.teacherShare || 0), 0);
  const totalExpenses = expenses.reduce((sum, exp) => sum + (exp.amount || 0), 0);
  const netAcademyShare = totalIncome - totalTeacherShare - totalExpenses;

  const handleAddExpense = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!expAmount || !expNote) return;
    await financeService.addExpense(parseFloat(expAmount), expNote, expDate);
    setExpAmount("");
    setExpNote("");
    setShowAddExpense(false);
  };

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
          <h1 className="text-3xl font-black tracking-tight text-gray-900 font-outfit uppercase">Finance Oversight</h1>
          <p className="text-gray-400 font-bold text-xs mt-1 uppercase tracking-[3px]">Real-time Transaction & Payout Hub</p>
        </div>
        <div className="flex gap-3">
          <button 
            onClick={() => setShowAddExpense(true)}
            className="flex items-center gap-2 px-6 py-3 rounded-2xl bg-black text-white font-black text-[10px] uppercase tracking-widest hover:scale-105 transition-all shadow-xl shadow-black/10"
          >
            <Plus className="w-4 h-4" />
            Record Outcome
          </button>
        </div>
      </div>

      {/* Summary Cards */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-6">
         <div className="bg-white p-8 rounded-[32px] border border-gray-100 shadow-sm relative overflow-hidden group">
            <div className="absolute top-0 right-0 p-4 opacity-5 group-hover:opacity-10 transition-opacity">
              <TrendingUpIcon className="w-16 h-16" />
            </div>
            <p className="text-gray-400 text-[10px] font-black uppercase tracking-widest mb-2">Net Academy Share</p>
            <h2 className="text-4xl font-black tracking-tighter">${netAcademyShare.toLocaleString()}</h2>
            <div className="flex items-center gap-1 text-green-600 text-[10px] font-black mt-4 uppercase">
              <ArrowUpRight className="w-3 h-3" />
              Operational Profit
            </div>
         </div>
         
         <div className="bg-white p-8 rounded-[32px] border border-gray-100 shadow-sm">
            <p className="text-gray-400 text-[10px] font-black uppercase tracking-widest mb-2">Total Gross Income</p>
            <h2 className="text-4xl font-black tracking-tighter">${totalIncome.toLocaleString()}</h2>
            <p className="text-gray-400 text-[10px] font-bold mt-4 uppercase tracking-widest">{transactions.length} Total Sales</p>
         </div>

         <div className="bg-white p-8 rounded-[32px] border border-gray-100 shadow-sm flex flex-col justify-between">
            <div>
              <p className="text-gray-400 text-[10px] font-black uppercase tracking-widest mb-2">Total Outcomes</p>
              <h2 className="text-4xl font-black tracking-tighter text-red-500">-${totalExpenses.toLocaleString()}</h2>
            </div>
            <p className="text-gray-400 text-[10px] font-bold mt-4 uppercase tracking-widest">{expenses.length} Logged Expenses</p>
         </div>

         <div className="bg-[#FFFBEB] p-8 rounded-[32px] border border-amber-100 shadow-sm">
            <p className="text-amber-800/60 text-[10px] font-black uppercase tracking-widest mb-2">Teacher Payouts</p>
            <h2 className="text-4xl font-black text-amber-900 tracking-tighter">${totalTeacherShare.toLocaleString()}</h2>
            <p className="text-amber-900/40 text-[10px] font-bold mt-4 uppercase tracking-widest">Awaiting Settlement</p>
         </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-1 gap-8 text-left">
        {/* Full Width Columns */}
        <div className="space-y-8">
          {/* Teacher Payout Strategy */}
          <div className="bg-white rounded-[40px] border border-gray-100 shadow-sm overflow-hidden">
            <div className="p-10 border-b border-gray-50 flex justify-between items-center bg-gray-50/30">
              <div>
                <h3 className="text-sm font-black uppercase tracking-widest text-left">Teacher Payout Schedule</h3>
                <p className="text-[10px] font-bold text-gray-400 uppercase tracking-widest mt-1 text-left">Automatic Settlement Eligibility (Course End + 2 Days)</p>
              </div>
              <Clock className="w-4 h-4 text-gray-300" />
            </div>
            <div className="overflow-x-auto max-h-[400px] overflow-y-auto pr-2 scrollbar-hide">
              <table className="w-full text-left">
                <thead>
                  <tr className="bg-gray-50/50">
                    <th className="px-10 py-5 text-[10px] font-black uppercase tracking-widest text-gray-400">Course / Teacher</th>
                    <th className="px-10 py-5 text-[10px] font-black uppercase tracking-widest text-gray-400">Ends On</th>
                    <th className="px-10 py-5 text-[10px] font-black uppercase tracking-widest text-gray-400">Payout Date</th>
                    <th className="px-10 py-5 text-right text-[10px] font-black uppercase tracking-widest text-gray-400">Status</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-gray-50">
                  {payoutEligibility.map((item) => (
                    <tr key={item.id} className="hover:bg-gray-50/50 transition-colors">
                      <td className="px-10 py-6">
                        <p className="text-sm font-black text-gray-900">{item.courseName}</p>
                        <p className="text-[10px] font-bold text-gray-400 uppercase tracking-tighter">{item.teacherName}</p>
                      </td>
                      <td className="px-10 py-6 text-xs font-black text-gray-500">{item.endDate}</td>
                      <td className="px-10 py-6 text-xs font-black text-gray-900 italic underline decoration-gray-200">{item.payoutDate}</td>
                      <td className="px-10 py-6 text-right">
                        <span className={`px-4 py-1.5 rounded-full text-[9px] font-black uppercase tracking-widest ${
                          item.status === "ready" ? "bg-green-50 text-green-600 border border-green-100" : 
                          item.status === "processing" ? "bg-amber-50 text-amber-600 border border-amber-100" :
                          "bg-gray-100 text-gray-400"
                        }`}>
                          {item.status}
                        </span>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-8">
            {/* Transaction Table */}
            <div className="bg-white rounded-[40px] border border-gray-100 shadow-sm overflow-hidden text-left">
              <div className="p-10 border-b border-gray-50 flex justify-between items-center">
                <h3 className="text-sm font-black uppercase tracking-widest">Recent Sales (Income)</h3>
                <Search className="w-4 h-4 text-gray-300" />
              </div>
              <div className="overflow-x-auto max-h-[500px] overflow-y-auto">
                <table className="w-full text-left">
                  <tbody className="divide-y divide-gray-50">
                    {transactions.map((tx) => (
                      <tr key={tx.id} className="hover:bg-gray-50/50 transition-colors">
                        <td className="px-10 py-6">
                          <p className="text-sm font-black text-gray-900">{tx.studentName || "Student"}</p>
                          <p className="text-[10px] font-bold text-gray-400 uppercase tracking-tighter">{tx.courseName}</p>
                        </td>
                        <td className="px-10 py-6 text-right">
                          <p className="text-sm font-black text-green-600">+${tx.amount}</p>
                          <p className="text-[10px] font-bold text-gray-400 uppercase">Settled</p>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </div>

            {/* Expense Logs */}
            <div className="bg-white rounded-[40px] border border-gray-100 shadow-sm overflow-hidden text-left">
              <div className="p-10 border-b border-gray-50 flex justify-between items-center">
                <h3 className="text-sm font-black uppercase tracking-widest">Operational Outcomes</h3>
                <Calendar className="w-4 h-4 text-gray-300" />
              </div>
              <div className="overflow-x-auto max-h-[500px] overflow-y-auto">
                <table className="w-full text-left">
                  <tbody className="divide-y divide-gray-50">
                    {expenses.map((exp) => (
                      <tr key={exp.id} className="hover:bg-gray-50/50 transition-colors">
                        <td className="px-10 py-6">
                          <p className="text-sm font-black text-gray-900">{exp.note}</p>
                          <p className="text-[10px] font-bold text-gray-400 uppercase tracking-tighter">{exp.date}</p>
                        </td>
                        <td className="px-10 py-6 text-right">
                          <p className="text-sm font-black text-red-500">-${exp.amount}</p>
                          <p className="text-[10px] font-bold text-gray-400 uppercase tracking-widest">{exp.category}</p>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* Add Expense Modal */}
      <AnimatePresence>
        {showAddExpense && (
          <div className="fixed inset-0 z-[100] flex items-center justify-center p-6 text-left">
            <motion.div 
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
              onClick={() => setShowAddExpense(false)}
              className="absolute inset-0 bg-black/40 backdrop-blur-sm"
            />
            <motion.div 
              initial={{ scale: 0.9, opacity: 0 }}
              animate={{ scale: 1, opacity: 1 }}
              exit={{ scale: 0.9, opacity: 0 }}
              className="relative w-full max-w-sm bg-white rounded-[40px] p-12 shadow-2xl border border-gray-100"
            >
              <h2 className="text-2xl font-black uppercase tracking-tighter mb-10">Record Outcome</h2>
              
              <form onSubmit={handleAddExpense} className="space-y-8">
                <div>
                  <label className="text-[10px] font-black uppercase tracking-widest text-gray-400 block mb-3 px-1">Amount ($)</label>
                  <input 
                    type="number" 
                    value={expAmount}
                    onChange={(e) => setExpAmount(e.target.value)}
                    placeholder="0.00"
                    className="w-full px-8 py-5 bg-gray-50 border border-gray-100 rounded-2xl outline-none focus:bg-white focus:border-black transition-all font-black text-xl"
                    required
                  />
                </div>
                <div>
                  <label className="text-[10px] font-black uppercase tracking-widest text-gray-400 block mb-3 px-1">Note / Description</label>
                  <input 
                    type="text" 
                    value={expNote}
                    onChange={(e) => setExpNote(e.target.value)}
                    placeholder="e.g. Marketing Campaign"
                    className="w-full px-8 py-5 bg-gray-50 border border-gray-100 rounded-2xl outline-none focus:bg-white focus:border-black transition-all font-bold text-sm"
                    required
                  />
                </div>
                <div>
                  <label className="text-[10px] font-black uppercase tracking-widest text-gray-400 block mb-3 px-1">Date</label>
                  <input 
                    type="date" 
                    value={expDate}
                    onChange={(e) => setExpDate(e.target.value)}
                    className="w-full px-8 py-5 bg-gray-50 border border-gray-100 rounded-2xl outline-none focus:bg-white focus:border-black transition-all font-bold text-sm"
                    required
                  />
                </div>
                <button 
                  type="submit"
                  className="w-full py-6 bg-black text-white rounded-[28px] font-black uppercase tracking-[4px] text-xs shadow-xl shadow-black/20 hover:scale-[1.02] active:scale-[0.98] transition-all"
                >
                  Log Outcome
                </button>
              </form>
            </motion.div>
          </div>
        )}
      </AnimatePresence>
    </div>
  );
}
