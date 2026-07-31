const fs = require('fs');
const file = '/Users/yazanqattous/Desktop/flutter_projects/calligro_app/calligro_intro_video/src/Intro.tsx';
let content = fs.readFileSync(file, 'utf8');

// The file should end at line 1884.
const lines = content.split('\n');
const fixedLines = lines.slice(0, 1885); // keep 0 to 1884
fs.writeFileSync(file, fixedLines.join('\n'));
console.log("File truncated successfully.");
