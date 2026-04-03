"use client";

import { useState, useEffect } from "react";
import { 
  ShieldCheck, 
  User, 
  BookOpen, 
  UserCheck, 
  Calendar, 
  Search,
  Loader2,
  FileText,
  DollarSign
} from "lucide-react";
import { motion } from "framer-motion";
import { financeService, Order } from "@/lib/financeService";

export default function AdminOrders() {
  const [orders, setOrders] = useState<Order[]>([]);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState("");

  useEffect(() => {
    const unsub = financeService.getOrders((data) => {
      setOrders(data);
      setLoading(false);
    });
    return () => unsub();
  }, []);

  const filteredOrders = orders.filter(order => 
    order.studentName.toLowerCase().includes(searchTerm.toLowerCase()) ||
    order.courseName.toLowerCase().includes(searchTerm.toLowerCase()) ||
    order.teacherName.toLowerCase().includes(searchTerm.toLowerCase())
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
          <h1 className="text-3xl font-black tracking-tight text-gray-900 font-outfit uppercase">Detailed Order Audit</h1>
          <p className="text-gray-400 font-bold text-xs mt-1 uppercase tracking-[3px]">Secure Server-Side Validated Transactions</p>
        </div>
        
        <div className="relative group">
          <Search className="absolute left-4 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400 group-focus-within:text-black transition-colors" />
          <input 
            type="text"
            placeholder="Search students, courses..."
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            className="pl-12 pr-6 py-3 bg-white border border-gray-100 rounded-2xl outline-none focus:border-black transition-all font-bold text-xs w-64 shadow-sm"
          />
        </div>
      </div>

      {/* Audit Table */}
      <div className="bg-white rounded-[40px] border border-gray-100 shadow-sm overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-left">
            <thead>
              <tr className="bg-gray-50/50">
                <th className="px-10 py-6 text-[10px] font-black uppercase tracking-widest text-gray-400">Timeline / Status</th>
                <th className="px-10 py-6 text-[10px] font-black uppercase tracking-widest text-gray-400">Student Entity</th>
                <th className="px-10 py-6 text-[10px] font-black uppercase tracking-widest text-gray-400">Course & Merchant</th>
                <th className="px-10 py-6 text-right text-[10px] font-black uppercase tracking-widest text-gray-400">Financials</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-50">
              {filteredOrders.length === 0 ? (
                <tr>
                  <td colSpan={4} className="px-10 py-20 text-center">
                    <p className="text-gray-300 font-black uppercase tracking-widest text-xs italic">No transactions detected in the audit trail</p>
                  </td>
                </tr>
              ) : (
                filteredOrders.map((order, index) => (
                  <motion.tr 
                    key={order.id}
                    initial={{ opacity: 0, y: 10 }}
                    animate={{ opacity: 1, y: 0 }}
                    transition={{ delay: index * 0.05 }}
                    className="hover:bg-gray-50/50 transition-colors group"
                  >
                    <td className="px-10 py-8">
                      <div className="flex items-center gap-3">
                        <div className="p-2 rounded-xl bg-green-50 text-green-600">
                          <ShieldCheck className="w-4 h-4" />
                        </div>
                        <div>
                          <p className="text-xs font-black text-gray-900">
                            {order.timestamp?.toDate ? order.timestamp.toDate().toLocaleDateString() : 'Recent'}
                          </p>
                          <p className="text-[10px] font-bold text-gray-400 uppercase">
                            {order.timestamp?.toDate ? order.timestamp.toDate().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }) : 'Success'}
                          </p>
                        </div>
                      </div>
                    </td>

                    <td className="px-10 py-8">
                      <div className="flex items-center gap-3">
                        <div className="w-10 h-10 rounded-full bg-gray-100 flex items-center justify-center border border-gray-100">
                          <User className="w-5 h-5 text-gray-400" />
                        </div>
                        <div>
                          <p className="text-sm font-black text-gray-900">{order.studentName}</p>
                          <p className="text-[10px] font-bold text-gray-400 uppercase tracking-tighter">{order.studentEmail}</p>
                        </div>
                      </div>
                    </td>

                    <td className="px-10 py-8">
                      <div className="space-y-2">
                        <div className="flex items-center gap-2">
                          <BookOpen className="w-3 h-3 text-amber-500" />
                          <p className="text-xs font-black text-gray-800 uppercase tracking-tight">{order.courseName}</p>
                        </div>
                        <div className="flex items-center gap-2">
                          <UserCheck className="w-3 h-3 text-gray-300" />
                          <p className="text-[10px] font-bold text-gray-400 uppercase tracking-widest italic">{order.teacherName}</p>
                        </div>
                      </div>
                    </td>

                    <td className="px-10 py-8 text-right">
                      <p className="text-lg font-black text-gray-900">${order.price}</p>
                      <div className="flex items-center justify-end gap-1 text-[9px] font-black text-green-600 uppercase tracking-[2px] mt-1">
                        <DollarSign className="w-2.5 h-2.5" />
                        Verified
                      </div>
                      <p className="text-[8px] font-bold text-gray-300 mt-2 font-mono uppercase">Tx: {order.transactionId.substring(0, 12)}...</p>
                    </td>
                  </motion.tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* Footer Info */}
      <div className="flex items-center gap-4 px-10">
        <div className="flex items-center gap-2 text-[10px] font-black text-gray-400 uppercase tracking-widest">
          <FileText className="w-3 h-3" />
          Audit Integrity: 100% Secure
        </div>
        <div className="w-1 h-1 rounded-full bg-gray-200" />
        <div className="text-[10px] font-bold text-gray-400 uppercase tracking-widest">
          Showing {filteredOrders.length} Premium Orders
        </div>
      </div>
    </div>
  );
}
