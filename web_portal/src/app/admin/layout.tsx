"use client";
import { useEffect, useState } from "react";
import { auth, db } from "@/lib/firebase";
import { doc, getDoc } from "firebase/firestore";
import { useRouter } from "next/navigation";
import { LayoutDashboard, Wallet, UserCheck, FileText, BarChart3, LogOut, Loader2, Menu, X, Lock, ShieldCheck } from "lucide-react";
import { motion } from "framer-motion";
import Link from "next/link";
import { usePathname } from "next/navigation";

export default function AdminLayout({ children }: { children: React.ReactNode }) {
  const [isAdmin, setIsAdmin] = useState<boolean | null>(null);
  const [adminData, setAdminData] = useState<any>(null);
  const [isUnlocked, setIsUnlocked] = useState(false);
  const [storedPin, setStoredPin] = useState<string | null>(null);
  const [pin, setPin] = useState("");
  const [pinError, setPinError] = useState(false);
  const [isSidebarOpen, setSidebarOpen] = useState(false);
  const [isLoadingPin, setIsLoadingPin] = useState(true);
  const router = useRouter();
  const pathname = usePathname();

  useEffect(() => {
    const hashPin = async (p: string) => {
      const msgUint8 = new TextEncoder().encode(p);
      const hashBuffer = await crypto.subtle.digest("SHA-256", msgUint8);
      const hashArray = Array.from(new Uint8Array(hashBuffer));
      return hashArray.map((b) => b.toString(16).padStart(2, "0")).join("");
    };

    const checkAdminAndFetchPin = async () => {
      const user = auth.currentUser;
      if (!user) {
        router.push("/login");
        return;
      }
      
      // 1. Check Admin Role & Get Profile Data
      const userDoc = await getDoc(doc(db, "users", user.uid));
      if (userDoc.exists() && userDoc.data()?.role === "admin") {
        setIsAdmin(true);
        setAdminData(userDoc.data());
        
        // 2. Fetch Vault PIN from Database
        try {
          const settingsDoc = await getDoc(doc(db, "settings", "admin"));
          if (settingsDoc.exists()) {
            setStoredPin(settingsDoc.data()?.vaultPin);
          } else {
            const defaultHash = await hashPin("294023");
            const { setDoc } = await import("firebase/firestore");
            await setDoc(doc(db, "settings", "admin"), {
              vaultPin: defaultHash,
              updatedAt: new Date().toISOString()
            });
            setStoredPin(defaultHash);
          }
        } catch (error) {
          console.error("Error fetching PIN:", error);
          const fallbackHash = await hashPin("294023");
          setStoredPin(fallbackHash);
        } finally {
          setIsLoadingPin(false);
        }
      } else {
        router.push("/courses");
      }
    };
    
    const unsubscribe = auth.onAuthStateChanged((user) => {
      if (user) checkAdminAndFetchPin();
      else router.push("/login");
    });

    return () => unsubscribe();
  }, [router]);

  const handlePinSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    const msgUint8 = new TextEncoder().encode(pin);
    const hashBuffer = await crypto.subtle.digest("SHA-256", msgUint8);
    const hashArray = Array.from(new Uint8Array(hashBuffer));
    const inputHash = hashArray.map((b) => b.toString(16).padStart(2, "0")).join("");

    if (inputHash === storedPin) {
      setIsUnlocked(true);
      setPinError(false);
    } else {
      setPinError(true);
      setPin("");
    }
  };

  if (isAdmin === null || (isAdmin && isLoadingPin)) {
    return (
      <div className="min-h-screen bg-white flex items-center justify-center">
        <Loader2 className="w-8 h-8 animate-spin text-black" />
      </div>
    );
  }

  // Vault Lock Screen (Keep clean)
  if (isAdmin && !isUnlocked) {
    return (
      <div className="min-h-screen bg-[#F8F9FA] flex flex-col items-center justify-center p-6">
        <motion.div 
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          className="w-full max-w-md bg-white rounded-[40px] p-12 shadow-2xl shadow-black/5 border border-gray-100 text-center"
        >
          <div className="w-20 h-20 bg-black rounded-3xl flex items-center justify-center mx-auto mb-8 shadow-xl shadow-black/20">
            <Lock className="w-10 h-10 text-white" />
          </div>
          <h2 className="text-3xl font-black tracking-tight text-gray-900 font-outfit uppercase">Admin Vault</h2>
          <p className="text-gray-400 font-bold text-[10px] uppercase tracking-[4px] mt-2 mb-10">Secondary Authentication Required</p>
          
          <form onSubmit={handlePinSubmit} className="space-y-6">
            <div className="relative group">
              <input
                type="password"
                maxLength={6}
                value={pin}
                onChange={(e) => setPin(e.target.value)}
                placeholder="ENTER 6-DIGIT PIN"
                className={`w-full text-center py-4 bg-gray-50 border-2 rounded-2xl outline-none transition-all text-xl font-black tracking-[1em] placeholder:tracking-normal placeholder:text-gray-300 placeholder:text-xs ${pinError ? "border-red-500 bg-red-50" : "border-gray-100 focus:border-black focus:bg-white"}`}
                autoFocus
                required
              />
              {pinError && (
                <p className="text-red-500 text-[10px] font-black uppercase tracking-widest mt-3">Invalid Secure Key. Try again.</p>
              )}
            </div>
            
            <button
              type="submit"
              className="w-full py-4 bg-black text-white rounded-2xl font-black uppercase tracking-[3px] text-xs hover:scale-[1.02] active:scale-[0.98] transition-all shadow-lg shadow-black/20"
            >
              Unlock Dashboard
            </button>
          </form>

          <button 
            onClick={() => auth.signOut()}
            className="mt-8 text-[10px] font-black uppercase tracking-widest text-gray-400 hover:text-red-500 transition-colors"
          >
            Switch Account
          </button>
        </motion.div>
      </div>
    );
  }

  const menuItems = [
    { icon: LayoutDashboard, label: "Dashboard", href: "/admin/dashboard" },
    { icon: ShieldCheck, label: "Order Audit", href: "/admin/orders" },
    { icon: Wallet, label: "Finance & Oversight", href: "/admin/finance" },
    { icon: BarChart3, label: "Course Analytics", href: "/admin/courses" },
    { icon: UserCheck, label: "Teacher Commissions", href: "/admin/commissions" },
    { icon: FileText, label: "Executive Notes", href: "/admin/notes" },
  ];

  return (
    <div className="min-h-screen bg-[#F8F9FA] flex">
      <aside className={`fixed inset-y-0 left-0 z-50 w-64 bg-white border-r border-gray-200 transform transition-transform duration-300 ${isSidebarOpen ? "translate-x-0" : "-translate-x-full"} lg:translate-x-0`}>
        <div className="p-8">
          <div className="flex items-center gap-3 mb-10">
            <div className="w-8 h-8 bg-black rounded-lg flex items-center justify-center">
              <span className="text-white font-black text-xs">C</span>
            </div>
            <span className="font-black tracking-tighter text-xl">CALLIGRO</span>
          </div>

          <nav className="space-y-1">
            {menuItems.map((item) => (
              <Link
                key={item.href}
                href={item.href}
                className={`flex items-center gap-3 px-4 py-3 rounded-xl transition-all ${pathname === item.href ? "bg-black text-white shadow-lg shadow-black/10" : "text-gray-500 hover:bg-gray-50"}`}
              >
                <item.icon className="w-5 h-5" />
                <span className="font-bold text-sm">{item.label}</span>
              </Link>
            ))}
          </nav>
        </div>

        <div className="absolute bottom-8 left-0 w-full px-8">
          <button 
            onClick={() => auth.signOut()}
            className="flex items-center gap-3 px-4 py-3 w-full rounded-xl text-red-500 hover:bg-red-50 transition-all font-bold text-sm"
          >
            <LogOut className="w-5 h-5" />
            Sign Out
          </button>
        </div>
      </aside>

      <main className="flex-1 lg:ml-64 bg-[#F8F9FA] min-h-screen text-black">
        <header className="h-20 bg-white border-b border-gray-200 flex items-center justify-between px-8 sticky top-0 z-40">
          <button className="lg:hidden" onClick={() => setSidebarOpen(!isSidebarOpen)}>
            {isSidebarOpen ? <X /> : <Menu />}
          </button>
          <div className="flex-1" />
          <div className="flex items-center gap-4">
            <div className="text-right">
              <p className="text-xs font-black uppercase tracking-widest text-gray-400">Master Admin</p>
              <p className="text-sm font-bold truncate max-w-[150px]">{adminData?.name || "Yazan Qattous"}</p>
            </div>
            <div className="w-10 h-10 rounded-full bg-gray-100 border border-gray-200 overflow-hidden">
               {adminData?.photoUrl ? (
                 <img src={adminData.photoUrl} alt="Profile" className="w-full h-full object-cover" />
               ) : (
                 <div className="w-full h-full bg-black flex items-center justify-center text-white font-black text-xs">
                   {adminData?.name?.[0] || "Y"}
                 </div>
               )}
            </div>
          </div>
        </header>

        <div className="p-8">
          {children}
        </div>
      </main>
    </div>
  );
}
