const fs = require('fs');

const newKeysEn = {
  "home.teachers.certified": "Certified Master",
  "home.teachers.students": "Students",
  "home.teachers.rating": "Rating",
  "home.cta.title": "Begin Your Journey",
  "home.cta.desc": "Join thousands of students mastering the art of Arabic calligraphy.",
  "home.cta.btn": "Create Free Account",
  "home.premium.title": "The Premium Experience",
  "home.premium.desc": "Scroll to explore the features that set Calligro apart from any other academy.",
  "home.features.video.title": "Interactive 4K Classrooms",
  "home.features.video.desc": "Join live sessions with multiple camera angles. Watch the master's pen strokes in crystal clear 4K resolution while interacting in real-time. Zoom in on the finest details.",
  "home.features.community.title": "Global Community",
  "home.features.community.desc": "Share your homework, get personalized video feedback from certified masters, and connect with thousands of calligraphy enthusiasts worldwide in our exclusive forums.",
  "home.features.certificates.title": "Verified Certificates",
  "home.features.certificates.desc": "Earn your traditional Ijazah (certificate) through our rigorous testing process. Each certificate is digitally verified and physically mailed to your doorstep.",
  "home.courses.bestseller": "Bestseller",
  "home.courses.weeks": "Weeks",
  "home.courses.lessons": "Lessons"
};

const newKeysAr = {
  "home.teachers.certified": "أستاذ معتمد",
  "home.teachers.students": "الطلاب",
  "home.teachers.rating": "التقييم",
  "home.cta.title": "ابدأ رحلتك",
  "home.cta.desc": "انضم إلى آلاف الطلاب الذين يتقنون فن الخط العربي.",
  "home.cta.btn": "إنشاء حساب مجاني",
  "home.premium.title": "التجربة المتميزة",
  "home.premium.desc": "مرر لاستكشاف الميزات التي تميز كاليجرو عن أي أكاديمية أخرى.",
  "home.features.video.title": "فصول دراسية تفاعلية 4K",
  "home.features.video.desc": "انضم إلى الجلسات المباشرة بزوايا تصوير متعددة. شاهد حركة القلم بدقة 4K عالية الوضوح مع التفاعل في الوقت الفعلي. قم بالتكبير على أدق التفاصيل.",
  "home.features.community.title": "مجتمع عالمي",
  "home.features.community.desc": "شارك واجباتك، واحصل على تقييمات فيديو مخصصة من أساتذة معتمدين، وتواصل مع آلاف عشاق الخط حول العالم في منتدياتنا الحصرية.",
  "home.features.certificates.title": "شهادات معتمدة",
  "home.features.certificates.desc": "احصل على إجازتك التقليدية من خلال عملية اختبار صارمة. يتم التحقق من كل شهادة رقمياً وإرسالها فعلياً إلى باب منزلك.",
  "home.courses.bestseller": "الأكثر مبيعاً",
  "home.courses.weeks": "أسابيع",
  "home.courses.lessons": "دروس"
};

const newKeysTr = {
  "home.teachers.certified": "Sertifikalı Usta",
  "home.teachers.students": "Öğrenciler",
  "home.teachers.rating": "Değerlendirme",
  "home.cta.title": "Yolculuğunuza Başlayın",
  "home.cta.desc": "Arap hat sanatında ustalaşan binlerce öğrenciye katılın.",
  "home.cta.btn": "Ücretsiz Hesap Oluştur",
  "home.premium.title": "Premium Deneyim",
  "home.premium.desc": "Calligro'yu diğer akademilerden ayıran özellikleri keşfetmek için kaydırın.",
  "home.features.video.title": "İnteraktif 4K Sınıflar",
  "home.features.video.desc": "Birden fazla kamera açısıyla canlı oturumlara katılın. Gerçek zamanlı etkileşimde bulunurken ustanın kalem darbelerini kristal netliğinde 4K çözünürlükte izleyin. En ince ayrıntılara yakınlaştırın.",
  "home.features.community.title": "Küresel Topluluk",
  "home.features.community.desc": "Ödevinizi paylaşın, sertifikalı ustalardan kişiselleştirilmiş video geri bildirimi alın ve özel forumlarımızda dünya çapında binlerce hat meraklısıyla bağlantı kurun.",
  "home.features.certificates.title": "Doğrulanmış Sertifikalar",
  "home.features.certificates.desc": "Zorlu test sürecimiz aracılığıyla geleneksel İcazet (sertifika) kazanın. Her sertifika dijital olarak doğrulanır ve fiziksel olarak kapınıza postalanır.",
  "home.courses.bestseller": "En Çok Satan",
  "home.courses.weeks": "Hafta",
  "home.courses.lessons": "Dersler"
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

console.log("Locales updated with phase 2 keys!");
