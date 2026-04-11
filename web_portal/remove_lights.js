const fs = require('fs');
const path = require('path');

function walk(dir, callback) {
    fs.readdirSync(dir).forEach(f => {
        let dirPath = path.join(dir, f);
        let isDirectory = fs.statSync(dirPath).isDirectory();
        isDirectory ? walk(dirPath, callback) : callback(path.join(dir, f));
    });
}
walk('src', (filePath) => {
    if(filePath.endsWith('.tsx') || filePath.endsWith('.css')) {
        let content = fs.readFileSync(filePath, 'utf8');
        let newContent = content
            .replace(/\bdrop-shadow-\[.*?\]\b/g, '')
            .replace(/\bdrop-shadow(-lg|-md|-sm|-xl|-2xl)?\b/g, '')
            .replace(/\bshadow-\[0_0_[^\]]+\]\b/g, '')
            .replace(/(?<!backdrop-)\bblur-\[\d+px\]\b/g, '')
            .replace(/\bgold-glow\b/g, '')
            .replace(/\banimate-(pulse|bounce-slow)\b/g, '')
            .replace(/\bbg-\[radial-gradient[^\]]+\]\b/g, ''); // Also remove inline radial gradients
            
        fs.writeFileSync(filePath, newContent);
    }
});
console.log("Lights stripped.");
