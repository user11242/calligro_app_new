"use client";
import Navbar from "@/components/Navbar";
import Footer from "@/components/Footer";
import { motion } from "framer-motion";
import { RotateCcw, ShieldCheck, Mail, Clock, CheckCircle } from "lucide-react";
import { useTranslation } from "@/hooks/useTranslation";

export default function RefundPolicyPage() {
  const { locale } = useTranslation();
  const isAr = locale === "ar";
  const isTr = locale === "tr";

  return (
    <main className="academy-bg min-h-screen font-sans">
      <Navbar />

      <section className="pt-44 pb-24 px-6 max-w-4xl mx-auto">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          className="glass-premium p-8 md:p-16 rounded-[40px] border-white/5"
        >
          <div className="flex items-center gap-4 mb-8">
            <div className="w-12 h-12 rounded-2xl bg-primary/10 flex items-center justify-center">
              <RotateCcw className="w-6 h-6 text-primary" />
            </div>
            <div>
              <h1 className="text-3xl md:text-4xl font-black font-outfit gold-text">
                {isAr
                  ? "سياسة الإلغاء والاسترداد"
                  : isTr
                  ? "İptal ve İade Politikası"
                  : "Cancellation & Refund Policy"}
              </h1>
              <p className="text-[10px] font-black uppercase tracking-[3px] text-white/20 mt-1">
                {isAr ? "آخر تحديث: أكتوبر 2026" : isTr ? "Son Güncelleme: Ekim 2026" : "Last Updated: October 2026"}
              </p>
            </div>
          </div>

          <div className="space-y-10 text-white/70 leading-relaxed font-medium">
            {/* Overview Banner */}
            <div className="p-6 rounded-2xl bg-white/[0.02] border border-white/5 flex items-start gap-4">
              <ShieldCheck className="w-6 h-6 text-primary shrink-0 mt-1" />
              <p className="text-sm">
                {isAr
                  ? "في أكاديمية كاليغرو، نحن ملتزمون بتقديم أعلى مستويات التعليم الفني في الخط العربي. نوضح أدناه شروط ومعايير استرداد الرسوم لضمان الشفافية والعدالة لجميع طلابنا."
                  : isTr
                  ? "Calligro Akademi olarak hat sanatında en yüksek kalitede eğitim sunmayı taahhüt ediyoruz. Aşağıda tüm öğrencilerimiz için şeffaflık ve adillik sağlamak amacıyla iade koşullarımız yer almaktadır."
                  : "At Calligro Academy, we are dedicated to providing world-class Arabic calligraphy education. Below is our clear, fair cancellation and refund policy."}
              </p>
            </div>

            {/* Section 1 */}
            <section className="space-y-3">
              <h2 className="text-xl font-black font-outfit text-white uppercase tracking-wider flex items-center gap-2">
                <CheckCircle className="w-5 h-5 text-primary" />
                {isAr ? "1. أهلية الاسترداد (قبل بدء الدورة)" : isTr ? "1. İade Uygunluğu (Kurs Başlamadan Önce)" : "1. Refund Eligibility (Prior to Course Start)"}
              </h2>
              <p>
                {isAr
                  ? "يحق للطالب طلب استرداد كامل المبلغ المدفوع إذا تم تقديم الطلب قبل موعد الجلسة الأولى للدورة المسجلة. يتم خصم أي رسوم معالجة بنكية إن وجدت."
                  : isTr
                  ? "Öğrenci, kayıtlı kursun ilk canlı oturumu başlamadan önce talepte bulunması halinde ödediği tutarın tamamının iadesini talep etme hakkına sahiptir."
                  : "Students have the right to request a full refund of their course tuition if the request is submitted prior to the scheduled start date and time of the first live course session."}
              </p>
            </section>

            {/* Section 2 */}
            <section className="space-y-3">
              <h2 className="text-xl font-black font-outfit text-white uppercase tracking-wider flex items-center gap-2">
                <Clock className="w-5 h-5 text-primary" />
                {isAr ? "2. بدء الدورة وعدم قابلية الاسترداد" : isTr ? "2. Kursun Başlaması ve İade Edilemezlik" : "2. Commencement of Course & Non-Refundable Period"}
              </h2>
              <p>
                {isAr
                  ? "بمجرد بدء الجلسة الأولى للدورة، يسقط حق الطالب في المطالبة بأي استرداد مالي، سواء حضر الجلسات أو تعذر عليه الحضور، وذلك نظراً لحجز مقعد الطالب ومشاركة المواد التعليمية وجدول الأستاذ."
                  : isTr
                  ? "İlk canlı ders oturumu başladıktan sonra, öğrencinin oturumlara katılıp katılmadığına bakılmaksızın para iadesi hakkı sona erer."
                  : "Once the first course session has commenced, tuition fees become non-refundable regardless of attendance, as dedicated teacher schedules, live seats, and digital instructional materials are permanently allocated."}
              </p>
            </section>

            {/* Section 3 */}
            <section className="space-y-3">
              <h2 className="text-xl font-black font-outfit text-white uppercase tracking-wider flex items-center gap-2">
                <RotateCcw className="w-5 h-5 text-primary" />
                {isAr ? "3. آلية ومدة معالجة الاسترداد" : isTr ? "3. İade Süreci ve Süresi" : "3. Processing Method & Timelines"}
              </h2>
              <p>
                {isAr
                  ? "تتم معالجة المبالغ المستردة المعتمدة مباشرة إلى نفس وسيلة الدفع الأصلية (بطاقة الائتمان أو بوابة الدفع المستخدمة). يستغرق ظهور المبلغ في كشف حسابك البنكي عادة من 3 إلى 7 أيام عمل حسب البنك المصدر."
                  : isTr
                  ? "Onaylanan iadeler doğrudan ödemenin yapıldığı orijinal ödeme yöntemine (kredi kartı / banka) yansıtılır. İşlem süresi bankanıza bağlı olarak 3 ila 7 iş günüdür."
                  : "Approved refunds are credited directly back to the original payment method used during checkout. Depending on your issuing bank or payment provider, funds typically reflect in your account within 3 to 7 business days."}
              </p>
            </section>

            {/* Section 4 */}
            <section className="space-y-3">
              <h2 className="text-xl font-black font-outfit text-white uppercase tracking-wider flex items-center gap-2">
                <Mail className="w-5 h-5 text-primary" />
                {isAr ? "4. كيفية تقديم طلب الاسترداد" : isTr ? "4. İade Talebinde Bulunma" : "4. How to Request a Refund"}
              </h2>
              <p>
                {isAr
                  ? "لتقديم طلب استرداد، يرجى مراسلة فريق الدعم مع إرفاق رقم الطلب أو بريدك الإلكتروني المسجل:"
                  : isTr
                  ? "İade talebi oluşturmak için lütfen sipariş numaranız veya kayıtlı e-postanız ile birlikte destek ekibimize yazın:"
                  : "To submit a refund request, simply reach out to our dedicated support team with your order confirmation email or Student ID:"}
              </p>
            </section>

            {/* Contact Box */}
            <div className="pt-6 border-t border-white/5 space-y-4">
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <div className="glass p-5 rounded-2xl border-white/5">
                  <p className="text-[10px] text-white/30 uppercase font-black mb-1">
                    {isAr ? "البريد الإلكتروني للدعم" : isTr ? "Destek E-postası" : "Support Email"}
                  </p>
                  <a href="mailto:support@calligroacademy.com" className="text-sm font-bold text-primary hover:underline">
                    support@calligroacademy.com
                  </a>
                </div>
                <div className="glass p-5 rounded-2xl border-white/5">
                  <p className="text-[10px] text-white/30 uppercase font-black mb-1">
                    {isAr ? "زمن الاستجابة" : isTr ? "Yanıt Süresi" : "Response Time"}
                  </p>
                  <p className="text-sm font-bold text-white/80">
                    {isAr ? "خلال 24 ساعة" : isTr ? "24 saat içinde" : "Within 24 hours"}
                  </p>
                </div>
              </div>
            </div>
          </div>
        </motion.div>
      </section>

      <Footer />
    </main>
  );
}
