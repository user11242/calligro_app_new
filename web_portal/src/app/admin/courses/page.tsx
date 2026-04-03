"use client";

import { useState, useEffect } from "react";
import { 
  BarChart3, 
  Users, 
  DollarSign, 
  Percent, 
  TrendingUp, 
  Search, 
  Loader2,
  FileText,
  BadgePercent,
  Calculator
} from "lucide-react";
import { financeService } from "@/lib/financeService";
import { motion, AnimatePresence } from "framer-motion";

export default function CourseAnalytics() {
  const [analytics, setAnalytics] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState("");

  useEffect(() => {
    const unsub = financeService.getCourseAnalytics((data) => {
      setAnalytics(data);
      setLoading(false);
    });
    return () => unsub();
  }, []);

  const filteredAnalytics = analytics.filter(course => 
    course.title.toLowerCase().includes(searchQuery.toLowerCase()) ||
    course.teacherName.toLowerCase().includes(searchQuery.toLowerCase())
  );

  const totalGross = analytics.reduce((sum, c) => sum + c.gross, 0);
  const totalAcademyNet = analytics.reduce((sum, c) => sum + c.academyNet, 0);

  if (loading) {
    return (
      <div className="min-h-[400px] flex flex-col items-center justify-center text-center">
        <Loader2 className="w-8 h-8 animate-spin text-black mb-4" />
        <p className="text-[10px] font-black uppercase tracking-[4px] text-gray-300">Calculating Real-time Metrics...</p>
      </div>
    );
  }

  return (
    <div className="space-y-8 animate-in fade-in duration-700 pb-20 text-left">
      <div className="flex justify-between items-end">
        <div>
          <h1 className="text-3xl font-black tracking-tight text-gray-900 font-outfit uppercase">Course Analytics</h1>
          <p className="text-gray-400 font-bold text-xs mt-1 uppercase tracking-[3px]">Granular Performance & Profit Distribution</p>
        </div>
        <div className="relative">
          <Search className="absolute left-4 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
          <input 
            type="text"
            placeholder="Search courses or teachers..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="pl-12 pr-6 py-3 bg-white border border-gray-100 rounded-2xl outline-none focus:border-black transition-all text-xs font-bold w-72 shadow-sm"
          />
        </div>
      </div>

      {/* Global Highlights */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        <div className="bg-black p-8 rounded-[32px] text-white shadow-xl shadow-black/10 relative overflow-hidden group">
          <div className="absolute top-0 right-0 p-4 opacity-10 group-hover:opacity-20 transition-opacity">
            <Calculator className="w-16 h-16" />
          </div>
          <p className="text-white/40 text-[10px] font-black uppercase tracking-widest mb-2">Total Course Volume</p>
          <h2 className="text-4xl font-black tracking-tighter">${totalGross.toLocaleString()}</h2>
          <p className="text-white/40 text-[10px] font-bold mt-4 uppercase tracking-widest">Gross Platform Revenue</p>
        </div>

        <div className="bg-white p-8 rounded-[32px] border border-gray-100 shadow-sm relative overflow-hidden group">
          <div className="absolute top-0 right-0 p-4 opacity-5 group-hover:opacity-10 transition-opacity">
            <TrendingUp className="w-16 h-16 text-black" />
          </div>
          <p className="text-gray-400 text-[10px] font-black uppercase tracking-widest mb-2">Platform Net Profit</p>
          <h2 className="text-4xl font-black tracking-tighter text-black">${totalAcademyNet.toLocaleString()}</h2>
          <p className="text-gray-400 text-[10px] font-bold mt-4 uppercase tracking-widest">After Teachers & Taxes</p>
        </div>

        <div className="bg-white p-8 rounded-[32px] border border-gray-100 shadow-sm">
          <p className="text-gray-400 text-[10px] font-black uppercase tracking-widest mb-2">Avg. Enrollment</p>
          <h2 className="text-4xl font-black tracking-tighter text-black">
            {analytics.length > 0 
              ? Math.round(analytics.reduce((sum, c) => sum + c.enrollmentRate, 0) / analytics.length) 
              : 0}% 
          </h2>
          <p className="text-gray-400 text-[10px] font-bold mt-4 uppercase tracking-widest">Active Capacity Utilization</p>
        </div>
      </div>

      {/* Analytics Table */}
      <div className="bg-white rounded-[40px] border border-gray-100 shadow-sm overflow-hidden">
        <div className="p-10 border-b border-gray-50 flex justify-between items-center bg-gray-50/30">
          <h3 className="text-sm font-black uppercase tracking-widest">Advanced Course Performance</h3>
          <BarChart3 className="w-4 h-4 text-gray-400" />
        </div>
        
        <div className="overflow-x-auto">
          <table className="w-full text-left">
            <thead>
              <tr className="bg-gray-50/50">
                <th className="px-10 py-5 text-[10px] font-black uppercase tracking-widest text-gray-400">Course / Teacher</th>
                <th className="px-10 py-5 text-[10px] font-black uppercase tracking-widest text-gray-400">Capacity</th>
                <th className="px-10 py-5 text-[10px] font-black uppercase tracking-widest text-gray-400 text-right">Gross ($)</th>
                <th className="px-10 py-5 text-[10px] font-black uppercase tracking-widest text-gray-400 text-right">Teacher ($)</th>
                <th className="px-10 py-5 text-[10px] font-black uppercase tracking-widest text-gray-400 text-right">Tax (5%)</th>
                <th className="px-10 py-5 text-[10px] font-black uppercase tracking-widest text-gray-400 text-right">Net Profit</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-50 font-outfit">
              {filteredAnalytics.map((course) => (
                <tr key={course.id} className="hover:bg-gray-50/30 transition-colors group">
                  <td className="px-10 py-8">
                    <p className="text-sm font-black text-gray-900 group-hover:text-black transition-colors">{course.title}</p>
                    <p className="text-[10px] font-bold text-gray-400 uppercase tracking-tighter mt-0.5">{course.teacherName}</p>
                  </td>
                  <td className="px-10 py-8">
                    <div className="space-y-2">
                      <div className="flex justify-between items-center text-[10px] font-black uppercase tracking-tighter">
                        <span className="text-gray-400">{course.currentEnrollment} / {course.maxStudents}</span>
                        <span className={course.enrollmentRate > 90 ? "text-red-500" : "text-gray-900"}>{Math.round(course.enrollmentRate)}%</span>
                      </div>
                      <div className="w-24 h-1.5 bg-gray-100 rounded-full overflow-hidden">
                        <motion.div 
                          initial={{ width: 0 }}
                          animate={{ width: `${course.enrollmentRate}%` }}
                          className={`h-full rounded-full ${
                            course.enrollmentRate > 90 ? "bg-red-500" : "bg-black"
                          }`}
                        />
                      </div>
                    </div>
                  </td>
                  <td className="px-10 py-8 text-right font-black text-sm">${course.gross.toLocaleString()}</td>
                  <td className="px-10 py-8 text-right font-bold text-xs text-amber-600">-${course.teacherShare.toLocaleString()}</td>
                  <td className="px-10 py-8 text-right font-bold text-xs text-gray-400">-${course.taxes.toLocaleString()}</td>
                  <td className="px-10 py-8 text-right">
                    <span className="px-4 py-1.5 bg-green-50 text-green-700 rounded-full text-[10px] font-black uppercase tracking-widest border border-green-100">
                      +${course.academyNet.toLocaleString()}
                    </span>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
          
          {filteredAnalytics.length === 0 && (
            <div className="p-20 text-center">
              <Plus className="w-12 h-12 text-gray-100 mx-auto mb-4" />
              <p className="text-[10px] font-black uppercase tracking-[4px] text-gray-300">No course data integrated yet</p>
            </div>
          )}
        </div>
      </div>

      {/* Logic Explained */}
      <div className="bg-gray-50 rounded-[40px] p-10 flex items-start gap-8">
        <div className="p-4 bg-white rounded-2xl shadow-sm">
          <Calculator className="w-6 h-6 text-black" />
        </div>
        <div>
          <h4 className="text-xs font-black uppercase tracking-[2px] mb-2">Automated P&L Logic</h4>
          <p className="text-gray-400 text-[10px] font-bold leading-relaxed uppercase tracking-widest">
            Net Profit = Gross Revenue - (Teacher Tier Share) - (5% Standard Processing Tax). 
            Enrollment metrics are calculated identifying active seats against maximum capacity set by teachers.
          </p>
        </div>
      </div>
    </div>
  );
}

function Plus({ className }: { className?: string }) {
  return (
    <svg className={className} fill="none" viewBox="0 0 24 24" stroke="currentColor">
      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 6v6m0 0v6m0-6h6m-6 0H6" />
    </svg>
  );
}
