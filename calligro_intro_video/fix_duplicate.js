const fs = require('fs');
const file = '/Users/yazanqattous/Desktop/flutter_projects/calligro_app/calligro_intro_video/src/Intro.tsx';
let content = fs.readFileSync(file, 'utf8');

const lines = content.split('\n');
let exportCount = 0;
let truncateIndex = -1;

for (let i = 0; i < lines.length; i++) {
  if (lines[i].includes('export const Intro: React.FC = () => {')) {
    exportCount++;
    if (exportCount === 2) {
      // Find the start of the duplicate block (the comments before it)
      truncateIndex = i - 4; 
      break;
    }
  }
}

if (truncateIndex !== -1) {
  const fixedLines = lines.slice(0, truncateIndex);
  fs.writeFileSync(file, fixedLines.join('\n'));
  console.log("Truncated duplicate Intro!");
} else {
  console.log("Duplicate Intro not found.");
}
