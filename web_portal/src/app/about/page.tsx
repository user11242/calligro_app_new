"use client";
import Navbar from "@/components/Navbar";
import Footer from "@/components/Footer";
import { motion } from "framer-motion";
import { useTranslation } from "@/hooks/useTranslation";
import Image from "next/image";
import { 
  Code2, 
  Cpu, 
  Globe, 
  Layers, 
  Rocket, 
  ShieldCheck, 
  Sparkles, 
  Users,
  Zap,
  GraduationCap,
  CreditCard,
  Briefcase
} from "lucide-react";

export default function AboutPage() {
  const { t } = useTranslation();

  const roadmapSteps = [
    {
      id: "01",
      title: t("about.roadmap.step1.title"),
      desc: t("about.roadmap.step1.desc"),
      icon: Code2,
      color: "from-blue-500/20 to-cyan-500/20"
    },
    {
      id: "02",
      title: t("about.roadmap.step2.title"),
      desc: t("about.roadmap.step2.desc"),
      icon: Globe,
      color: "from-purple-500/20 to-pink-500/20"
    },
    {
      id: "03",
      title: t("about.roadmap.step3.title"),
      desc: t("about.roadmap.step3.desc"),
      icon: Cpu,
      color: "from-amber-500/20 to-orange-500/20"
    },
    {
      id: "04",
      title: t("about.roadmap.step4.title"),
      desc: t("about.roadmap.step4.desc"),
      icon: Rocket,
      color: "from-emerald-500/20 to-teal-500/20"
    }
  ];

  return (
    <main className="academy-bg min-h-screen">
      <Navbar />

      {/* ═══════ Hero Section ═══════ */}
      <section className="relative pt-48 pb-32 px-6 overflow-hidden">
        <div className="max-w-7xl mx-auto text-center relative z-10">
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.8 }}
          >
            <span className="text-xs font-black text-primary uppercase tracking-[0.5em] mb-6 inline-block">
              {t("about.page.title")}
            </span>
            <h1 className="text-4xl md:text-6xl lg:text-8xl font-black font-outfit text-white tracking-tighter leading-none mb-10">
              {t("about.page.subtitle")}
            </h1>
          </motion.div>
        </div>

        {/* Abstract Background Glow */}
        <div className="absolute top-0 left-1/2 -translate-x-1/2 w-full h-full pointer-events-none overflow-hidden">
           <div className="absolute top-[10%] left-[10%] w-[500px] h-[500px] bg-primary/10 rounded-full blur-[120px] animate-pulse" />
           <div className="absolute bottom-[10%] right-[10%] w-[400px] h-[400px] bg-blue-500/5 rounded-full blur-[100px]" />
        </div>
      </section>

      {/* ═══════ CEO Profile Section ═══════ */}
      <section className="relative py-32 px-6 max-w-7xl mx-auto z-10">
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-20 items-center">
          <motion.div
            initial={{ opacity: 0, x: -50 }}
            whileInView={{ opacity: 1, x: 0 }}
            viewport={{ once: true }}
            transition={{ duration: 0.8 }}
            className="relative"
          >
            <div className="relative aspect-[4/5] rounded-[64px] overflow-hidden border border-white/10 shadow-2xl group">
               <Image 
                 src="/assets/images/yazan_ceo.jpeg" 
                 alt="Yazan Qattous - CEO"
                 fill
                 className="object-cover transition-transform duration-1000 group-hover:scale-105"
               />
               <div className="absolute inset-0 bg-gradient-to-t from-[#0a0a0a] via-transparent to-transparent" />
               <div className="absolute bottom-6 md:bottom-12 left-6 md:left-12">
                 <h2 className="text-2xl md:text-4xl font-black text-white font-outfit tracking-tight">{t("about.ceo.name")}</h2>
                 <p className="text-primary text-xs md:text-sm font-black uppercase tracking-widest">{t("about.ceo.role")}</p>
               </div>
            </div>
          </motion.div>

          <motion.div
            initial={{ opacity: 0, x: 50 }}
            whileInView={{ opacity: 1, x: 0 }}
            viewport={{ once: true }}
            transition={{ duration: 0.8 }}
            className="space-y-10"
          >
            <div>
              <span className="text-[10px] font-black text-primary uppercase tracking-[0.4em] mb-4 inline-block">
                {t("about.ceo.title")}
              </span>
              <h3 className="text-3xl md:text-5xl lg:text-6xl font-black font-outfit text-white leading-tight">
                {t("about.vision.title")}
              </h3>
            </div>
            
            <p className="text-xl text-white/60 leading-relaxed font-medium">
              {t("about.ceo.bio")}
            </p>

            <div className="grid grid-cols-2 gap-8 pt-8">
               <div className="space-y-4">
                  <div className="flex items-center gap-3 text-primary">
                     <Briefcase className="w-5 h-5" />
                     <span className="text-sm font-black uppercase tracking-widest">{t("about.features.multi_project")}</span>
                  </div>
                  <p className="text-white/40 text-sm">{t("about.features.multi_project_desc")}</p>
               </div>
               <div className="space-y-4">
                  <div className="flex items-center gap-3 text-primary">
                     <ShieldCheck className="w-5 h-5" />
                     <span className="text-sm font-black uppercase tracking-widest">{t("about.features.secure_payments")}</span>
                  </div>
                  <p className="text-white/40 text-sm">{t("about.features.secure_payments_desc")}</p>
               </div>
            </div>
          </motion.div>
        </div>
      </section>

      {/* ═══════ Vision Roadmap Section ═══════ */}
      <section className="relative py-40 px-6 overflow-hidden">
        <div className="max-w-7xl mx-auto z-10 relative">
          <div className="text-center mb-32">
            <h2 className="text-4xl md:text-6xl lg:text-8xl font-black font-outfit text-white tracking-tighter mb-6">
              {t("about.roadmap.title")}
            </h2>
            <div className="h-2 w-32 bg-primary mx-auto rounded-full blur-[2px]" />
          </div>

          <div className="relative grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-8">
            {/* Connecting Line (Desktop) */}
            <div className="absolute top-1/2 left-0 w-full h-[2px] bg-white/5 hidden lg:block -translate-y-1/2 z-0" />
            
            {roadmapSteps.map((step, idx) => (
              <motion.div
                key={idx}
                initial={{ opacity: 0, y: 50 }}
                whileInView={{ opacity: 1, y: 0 }}
                viewport={{ once: true }}
                transition={{ delay: idx * 0.2, duration: 0.8 }}
                whileHover={{ y: -20 }}
                className="group relative z-10"
              >
                <div className={`h-full glass-premium p-10 rounded-[48px] border border-white/10 bg-gradient-to-br ${step.color} backdrop-blur-3xl flex flex-col justify-between relative overflow-hidden`}>
                  {/* Step Number Badge */}
                  <div className="absolute top-6 right-8 text-sm font-black text-white/20 font-outfit">
                    {step.id}
                  </div>
                  
                  <div className="z-10">
                    <div className="w-16 h-16 rounded-3xl bg-[#0a0a0a] border border-white/10 flex items-center justify-center mb-10 group-hover:bg-primary group-hover:text-black transition-all shadow-xl">
                      <step.icon className="w-8 h-8" />
                    </div>
                    <h4 className="text-2xl font-black text-white mb-6 uppercase tracking-tight leading-tight">
                      {step.title}
                    </h4>
                    <p className="text-white/40 text-sm font-medium leading-relaxed">
                      {step.desc}
                    </p>
                  </div>
                  <div className="mt-12 z-10">
                     <div className="h-1 w-12 bg-white/10 rounded-full group-hover:w-full group-hover:bg-primary transition-all duration-700" />
                  </div>
                </div>
              </motion.div>
            ))}
          </div>
        </div>

        {/* Decorative Wave Background */}
        <div className="absolute bottom-0 left-0 w-full opacity-10 pointer-events-none">
           <svg viewBox="0 0 1440 320" xmlns="http://www.w3.org/2000/svg">
              <path fill="#EEE593" fillOpacity="1" d="M0,288L48,272C96,256,192,224,288,197.3C384,171,480,149,576,165.3C672,181,768,235,864,250.7C960,267,1056,245,1152,224C1248,203,1344,181,1392,170.7L1440,160L1440,320L1392,320C1344,320,1248,320,1152,320C1056,320,960,320,864,320C768,320,672,320,576,320C480,320,384,320,288,320C192,320,96,320,48,320L0,320Z"></path>
           </svg>
        </div>
      </section>

      <Footer />
    </main>
  );
}
