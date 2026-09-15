const fs = require('fs');

const enFile = 'lib/l10n/app_en.arb';
const arFile = 'lib/l10n/app_ar.arb';
const trFile = 'lib/l10n/app_tr.arb';

const keysEn = {
  "bankTransferFeeNote": "Note: There may be transfer commissions applied by the banks themselves, not by Calligro."
};

const keysAr = {
  "bankTransferFeeNote": "ملاحظة: قد تكون هناك عمولات على التحويل البنكي يتم خصمها من قبل البنوك نفسها، وليس من كاليجرو."
};

const keysTr = {
  "bankTransferFeeNote": "Not: Banka transferlerinde bankaların kendileri tarafından uygulanan, Calligro'dan bağımsız komisyonlar olabilir."
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
