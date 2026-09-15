const fs = require('fs');

const enFile = 'lib/l10n/app_en.arb';
const arFile = 'lib/l10n/app_ar.arb';
const trFile = 'lib/l10n/app_tr.arb';

const keysEn = {
  "bankTransferFeeNote": "Note: Any transfer commissions are deducted by the banks themselves, not by Calligro."
};

const keysAr = {
  "bankTransferFeeNote": "ملاحظة: هذه العمولات ليست من كاليجرو، بل يتم خصمها من قبل البنوك العالمية نفسها."
};

const keysTr = {
  "bankTransferFeeNote": "Not: Transfer komisyonları Calligro tarafından değil, bankaların kendileri tarafından kesilir."
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
