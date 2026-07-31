const fs = require('fs');
const file = '/Users/yazanqattous/Desktop/flutter_projects/calligro_app/calligro_intro_video/src/Intro.tsx';
let content = fs.readFileSync(file, 'utf8');

const target1 = `opacity: frame >= 1170 && frame < 1230 ? 1 : interpolate(frame, [1230, 1235], [1, 0], {extrapolateRight: 'clamp'}),`;
const replace1 = `opacity: frame < 1170 ? 0 : frame < 1230 ? 1 : interpolate(frame, [1230, 1235], [1, 0], {extrapolateRight: 'clamp', extrapolateLeft: 'clamp'}),`;

const target2 = `opacity: frame >= 1235 && frame < 1290 ? 1 : interpolate(frame, [1290, 1295], [1, 0], {extrapolateRight: 'clamp'}),`;
const replace2 = `opacity: frame < 1235 ? 0 : frame < 1290 ? 1 : interpolate(frame, [1290, 1295], [1, 0], {extrapolateRight: 'clamp', extrapolateLeft: 'clamp'}),`;

const target3 = `opacity: frame >= 1295 && frame < 1350 ? 1 : interpolate(frame, [1350, 1355], [1, 0], {extrapolateRight: 'clamp'}),`;
const replace3 = `opacity: frame < 1295 ? 0 : frame < 1350 ? 1 : interpolate(frame, [1350, 1355], [1, 0], {extrapolateRight: 'clamp', extrapolateLeft: 'clamp'}),`;

const target4 = `opacity: frame >= 1355 ? 1 : 0,`; // wait, what did I write for phase 4?
// Let's check my previous script:
// opacity: frame >= 1355 ? 1 : 0,

content = content.replace(target1, replace1);
content = content.replace(target2, replace2);
content = content.replace(target3, replace3);

fs.writeFileSync(file, content);
console.log("Opacities fixed!");
