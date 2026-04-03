"use client";

import { useState, useEffect } from "react";
import { motion } from "framer-motion";
import { Users, BookOpen, GraduationCap, Banknote, TrendingUp, ArrowUpRight, ArrowDownRight, Clock, Loader2, Plus } from "lucide-react";
import { 
  AreaChart, 
  Area, 
  XAxis, 
  YAxis, 
  CartesianGrid, 
  Tooltip, 
  ResponsiveContainer 
} from "recharts";
import { financeService, Transaction } from "@/lib/financeService";

export default function AdminDashboard() {
  const [transactions, setTransactions] = useState<Transaction[]>([]);
  const [counts, setCounts] = useState({ students: 0, courses: 0 });
  const [chartData, setChartData] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const unsubTxs = financeService.getTransactions(setTransactions);
    const unsubCounts = financeService.getGlobalCounts((data) => {
      setCounts(data);
    });
    const unsubChart = financeService.getRevenueHistory((data) => {
      setChartData(data);
      setLoading(false);
    });

    return () => {
      unsubTxs();
      unsubCounts();
      unsubChart();
    };
  }, []);

  const totalRevenue = transactions.reduce((sum, tx) => sum + (tx.amount || 0), 0);
  const pendingPayouts = transactions.reduce((sum, tx) => sum + (tx.teacherShare || 0), 0);

  const stats = [
    { label: "Total Revenue", value: `$${totalRevenue.toLocaleString()}`, icon: Banknote, trend: "+12.5%", positive: true },
    { label: "Active Students", value: counts.students.toLocaleString(), icon: GraduationCap, trend: "+5.2%", positive: true },
    { label: "Total Courses", value: counts.courses.toString(), icon: BookOpen, trend: "0%", positive: true },
    { label: "Pending Payouts", value: `$${pendingPayouts.toLocaleString()}`, icon: Clock, trend: "-2.1%", positive: false },
  ];

  if (loading) {
    return (
      <div className="min-h-[400px] flex items-center justify-center">
        <Loader2 className="w-8 h-8 animate-spin text-black" />
      </div>
    );
  }

  return (
    <div className="space-y-8 animate-in fade-in duration-700">
      <div className="text-left">
        <h1 className="text-5xl font-black tracking-tighter text-gray-900 font-outfit uppercase">THE BOSS IS IN 👑</h1>
        <p className="text-gray-400 font-bold text-xs mt-2 uppercase tracking-[4px]">Welcome back, Yazan Qattous. All systems are operational.</p>
        <p className="text-gray-400/40 text-[10px] font-medium mt-4 uppercase tracking-widest">Real-time performance metrics and academy health.</p>
      </div>

      {/* Stats Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        {stats.map((stat, i) => (
          <motion.div
            key={stat.label}
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: i * 0.1 }}
            className="bg-white p-6 rounded-3xl border border-gray-100 shadow-sm hover:shadow-xl hover:shadow-black/5 transition-all group"
          >
            <div className="flex justify-between items-start mb-4">
              <div className="p-3 bg-gray-50 rounded-2xl group-hover:bg-black group-hover:text-white transition-colors">
                <stat.icon className="w-6 h-6" />
              </div>
              <div className={`flex items-center gap-1 text-xs font-black px-2 py-1 rounded-full ${stat.positive ? "bg-green-50 text-green-600" : "bg-red-50 text-red-600"}`}>
                {stat.positive ? <ArrowUpRight className="w-3 h-3" /> : <ArrowDownRight className="w-3 h-3" />}
                {stat.trend}
              </div>
            </div>
            <p className="text-gray-400 text-xs font-black uppercase tracking-widest">{stat.label}</p>
            <h2 className="text-3xl font-black mt-2 tracking-tight">{stat.value}</h2>
          </motion.div>
        ))}
      </div>

      {/* Recent Enrollments & Growth */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
        <div className="bg-white rounded-[32px] border border-gray-100 shadow-sm p-8">
          <div className="flex items-center justify-between mb-8">
            <h3 className="text-sm font-black uppercase tracking-widest">Recent Enrollments</h3>
            <Users className="w-5 h-5 text-gray-300" />
          </div>
          <div className="space-y-6">
            {transactions.slice(0, 5).map((tx) => (
              <div key={tx.id} className="flex items-center gap-4">
                <div className="w-10 h-10 rounded-2xl bg-gray-50 flex items-center justify-center text-[10px] font-black">
                   {tx.studentName?.[0] || "?"}
                </div>
                <div className="flex-1">
                  <p className="text-xs font-black">{tx.studentName || "New Student"}</p>
                  <p className="text-[10px] font-bold text-gray-400 uppercase tracking-tighter">{tx.courseName}</p>
                </div>
                <div className="p-2 bg-green-50 rounded-xl">
                  <Plus className="w-3 h-3 text-green-600" />
                </div>
              </div>
            ))}
            {transactions.length === 0 && (
              <div className="text-center py-10">
                 <p className="text-[10px] font-black uppercase tracking-widest text-gray-300">No recent enrollments</p>
              </div>
            )}
          </div>
        </div>

        <div className="lg:col-span-2 bg-white rounded-[32px] border border-gray-100 shadow-sm p-8 min-h-[400px]">
          <div className="flex items-center justify-between mb-8">
            <h3 className="text-sm font-black uppercase tracking-widest">Revenue Growth</h3>
            <TrendingUp className="w-5 h-5 text-gray-300" />
          </div>
          
          <div className="h-[300px] w-full">
            <ResponsiveContainer width="100%" height="100%">
              <AreaChart data={chartData}>
                <defs>
                  <linearGradient id="colorRevenue" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="5%" stopColor="#000000" stopOpacity={0.1}/>
                    <stop offset="95%" stopColor="#000000" stopOpacity={0}/>
                  </linearGradient>
                </defs>
                <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="#F3F4F6" />
                <XAxis 
                  dataKey="name" 
                  axisLine={false} 
                  tickLine={false} 
                  tick={{ fontSize: 10, fontWeight: 900, fill: '#9CA3AF' }}
                  dy={10}
                />
                <YAxis 
                  hide={true}
                />
                <Tooltip 
                  contentStyle={{ 
                    borderRadius: '16px', 
                    border: 'none', 
                    boxShadow: '0 10px 30px rgba(0,0,0,0.1)',
                    fontSize: '10px',
                    fontWeight: 900,
                    textTransform: 'uppercase'
                  }}
                />
                <Area 
                  type="monotone" 
                  dataKey="revenue" 
                  stroke="#000000" 
                  strokeWidth={4}
                  fillOpacity={1} 
                  fill="url(#colorRevenue)" 
                />
              </AreaChart>
            </ResponsiveContainer>
          </div>
        </div>
      </div>
    </div>
  );
}
