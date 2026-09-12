"use client";

import { useState, useEffect, useMemo } from "react";
import { ArrowUpRight, Plus, Calendar, Clock, TrendingUp as TrendingUpIcon, Loader2, Search, ChevronDown, Landmark, BadgeDollarSign, ReceiptText } from "lucide-react";
import { motion, AnimatePresence } from "framer-motion";
import { financeService, Transaction, Expense } from "@/lib/financeService";

// ─── Translations ─────────────────────────────────────────────────────────────
const translations = {
  en: {
    dir: "ltr" as const,
    title: "Finance Oversight",
    subtitle: "Real-time P&L · Fee Breakdown · Settlement Log",
    logSettlement: "Log Settlement",
    recordOutcome: "Record Outcome",
    netAcademyProfit: "Net Academy Profit",
    afterAllExpenses: "After all expenses",
    grossSales: "Gross Sales",
    salesWithFee: "Sales (with 8%)",
    teacherPayoutsDue: "Teacher Payouts Due",
    awaitingSettlement: "Awaiting Settlement",
    totalOutcomes: "Total Outcomes",
    logged: "Logged",
    netRevenue: "Net Revenue (ex-8%)",
    grossDiv108: "Gross ÷ 1.08",
    lsProcessing: "LS Processing (5%+$0.50)",
    paidToLS: "Paid to Lemon Squeezy",
    lsExchange: "LS Exchange (1.5%)",
    currencyConversion: "Currency conversion",
    bankReceivingFees: "Bank Receiving Fees",
    fromSettlements: "From logged settlements",
    plBreakdown: "P&L Breakdown",
    plSubtitle: "Gross → Strip 8% → Fees → Teacher Cut → Academy Profit",
    daily: "Daily",
    weekly: "Weekly",
    monthly: "Monthly",
    yearly: "Yearly",
    period: "Period",
    grossSalesCol: "Gross Sales",
    netRevCol: "Net Rev (÷1.08)",
    lsFeeCol: "LS Fee (5%+$0.5)",
    exchangeCol: "Exchange (1.5%)",
    teacherCutCol: "All Teachers",
    bufferTotalCol: "8% Buffer Collected",
    bufferSurplusCol: "Buffer Remaining",
    academyProfitCol: "Academy Profit",
    noTransactions: "No transactions yet.",
    allTime: "All Time",
    sales: "sales",
    teacherEarningsTitle: "Teacher Earnings Breakdown",
    teacherEarningsSubtitle: "Per-teacher commission earnings for the selected period",
    teacherNameCol: "Teacher",
    commissionRateCol: "Rate",
    teacherNetSalesCol: "Net Sales",
    teacherEarningsCol: "Earnings",
    noTeacherData: "No teacher data for this period.",
    totalRow: "Total",
    inboundSettlements: "Inbound Settlements",
    settlementSubtitle: "Log every Lemon Squeezy wire to your bank. Bank fee is editable per transfer.",
    totalNetCash: "Total Net Cash Received",
    dateReceived: "Date Received",
    grossWiredByLS: "Gross Wired by LS",
    bankReceivingFee: "Bank Receiving Fee ✏️",
    netCashInBank: "Net Cash in Bank",
    noSettlements: 'No settlements logged yet. Click "Log Settlement" when LS wires you money.',
    teacherPayoutSchedule: "Teacher Payout Schedule",
    payoutScheduleSubtitle: "Course End + 2 Days = Payout Ready",
    courseTeacher: "Course / Teacher",
    endsOn: "Ends On",
    payoutDate: "Payout Date",
    status: "Status",
    withdrawalRequests: "Teacher Withdrawal Requests",
    withdrawalSubtitle: "Requested by teachers in-app",
    teacher: "Teacher",
    method: "Method",
    amount: "Amount",
    actionStatus: "Action/Status",
    approveAndPay: "Approve & Pay",
    settled: "Settled",
    noWithdrawals: "No withdrawal requests found.",
    recentSales: "Recent Sales",
    operationalOutcomes: "Operational Outcomes",
    gross: "gross",
    net: "Net",
    modalRecordOutcome: "Record Outcome",
    amountLabel: "Amount ($)",
    noteLabel: "Note / Description",
    notePlaceholder: "e.g. Marketing Campaign",
    dateLabel: "Date",
    logOutcome: "Log Outcome",
    modalLogSettlement: "Log Settlement",
    settlementDesc: "When Lemon Squeezy wires money to your bank, log it here with the exact bank fee you were charged.",
    dateReceivedLabel: "Date Received",
    grossWiredLabel: "Gross Wired by LS ($)",
    bankFeeLabel: "Your Bank Receiving Fee ($) ✏️",
    netCashLabel: "Net Cash in Your Bank",
    saveSettlement: "Save Settlement",
    recent: "Recent",
  },
  ar: {
    dir: "rtl" as const,
    title: "الإشراف المالي",
    subtitle: "الأرباح والخسائر الفورية · تفصيل الرسوم · سجل التسويات",
    logSettlement: "تسجيل تسوية",
    recordOutcome: "تسجيل مصروف",
    netAcademyProfit: "صافي ربح الأكاديمية",
    afterAllExpenses: "بعد كل المصاريف",
    grossSales: "إجمالي المبيعات",
    salesWithFee: "مبيعات (مع 8%)",
    teacherPayoutsDue: "مستحقات المعلمين",
    awaitingSettlement: "بانتظار التسوية",
    totalOutcomes: "إجمالي المصاريف",
    logged: "مسجّل",
    netRevenue: "الإيراد الصافي (بدون 8%)",
    grossDiv108: "الإجمالي ÷ 1.08",
    lsProcessing: "رسوم LS (5%+$0.50)",
    paidToLS: "مدفوعة لـ Lemon Squeezy",
    lsExchange: "رسوم صرف LS (1.5%)",
    currencyConversion: "تحويل العملة",
    bankReceivingFees: "رسوم استقبال البنك",
    fromSettlements: "من التسويات المسجّلة",
    plBreakdown: "تفصيل الأرباح والخسائر",
    plSubtitle: "الإجمالي ← خصم 8% ← الرسوم ← حصة المعلم ← ربح الأكاديمية",
    daily: "يومي",
    weekly: "أسبوعي",
    monthly: "شهري",
    yearly: "سنوي",
    period: "الفترة",
    grossSalesCol: "الإجمالي",
    netRevCol: "الصافي (÷1.08)",
    lsFeeCol: "رسوم LS (5%+$0.5)",
    exchangeCol: "رسوم الصرف (1.5%)",
    teacherCutCol: "إجمالي المعلمين",
    bufferTotalCol: "إجمالي الـ 8% المحصّل",
    bufferSurplusCol: "المتبقي من الـ 8%",
    academyProfitCol: "ربح الأكاديمية",
    noTransactions: "لا توجد معاملات بعد.",
    allTime: "الإجمالي الكلي",
    sales: "مبيعات",
    teacherEarningsTitle: "تفصيل أرباح المعلمين",
    teacherEarningsSubtitle: "عمولة كل معلم للفترة المحددة",
    teacherNameCol: "المعلم",
    commissionRateCol: "نسبة العمولة",
    teacherNetSalesCol: "صافي المبيعات",
    teacherEarningsCol: "أرباحه",
    noTeacherData: "لا توجد بيانات لهذه الفترة.",
    totalRow: "المجموع",
    inboundSettlements: "التسويات الواردة",
    settlementSubtitle: "سجّل كل تحويل من Lemon Squeezy لبنكك. رسوم البنك قابلة للتعديل لكل تحويل.",
    totalNetCash: "إجمالي النقد الصافي المستلم",
    dateReceived: "تاريخ الاستلام",
    grossWiredByLS: "المبلغ المحوّل من LS",
    bankReceivingFee: "رسوم استقبال البنك ✏️",
    netCashInBank: "الصافي في البنك",
    noSettlements: 'لا توجد تسويات مسجّلة. اضغط "تسجيل تسوية" عند استلام تحويل.',
    teacherPayoutSchedule: "جدول مدفوعات المعلمين",
    payoutScheduleSubtitle: "انتهاء الدورة + يومان = مدفوعات جاهزة",
    courseTeacher: "الدورة / المعلم",
    endsOn: "تنتهي في",
    payoutDate: "تاريخ الدفع",
    status: "الحالة",
    withdrawalRequests: "طلبات سحب المعلمين",
    withdrawalSubtitle: "مقدّمة من المعلمين عبر التطبيق",
    teacher: "المعلم",
    method: "الطريقة",
    amount: "المبلغ",
    actionStatus: "الإجراء/الحالة",
    approveAndPay: "موافقة ودفع",
    settled: "مسوّى",
    noWithdrawals: "لا توجد طلبات سحب.",
    recentSales: "آخر المبيعات",
    operationalOutcomes: "المصاريف التشغيلية",
    gross: "الإجمالي",
    net: "الصافي",
    modalRecordOutcome: "تسجيل مصروف",
    amountLabel: "المبلغ ($)",
    noteLabel: "الملاحظة / الوصف",
    notePlaceholder: "مثال: حملة تسويقية",
    dateLabel: "التاريخ",
    logOutcome: "تسجيل",
    modalLogSettlement: "تسجيل تسوية",
    settlementDesc: "عند استلام تحويل من Lemon Squeezy، سجّله هنا مع رسوم بنكك الفعلية.",
    dateReceivedLabel: "تاريخ الاستلام",
    grossWiredLabel: "المبلغ المحوّل من LS ($)",
    bankFeeLabel: "رسوم استقبال بنكك ($) ✏️",
    netCashLabel: "الصافي في بنكك",
    saveSettlement: "حفظ التسوية",
    recent: "مؤخراً",
  }
};

