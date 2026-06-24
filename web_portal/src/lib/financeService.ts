import { db, auth } from "./firebase";
import { 
  collection, 
  query, 
  orderBy, 
  onSnapshot, 
  addDoc, 
  updateDoc, 
  deleteDoc,
  doc, 
  where,
  Timestamp,
  serverTimestamp 
} from "firebase/firestore";

export interface Transaction {
  id: string;
  amount: number;
  teacherShare: number;
  teacherId: string;
  teacherName: string;
  courseName: string;
  studentName: string;
  createdAt: any;
  status: string;
}

export interface Order {
  id: string; // Transaction ID
  uid: string;
  studentName: string;
  studentEmail: string;
  courseId: string;
  courseName: string;
  courseArabicName: string;
  teacherId: string;
  teacherName: string;
  productId: string;
  transactionId: string;
  price: number;
  timestamp: any;
  environment: string;
}

export interface Expense {
  id: string;
  amount: number;
  note: string;
  date: string;
  category: string;
  createdAt: any;
}

export interface Teacher {
  uid: string;
  name: string;
  email: string;
  commissionRate?: number; // 0.6 or 0.8
  photoUrl?: string;
}

class FinanceService {
  // --- INCOME (Legacy Transactions) ---
  getTransactions(callback: (txs: Transaction[]) => void) {
    const q = query(collection(db, "transactions"), orderBy("createdAt", "desc"));
    return onSnapshot(q, (snapshot) => {
      const txs = snapshot.docs.map(doc => ({
        id: doc.id,
        ...doc.data()
      })) as Transaction[];
      callback(txs);
    });
  }

  // --- PREMIUM ORDERS (New Audit Trail) ---
  getOrders(callback: (orders: Order[]) => void) {
    const q = query(collection(db, "orders"), orderBy("timestamp", "desc"));
    return onSnapshot(q, (snapshot) => {
      const orders = snapshot.docs.map(doc => ({
        id: doc.id,
        ...doc.data()
      })) as Order[];
      callback(orders);
    }, (error) => {
      console.error("Error fetching orders:", error);
      callback([]);
    });
  }

  // --- OUTCOME (Expenses + Payouts) ---
  getExpenses(callback: (expenses: Expense[]) => void) {
    const q = query(collection(db, "admin_expenses"), orderBy("date", "desc"));
    return onSnapshot(q, (snapshot) => {
      const expenses = snapshot.docs.map(doc => ({
        id: doc.id,
        ...doc.data()
      })) as Expense[];
      callback(expenses);
    });
  }

  async addExpense(amount: number, note: string, date: string, category: string = "general") {
    return await addDoc(collection(db, "admin_expenses"), {
      amount,
      note,
      date,
      category,
      createdAt: serverTimestamp()
    });
  }

  getPayouts(callback: (payouts: any[]) => void) {
    const q = query(collection(db, "withdrawal_requests"), orderBy("createdAt", "desc"));
    return onSnapshot(q, (snapshot) => {
      const payouts = snapshot.docs.map(doc => ({
        id: doc.id,
        ...doc.data()
      }));
      callback(payouts);
    });
  }

  async approveWithdrawal(payoutId: string, teacherName: string, amount: number) {
    const payoutRef = doc(db, "withdrawal_requests", payoutId);
    
    // 1. Mark as completed
    await updateDoc(payoutRef, {
      status: "completed",
      updatedAt: serverTimestamp()
    });

    // 2. Log as an admin expense to keep accounting accurate
    await this.addExpense(
      amount,
      `Payout to ${teacherName}`,
      new Date().toISOString().split("T")[0],
      "payout"
    );
  }

  // --- TEACHER TIERS ---
  getTeachers(callback: (teachers: Teacher[]) => void) {
    const q = query(collection(db, "users"), where("role", "==", "teacher"));
    return onSnapshot(q, (snapshot) => {
      const teachers = snapshot.docs.map(doc => ({
        uid: doc.id,
        ...doc.data()
      })) as Teacher[];
      callback(teachers);
    });
  }

  async setTeacherCommission(uid: string, rate: number) {
    const userRef = doc(db, "users", uid);
    return await updateDoc(userRef, {
      commissionRate: rate,
      updatedAt: serverTimestamp()
    });
  }

  // --- GLOBAL COUNTS FOR DASHBOARD ---
  getGlobalCounts(callback: (counts: { students: number, courses: number }) => void) {
    const studentsQuery = query(collection(db, "users"), where("role", "==", "student"));
    const coursesQuery = collection(db, "courses");

    const unsubStudents = onSnapshot(studentsQuery, (sSnap) => {
      onSnapshot(coursesQuery, (cSnap) => {
        callback({
          students: sSnap.docs.length,
          courses: cSnap.docs.length
        });
      });
    });

    return unsubStudents;
  }

  // --- USER DIRECTORY ---
  getUsers(callback: (users: any[]) => void) {
    const q = query(collection(db, "users"), orderBy("createdAt", "desc"));
    return onSnapshot(q, (snapshot) => {
      const users = snapshot.docs.map(doc => ({
        uid: doc.id,
        ...doc.data()
      }));
      callback(users);
    });
  }

  // --- PILLAR 5: AUDIT TRAIL ---
  getAdminLogs(callback: (logs: any[]) => void) {
    const q = query(collection(db, "admin_logs"), orderBy("timestamp", "desc"));
    return onSnapshot(q, (snapshot) => {
      const logs = snapshot.docs.map(doc => ({
        id: doc.id,
        ...doc.data()
      }));
      callback(logs);
    });
  }

