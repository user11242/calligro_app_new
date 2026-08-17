const fs = require('fs');
const en = JSON.parse(fs.readFileSync('src/locales/en.json', 'utf8'));
const ar = JSON.parse(fs.readFileSync('src/locales/ar.json', 'utf8'));

en["teachers.available_courses"] = "Available Courses";
ar["teachers.available_courses"] = "الدورات المتاحة";

fs.writeFileSync('src/locales/en.json', JSON.stringify(en, null, 2));
fs.writeFileSync('src/locales/ar.json', JSON.stringify(ar, null, 2));
