const fs = require('fs');

const newKeysEn = {
  "home.vision.title": "The Future of Calligraphy",
  "home.vision.desc": "Where we see Calligro heading in the next decade.",
  "home.vision.1.front": "A Global Digital University",
  "home.vision.1.reveal": "We envision Calligro as the world’s premier, fully accredited digital university for the art of Arabic calligraphy, crossing all physical borders.",
  "home.vision.2.front": "Smart AI Correction",
  "home.vision.2.reveal": "Integrating cutting-edge AI to provide instant, precise technical feedback on every pen stroke.",
  "home.vision.3.front": "A Unified Artistic Hub",
  "home.vision.3.reveal": "A single marketplace connecting the finest masters with thousands of students and collectors globally.",
  "home.vision.4.front": "Preserving The Tradition",
  "home.vision.4.reveal": "Merging ancient artistic traditions with modern technology to ensure this beautiful art form thrives for generations to come."
};

const newKeysAr = {
  "home.vision.title": "مستقبل الخط العربي",
  "home.vision.desc": "إلى أين تتجه كاليجرو في العقد القادم.",
  "home.vision.1.front": "جامعة رقمية عالمية",
  "home.vision.1.reveal": "نطمح أن تكون كاليجرو الجامعة الرقمية الأولى والمعتمدة عالمياً لفن الخط العربي، عابرة لجميع الحدود الجغرافية.",
  "home.vision.2.front": "تصحيح ذكي بالذكاء الاصطناعي",
  "home.vision.2.reveal": "دمج أحدث تقنيات الذكاء الاصطناعي لتقديم تعليقات فنية دقيقة وفورية على كل حركة قلم.",
  "home.vision.3.front": "مركز فني موحد",
  "home.vision.3.reveal": "سوق واحد يربط أمهر الأساتذة بآلاف الطلاب وهواة الجمع على مستوى العالم.",
  "home.vision.4.front": "الحفاظ على التراث",
  "home.vision.4.reveal": "دمج التقاليد الفنية العريقة مع التكنولوجيا الحديثة لضمان ازدهار هذا الفن الجميل للأجيال القادمة."
};

const newKeysTr = {
  "home.vision.title": "Hat Sanatının Geleceği",
  "home.vision.desc": "Önümüzdeki on yılda Calligro'nun nereye gittiğini görüyoruz.",
  "home.vision.1.front": "Küresel Dijital Üniversite",
  "home.vision.1.reveal": "Calligro'yu Arap hat sanatı için fiziksel sınırları aşan, dünyanın önde gelen, tam akredite dijital üniversitesi olarak hayal ediyoruz.",
  "home.vision.2.front": "Akıllı Yapay Zeka Düzeltmesi",
  "home.vision.2.reveal": "Her kalem darbesinde anında ve kesin teknik geri bildirim sağlamak için en son yapay zekayı entegre ediyoruz.",
  "home.vision.3.front": "Birleşik Sanat Merkezi",
  "home.vision.3.reveal": "En iyi ustaları küresel çapta binlerce öğrenci ve koleksiyoncuyla buluşturan tek bir pazar yeri.",
  "home.vision.4.front": "Geleneği Korumak",
  "home.vision.4.reveal": "Bu güzel sanat formunun gelecek nesiller için gelişmesini sağlamak amacıyla kadim sanatsal gelenekleri modern teknolojiyle birleştiriyoruz."
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

console.log("Vision locales updated!");