  async logAdminAction(action: string, details: string) {
    return await addDoc(collection(db, "admin_logs"), {
      action,
      details,
      adminId: auth.currentUser?.uid,
      adminEmail: auth.currentUser?.email,
      timestamp: serverTimestamp()
    });
  }

  // --- CHART DATA: REVENUE OVER TIME ---
  getRevenueHistory(callback: (data: any[]) => void) {
    const q = query(collection(db, "transactions"), orderBy("createdAt", "asc"));
    return onSnapshot(q, (snapshot) => {
      const monthlyData: { [key: string]: number } = {};
      
      snapshot.docs.forEach(doc => {
        const data = doc.data();
        if (!data.createdAt) return;
        
        const date = data.createdAt.toDate ? data.createdAt.toDate() : new Date();
        const month = date.toLocaleString('en-US', { month: 'short' });
        
        monthlyData[month] = (monthlyData[month] || 0) + (data.amount || 0);
      });

      const chartData = Object.entries(monthlyData).map(([name, revenue]) => ({
        name,
        revenue
      }));
      
      callback(chartData);
    });
  }

  // --- PILLAR 3: COURSE-BASED PAYOUT READINESS ---
  getPayoutEligibility(callback: (eligibility: any[]) => void) {
    const q = collection(db, "courses");
    return onSnapshot(q, (snapshot) => {
      const eligibility = snapshot.docs.map(doc => {
        const data = doc.data();
        const endDate = data.expiryDate?.toDate ? data.expiryDate.toDate() : 
                        data.createdAt?.toDate ? new Date(data.createdAt.toDate().getTime() + 30 * 24 * 60 * 60 * 1000) : 
                        new Date();
        
        const payoutDate = new Date(endDate.getTime() + 2 * 24 * 60 * 60 * 1000);
        const now = new Date();
        
        let status = "ongoing";
        if (now >= endDate && now < payoutDate) status = "processing";
        if (now >= payoutDate) status = "ready";

        return {
          id: doc.id,
          courseName: data.title || data.courseName || "Untitled Course",
          teacherName: data.teacherName || "Academy Teacher",
          endDate: endDate.toLocaleDateString(),
          payoutDate: payoutDate.toLocaleDateString(),
          status
        };
      });
      callback(eligibility);
    });
  }

  // --- FLEXIBLE NOTES SYSTEM ---
  getNotes(callback: (notes: any[]) => void) {
    const q = query(collection(db, "admin_notes")); // Removed orderBy to avoid index requirement for small sets
    return onSnapshot(q, (snapshot) => {
      const notes = snapshot.docs.map(doc => ({
        id: doc.id,
        ...doc.data()
      })).sort((a: any, b: any) => {
        const timeA = a.createdAt?.toMillis ? a.createdAt.toMillis() : 0;
        const timeB = b.createdAt?.toMillis ? b.createdAt.toMillis() : 0;
        return timeB - timeA;
      });
      callback(notes);
    }, (error) => {
      console.error("Firestore error in getNotes:", error);
      callback([]); // Ensure the spinner stops even on error
    });
  }

  async addNote(content: string) {
    try {
      const user = auth.currentUser;
      const noteData = {
        content,
        authorName: user?.displayName || "Admin",
        authorId: user?.uid,
        createdAt: Timestamp.now()
      };
      await addDoc(collection(db, "admin_notes"), noteData);
      await this.logAdminAction("Added Note", content.substring(0, 50));
    } catch (e) {
      console.error("Error adding note to Firestore:", e);
      throw e; // Rethrow to let the UI know it failed
    }
  }

  async deleteNote(noteId: string) {
    try {
      await deleteDoc(doc(db, "admin_notes", noteId));
      await this.logAdminAction("Deleted Note", `Note ID: ${noteId}`);
    } catch (e) {
      console.error("Error deleting note:", e);
    }
  }

  async updateNote(noteId: string, content: string) {
    try {
      const noteRef = doc(db, "admin_notes", noteId);
      await updateDoc(noteRef, {
        content,
        updatedAt: serverTimestamp()
      });
      await this.logAdminAction("Updated Note", content.substring(0, 50));
    } catch (e) {
      console.error("Error updating note:", e);
    }
  }

  // --- PILLAR 4: ADVANCED COURSE ANALYTICS ---
  getCourseAnalytics(callback: (analytics: any[]) => void) {
    const coursesRef = collection(db, "courses");
    const transactionsRef = collection(db, "transactions");

    return onSnapshot(coursesRef, (courseSnap) => {
      onSnapshot(transactionsRef, (txSnap) => {
        const txs = txSnap.docs.map(d => d.data());
        const analytics = courseSnap.docs.map(doc => {
          const course = doc.data();
          const cid = doc.id;
          
          // Filter transactions for this course
          const courseTxs = txs.filter(tx => tx.courseId === cid);
          const gross = courseTxs.reduce((sum, tx) => sum + (tx.amount || 0), 0);
          const teacherShare = courseTxs.reduce((sum, tx) => sum + (tx.teacherShare || 0), 0);
          const taxes = gross * 0.05; // 5% Standard Tax
          const academyNet = gross - teacherShare - taxes;

          const students = course.students || course.enrolledStudents || [];
          const currentEnrollment = Array.isArray(students) ? students.length : (typeof students === 'number' ? students : 0);
          const maxStudents = course.maxStudents || 0;

          return {
            id: cid,
            title: course.title || course.courseName || "Untitled Course",
            teacherName: course.teacherName || "Unassigned",
            currentEnrollment,
            maxStudents,
            gross,
            teacherShare,
            taxes,
            academyNet,
            enrollmentRate: maxStudents > 0 ? (currentEnrollment / maxStudents) * 100 : 0
          };
        });
        
        callback(analytics);
      });
    });
  }
}

export const financeService = new FinanceService();
