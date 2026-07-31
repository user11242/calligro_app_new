const fs = require('fs');
const file = '/Users/yazanqattous/Desktop/flutter_projects/calligro_app/calligro_intro_video/src/Intro.tsx';
let content = fs.readFileSync(file, 'utf8');

const startMarker = `      {/* ═══════════════════════════════════════════════════════════════════════════════ */}
      {/* SCENE 5: THE EXACT FLUTTER TEACHER DASHBOARD (2000 - 2500)                    */}`;
const endMarker = `    </AbsoluteFill>`;

const startIndex = content.indexOf(startMarker);
const endIndex = content.lastIndexOf(endMarker);

if (startIndex !== -1 && endIndex !== -1) {
  const newDashboardScene = `      {/* ═══════════════════════════════════════════════════════════════════════════════ */}
      {/* SCENE 5: THE EXACT FLUTTER TEACHER DASHBOARD (2000 - 2500)                    */}
      {/* ═══════════════════════════════════════════════════════════════════════════════ */}
      {frame >= 1980 && (
        <div style={{
          position: 'absolute', inset: 0,
          background: '#1E1E1E', 
          display: 'flex', flexDirection: 'column',
          alignItems: 'center',
          opacity: interpolate(frame, [1980, 2020], [0, 1], {extrapolateRight: 'clamp'}),
          zIndex: 600,
          fontFamily: FONT_AR,
          color: '#FFF'
        }}>
           
           <div style={{ width: 1080, height: 1920, position: 'relative', display: 'flex', flexDirection: 'column' }}>
              
              {/* STATUS BAR (PHONE LAYOUT) */}
              <div style={{
                 height: 120, width: '100%', display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '0 80px',
                 paddingTop: 30, zIndex: 100
              }}>
                 <span style={{ color: '#FFF', fontSize: 35, fontWeight: 'bold' }}>12:30</span>
                 {/* Dynamic Island */}
                 <div style={{ width: 300, height: 80, background: '#000', borderRadius: 40, marginTop: -20 }}></div>
                 <div style={{ display: 'flex', alignItems: 'center', gap: 15 }}>
                    <span className="material-icons" style={{ color: '#FFF', fontSize: 35 }}>signal_cellular_4_bar</span>
                    <span className="material-icons" style={{ color: '#FFF', fontSize: 35 }}>wifi</span>
                    <span className="material-icons" style={{ color: '#FFF', fontSize: 35 }}>battery_full</span>
                 </div>
              </div>

              {/* MAIN CONTENT AREA */}
              <div style={{ paddingLeft: 40, paddingRight: 40, flex: 1, display: 'flex', flexDirection: 'column' }}>
                 
                 {/* HEADER (Notification, Greeting, Avatar) */}
                 <div style={{ 
                    display: 'flex', justifyContent: 'space-between', alignItems: 'center', width: '100%', marginTop: 20,
                    transform: \`translateY(\${interpolate(spring({ frame: Math.max(0, frame - 2000), fps }), [0, 1], [50, 0])}px)\`,
                    opacity: interpolate(frame, [2000, 2020], [0, 1], {extrapolateRight: 'clamp'})
                 }}>
                    {/* Notification Bell (Left) */}
                    <div style={{
                       width: 100, height: 100, borderRadius: 30,
                       background: '#2A2A2A',
                       display: 'flex', alignItems: 'center', justifyContent: 'center'
                    }}>
                       <span className="material-icons" style={{ color: '#FFF', fontSize: 50 }}>notifications_none</span>
                    </div>

                    {/* Welcome Text & Avatar (Right) */}
                    <div style={{ display: 'flex', alignItems: 'center', gap: 30 }}>
                       <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'flex-end', gap: 5 }}>
                          <span style={{ color: '#FFF', fontSize: 50, fontWeight: 'bold' }}>مرحباً، sd fsd</span>
                          <span style={{ color: '#999', fontSize: 30 }}>.لنقم بتدريس شيء جميل اليوم</span>
                       </div>
                       <div style={{
                          width: 120, height: 120, borderRadius: 60,
                          background: '#FFF'
                       }} />
                    </div>
                 </div>

                 {/* STATS ROW (STAGGERED ANIMATION) */}
                 <div style={{ display: 'flex', gap: 30, marginTop: 80, width: '100%' }}>
                    
                    {/* Stat 1: Earnings (Left) */}
                    <div style={{
                       flex: 1, height: 350, borderRadius: 40,
                       background: '#2A2A2A',
                       display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: 20,
                       transform: \`scale(\${spring({ frame: Math.max(0, frame - 2090), fps, config: { damping: 12 } })})\`,
                    }}>
                       <span className="material-icons" style={{ color: '#D4AF37', fontSize: 80 }}>account_balance_wallet</span>
                       <span style={{ color: '#FFF', fontSize: 60, fontWeight: 'bold' }}>$0</span>
                       <span style={{ color: '#999', fontSize: 30 }}>الأرباح</span>
                    </div>

                    {/* Stat 2: Active Students (Middle) */}
                    <div style={{
                       flex: 1, height: 350, borderRadius: 40,
                       background: '#2A2A2A',
                       display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: 20,
                       transform: \`scale(\${spring({ frame: Math.max(0, frame - 2070), fps, config: { damping: 12 } })})\`,
                    }}>
                       <span className="material-icons" style={{ color: '#D4AF37', fontSize: 80 }}>groups</span>
                       <span style={{ color: '#FFF', fontSize: 60, fontWeight: 'bold' }}>0</span>
                       <span style={{ color: '#999', fontSize: 30 }}>الطلاب النشطون</span>
                    </div>

                    {/* Stat 3: Active Courses (Right) */}
                    <div style={{
                       flex: 1, height: 350, borderRadius: 40,
                       background: '#2A2A2A',
                       display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: 20,
                       transform: \`scale(\${spring({ frame: Math.max(0, frame - 2050), fps, config: { damping: 12 } })})\`,
                    }}>
                       <span className="material-icons" style={{ color: '#D4AF37', fontSize: 80 }}>assignment_ind</span>
                       <span style={{ color: '#FFF', fontSize: 60, fontWeight: 'bold' }}>1</span>
                       <span style={{ color: '#999', fontSize: 30 }}>الدورات النشطة</span>
                    </div>
                 </div>

                 {/* NEXT SECTION TITLE */}
                 <div style={{
                    marginTop: 80, width: '100%', display: 'flex', justifyContent: 'flex-end',
                    transform: \`translateY(\${interpolate(spring({ frame: Math.max(0, frame - 2100), fps }), [0, 1], [50, 0])}px)\`,
                    opacity: interpolate(frame, [2100, 2120], [0, 1], {extrapolateRight: 'clamp'})
                 }}>
                    <span style={{ color: '#FFF', fontSize: 50, fontWeight: 'bold' }}>التالي</span>
                 </div>

                 {/* HERO COURSE CARD */}
                 <div style={{
                    marginTop: 40, width: '100%', height: 750, borderRadius: 60, overflow: 'hidden', position: 'relative',
                    background: '#000',
                    transform: \`translateY(\${interpolate(spring({ frame: Math.max(0, frame - 2120), fps }), [0, 1], [50, 0])}px)\`,
                    opacity: interpolate(frame, [2120, 2140], [0, 1], {extrapolateRight: 'clamp'})
                 }}>
                    {/* Background image & gradient overlay */}
                    <Img src={staticFile('normal_writing.jpg')} style={{ position: 'absolute', inset: 0, width: '100%', height: '100%', objectFit: 'cover', opacity: 0.8 }} />
                    <div style={{ position: 'absolute', inset: 0, background: 'linear-gradient(to bottom, rgba(0,0,0,0.5) 0%, rgba(0,0,0,1) 100%)' }} />

                    <div style={{ position: 'absolute', inset: 0, padding: 50, display: 'flex', flexDirection: 'column' }}>
                       
                       {/* Top Pills */}
                       <div style={{ display: 'flex', justifyContent: 'space-between', width: '100%' }}>
                          <div style={{ background: 'rgba(255,255,255,0.15)', padding: '20px 30px', borderRadius: 30, display: 'flex', alignItems: 'center', gap: 15, backdropFilter: 'blur(10px)' }}>
                             <span className="material-icons" style={{ color: '#FFF', fontSize: 35 }}>event</span>
                             <span style={{ color: '#FFF', fontSize: 30 }}>غداً، ٣:٤٩ م</span>
                          </div>
                          <div style={{ background: '#D4AF37', padding: '20px 50px', borderRadius: 40 }}>
                             <span style={{ color: '#000', fontSize: 35, fontWeight: 'bold' }}>قادم</span>
                          </div>
                       </div>

                       {/* Course Title */}
                       <span style={{ color: '#FFF', fontSize: 60, fontWeight: 'bold', textAlign: 'center', marginTop: 120, lineHeight: 1.5, textShadow: '0 4px 10px rgba(0,0,0,0.8)' }}>
                          دورة تحسين الكتابة بالقلم العادي للمستوى المبتدئ
                       </span>

                       {/* Countdown Timer */}
                       <div style={{ display: 'flex', justifyContent: 'center', gap: 60, marginTop: 100, background: 'rgba(0,0,0,0.6)', padding: '30px 60px', borderRadius: 40, alignSelf: 'center', backdropFilter: 'blur(10px)', border: '1px solid rgba(255,255,255,0.1)' }}>
                          <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
                             {/* Dynamic seconds counting down from 54 */}
                             <span style={{ color: '#FFF', fontSize: 70, fontWeight: 'bold' }}>
                                {Math.max(0, 54 - Math.floor(Math.max(0, frame - 2120) / fps)).toString().padStart(2, '0')}
                             </span>
                             <span style={{ color: '#D4AF37', fontSize: 30 }}>ثانية</span>
                          </div>
                          <div style={{ width: 2, height: 100, background: 'rgba(255,255,255,0.2)', marginTop: 20 }} />
                          <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
                             <span style={{ color: '#FFF', fontSize: 70, fontWeight: 'bold' }}>20</span>
                             <span style={{ color: '#D4AF37', fontSize: 30 }}>دقيقة</span>
                          </div>
                          <div style={{ width: 2, height: 100, background: 'rgba(255,255,255,0.2)', marginTop: 20 }} />
                          <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
                             <span style={{ color: '#FFF', fontSize: 70, fontWeight: 'bold' }}>15</span>
                             <span style={{ color: '#D4AF37', fontSize: 30 }}>ساعة</span>
                          </div>
                          <div style={{ width: 2, height: 100, background: 'rgba(255,255,255,0.2)', marginTop: 20 }} />
                          <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
                             <span style={{ color: '#FFF', fontSize: 70, fontWeight: 'bold' }}>1</span>
                             <span style={{ color: '#D4AF37', fontSize: 30 }}>أيام</span>
                          </div>
                       </div>

                       {/* Prepare Button */}
                       <div style={{ width: '100%', height: 130, background: '#D4AF37', borderRadius: 40, marginTop: 'auto', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 20 }}>
                          <span style={{ color: '#000', fontSize: 50, fontWeight: 'bold' }}>تجهيز الحصة</span>
                          <span style={{ fontSize: 50 }}>🚀</span>
                       </div>

                    </div>
                 </div>
                 
              </div>

              {/* BOTTOM NAVIGATION BAR */}
              <div style={{
                 position: 'absolute', bottom: 0, left: 0, right: 0, height: 180, background: '#1E1E1E', borderTop: '2px solid #2A2A2A',
                 display: 'flex', justifyContent: 'space-around', alignItems: 'center', paddingBottom: 40,
                 transform: \`translateY(\${interpolate(spring({ frame: Math.max(0, frame - 2020), fps }), [0, 1], [200, 0])}px)\`,
              }}>
                 <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 10 }}>
                    <span className="material-icons" style={{ color: '#999', fontSize: 50 }}>person_outline</span>
                    <span style={{ color: '#999', fontSize: 30 }}>الملف الشخصي</span>
                 </div>
                 <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 10 }}>
                    <span className="material-icons" style={{ color: '#999', fontSize: 50 }}>groups</span>
                    <span style={{ color: '#999', fontSize: 30 }}>المجتمع</span>
                 </div>
                 <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 10 }}>
                    <span className="material-icons" style={{ color: '#999', fontSize: 50 }}>book</span>
                    <span style={{ color: '#999', fontSize: 30 }}>الدورات</span>
                 </div>
                 <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 10 }}>
                    <span className="material-icons" style={{ color: '#D4AF37', fontSize: 50 }}>home</span>
                    <span style={{ color: '#D4AF37', fontSize: 30 }}>الرئيسية</span>
                 </div>
              </div>

           </div>
        </div>
      )}
\n`;

  const newContent = content.substring(0, startIndex) + newDashboardScene + content.substring(endIndex);
  fs.writeFileSync(file, newContent);
  console.log("Teacher Dashboard exactly replaced with Image and dynamic timer!");
} else {
  console.log("Could not find markers!");
}
