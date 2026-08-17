const fs = require('fs');
const en = JSON.parse(fs.readFileSync('src/locales/en.json', 'utf8'));
const ar = JSON.parse(fs.readFileSync('src/locales/ar.json', 'utf8'));

en["teachers.view_profile"] = "View Profile";
ar["teachers.view_profile"] = "عرض الملف الشخصي";

fs.writeFileSync('src/locales/en.json', JSON.stringify(en, null, 2));
fs.writeFileSync('src/locales/ar.json', JSON.stringify(ar, null, 2));
