const fs = require('fs');
const file = '/Users/yazanqattous/Desktop/flutter_projects/calligro_app/calligro_intro_video/src/Intro.tsx';
let content = fs.readFileSync(file, 'utf8');

// 1. Fade out the Payment Scene
// The opacity line looks like: opacity: interpolate(frame, [1750, 1770], [0, 1], {extrapolateRight: 'clamp'}),
content = content.replace(
  "opacity: interpolate(frame, [1750, 1770], [0, 1], {extrapolateRight: 'clamp'}),",
  "opacity: interpolate(frame, [1750, 1770, 1980, 2000], [0, 1, 1, 0], {extrapolateRight: 'clamp'}),"
);

// 2. Append the Dashboard Scene
const dashboardScene = `
      {/* ═══════════════════════════════════════════════════════════════════════════════ */}
      {/* SCENE 5: THE TEACHER DASHBOARD (2000 - 2500)                                  */}
      {/* ═══════════════════════════════════════════════════════════════════════════════ */}
      {frame >= 1980 && (
        <div style={{
          position: 'absolute', inset: 0,
          background: '#121212',
          display: 'flex', flexDirection: 'column',
          alignItems: 'center',
          opacity: interpolate(frame, [1980, 2020], [0, 1], {extrapolateRight: 'clamp'}),
          zIndex: 600,
          paddingTop: 100*S,
          fontFamily: FONT_AR
        }}>
           
           <div style={{ width: 800*S, display: 'flex', flexDirection: 'column', gap: 40*S }}>
              
              {/* HEADER */}
              <div style={{ 
                 display: 'flex', justifyContent: 'space-between', alignItems: 'center',
                 transform: \`translateY(\${interpolate(spring({ frame: Math.max(0, frame - 2000), fps }), [0, 1], [50, 0])}px)\`,
                 opacity: interpolate(frame, [2000, 2020], [0, 1], {extrapolateRight: 'clamp'})
              }}>
                 {/* Notification Bell */}
                 <div style={{
                    width: 80*S, height: 80*S, borderRadius: 24*S,
                    background: '#1E1E1E',
                    boxShadow: '0 10px 20px rgba(0,0,0,0.5)',
                    display: 'flex', alignItems: 'center', justifyContent: 'center'
                 }}>
                    <span className="material-icons" style={{ color: '#FFF', fontSize: 40*S }}>notifications_none</span>
                 </div>

                 {/* Welcome Text & Avatar */}
                 <div style={{ display: 'flex', alignItems: 'center', gap: 20*S }}>
                    <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'flex-end' }}>
                       <span style={{ color: '#FFF', fontSize: 36*S, fontWeight: 'bold' }}>،مرحباً أستاذ</span>
                       <span style={{ color: 'rgba(255,255,255,0.5)', fontSize: 20*S }}>.لنقم بتدريس شيء جميل اليوم</span>
                    </div>
                    <div style={{
                       width: 100*S, height: 100*S, borderRadius: 50*S,
                       background: '#FFF',
                       boxShadow: '0 0 20px rgba(255,255,255,0.2)'
                    }} />
                 </div>
              </div>

              {/* STATS ROW (STAGGERED ANIMATION) */}
              <div style={{ display: 'flex', gap: 20*S, marginTop: 40*S }}>
                 
                 {/* Stat 1: Earnings (Pops in at 2090) */}
                 <div style={{
                    flex: 1, height: 200*S, borderRadius: 32*S,
                    background: 'linear-gradient(135deg, #1E1E1E, #2A2A2A)',
                    boxShadow: '0 20px 40px rgba(0,0,0,0.6)',
                    display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: 16*S,
                    transform: \`scale(\${spring({ frame: Math.max(0, frame - 2090), fps, config: { damping: 12 } })})\`,
                 }}>
                    <span className="material-icons" style={{ color: '#D4AF37', fontSize: 50*S }}>account_balance_wallet</span>
                    <span style={{ color: '#FFF', fontSize: 40*S, fontWeight: 'bold', fontFamily: FONT_BRAND }}>$24,500</span>
                    <span style={{ color: 'rgba(255,255,255,0.5)', fontSize: 20*S }}>الأرباح</span>
                 </div>

                 {/* Stat 2: Active Students (Pops in at 2070) */}
                 <div style={{
                    flex: 1, height: 200*S, borderRadius: 32*S,
                    background: 'linear-gradient(135deg, #1E1E1E, #2A2A2A)',
                    boxShadow: '0 20px 40px rgba(0,0,0,0.6)',
                    display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: 16*S,
                    transform: \`scale(\${spring({ frame: Math.max(0, frame - 2070), fps, config: { damping: 12 } })})\`,
                 }}>
                    <span className="material-icons" style={{ color: '#D4AF37', fontSize: 50*S }}>groups</span>
                    <span style={{ color: '#FFF', fontSize: 40*S, fontWeight: 'bold', fontFamily: FONT_BRAND }}>342</span>
                    <span style={{ color: 'rgba(255,255,255,0.5)', fontSize: 20*S }}>الطلاب النشطون</span>
                 </div>

                 {/* Stat 3: Active Courses (Pops in at 2050) */}
                 <div style={{
                    flex: 1, height: 200*S, borderRadius: 32*S,
                    background: 'linear-gradient(135deg, #1E1E1E, #2A2A2A)',
                    boxShadow: '0 20px 40px rgba(0,0,0,0.6)',
                    display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: 16*S,
                    transform: \`scale(\${spring({ frame: Math.max(0, frame - 2050), fps, config: { damping: 12 } })})\`,
                 }}>
                    <span className="material-icons" style={{ color: '#D4AF37', fontSize: 50*S }}>assignment_ind</span>
                    <span style={{ color: '#FFF', fontSize: 40*S, fontWeight: 'bold', fontFamily: FONT_BRAND }}>12</span>
                    <span style={{ color: 'rgba(255,255,255,0.5)', fontSize: 20*S }}>الدورات النشطة</span>
                 </div>
              </div>

           </div>
           
           {/* Success Text Overlay */}
           <div style={{ position: 'absolute', bottom: '15%', display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 16*S }}>
              <span style={{ 
                 color: '#FFF', fontSize: 32*S, fontFamily: FONT_AR, fontWeight: 'bold', filter: 'drop-shadow(0 4px 10px rgba(0,0,0,0.5))',
                 transform: \`translateY(\${interpolate(spring({ frame: Math.max(0, frame - 2120), fps }), [0, 1], [50, 0])}px)\`,
                 opacity: interpolate(frame, [2120, 2140], [0, 1], {extrapolateRight: 'clamp'})
              }}>شاهد أرباحك وطلابك ينمون</span>
              <span style={{ 
                 color: '#D4AF37', fontSize: 20*S, fontFamily: FONT_AR, fontWeight: 'bold',
                 background: 'linear-gradient(135deg, rgba(212, 175, 55, 0.2), rgba(212, 175, 55, 0.05))', 
                 padding: \`12px \${30*S}px\`, borderRadius: 24*S, border: '1px solid rgba(212, 175, 55, 0.4)',
                 backdropFilter: 'blur(10px)', WebkitBackdropFilter: 'blur(10px)',
                 transform: \`scale(\${interpolate(spring({ frame: Math.max(0, frame - 2150), fps, config: { damping: 8, stiffness: 300 } }), [0, 1], [2, 1])})\`,
                 opacity: frame >= 2150 ? 1 : 0
              }}>لوحة تحكم متكاملة للمعلمين</span>
           </div>

        </div>
      )}
`;

const insertIndex = content.lastIndexOf('    </AbsoluteFill>');
if (insertIndex !== -1) {
  content = content.substring(0, insertIndex) + dashboardScene + content.substring(insertIndex);
  fs.writeFileSync(file, content);
  console.log("Teacher Dashboard Scene appended successfully!");
} else {
  console.log("Failed to find end of AbsoluteFill");
}
