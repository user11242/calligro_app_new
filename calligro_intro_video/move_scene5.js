const fs = require('fs');
const file = '/Users/yazanqattous/Desktop/flutter_projects/calligro_app/calligro_intro_video/src/Intro.tsx';
let content = fs.readFileSync(file, 'utf8');

// 1. Update meetStageReveal
content = content.replace(
  'const meetStageReveal = interpolate(frame, [1120, 1160], [0, 1], {',
  'const meetStageReveal = interpolate(frame, [1120, 1160, 1950, 2000], [0, 1, 1, 0], {'
);

// 2. Extract SCENE 5
const scene5Start = `      {/* ═══════════════════════════════════════════════════════════════════════════════ */}
      {/* SCENE 5: THE EXACT FLUTTER TEACHER DASHBOARD (2000 - 2500)                    */}`;
const scene5EndStr = `        </div>
      )}
    </AbsoluteFill>
  );
};`;

const scene5StartIndex = content.indexOf(scene5Start);
const scene5EndIndex = content.lastIndexOf('      )}');

if (scene5StartIndex !== -1 && scene5EndIndex !== -1) {
  let scene5Block = content.substring(scene5StartIndex, scene5EndIndex + 8);
  
  // Change width/height to 100%
  scene5Block = scene5Block.replace(
    /width: 1080, height: 1920/g,
    "width: '100%', height: '100%'"
  );

  // Remove SCENE 5 from bottom
  content = content.substring(0, scene5StartIndex) + `    </AbsoluteFill>\n  );\n};\n`;

  // Insert SCENE 5 before </AbsoluteFill> (around line 3757)
  const insertMarker = `              )}
            </AbsoluteFill>`;
            
  content = content.replace(insertMarker, scene5Block + '\n' + insertMarker);
  
  fs.writeFileSync(file, content);
  console.log("Successfully moved SCENE 5 inside the Phone Shell and updated meetStageReveal!");
} else {
  console.log("Could not find SCENE 5 markers");
}
