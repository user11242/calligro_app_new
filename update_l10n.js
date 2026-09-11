const fs = require('fs');

const enFile = 'lib/l10n/app_en.arb';
const arFile = 'lib/l10n/app_ar.arb';
const trFile = 'lib/l10n/app_tr.arb';

const keysEn = {
  "salesHistory": "Sales History",
  "viewSalesHistory": "View Sales History",
  "noSalesYet": "No sales yet.",
  "saleBreakdown": "Sale Breakdown",
  "studentPaid": "Student Paid",
  "processingFee": "Processing Fee",
  "netRevenue": "Net Revenue",
  "yourCommission": "Your Commission",
  "sourceWebsite": "Website",
  "sourceApp": "Mobile App"
};

const keysAr = {
  "salesHistory": "سجل المبيعات",
  "viewSalesHistory": "عرض سجل المبيعات",
  "noSalesYet": "لا توجد مبيعات حتى الآن.",
  "saleBreakdown": "تفاصيل البيع",
  "studentPaid": "دفع الطالب",
  "processingFee": "رسوم المعالجة",
  "netRevenue": "صافي الإيرادات",
  "yourCommission": "عمولتك",
  "sourceWebsite": "الموقع الإلكتروني",
  "sourceApp": "التطبيق"
};

const keysTr = {
  "salesHistory": "Satış Geçmişi",
  "viewSalesHistory": "Satış Geçmişini Görüntüle",
  "noSalesYet": "Henüz satış yok.",
  "saleBreakdown": "Satış Detayı",
  "studentPaid": "Öğrenci Ödedi",
  "processingFee": "İşlem Ücreti",
  "netRevenue": "Net Gelir",
  "yourCommission": "Komisyonunuz",
  "sourceWebsite": "Web Sitesi",
  "sourceApp": "Mobil Uygulama"
};

function addKeys(file, keys) {
  let content = fs.readFileSync(file, 'utf8');
  let obj = JSON.parse(content);
  for (let key in keys) {
    obj[key] = keys[key];
  }
  fs.writeFileSync(file, JSON.stringify(obj, null, 2) + '\n');
}

addKeys(enFile, keysEn);
addKeys(arFile, keysAr);
addKeys(trFile, keysTr);

console.log("Updated arb files.");