// ─── Fee Constants ─────────────────────────────────────────────────────────
const LS_PROCESSING_RATE = 0.05;
const LS_PROCESSING_FLAT = 0.50;
const LS_EXCHANGE_RATE   = 0.015;
const FEE_BUFFER_RATE    = 0.08;

function toNetRevenue(gross: number) { return gross / (1 + FEE_BUFFER_RATE); }
function lsProcessingFee(gross: number) { return gross * LS_PROCESSING_RATE + LS_PROCESSING_FLAT; }

type Period = "day" | "week" | "month" | "year";
type Lang = "en" | "ar";

function periodKey(period: Period, date: Date): string {
  if (period === "day")   return date.toISOString().split("T")[0];
  if (period === "week")  { const d = new Date(date); d.setDate(d.getDate() - d.getDay()); return d.toISOString().split("T")[0]; }
  if (period === "month") return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, "0")}`;
  return `${date.getFullYear()}`;
}

function periodLabel(period: Period, date: Date, lang: Lang): string {
  const locale = lang === "ar" ? "ar-SA" : "en-US";
  if (period === "day")   return date.toLocaleDateString(locale, { weekday: "short", month: "short", day: "numeric" });
  if (period === "week")  { const d = new Date(date); d.setDate(d.getDate() - d.getDay()); return `${lang === "ar" ? "أسبوع" : "Week of"} ${d.toLocaleDateString(locale, { month: "short", day: "numeric" })}`; }
  if (period === "month") return date.toLocaleDateString(locale, { month: "long", year: "numeric" });
  return date.getFullYear().toString();
}

interface Settlement { id: string; date: string; grossWired: number; bankFee: number; netCash: number; createdAt: any; }

export default function AdminFinance() {
  const [transactions, setTransactions] = useState<Transaction[]>([]);
  const [expenses, setExpenses]         = useState<Expense[]>([]);
  const [payoutEligibility, setPayoutEligibility] = useState<any[]>([]);
  const [payouts, setPayouts]           = useState<any[]>([]);
  const [settlements, setSettlements]   = useState<Settlement[]>([]);
  const [loading, setLoading]           = useState(true);
  const [period, setPeriod]             = useState<Period>("month");
  const [lang, setLang]                 = useState<Lang>("en");
  const [showAddExpense,    setShowAddExpense]    = useState(false);
  const [showAddSettlement, setShowAddSettlement] = useState(false);
  const [expAmount, setExpAmount] = useState("");
  const [expNote,   setExpNote]   = useState("");
  const [expDate,   setExpDate]   = useState(new Date().toISOString().split("T")[0]);
  const [setlDate,    setSetlDate]    = useState(new Date().toISOString().split("T")[0]);
  const [setlGross,   setSetlGross]   = useState("");
  const [setlBankFee, setSetlBankFee] = useState("");

  const t = translations[lang];

  useEffect(() => {
    const unsubTxs  = financeService.getTransactions(setTransactions);
    const unsubExps = financeService.getExpenses(setExpenses);
    const unsubPays = financeService.getPayouts(setPayouts);
    const unsubSett = financeService.getSettlements((data: Settlement[]) => setSettlements(data));
    const unsubElig = financeService.getPayoutEligibility((data: any[]) => { setPayoutEligibility(data); setLoading(false); });
    return () => { unsubTxs(); unsubExps(); unsubPays(); unsubSett(); unsubElig(); };
  }, []);

  const plRows = useMemo(() => {
    const map = new Map<string, any>();
    transactions.forEach((tx) => {
      const date  = tx.createdAt?.toDate ? tx.createdAt.toDate() : new Date();
      const key   = periodKey(period, date);
      const label = periodLabel(period, date, lang);
      if (!map.has(key)) map.set(key, { label, sales: 0, salesCount: 0, lsProcessing: 0, lsExchange: 0, netRevenue: 0, teacherShare: 0, bufferTotal: 0, bufferSurplus: 0, academyProfit: 0 });
      const row     = map.get(key)!;
      const gross   = tx.amount || 0;
      const net     = toNetRevenue(gross);
      const buffer  = gross - net;
      const lsProc  = lsProcessingFee(gross);
      const lsExch  = gross * LS_EXCHANGE_RATE;
      const surplus = buffer - lsProc - lsExch;
      const tShare  = tx.teacherShare || 0;
      row.sales += gross; row.salesCount += 1;
      row.lsProcessing += lsProc; row.lsExchange += lsExch;
      row.netRevenue += net; row.teacherShare += tShare;
      row.bufferTotal += buffer;
      row.bufferSurplus += surplus;
      row.academyProfit += (net - tShare) + surplus;
    });
    return Array.from(map.entries()).sort(([a],[b]) => b.localeCompare(a)).map(([,v]) => v);
  }, [transactions, period, lang]);

  // ─── Per-Teacher Earnings for selected period ──────────────────────────────
  const teacherRows = useMemo(() => {
    const map = new Map<string, { name: string; netSales: number; earnings: number; txCount: number; rate: number }>();
    transactions.forEach((tx) => {
      const date = tx.createdAt?.toDate ? tx.createdAt.toDate() : new Date();
      const key  = periodKey(period, date);
      // Only include transactions in periods that exist in plRows
      const tId   = (tx as any).teacherId || tx.teacherName || "unknown";
      const tName = tx.teacherName || "Unknown Teacher";
      const net   = toNetRevenue(tx.amount || 0);
      const share = tx.teacherShare || 0;
      const rate  = net > 0 ? share / net : 0;
      if (!map.has(tId)) map.set(tId, { name: tName, netSales: 0, earnings: 0, txCount: 0, rate });
      const row = map.get(tId)!;
      row.netSales += net;
      row.earnings += share;
      row.txCount  += 1;
    });
    return Array.from(map.values()).sort((a, b) => b.earnings - a.earnings);
  }, [transactions, period]);

  const totalTeacherEarnings = teacherRows.reduce((s, r) => s + r.earnings, 0);
  const totalTeacherNetSales = teacherRows.reduce((s, r) => s + r.netSales, 0);

  const totalGross        = transactions.reduce((s, tx) => s + (tx.amount || 0), 0);
  const totalNetRevenue   = toNetRevenue(totalGross);
  const totalLsProc       = transactions.reduce((s, tx) => s + lsProcessingFee(tx.amount || 0), 0);
  const totalLsExch       = transactions.reduce((s, tx) => s + (tx.amount || 0) * LS_EXCHANGE_RATE, 0);
  const totalTeacherShare = transactions.reduce((s, tx) => s + (tx.teacherShare || 0), 0);
  const totalBufferSurplus= (totalGross - totalNetRevenue) - totalLsProc - totalLsExch;
  const totalAcademy      = (totalNetRevenue - totalTeacherShare) + totalBufferSurplus;
  const totalExpenses     = expenses.reduce((s, e) => s + (e.amount || 0), 0);
  const netAcademyProfit  = totalAcademy - totalExpenses;
  const totalSettlements  = settlements.reduce((s, st) => s + st.netCash, 0);
  const totalBankFees     = settlements.reduce((s, st) => s + st.bankFee, 0);

  const handleAddExpense = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!expAmount || !expNote) return;
    await financeService.addExpense(parseFloat(expAmount), expNote, expDate);
    setExpAmount(""); setExpNote(""); setShowAddExpense(false);
  };
  const handleAddSettlement = async (e: React.FormEvent) => {
    e.preventDefault();
    const gross = parseFloat(setlGross) || 0;
    const bankFee = parseFloat(setlBankFee) || 0;
    await financeService.addSettlement(setlDate, gross, bankFee, gross - bankFee);
    setSetlGross(""); setSetlBankFee(""); setShowAddSettlement(false);
  };

  if (loading) return <div className="min-h-[400px] flex items-center justify-center"><Loader2 className="w-8 h-8 animate-spin text-black" /></div>;

  return (
    <div dir={t.dir} className="space-y-10 animate-in fade-in duration-700 pb-24 text-left">

      {/* Header */}
      <div className="flex justify-between items-end flex-wrap gap-4">
        <div>
          <h1 className="text-3xl font-black tracking-tight text-gray-900 font-outfit uppercase">{t.title}</h1>
          <p className="text-gray-400 font-bold text-xs mt-1 uppercase tracking-[3px]">{t.subtitle}</p>
        </div>
        <div className="flex gap-3 flex-wrap items-center">
          {/* Language Toggle */}
          <div className="flex items-center bg-gray-100 rounded-2xl p-1 gap-1">
            <button onClick={() => setLang("en")} className={`px-4 py-2 rounded-xl text-[10px] font-black uppercase tracking-widest transition-all ${lang === "en" ? "bg-black text-white shadow" : "text-gray-400 hover:text-black"}`}>EN</button>
            <button onClick={() => setLang("ar")} className={`px-4 py-2 rounded-xl text-[10px] font-black uppercase tracking-widest transition-all ${lang === "ar" ? "bg-black text-white shadow" : "text-gray-400 hover:text-black"}`}>AR</button>
          </div>
          <button onClick={() => setShowAddSettlement(true)} className="flex items-center gap-2 px-6 py-3 rounded-2xl bg-gray-900 text-white font-black text-[10px] uppercase tracking-widest hover:scale-105 transition-all shadow-xl shadow-black/10">
            <Landmark className="w-4 h-4" /> {t.logSettlement}
          </button>
          <button onClick={() => setShowAddExpense(true)} className="flex items-center gap-2 px-6 py-3 rounded-2xl bg-black text-white font-black text-[10px] uppercase tracking-widest hover:scale-105 transition-all shadow-xl shadow-black/10">
            <Plus className="w-4 h-4" /> {t.recordOutcome}
          </button>
        </div>
      </div>

      {/* KPI Row 1 */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-5">
        <div className="bg-black text-white p-8 rounded-[32px] relative overflow-hidden">
          <div className="absolute -bottom-4 -right-4 opacity-5"><TrendingUpIcon className="w-24 h-24" /></div>
          <p className="text-white/50 text-[10px] font-black uppercase tracking-widest mb-2">{t.netAcademyProfit}</p>
          <h2 className="text-4xl font-black tracking-tighter">${netAcademyProfit.toFixed(2)}</h2>
          <div className="flex items-center gap-1 text-green-400 text-[10px] font-black mt-4 uppercase"><ArrowUpRight className="w-3 h-3" /> {t.afterAllExpenses}</div>
        </div>
        <div className="bg-white p-8 rounded-[32px] border border-gray-100 shadow-sm">
          <p className="text-gray-400 text-[10px] font-black uppercase tracking-widest mb-2">{t.grossSales}</p>
          <h2 className="text-3xl font-black tracking-tighter">${totalGross.toFixed(2)}</h2>
          <p className="text-gray-400 text-[10px] font-bold mt-4 uppercase tracking-widest">{transactions.length} {t.salesWithFee}</p>
        </div>
        <div className="bg-amber-50 p-8 rounded-[32px] border border-amber-100 shadow-sm">
          <p className="text-amber-600/60 text-[10px] font-black uppercase tracking-widest mb-2">{t.teacherPayoutsDue}</p>
          <h2 className="text-3xl font-black text-amber-900 tracking-tighter">${totalTeacherShare.toFixed(2)}</h2>
          <p className="text-amber-600/40 text-[10px] font-bold mt-4 uppercase tracking-widest">{t.awaitingSettlement}</p>
        </div>
        <div className="bg-red-50 p-8 rounded-[32px] border border-red-100 shadow-sm">
          <p className="text-red-400/60 text-[10px] font-black uppercase tracking-widest mb-2">{t.totalOutcomes}</p>
          <h2 className="text-3xl font-black text-red-600 tracking-tighter">-${totalExpenses.toFixed(2)}</h2>
          <p className="text-red-400/40 text-[10px] font-bold mt-4 uppercase tracking-widest">{expenses.length} {t.logged}</p>
        </div>
      </div>

      {/* KPI Row 2: Fees */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-5">
        <div className="bg-white p-6 rounded-[28px] border border-gray-100 shadow-sm">
          <p className="text-gray-400 text-[9px] font-black uppercase tracking-widest mb-1">{t.netRevenue}</p>
          <h3 className="text-2xl font-black tracking-tight">${totalNetRevenue.toFixed(2)}</h3>
          <p className="text-gray-300 text-[9px] mt-2 font-bold">{t.grossDiv108}</p>
        </div>
        <div className="bg-white p-6 rounded-[28px] border border-gray-100 shadow-sm">
          <p className="text-orange-400 text-[9px] font-black uppercase tracking-widest mb-1">{t.lsProcessing}</p>
          <h3 className="text-2xl font-black tracking-tight text-orange-500">-${totalLsProc.toFixed(2)}</h3>
          <p className="text-gray-300 text-[9px] mt-2 font-bold">{t.paidToLS}</p>
        </div>
        <div className="bg-white p-6 rounded-[28px] border border-gray-100 shadow-sm">
          <p className="text-orange-300 text-[9px] font-black uppercase tracking-widest mb-1">{t.lsExchange}</p>
          <h3 className="text-2xl font-black tracking-tight text-orange-400">-${totalLsExch.toFixed(2)}</h3>
          <p className="text-gray-300 text-[9px] mt-2 font-bold">{t.currencyConversion}</p>
        </div>
        <div className="bg-white p-6 rounded-[28px] border border-gray-100 shadow-sm">
          <p className="text-red-400 text-[9px] font-black uppercase tracking-widest mb-1">{t.bankReceivingFees}</p>
          <h3 className="text-2xl font-black tracking-tight text-red-500">-${totalBankFees.toFixed(2)}</h3>
          <p className="text-gray-300 text-[9px] mt-2 font-bold">{t.fromSettlements}</p>
        </div>
      </div>

      {/* P&L Table */}
      <div className="bg-white rounded-[40px] border border-gray-100 shadow-sm overflow-hidden">
        <div className="p-8 border-b border-gray-50 flex justify-between items-center flex-wrap gap-4">
          <div>
            <h3 className="text-sm font-black uppercase tracking-widest flex items-center gap-2"><ReceiptText className="w-4 h-4" /> {t.plBreakdown}</h3>
            <p className="text-[10px] font-bold text-gray-400 uppercase tracking-widest mt-1">{t.plSubtitle}</p>
          </div>
          <div className="relative">
            <select value={period} onChange={(e) => setPeriod(e.target.value as Period)} className="appearance-none bg-gray-50 border border-gray-100 rounded-2xl pl-5 pr-10 py-3 text-[10px] font-black uppercase tracking-widest text-gray-700 outline-none cursor-pointer hover:border-black transition-colors">
              <option value="day">{t.daily}</option>
              <option value="week">{t.weekly}</option>
              <option value="month">{t.monthly}</option>
              <option value="year">{t.yearly}</option>
            </select>
            <ChevronDown className="absolute right-3 top-1/2 -translate-y-1/2 w-3 h-3 text-gray-400 pointer-events-none" />
          </div>
        </div>
        <div className="overflow-x-auto">
          <table className="w-full text-left min-w-[960px]" dir={t.dir}>
            <thead>
              <tr className="bg-gray-50/50 border-b border-gray-100">
                <th className="px-6 py-4 text-[9px] font-black uppercase tracking-widest text-gray-400">{t.period}</th>
                <th className="px-6 py-4 text-[9px] font-black uppercase tracking-widest text-gray-400 text-right">{t.grossSalesCol}</th>
                <th className="px-6 py-4 text-[9px] font-black uppercase tracking-widest text-gray-400 text-right">{t.netRevCol}</th>
                <th className="px-6 py-4 text-[9px] font-black uppercase tracking-widest text-orange-400 text-right">{t.lsFeeCol}</th>
                <th className="px-6 py-4 text-[9px] font-black uppercase tracking-widest text-orange-300 text-right">{t.exchangeCol}</th>
                <th className="px-6 py-4 text-[9px] font-black uppercase tracking-widest text-amber-500 text-right">{t.teacherCutCol}</th>
                <th className="px-6 py-4 text-[9px] font-black uppercase tracking-widest text-blue-300 text-right">{t.bufferTotalCol}</th>
                <th className="px-6 py-4 text-[9px] font-black uppercase tracking-widest text-blue-500 text-right">{t.bufferSurplusCol}</th>
                <th className="px-6 py-4 text-[9px] font-black uppercase tracking-widest text-green-600 text-right">{t.academyProfitCol}</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-50">
              {plRows.length === 0 && <tr><td colSpan={8} className="px-6 py-10 text-center text-sm text-gray-400 font-bold">{t.noTransactions}</td></tr>}
              {plRows.map((row: any, i: number) => (
                <tr key={i} className="hover:bg-gray-50/50 transition-colors">
                  <td className="px-6 py-5 font-black text-sm text-gray-900">{row.label} <span className="text-[9px] text-gray-300 font-bold mx-1">({row.salesCount} {t.sales})</span></td>
                  <td className="px-6 py-5 text-right font-mono font-bold text-gray-800">${row.sales.toFixed(2)}</td>
                  <td className="px-6 py-5 text-right font-mono text-gray-600">${row.netRevenue.toFixed(2)}</td>
                  <td className="px-6 py-5 text-right font-mono text-orange-500">${row.lsProcessing.toFixed(2)}</td>
                  <td className="px-6 py-5 text-right font-mono text-orange-400">${row.lsExchange.toFixed(2)}</td>
                  <td className="px-6 py-5 text-right font-mono font-bold text-amber-600">${row.teacherShare.toFixed(2)}</td>
                  <td className="px-6 py-5 text-right font-mono text-blue-300">${row.bufferTotal.toFixed(2)}</td>
                  <td className={`px-6 py-5 text-right font-mono font-bold ${row.bufferSurplus >= 0 ? 'text-blue-500' : 'text-red-500'}`}>
                    {row.bufferSurplus < 0 ? '-' : ''}${Math.abs(row.bufferSurplus).toFixed(2)}
                  </td>
                  <td className="px-6 py-5 text-right font-mono font-black text-green-600">${row.academyProfit.toFixed(2)}</td>
                </tr>
              ))}
            </tbody>
            {plRows.length > 0 && (
              <tfoot>
                <tr className="bg-gray-900 text-white">
                  <td className="px-6 py-5 font-black text-[10px] uppercase tracking-widest">{t.allTime}</td>
                  <td className="px-6 py-5 text-right font-mono font-bold">${totalGross.toFixed(2)}</td>
                  <td className="px-6 py-5 text-right font-mono">${totalNetRevenue.toFixed(2)}</td>
                  <td className="px-6 py-5 text-right font-mono text-orange-300">${totalLsProc.toFixed(2)}</td>
                  <td className="px-6 py-5 text-right font-mono text-orange-200">${totalLsExch.toFixed(2)}</td>
                  <td className="px-6 py-5 text-right font-mono font-bold text-amber-300">${totalTeacherShare.toFixed(2)}</td>
                  <td className="px-6 py-5 text-right font-mono text-blue-300">${(totalGross - totalNetRevenue).toFixed(2)}</td>
                  <td className={`px-6 py-5 text-right font-mono font-bold ${totalBufferSurplus >= 0 ? 'text-blue-400' : 'text-red-400'}`}>
                    {totalBufferSurplus < 0 ? '-' : ''}${Math.abs(totalBufferSurplus).toFixed(2)}
                  </td>
                  <td className="px-6 py-5 text-right font-mono font-black text-green-400">${totalAcademy.toFixed(2)}</td>
                </tr>
              </tfoot>
            )}
          </table>
        </div>
      </div>

      {/* Inbound Settlements */}
      <div className="bg-white rounded-[40px] border border-gray-100 shadow-sm overflow-hidden">
        <div className="p-8 border-b border-gray-50 flex justify-between items-center bg-green-50/30 flex-wrap gap-4">
          <div>
            <h3 className="text-sm font-black uppercase tracking-widest flex items-center gap-2"><Landmark className="w-4 h-4 text-green-600" /> {t.inboundSettlements}</h3>
            <p className="text-[10px] font-bold text-gray-400 uppercase tracking-widest mt-1">{t.settlementSubtitle}</p>
          </div>
          <div className="text-right">
            <p className="text-[9px] font-black uppercase tracking-widest text-gray-400">{t.totalNetCash}</p>
            <p className="text-2xl font-black text-green-600">${totalSettlements.toFixed(2)}</p>
          </div>
        </div>
        <div className="overflow-x-auto max-h-[400px] overflow-y-auto">
          <table className="w-full text-left" dir={t.dir}>
            <thead>
              <tr className="bg-green-50/30 border-b border-green-50">
                <th className="px-8 py-4 text-[9px] font-black uppercase tracking-widest text-gray-400">{t.dateReceived}</th>
                <th className="px-8 py-4 text-[9px] font-black uppercase tracking-widest text-gray-400 text-right">{t.grossWiredByLS}</th>
                <th className="px-8 py-4 text-[9px] font-black uppercase tracking-widest text-red-400 text-right">{t.bankReceivingFee}</th>
                <th className="px-8 py-4 text-[9px] font-black uppercase tracking-widest text-green-600 text-right">{t.netCashInBank}</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-50">
              {settlements.length === 0 && <tr><td colSpan={4} className="px-8 py-10 text-center text-sm text-gray-400 font-bold">{t.noSettlements}</td></tr>}
              {settlements.map((s) => (
                <tr key={s.id} className="hover:bg-green-50/20 transition-colors">
                  <td className="px-8 py-5 font-black text-sm text-gray-900">{s.date}</td>
                  <td className="px-8 py-5 text-right font-mono font-bold text-gray-700">${s.grossWired.toFixed(2)}</td>
                  <td className="px-8 py-5 text-right font-mono text-red-500">-${s.bankFee.toFixed(2)}</td>
                  <td className="px-8 py-5 text-right font-mono font-black text-green-600">${s.netCash.toFixed(2)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      {/* Teacher Payout Schedule */}
      <div className="bg-white rounded-[40px] border border-gray-100 shadow-sm overflow-hidden">
        <div className="p-8 border-b border-gray-50 flex justify-between items-center bg-gray-50/30">
          <div>
            <h3 className="text-sm font-black uppercase tracking-widest">{t.teacherPayoutSchedule}</h3>
            <p className="text-[10px] font-bold text-gray-400 uppercase tracking-widest mt-1">{t.payoutScheduleSubtitle}</p>
          </div>
          <Clock className="w-4 h-4 text-gray-300" />
        </div>
        <div className="overflow-x-auto max-h-[400px] overflow-y-auto scrollbar-hide">
          <table className="w-full text-left" dir={t.dir}>
            <thead>
              <tr className="bg-gray-50/50">
                <th className="px-10 py-5 text-[10px] font-black uppercase tracking-widest text-gray-400">{t.courseTeacher}</th>
                <th className="px-10 py-5 text-[10px] font-black uppercase tracking-widest text-gray-400">{t.endsOn}</th>
                <th className="px-10 py-5 text-[10px] font-black uppercase tracking-widest text-gray-400">{t.payoutDate}</th>
                <th className="px-10 py-5 text-right text-[10px] font-black uppercase tracking-widest text-gray-400">{t.status}</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-50">
              {payoutEligibility.map((item) => (
                <tr key={item.id} className="hover:bg-gray-50/50 transition-colors">
                  <td className="px-10 py-6"><p className="text-sm font-black text-gray-900">{item.courseName}</p><p className="text-[10px] font-bold text-gray-400 uppercase tracking-tighter">{item.teacherName}</p></td>
                  <td className="px-10 py-6 text-xs font-black text-gray-500">{item.endDate}</td>
                  <td className="px-10 py-6 text-xs font-black text-gray-900 italic underline decoration-gray-200">{item.payoutDate}</td>
                  <td className="px-10 py-6 text-right">
                    <span className={`px-4 py-1.5 rounded-full text-[9px] font-black uppercase tracking-widest ${item.status === "ready" ? "bg-green-50 text-green-600 border border-green-100" : item.status === "processing" ? "bg-amber-50 text-amber-600 border border-amber-100" : "bg-gray-100 text-gray-400"}`}>{item.status}</span>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      {/* Teacher Withdrawal Requests */}
      <div className="bg-white rounded-[40px] border border-gray-100 shadow-sm overflow-hidden text-left">
        <div className="p-8 border-b border-gray-50 flex justify-between items-center bg-amber-50/30">
          <div>
            <h3 className="text-sm font-black uppercase tracking-widest flex items-center gap-2"><BadgeDollarSign className="w-4 h-4 text-amber-500" /> {t.withdrawalRequests}</h3>
            <p className="text-[10px] font-bold text-gray-400 uppercase tracking-widest mt-1">{t.withdrawalSubtitle}</p>
          </div>
          <Clock className="w-4 h-4 text-amber-300" />
        </div>
        <div className="overflow-x-auto max-h-[400px] overflow-y-auto scrollbar-hide">
          <table className="w-full text-left" dir={t.dir}>
            <thead>
              <tr className="bg-amber-50/50">
                <th className="px-10 py-5 text-[10px] font-black uppercase tracking-widest text-gray-400">{t.teacher}</th>
                <th className="px-10 py-5 text-[10px] font-black uppercase tracking-widest text-gray-400">{t.method}</th>
                <th className="px-10 py-5 text-[10px] font-black uppercase tracking-widest text-gray-400">{t.amount}</th>
                <th className="px-10 py-5 text-right text-[10px] font-black uppercase tracking-widest text-gray-400">{t.actionStatus}</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-50">
              {payouts.map((item) => (
                <tr key={item.id} className="hover:bg-amber-50/50 transition-colors">
                  <td className="px-10 py-6"><p className="text-sm font-black text-gray-900">{item.teacherName}</p><p className="text-[10px] font-bold text-gray-400 uppercase tracking-tighter">{item.createdAt?.toDate ? new Date(item.createdAt.toDate()).toLocaleDateString(lang === "ar" ? "ar-SA" : "en-US") : t.recent}</p></td>
                  <td className="px-10 py-6 text-xs font-black text-gray-500 uppercase tracking-widest">{item.payoutMethod || item.method}</td>
                  <td className="px-10 py-6"><p className="text-sm font-black text-gray-900">${item.amount || item.netAmount || 0}</p>{item.fee > 0 && <p className="text-[10px] font-bold text-red-400 uppercase tracking-tighter">Fee: ${item.fee}</p>}</td>
                  <td className="px-10 py-6 text-right">
                    {item.status === "pending" ? (
                      <button onClick={() => financeService.approveWithdrawal(item.id, item.teacherName, item.amount || item.netAmount || 0)} className="px-4 py-2 bg-black text-white text-[10px] font-black uppercase tracking-widest rounded-full hover:bg-gray-800 transition-colors">{t.approveAndPay}</button>
                    ) : (
                      <span className="px-4 py-1.5 rounded-full text-[9px] font-black uppercase tracking-widest bg-green-50 text-green-600 border border-green-100">{t.settled}</span>
                    )}
                  </td>
                </tr>
              ))}
              {payouts.length === 0 && <tr><td colSpan={4} className="px-10 py-10 text-center text-sm font-bold text-gray-400">{t.noWithdrawals}</td></tr>}
            </tbody>
          </table>
        </div>
      </div>

      {/* Recent Sales + Expenses */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-8">
        <div className="bg-white rounded-[40px] border border-gray-100 shadow-sm overflow-hidden">
          <div className="p-8 border-b border-gray-50 flex justify-between items-center">
            <h3 className="text-sm font-black uppercase tracking-widest">{t.recentSales}</h3>
            <Search className="w-4 h-4 text-gray-300" />
          </div>
          <div className="overflow-x-auto max-h-[500px] overflow-y-auto">
            <table className="w-full text-left" dir={t.dir}>
              <tbody className="divide-y divide-gray-50">
                {transactions.map((tx) => {
                  const net = toNetRevenue(tx.amount || 0);
                  return (
                    <tr key={tx.id} className="hover:bg-gray-50/50 transition-colors">
                      <td className="px-8 py-5"><p className="text-sm font-black text-gray-900">{tx.studentName || "Student"}</p><p className="text-[10px] font-bold text-gray-400 uppercase tracking-tighter">{tx.courseName}</p><p className="text-[9px] text-gray-300 font-bold mt-0.5">{tx.teacherName}</p></td>
                      <td className="px-8 py-5 text-right"><p className="text-sm font-black text-gray-800">${(tx.amount||0).toFixed(2)} <span className="text-gray-300 text-[9px]">{t.gross}</span></p><p className="text-[10px] font-bold text-gray-500">{t.net}: ${net.toFixed(2)}</p><p className="text-[10px] font-bold text-amber-600">Teacher: +${(tx.teacherShare||0).toFixed(2)}</p></td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        </div>
        <div className="bg-white rounded-[40px] border border-gray-100 shadow-sm overflow-hidden">
          <div className="p-8 border-b border-gray-50 flex justify-between items-center">
            <h3 className="text-sm font-black uppercase tracking-widest">{t.operationalOutcomes}</h3>
            <Calendar className="w-4 h-4 text-gray-300" />
          </div>
          <div className="overflow-x-auto max-h-[500px] overflow-y-auto">
            <table className="w-full text-left" dir={t.dir}>
              <tbody className="divide-y divide-gray-50">
                {expenses.map((exp) => (
                  <tr key={exp.id} className="hover:bg-gray-50/50 transition-colors">
                    <td className="px-8 py-5"><p className="text-sm font-black text-gray-900">{exp.note}</p><p className="text-[10px] font-bold text-gray-400 uppercase tracking-tighter">{exp.date}</p></td>
                    <td className="px-8 py-5 text-right"><p className="text-sm font-black text-red-500">-${exp.amount}</p><p className="text-[10px] font-bold text-gray-400 uppercase tracking-widest">{exp.category}</p></td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      </div>

      {/* Add Expense Modal */}
      <AnimatePresence>
        {showAddExpense && (
          <div className="fixed inset-0 z-[100] flex items-center justify-center p-6">
            <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} onClick={() => setShowAddExpense(false)} className="absolute inset-0 bg-black/40 backdrop-blur-sm" />
            <motion.div initial={{ scale: 0.9, opacity: 0 }} animate={{ scale: 1, opacity: 1 }} exit={{ scale: 0.9, opacity: 0 }} className="relative w-full max-w-sm bg-white rounded-[40px] p-12 shadow-2xl border border-gray-100" dir={t.dir}>
              <h2 className="text-2xl font-black uppercase tracking-tighter mb-10">{t.modalRecordOutcome}</h2>
              <form onSubmit={handleAddExpense} className="space-y-6">
                <div><label className="text-[10px] font-black uppercase tracking-widest text-gray-400 block mb-3 px-1">{t.amountLabel}</label><input type="number" value={expAmount} onChange={(e) => setExpAmount(e.target.value)} placeholder="0.00" className="w-full px-8 py-5 bg-gray-50 border border-gray-100 rounded-2xl outline-none focus:bg-white focus:border-black transition-all font-black text-xl" required /></div>
                <div><label className="text-[10px] font-black uppercase tracking-widest text-gray-400 block mb-3 px-1">{t.noteLabel}</label><input type="text" value={expNote} onChange={(e) => setExpNote(e.target.value)} placeholder={t.notePlaceholder} className="w-full px-8 py-5 bg-gray-50 border border-gray-100 rounded-2xl outline-none focus:bg-white focus:border-black transition-all font-bold text-sm" required /></div>
                <div><label className="text-[10px] font-black uppercase tracking-widest text-gray-400 block mb-3 px-1">{t.dateLabel}</label><input type="date" value={expDate} onChange={(e) => setExpDate(e.target.value)} className="w-full px-8 py-5 bg-gray-50 border border-gray-100 rounded-2xl outline-none focus:bg-white focus:border-black transition-all font-bold text-sm" required /></div>
                <button type="submit" className="w-full py-6 bg-black text-white rounded-[28px] font-black uppercase tracking-[4px] text-xs shadow-xl shadow-black/20 hover:scale-[1.02] active:scale-[0.98] transition-all">{t.logOutcome}</button>
              </form>
            </motion.div>
          </div>
        )}
      </AnimatePresence>

      {/* Add Settlement Modal */}
      <AnimatePresence>
        {showAddSettlement && (
          <div className="fixed inset-0 z-[100] flex items-center justify-center p-6">
            <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} onClick={() => setShowAddSettlement(false)} className="absolute inset-0 bg-black/40 backdrop-blur-sm" />
            <motion.div initial={{ scale: 0.9, opacity: 0 }} animate={{ scale: 1, opacity: 1 }} exit={{ scale: 0.9, opacity: 0 }} className="relative w-full max-w-sm bg-white rounded-[40px] p-12 shadow-2xl border border-gray-100" dir={t.dir}>
              <h2 className="text-2xl font-black uppercase tracking-tighter mb-2">{t.modalLogSettlement}</h2>
              <p className="text-xs text-gray-400 font-bold mb-10">{t.settlementDesc}</p>
              <form onSubmit={handleAddSettlement} className="space-y-6">
                <div><label className="text-[10px] font-black uppercase tracking-widest text-gray-400 block mb-3 px-1">{t.dateReceivedLabel}</label><input type="date" value={setlDate} onChange={(e) => setSetlDate(e.target.value)} className="w-full px-8 py-5 bg-gray-50 border border-gray-100 rounded-2xl outline-none focus:bg-white focus:border-black transition-all font-bold text-sm" required /></div>
                <div><label className="text-[10px] font-black uppercase tracking-widest text-gray-400 block mb-3 px-1">{t.grossWiredLabel}</label><input type="number" step="0.01" value={setlGross} onChange={(e) => setSetlGross(e.target.value)} placeholder="0.00" className="w-full px-8 py-5 bg-gray-50 border border-gray-100 rounded-2xl outline-none focus:bg-white focus:border-black transition-all font-black text-xl" required /></div>
                <div><label className="text-[10px] font-black uppercase tracking-widest text-gray-400 block mb-3 px-1">{t.bankFeeLabel}</label><input type="number" step="0.01" value={setlBankFee} onChange={(e) => setSetlBankFee(e.target.value)} placeholder="0.00" className="w-full px-8 py-5 bg-gray-50 border border-gray-100 rounded-2xl outline-none focus:bg-white focus:border-black transition-all font-bold text-sm" /></div>
                {setlGross && (
                  <div className="bg-green-50 rounded-2xl px-6 py-4 border border-green-100">
                    <p className="text-[9px] font-black uppercase tracking-widest text-green-600 mb-1">{t.netCashLabel}</p>
                    <p className="text-2xl font-black text-green-700">${((parseFloat(setlGross)||0) - (parseFloat(setlBankFee)||0)).toFixed(2)}</p>
                  </div>
                )}
                <button type="submit" className="w-full py-6 bg-gray-900 text-white rounded-[28px] font-black uppercase tracking-[4px] text-xs shadow-xl shadow-black/20 hover:scale-[1.02] active:scale-[0.98] transition-all">{t.saveSettlement}</button>
              </form>
            </motion.div>
          </div>
        )}
      </AnimatePresence>
    </div>
  );
}
