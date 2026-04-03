"use client";
import { useState, useEffect } from "react";
import { 
  Users, 
  Search, 
  Filter, 
  UserPlus, 
  Shield, 
  User, 
  MoreHorizontal, 
  History, 
  Loader2,
  CheckCircle2
} from "lucide-react";
import { motion } from "framer-motion";
import { financeService } from "@/lib/financeService";

export default function AdminUsers() {
  const [users, setUsers] = useState<any[]>([]);
  const [logs, setLogs] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState("");

  useEffect(() => {
    const unsubUsers = financeService.getUsers(setUsers);
    const unsubLogs = financeService.getAdminLogs((data) => {
      setLogs(data);
      setLoading(false);
    });

    return () => {
      unsubUsers();
      unsubLogs();
    };
  }, []);

  const filteredUsers = users.filter(u => 
    u.name?.toLowerCase().includes(searchTerm.toLowerCase()) || 
    u.email?.toLowerCase().includes(searchTerm.toLowerCase())
  );

  const handleRoleChange = async (uid: string, newRole: string) => {
    // This is where you'd call a changeRole function in financeService
    await financeService.logAdminAction("Role Change", `Changed UID ${uid} to role ${newRole}`);
  };

  if (loading) {
    return (
      <div className="min-h-[400px] flex items-center justify-center">
        <Loader2 className="w-8 h-8 animate-spin text-black" />
      </div>
    );
  }

  return (
    <div className="space-y-8 animate-in fade-in duration-700 pb-20">
      <div className="flex justify-between items-end">
        <div>
          <h1 className="text-3xl font-black tracking-tight text-gray-900 font-outfit uppercase text-left">User Management</h1>
          <p className="text-gray-400 font-bold text-xs mt-1 text-left uppercase tracking-[3px]">Academy Directory & Security Control</p>
        </div>
        <button className="flex items-center gap-2 px-6 py-3 rounded-2xl bg-black text-white font-black text-[10px] uppercase tracking-widest hover:scale-105 transition-all shadow-xl shadow-black/10">
          <UserPlus className="w-4 h-4" />
          Add User
        </button>
      </div>

      {/* User Directory */}
      <div className="bg-white rounded-[32px] border border-gray-100 shadow-sm overflow-hidden">
        <div className="p-8 border-b border-gray-50 flex flex-col md:flex-row justify-between items-center gap-4">
          <div className="flex items-center gap-4">
             <div className="p-3 bg-gray-50 rounded-2xl">
               <Users className="w-5 h-5 text-black" />
             </div>
             <div>
               <h3 className="text-sm font-black uppercase tracking-widest">Global Directory</h3>
               <p className="text-[10px] font-bold text-gray-400 uppercase tracking-widest">{users.length} Active Members</p>
             </div>
          </div>
          <div className="flex items-center gap-3 w-full md:w-auto">
            <div className="relative flex-1 md:w-80">
              <Search className="absolute left-4 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
              <input 
                type="text" 
                placeholder="Search by name or email..." 
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
                className="w-full pl-12 pr-4 py-3 border border-gray-100 rounded-2xl bg-gray-50 focus:bg-white focus:border-black transition-all outline-none text-xs font-bold" 
              />
            </div>
            <button className="p-3 border border-gray-100 rounded-2xl hover:bg-gray-50 transition-colors">
              <Filter className="w-5 h-5 text-gray-500" />
            </button>
          </div>
        </div>
        
        <div className="overflow-x-auto">
          <table className="w-full text-left">
            <thead>
              <tr className="bg-gray-50/50">
                <th className="px-8 py-4 text-[10px] font-black uppercase tracking-widest text-gray-400">User</th>
                <th className="px-8 py-4 text-[10px] font-black uppercase tracking-widest text-gray-400">Role</th>
                <th className="px-8 py-4 text-[10px] font-black uppercase tracking-widest text-gray-400">Status</th>
                <th className="px-8 py-4 text-[10px] font-black uppercase tracking-widest text-gray-400">Joined</th>
                <th className="px-8 py-4 text-[10px] font-black uppercase tracking-widest text-gray-400"></th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-50">
              {filteredUsers.map((user) => (
                <tr key={user.uid} className="hover:bg-gray-50/30 transition-colors group">
                  <td className="px-8 py-5 flex items-center gap-3">
                    <div className="w-10 h-10 rounded-2xl bg-gray-100 border border-gray-50 overflow-hidden flex-shrink-0">
                       {user.photoUrl ? (
                         <img src={user.photoUrl} alt="" className="w-full h-full object-cover" />
                       ) : (
                         <div className="w-full h-full bg-black flex items-center justify-center text-white font-black text-xs">
                           {user.name?.[0] || "U"}
                         </div>
                       )}
                    </div>
                    <div>
                      <p className="text-xs font-black">{user.name || "Anonymous"}</p>
                      <p className="text-[10px] font-bold text-gray-400 uppercase tracking-tighter">{user.email}</p>
                    </div>
                  </td>
                  <td className="px-8 py-5">
                    <span className={`px-3 py-1 rounded-full text-[9px] font-black uppercase tracking-widest flex items-center gap-1.5 w-fit ${user.role === "admin" ? "bg-black text-white shadow-lg shadow-black/10" : user.role === "teacher" ? "bg-blue-50 text-blue-600" : "bg-gray-100 text-gray-500"}`}>
                      {user.role === "admin" && <Shield className="w-3 h-3" />}
                      {user.role}
                    </span>
                  </td>
                  <td className="px-8 py-5">
                    <span className="flex items-center gap-1.5 text-[10px] font-black uppercase text-green-600 tracking-widest">
                       <CheckCircle2 className="w-3.5 h-3.5" />
                       Active
                    </span>
                  </td>
                  <td className="px-8 py-5 text-[10px] font-bold text-gray-400 uppercase">
                    {user.createdAt ? new Date(user.createdAt?.seconds * 1000).toLocaleDateString() : "Historical"}
                  </td>
                  <td className="px-8 py-5 text-right">
                    <button className="p-2 hover:bg-white rounded-xl transition-colors border border-transparent hover:border-gray-100">
                      <MoreHorizontal className="w-5 h-5 text-gray-300" />
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      {/* Pillar 5: Audit Trail */}
      <div className="bg-black rounded-[32px] p-8 shadow-2xl shadow-black/20 text-white">
        <div className="flex items-center gap-3 mb-8">
          <History className="w-5 h-5 text-white/40" />
          <h3 className="text-sm font-black uppercase tracking-widest">Pillar 5: Administrative Audit Trail</h3>
        </div>
        
        <div className="space-y-4 max-h-[400px] overflow-y-auto pr-4 scrollbar-hide">
          {logs.map((log) => (
            <div key={log.id} className="flex flex-col md:flex-row md:items-center justify-between p-4 bg-white/5 rounded-2xl border border-white/10 hover:bg-white/10 transition-colors gap-2">
              <div className="flex items-center gap-4">
                <div className="w-2 h-2 rounded-full bg-green-500 shadow-[0_0_10px_rgba(34,197,94,0.5)]" />
                <div>
                   <p className="text-[10px] font-black uppercase tracking-widest text-white/90">{log.action}</p>
                   <p className="text-[9px] font-medium text-white/40 uppercase tracking-widest">{log.details}</p>
                </div>
              </div>
              <div className="text-right">
                <p className="text-[9px] font-black uppercase text-white/30 tracking-widest italic">{log.adminEmail}</p>
                <p className="text-[8px] font-bold text-white/20 uppercase tracking-[2px] mt-1">
                  {log.timestamp ? new Date(log.timestamp?.seconds * 1000).toLocaleString() : "Just now"}
                </p>
              </div>
            </div>
          ))}
          {logs.length === 0 && (
            <div className="text-center py-10">
              <p className="text-[10px] font-black uppercase tracking-widest text-white/20">System logs are empty. Secure operations in effect.</p>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
