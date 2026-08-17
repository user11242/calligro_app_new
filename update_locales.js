const fs = require('fs');

const newKeysEn = {
  "home.stats.title": "A Legacy of Excellence",
  "home.stats.desc": "Join a thriving global ecosystem dedicated to preserving and mastering the ancient art of Arabic calligraphy.",
  "home.stats.students.label": "Active Students",
  "home.stats.students.value": "10,000+",
  "home.stats.students.desc": "From over 50 countries around the world.",
  "home.stats.classes.label": "Masterclasses",
  "home.stats.classes.value": "50+",
  "home.stats.classes.desc": "Filmed in breathtaking 4K resolution.",
  "home.stats.rating.label": "Average Rating",
  "home.stats.rating.value": "4.9/5",
  "home.stats.rating.desc": "Based on 2,000+ verified student reviews.",
  "home.stats.masters.label": "Certified Masters",
  "home.stats.masters.value": "20+",
  "home.stats.masters.desc": "World-renowned calligraphy experts.",
  
  "home.courses.title": "Masterclasses",
  "home.courses.subtitle": "Expand to explore",
  "home.courses.view_all": "View All",
  "home.courses.loading": "Loading masterpieces...",
  
  "home.why.title": "Why Calligro?",
  "home.why.subtitle": "The Future of Calligraphy",
  "home.why.desc": "Experience a revolutionary way to master the art of Arabic calligraphy.",
  
  "home.teachers.title": "Meet The Masters",
  "home.teachers.subtitle": "Swipe to explore"
};

const newKeysAr = {
  "home.stats.title": "إرث من التميز",
  "home.stats.desc": "انضم إلى نظام بيئي عالمي مزدهر مكرس للحفاظ على فن الخط العربي القديم وإتقانه.",
  "home.stats.students.label": "الطلاب النشطين",
  "home.stats.students.value": "10,000+",
  "home.stats.students.desc": "من أكثر من 50 دولة حول العالم.",
  "home.stats.classes.label": "دورات احترافية",
  "home.stats.classes.value": "50+",
  "home.stats.classes.desc": "مصورة بدقة 4K المذهلة.",
  "home.stats.rating.label": "متوسط التقييم",
  "home.stats.rating.value": "4.9/5",
  "home.stats.rating.desc": "بناءً على أكثر من 2,000 مراجعة من الطلاب.",
  "home.stats.masters.label": "أساتذة معتمدون",
  "home.stats.masters.value": "20+",
  "home.stats.masters.desc": "خبراء خط مشهورون عالمياً.",
  
  "home.courses.title": "الدورات الاحترافية",
  "home.courses.subtitle": "توسّع للاستكشاف",
  "home.courses.view_all": "عرض الكل",
  "home.courses.loading": "جاري تحميل التحف الفنية...",
  
  "home.why.title": "لماذا كاليجرو؟",
  "home.why.subtitle": "مستقبل الخط العربي",
  "home.why.desc": "استمتع بطريقة ثورية لإتقان فن الخط العربي.",
  
  "home.teachers.title": "تعرّف على الأساتذة",
  "home.teachers.subtitle": "اسحب للاستكشاف"
};

const newKeysTr = {
  "home.stats.title": "Mükemmellik Mirası",
  "home.stats.desc": "Kadim Arap hat sanatını korumaya ve ustalaşmaya adanmış küresel bir ekosisteme katılın.",
  "home.stats.students.label": "Aktif Öğrenciler",
  "home.stats.students.value": "10,000+",
  "home.stats.students.desc": "Dünya çapında 50'den fazla ülkeden.",
  "home.stats.classes.label": "Ustalık Sınıfları",
  "home.stats.classes.value": "50+",
  "home.stats.classes.desc": "Nefes kesici 4K çözünürlükte çekildi.",
  "home.stats.rating.label": "Ortalama Puan",
  "home.stats.rating.value": "4.9/5",
  "home.stats.rating.desc": "2.000'den fazla doğrulanmış öğrenci incelemesine göre.",
  "home.stats.masters.label": "Sertifikalı Ustalar",
  "home.stats.masters.value": "20+",
  "home.stats.masters.desc": "Dünyaca ünlü hat uzmanları.",
  
  "home.courses.title": "Ustalık Sınıfları",
  "home.courses.subtitle": "Keşfetmek için genişletin",
  "home.courses.view_all": "Hepsini Gör",
  "home.courses.loading": "Başyapıtlar yükleniyor...",
  
  "home.why.title": "Neden Calligro?",
  "home.why.subtitle": "Hat Sanatının Geleceği",
  "home.why.desc": "Arap hat sanatında ustalaşmanın devrim niteliğinde bir yolunu deneyimleyin.",
  
  "home.teachers.title": "Ustalarla Tanışın",
  "home.teachers.subtitle": "Keşfetmek için kaydırın"
};

const updateFile = (filename, newKeys) => {
  const content = fs.readFileSync(filename, 'utf8');
  const json = JSON.parse(content);
  Object.assign(json, newKeys);
  fs.writeFileSync(filename, JSON.stringify(json, null, 2));
};

updateFile('web_portal/src/locales/en.json', newKeysEn);
updateFile('web_portal/src/locales/ar.json', newKeysAr);
updateFile('web_portal/src/locales/tr.json', newKeysTr);

console.log("Locales updated!");
