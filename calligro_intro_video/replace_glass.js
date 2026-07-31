const fs = require('fs');
const file = '/Users/yazanqattous/Desktop/flutter_projects/calligro_app/calligro_intro_video/src/Intro.tsx';
let content = fs.readFileSync(file, 'utf8');

const startMarker = "{/*  CALLIGRO MEET 3D EXTRACTION & EXPLANATION (GLOBAL OVERLAY)                  */}";
const endMarker = "      )}\n    </AbsoluteFill>\n  );\n};";

const startIndex = content.indexOf(startMarker);
const endIndex = content.indexOf(endMarker);

if (startIndex === -1 || endIndex === -1) {
  console.log("Could not find markers!");
  process.exit(1);
}

const replacement = `{/*  CALLIGRO MEET 3D EXTRACTION & EXPLANATION (GLOBAL OVERLAY)                  */}
      {/* ═══════════════════════════════════════════════════════════════════════════════ */}
      {meetStageReveal > 0 && (
        <div style={{
          position: 'absolute', inset: 0,
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          zIndex: 300,
        }}>
          {/* The extracted Calligro Meet Card - FADES OUT AS EXPLANATION STARTS */}
          <div style={{
            position: 'absolute',
            width: 920 - (32 * S),
            padding: 24 * S,
            background: 'linear-gradient(145deg, rgba(28,28,31,0.6), rgba(10,10,13,0.8))',
            borderRadius: 28 * S,
            border: '1px solid rgba(238, 229, 147, 0.3)',
            transform: \`
              translateY(\${(1 - meetStageReveal) * -160}px)
              scale(\${0.72 + meetStageReveal * 0.38})
              perspective(1000px) rotateX(\${meetStageReveal * 5}deg)
            \`,
            opacity: meetStageReveal * (1 - meetCardFloatProgress),
            display: 'flex', flexDirection: 'column',
            boxShadow: \`0 \${meetStageReveal * 40}px \${meetStageReveal * 80}px rgba(0,0,0,0.8), inset 0 1px 1px rgba(255,255,255,0.1)\`,
            backdropFilter: 'blur(30px)',
            WebkitBackdropFilter: 'blur(30px)',
          }}>
            {/* Header */}
            <div style={{ display: 'flex', alignItems: 'center', marginBottom: 24 * S }}>
              <div style={{
                padding: 12 * S, background: 'linear-gradient(145deg, rgba(255,255,255,0.1), rgba(255,255,255,0.02))', borderRadius: '50%',
                display: 'flex', alignItems: 'center', justifyContent: 'center',
                boxShadow: 'inset 0 1px 1px rgba(255,255,255,0.2), inset 0 0 0 1px rgba(255,255,255,0.05)'
              }}>
                <span className="material-icons" style={{ fontSize: 24 * S, color: APP_TEXT_COLOR }}>stars</span>
              </div>
              <div style={{ display: 'flex', flexDirection: 'column', paddingRight: 16 * S, flex: 1 }}>
                <span style={{ fontSize: 18 * S, color: TEXT_COLOR, fontWeight: 'bold', fontFamily: FONT_AR, display: 'block', marginBottom: 2 * S }}>Calligro Meet</span>
                <span style={{ fontSize: 13 * S, color: 'rgba(255,255,255,0.54)', fontFamily: FONT_AR, display: 'block' }}>منصة الاجتماعات الآمنة الخاصة بنا</span>
              </div>
            </div>
            
            {/* Button */}
            <div style={{
              padding: \`\${14 * S}px 0\`, background: 'linear-gradient(145deg, rgba(105, 240, 174, 0.15), rgba(105, 240, 174, 0.02))',
              borderRadius: 16 * S, 
              display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 10 * S,
              boxShadow: 'inset 0 1px 1px rgba(105, 240, 174, 0.4), inset 0 0 0 1px rgba(105, 240, 174, 0.1)'
            }}>
              <span className="material-icons" style={{ fontSize: 20 * S, color: '#69F0AE' }}>verified</span>
              <span style={{ fontSize: 14 * S, color: '#69F0AE', fontWeight: 'bold', fontFamily: FONT_AR }}>الغرفة جاهزة</span>
            </div>
          </div>

          {/* ═══════════════════════════════════════════════════════════════════════════════ */}
          {/* THE VIRTUAL HUB NARRATIVE - VISION OS GLASSMORPHISM EDITION                   */}
          {/* ═══════════════════════════════════════════════════════════════════════════════ */}
          <div style={{
            position: 'absolute', inset: 0,
            background: 'linear-gradient(180deg, rgba(8,8,8,0.95), rgba(20,20,26,0.95))',
            backdropFilter: 'blur(20px)',
            opacity: meetCardFloatProgress,
            display: 'flex', flexDirection: 'column',
            alignItems: 'center', justifyContent: 'center',
            overflow: 'hidden',
          }}>
            
            {/* --- THE CENTRAL HUB --- */}
            <div style={{
               position: 'relative',
               width: 160 * S, height: 160 * S,
               transform: \`
                 translateY(-30px)
                 scale(\${spring({ frame: Math.max(0, frame - 1170), fps, config: { damping: 12, stiffness: 120 } })})
               \`
            }}>
               
               {/* VisionOS Hub Base: Frosted Glass Ring */}
               <div style={{
                 position: 'absolute', inset: 0, borderRadius: '50%',
                 background: 'linear-gradient(135deg, rgba(255,255,255,0.08), rgba(255,255,255,0.01))',
                 backdropFilter: 'blur(30px)', WebkitBackdropFilter: 'blur(30px)',
                 boxShadow: \`
                   inset 0 2px 2px rgba(255,255,255,0.2), 
                   inset 0 0 0 1px rgba(255,255,255,0.05),
                   0 20px 40px rgba(0,0,0,0.5),
                   0 0 60px rgba(105,240,174,\${interpolate(frame, [1170, 1180], [0, 0.15])})
                 \`,
                 // Pulse base on time
                 transform: \`scale(\${1 + Math.sin(frame * 0.1) * 0.03})\`
               }} />

               {/* Phase 1: Calendar (1170 - 1230) */}
               <div style={{
                 position: 'absolute', inset: 0, display: 'flex', alignItems: 'center', justifyContent: 'center',
                 opacity: frame < 1170 ? 0 : frame < 1230 ? 1 : interpolate(frame, [1230, 1240], [1, 0], {extrapolateRight: 'clamp', extrapolateLeft: 'clamp'}),
                 transform: \`scale(\${spring({ frame: Math.max(0, frame - 1175), fps, config: { damping: 10, stiffness: 200 } })})\`
               }}>
                 {/* Glass Calendar Icon Container */}
                 <div style={{
                   width: 90 * S, height: 90 * S, borderRadius: 24 * S,
                   background: 'linear-gradient(135deg, rgba(105,240,174,0.2), rgba(105,240,174,0.02))',
                   boxShadow: 'inset 0 1px 1px rgba(105,240,174,0.4), inset 0 0 0 1px rgba(105,240,174,0.1), 0 10px 20px rgba(0,0,0,0.3)',
                   display: 'flex', alignItems: 'center', justifyContent: 'center'
                 }}>
                   <span className="material-icons" style={{ fontSize: 50 * S, color: '#69F0AE', filter: 'drop-shadow(0 2px 5px rgba(0,0,0,0.5))' }}>event_available</span>
                 </div>
               </div>

               {/* Phase 2+: Teacher Takes Control (1230+) */}
               <div style={{
                 position: 'absolute', inset: 0, display: 'flex', alignItems: 'center', justifyContent: 'center',
                 opacity: spring({ frame: Math.max(0, frame - 1230), fps }),
                 transform: \`scale(\${spring({ frame: Math.max(0, frame - 1230), fps, config: { damping: 10, stiffness: 250 } })})\`
               }}>
                 {/* Teacher Avatar - Glassmorphism */}
                 <div style={{ 
                    width: 90 * S, height: 90 * S, borderRadius: '50%', 
                    background: 'linear-gradient(135deg, rgba(238,229,147,0.15), rgba(238,229,147,0.02))', 
                    display: 'flex', alignItems: 'center', justifyContent: 'center', 
                    boxShadow: 'inset 0 2px 2px rgba(238,229,147,0.4), inset 0 0 0 1px rgba(238,229,147,0.1), 0 10px 20px rgba(0,0,0,0.4)',
                 }}>
                    <span className="material-icons" style={{ fontSize: 45 * S, color: APP_TEXT_COLOR, filter: 'drop-shadow(0 2px 5px rgba(0,0,0,0.5))' }}>school</span>
                 </div>
                 
                 {/* Crown Parabolic Landing */}
                 <div style={{
                    position: 'absolute', top: 15 * S, right: 15 * S,
                    transform: \`
                      translate(
                        \${interpolate(spring({ frame: Math.max(0, frame - 1240), fps, config: { damping: 12 } }), [0, 1], [150, 0])}px, 
                        \${interpolate(spring({ frame: Math.max(0, frame - 1240), fps, config: { damping: 12, stiffness: 200 } }), [0, 1], [-150, 0])}px
                      )
                      rotate(\${interpolate(spring({ frame: Math.max(0, frame - 1240), fps }), [0, 1], [90, 15])}deg)
                      scale(\${spring({ frame: Math.max(0, frame - 1240), fps })})
                    \`,
                 }}>
                    <div style={{
                      background: 'linear-gradient(135deg, rgba(255,215,0,0.3), rgba(255,215,0,0.05))',
                      borderRadius: '50%', padding: 6 * S,
                      boxShadow: 'inset 0 1px 2px rgba(255,215,0,0.6), inset 0 0 0 1px rgba(255,215,0,0.2), 0 5px 15px rgba(0,0,0,0.5)',
                      display: 'flex', alignItems: 'center', justifyContent: 'center'
                    }}>
                      <span className="material-icons" style={{ fontSize: 30 * S, color: '#FFD700', filter: 'drop-shadow(0 2px 4px rgba(0,0,0,0.6))' }}>workspace_premium</span>
                    </div>
                 </div>
                 
                 {/* Impact Shockwave on Teacher Landing */}
                 <div style={{
                    position: 'absolute', inset: -20, borderRadius: '50%',
                    boxShadow: 'inset 0 0 0 2px rgba(255,215,0,1)',
                    opacity: interpolate(frame, [1245, 1260], [1, 0], {extrapolateRight: 'clamp', extrapolateLeft: 'clamp'}),
                    transform: \`scale(\${interpolate(frame, [1245, 1260], [0.5, 2.5], {extrapolateRight: 'clamp', extrapolateLeft: 'clamp'})})\`,
                 }} />
               </div>

               {/* Phase 3+: Students Flowing In (1290+) */}
               {/* Left Student */}
               <div style={{
                 position: 'absolute', top: 20 * S, left: -70 * S,
                 opacity: frame >= 1295 ? 1 : 0,
                 transform: \`
                   translateX(\${interpolate(spring({ frame: Math.max(0, frame - 1295), fps, config: { damping: 14 } }), [0, 1], [-200, 0])}px)
                   scale(\${spring({ frame: Math.max(0, frame - 1295), fps })})
                 \`
               }}>
                  <div style={{ 
                    width: 50 * S, height: 50 * S, borderRadius: '50%', 
                    background: 'linear-gradient(135deg, rgba(255,255,255,0.2), rgba(255,255,255,0.02))', 
                    display: 'flex', alignItems: 'center', justifyContent: 'center', 
                    boxShadow: 'inset 0 1px 2px rgba(255,255,255,0.5), inset 0 0 0 1px rgba(255,255,255,0.1), 0 8px 16px rgba(0,0,0,0.4)',
                    backdropFilter: 'blur(20px)', WebkitBackdropFilter: 'blur(20px)' 
                  }}>
                     <span className="material-icons" style={{ fontSize: 26 * S, color: '#FFF', filter: 'drop-shadow(0 2px 4px rgba(0,0,0,0.5))' }}>person</span>
                  </div>
               </div>
               
               {/* Right Student */}
               <div style={{
                 position: 'absolute', bottom: 20 * S, right: -70 * S,
                 opacity: frame >= 1305 ? 1 : 0,
                 transform: \`
                   translateX(\${interpolate(spring({ frame: Math.max(0, frame - 1305), fps, config: { damping: 14 } }), [0, 1], [200, 0])}px)
                   scale(\${spring({ frame: Math.max(0, frame - 1305), fps })})
                 \`
               }}>
                  <div style={{ 
                    width: 50 * S, height: 50 * S, borderRadius: '50%', 
                    background: 'linear-gradient(135deg, rgba(255,255,255,0.2), rgba(255,255,255,0.02))', 
                    display: 'flex', alignItems: 'center', justifyContent: 'center', 
                    boxShadow: 'inset 0 1px 2px rgba(255,255,255,0.5), inset 0 0 0 1px rgba(255,255,255,0.1), 0 8px 16px rgba(0,0,0,0.4)',
                    backdropFilter: 'blur(20px)', WebkitBackdropFilter: 'blur(20px)' 
                  }}>
                     <span className="material-icons" style={{ fontSize: 26 * S, color: '#FFF', filter: 'drop-shadow(0 2px 4px rgba(0,0,0,0.5))' }}>person</span>
                  </div>
               </div>

               {/* Phase 4: Blocked Stranger & Forcefield (1350+) */}
               {/* Red Forcefield - Glass Dome */}
               <div style={{
                 position: 'absolute', inset: -40 * S, borderRadius: '50%',
                 background: 'linear-gradient(135deg, rgba(255,59,48,0.15), rgba(255,59,48,0.02))',
                 boxShadow: 'inset 0 2px 10px rgba(255,59,48,0.4), inset 0 0 0 2px rgba(255,59,48,0.3), 0 0 40px rgba(255,59,48,0.3)',
                 backdropFilter: 'blur(5px)', WebkitBackdropFilter: 'blur(5px)',
                 opacity: interpolate(frame, [1365, 1370], [0, 1], {extrapolateRight: 'clamp', extrapolateLeft: 'clamp'}),
                 transform: \`scale(\${spring({ frame: Math.max(0, frame - 1365), fps, config: { stiffness: 300, damping: 8 } })})\`
               }} />

               {/* The Stranger Bouncing off Forcefield */}
               <div style={{
                 position: 'absolute', bottom: -120 * S, left: 35 * S,
                 display: frame >= 1350 ? 'block' : 'none',
                 transform: \`
                   translateY(\${interpolate(Math.min(1, Math.max(0, (frame-1350)/15)), [0, 1], [200, 0])}px)
                   translateY(\${interpolate(frame, [1365, 1370], [0, -60], {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'})}px)
                   translateY(\${interpolate(spring({ frame: Math.max(0, frame - 1370), fps, config: { damping: 10 } }), [0, 1], [0, 150])}px)
                   scale(\${interpolate(frame, [1375, 1390], [1, 0], {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'})})
                 \`
               }}>
                  <div style={{ 
                    width: 70 * S, height: 70 * S, borderRadius: '50%', 
                    background: 'linear-gradient(135deg, rgba(255,59,48,0.25), rgba(255,59,48,0.05))', 
                    display: 'flex', alignItems: 'center', justifyContent: 'center', 
                    boxShadow: 'inset 0 1px 2px rgba(255,59,48,0.6), inset 0 0 0 1px rgba(255,59,48,0.2), 0 10px 20px rgba(0,0,0,0.4)' 
                  }}>
                     <span className="material-icons" style={{ fontSize: 36 * S, color: '#FF3B30', filter: 'drop-shadow(0 2px 4px rgba(0,0,0,0.5))' }}>person_off</span>
                  </div>
               </div>
               
               {/* Impact Sparks when stranger hits forcefield */}
               <span className="material-icons" style={{ 
                 position: 'absolute', bottom: -30 * S, left: 60 * S, color: '#FFF', fontSize: 40 * S, filter: 'drop-shadow(0 0 10px rgba(255,255,255,0.8))',
                 opacity: interpolate(frame, [1368, 1375], [1, 0], {extrapolateRight: 'clamp', extrapolateLeft: 'clamp'}),
                 transform: \`scale(\${interpolate(frame, [1368, 1375], [0, 2], {extrapolateRight: 'clamp', extrapolateLeft: 'clamp'})})\`
               }}>flash_on</span>
            </div>

            {/* --- DYNAMIC TEXT MESSAGING (Below Hub) --- */}
            <div style={{ position: 'absolute', top: '68%', display: 'flex', flexDirection: 'column', alignItems: 'center', width: '100%' }}>
              
              {/* Phase 1 Text */}
              <div style={{ position: 'absolute', display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 12 * S,
                opacity: frame < 1170 ? 0 : frame < 1230 ? 1 : interpolate(frame, [1230, 1235], [1, 0], {extrapolateRight: 'clamp', extrapolateLeft: 'clamp'}),
                transform: \`translateY(\${interpolate(spring({ frame: Math.max(0, frame - 1175), fps }), [0, 1], [20, 0])}px)\`
              }}>
                 <span style={{ color: '#FFF', fontSize: 32 * S, fontFamily: FONT_AR, fontWeight: 'bold', filter: 'drop-shadow(0 4px 10px rgba(0,0,0,0.5))' }}>حصص مجدولة مسبقاً</span>
                 <div style={{ 
                   background: 'linear-gradient(135deg, rgba(105, 240, 174, 0.15), rgba(105, 240, 174, 0.02))', 
                   padding: \`8px \${20*S}px\`, borderRadius: 40 * S, 
                   boxShadow: 'inset 0 1px 1px rgba(105, 240, 174, 0.3), inset 0 0 0 1px rgba(105, 240, 174, 0.1), 0 8px 16px rgba(0,0,0,0.3)', 
                   display: 'flex', alignItems: 'center', gap: 10*S,
                   backdropFilter: 'blur(10px)', WebkitBackdropFilter: 'blur(10px)'
                 }}>
                    <div style={{width: 12*S, height: 12*S, borderRadius: '50%', background: '#69F0AE', boxShadow: '0 0 8px #69F0AE', transform: \`scale(\${Math.sin(frame * 0.2) * 0.2 + 0.8})\` }} />
                    <span style={{ color: '#69F0AE', fontFamily: FONT_AR, fontWeight: 'bold', fontSize: 18 * S }}>الغرفة جاهزة</span>
                 </div>
              </div>

              {/* Phase 2 Text */}
              <div style={{ position: 'absolute', display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 12 * S,
                opacity: frame < 1235 ? 0 : frame < 1290 ? 1 : interpolate(frame, [1290, 1295], [1, 0], {extrapolateRight: 'clamp', extrapolateLeft: 'clamp'}),
                transform: \`translateY(\${interpolate(spring({ frame: Math.max(0, frame - 1235), fps }), [0, 1], [20, 0])}px)\`
              }}>
                 <span style={{ color: '#FFF', fontSize: 32 * S, fontFamily: FONT_AR, fontWeight: 'bold', filter: 'drop-shadow(0 4px 10px rgba(0,0,0,0.5))' }}>دخول فوري للمعلم</span>
                 <span style={{ color: APP_TEXT_COLOR, fontSize: 20 * S, fontFamily: FONT_AR, filter: 'drop-shadow(0 2px 5px rgba(0,0,0,0.8))' }}>بصلاحيات تحكم كاملة في الجلسة</span>
              </div>

              {/* Phase 3 Text */}
              <div style={{ position: 'absolute', display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 16 * S,
                opacity: frame < 1295 ? 0 : frame < 1350 ? 1 : interpolate(frame, [1350, 1355], [1, 0], {extrapolateRight: 'clamp', extrapolateLeft: 'clamp'}),
                transform: \`translateY(\${interpolate(spring({ frame: Math.max(0, frame - 1295), fps }), [0, 1], [20, 0])}px)\`
              }}>
                 <span style={{ color: '#FFF', fontSize: 32 * S, fontFamily: FONT_AR, fontWeight: 'bold', filter: 'drop-shadow(0 4px 10px rgba(0,0,0,0.5))' }}>انضمام الطلاب بضغطة زر</span>
                 <span style={{ 
                   color: '#69F0AE', fontSize: 20 * S, fontFamily: FONT_AR, 
                   background: 'linear-gradient(135deg, rgba(105, 240, 174, 0.15), rgba(105, 240, 174, 0.02))', 
                   padding: \`10px \${24*S}px\`, borderRadius: 20 * S, 
                   boxShadow: 'inset 0 1px 1px rgba(105, 240, 174, 0.3), inset 0 0 0 1px rgba(105, 240, 174, 0.1), 0 8px 16px rgba(0,0,0,0.3)',
                   backdropFilter: 'blur(10px)', WebkitBackdropFilter: 'blur(10px)',
                   transform: \`scale(\${interpolate(spring({ frame: Math.max(0, frame - 1310), fps, config: { damping: 8, stiffness: 300 } }), [0, 1], [2, 1])})\`,
                   opacity: frame >= 1310 ? 1 : 0
                 }}>لا حاجة لإرسال روابط خارجية</span>
              </div>

              {/* Phase 4 Text */}
              <div style={{ position: 'absolute', display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 16 * S,
                opacity: frame < 1355 ? 0 : 1,
                transform: \`translateY(\${interpolate(spring({ frame: Math.max(0, frame - 1355), fps }), [0, 1], [20, 0])}px)\`
              }}>
                 <span style={{ color: '#FFF', fontSize: 32 * S, fontFamily: FONT_AR, fontWeight: 'bold', filter: 'drop-shadow(0 4px 10px rgba(0,0,0,0.5))' }}>حماية تامة من الدخلاء</span>
                 <span style={{ 
                   color: '#FF3B30', fontSize: 20 * S, fontFamily: FONT_AR, fontWeight: 'bold',
                   background: 'linear-gradient(135deg, rgba(255, 59, 48, 0.2), rgba(255, 59, 48, 0.02))', 
                   padding: \`12px \${30*S}px\`, borderRadius: 24 * S, 
                   boxShadow: 'inset 0 1px 1px rgba(255, 59, 48, 0.4), inset 0 0 0 1px rgba(255, 59, 48, 0.15), 0 8px 16px rgba(0,0,0,0.3)',
                   backdropFilter: 'blur(10px)', WebkitBackdropFilter: 'blur(10px)',
                   transform: \`scale(\${interpolate(spring({ frame: Math.max(0, frame - 1370), fps, config: { damping: 8, stiffness: 300 } }), [0, 1], [2, 1])})\`,
                   opacity: frame >= 1370 ? 1 : 0
                 }}>يُمنع دخول غير المشتركين تلقائياً</span>
              </div>

            </div>
          </div>
        </div>
\n`;

const newContent = content.substring(0, startIndex) + replacement + content.substring(endIndex);
fs.writeFileSync(file, newContent);
console.log("Replaced successfully!");
