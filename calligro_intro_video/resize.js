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
            background: 'linear-gradient(145deg, #1C1C1F, #0A0A0D)',
            borderRadius: 28 * S,
            border: '1px solid rgba(238, 229, 147, 0.3)',
            transform: \`
              translateY(\${(1 - meetStageReveal) * -160}px)
              scale(\${0.72 + meetStageReveal * 0.38})
              perspective(1000px) rotateX(\${meetStageReveal * 5}deg)
            \`,
            opacity: meetStageReveal * (1 - meetCardFloatProgress), // FADE OUT
            display: 'flex', flexDirection: 'column',
            boxShadow: \`0 \${meetStageReveal * 40}px \${meetStageReveal * 80}px rgba(0,0,0,0.8)\`,
            backdropFilter: 'blur(15px)',
          }}>
            {/* Header */}
            <div style={{ display: 'flex', alignItems: 'center', marginBottom: 24 * S }}>
              <div style={{
                padding: 12 * S, background: 'rgba(255,255,255,0.05)', borderRadius: '50%',
                display: 'flex', alignItems: 'center', justifyContent: 'center'
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
              padding: \`\${14 * S}px 0\`, background: 'rgba(105, 240, 174, 0.1)',
              borderRadius: 16 * S, border: '1px solid rgba(105, 240, 174, 0.2)',
              display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 10 * S
            }}>
              <span className="material-icons" style={{ fontSize: 20 * S, color: '#69F0AE' }}>verified</span>
              <span style={{ fontSize: 14 * S, color: '#69F0AE', fontWeight: 'bold', fontFamily: FONT_AR }}>الغرفة جاهزة</span>
            </div>
          </div>

          {/* ═══════════════════════════════════════════════════════════════════════════════ */}
          {/* FULL SCREEN WORKFLOW & SECURITY ANIMATION                                     */}
          {/* ═══════════════════════════════════════════════════════════════════════════════ */}
          <div style={{
            position: 'absolute', inset: 0,
            background: 'linear-gradient(180deg, rgba(8,8,8,0.95), rgba(20,20,26,0.95))',
            backdropFilter: 'blur(10px)',
            opacity: meetCardFloatProgress,
            display: 'flex', flexDirection: 'column',
            alignItems: 'center', justifyContent: 'center',
          }}>
            
            {/* Scene 1: Scheduled Sessions (1170 to 1230) */}
            <div style={{
               position: 'absolute', opacity: frame >= 1170 && frame < 1230 ? Math.min(1, (frame-1170)/10) * Math.min(1, (1230-frame)/10) : 0,
               display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 24 * S,
               transform: \`translateY(\${(1190 - Math.min(1190, Math.max(1170, frame)))*2}px)\`
            }}>
               <span className="material-icons" style={{ fontSize: 100 * S, color: APP_TEXT_COLOR, filter: 'drop-shadow(0 0 20px rgba(238, 229, 147, 0.4))' }}>event_available</span>
               <span style={{ color: '#FFF', fontSize: 32 * S, fontFamily: FONT_AR, fontWeight: 'bold', letterSpacing: 1 }}>حصص مجدولة مسبقاً</span>
               <div style={{ background: 'rgba(105, 240, 174, 0.1)', padding: \`12px \${24*S}px\`, borderRadius: 40 * S, border: '2px solid #69F0AE', display: 'flex', alignItems: 'center', gap: 12*S, opacity: frame > 1195 ? 1 : 0, transform: \`scale(\${frame > 1195 ? 1 : 0.8})\`, transition: 'all 0.3s ease' }}>
                  <div style={{width: 14*S, height: 14*S, borderRadius: '50%', background: '#69F0AE', boxShadow: '0 0 10px #69F0AE'}} />
                  <span style={{ color: '#69F0AE', fontFamily: FONT_AR, fontWeight: 'bold', fontSize: 20 * S }}>الغرفة مفتوحة الآن</span>
               </div>
            </div>

            {/* Scene 2: Teacher Access (1230 to 1290) */}
            <div style={{
               position: 'absolute', opacity: frame >= 1230 && frame < 1290 ? Math.min(1, (frame-1230)/10) * Math.min(1, (1290-frame)/10) : 0,
               display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 24 * S
            }}>
               <div style={{ position: 'relative', transform: \`scale(\${Math.min(1, Math.max(0, (frame-1230)/10))})\` }}>
                  <div style={{ width: 120 * S, height: 120 * S, borderRadius: '50%', background: 'rgba(238, 229, 147, 0.15)', display: 'flex', alignItems: 'center', justifyContent: 'center', border: \`3px solid \${APP_TEXT_COLOR}\`, boxShadow: \`0 0 30px rgba(238, 229, 147, 0.3)\` }}>
                     <span className="material-icons" style={{ fontSize: 60 * S, color: APP_TEXT_COLOR }}>school</span>
                  </div>
                  {/* Crown */}
                  <span className="material-icons" style={{ position: 'absolute', top: -20 * S, right: -10 * S, fontSize: 50 * S, color: '#FFD700', transform: \`scale(\${Math.min(1, Math.max(0, (frame-1245)/10))}) rotate(15deg)\`, filter: 'drop-shadow(0 5px 10px rgba(0,0,0,0.5))' }}>workspace_premium</span>
               </div>
               <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 12 * S }}>
                 <span style={{ color: '#FFF', fontSize: 32 * S, fontFamily: FONT_AR, fontWeight: 'bold' }}>دخول فوري للمعلم</span>
                 <span style={{ color: APP_TEXT_COLOR, fontSize: 20 * S, fontFamily: FONT_AR, opacity: frame > 1255 ? 1 : 0 }}>بصلاحيات تحكم كاملة في الجلسة</span>
               </div>
            </div>

            {/* Scene 3: Easy Join (1290 to 1350) */}
            <div style={{
               position: 'absolute', opacity: frame >= 1290 && frame < 1350 ? Math.min(1, (frame-1290)/10) * Math.min(1, (1350-frame)/10) : 0,
               display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 32 * S
            }}>
               <span style={{ color: '#FFF', fontSize: 32 * S, fontFamily: FONT_AR, fontWeight: 'bold', transform: \`translateY(\${(1 - Math.min(1, Math.max(0, (frame-1290)/10))) * -20}px)\` }}>انضمام الطلاب بضغطة زر</span>
               
               <div style={{ display: 'flex', gap: 24 * S, alignItems: 'center' }}>
                  {/* Student sliding in */}
                  <div style={{ 
                     width: 90 * S, height: 90 * S, borderRadius: '50%', background: 'rgba(255,255,255,0.1)', display: 'flex', alignItems: 'center', justifyContent: 'center', border: '2px solid rgba(255,255,255,0.3)',
                     transform: \`translateX(\${(1 - Math.min(1, Math.max(0, (frame-1300)/15))) * -100}px)\`, opacity: Math.min(1, Math.max(0, (frame-1300)/15))
                  }}>
                     <span className="material-icons" style={{ fontSize: 50 * S, color: '#FFF' }}>person</span>
                     <span className="material-icons" style={{ position: 'absolute', bottom: -5*S, right: -5*S, color: '#69F0AE', fontSize: 32*S, background: '#000', borderRadius: '50%', boxShadow: '0 0 10px rgba(105, 240, 174, 0.5)' }}>check_circle</span>
                  </div>
                  <span className="material-icons" style={{ color: '#69F0AE', fontSize: 50 * S, transform: \`scale(\${frame > 1315 ? 1 : 0})\`, transition: 'transform 0.3s cubic-bezier(0.175, 0.885, 0.32, 1.275)' }}>arrow_forward</span>
                  <div style={{ width: 110 * S, height: 110 * S, borderRadius: 24 * S, background: 'rgba(105, 240, 174, 0.1)', border: '3px solid #69F0AE', display: 'flex', alignItems: 'center', justifyContent: 'center', boxShadow: '0 0 30px rgba(105, 240, 174, 0.2)' }}>
                     <span className="material-icons" style={{ fontSize: 60 * S, color: '#69F0AE' }}>meeting_room</span>
                  </div>
               </div>
               
               <span style={{ color: '#FF3B30', fontSize: 20 * S, fontFamily: FONT_AR, textDecoration: 'line-through', opacity: frame > 1325 ? 1 : 0, background: 'rgba(255, 59, 48, 0.1)', padding: \`10px \${24*S}px\`, borderRadius: 20 * S }}>لا حاجة لإرسال روابط خارجية</span>
            </div>

            {/* Scene 4: Blocked Access (1350 to 1420+) */}
            <div style={{
               position: 'absolute', opacity: frame >= 1350 ? Math.min(1, (frame-1350)/10) : 0,
               display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 32 * S
            }}>
               <span style={{ color: '#FFF', fontSize: 32 * S, fontFamily: FONT_AR, fontWeight: 'bold' }}>حماية تامة من الدخلاء</span>
               
               <div style={{ display: 'flex', gap: 24 * S, alignItems: 'center' }}>
                  {/* Stranger sliding in */}
                  <div style={{ 
                     width: 90 * S, height: 90 * S, borderRadius: '50%', background: 'rgba(255, 59, 48, 0.15)', display: 'flex', alignItems: 'center', justifyContent: 'center', border: '2px solid #FF3B30',
                     transform: \`translateX(\${(1 - Math.min(1, Math.max(0, (frame-1360)/10))) * -50}px)\`
                  }}>
                     <span className="material-icons" style={{ fontSize: 50 * S, color: '#FF3B30' }}>person_off</span>
                  </div>
                  {/* The shield block */}
                  <div style={{ 
                     transform: \`scale(\${Math.min(1, Math.max(0, (frame-1375)/5))})\`,
                     opacity: Math.min(1, Math.max(0, (frame-1375)/5)),
                     zIndex: 10
                  }}>
                     <span className="material-icons" style={{ color: '#FF3B30', fontSize: 80 * S, filter: 'drop-shadow(0 0 15px rgba(255, 59, 48, 0.5))' }}>gpp_bad</span>
                  </div>
                  
                  <div style={{ width: 110 * S, height: 110 * S, borderRadius: 24 * S, background: 'rgba(255,255,255,0.05)', border: '3px dashed rgba(255,255,255,0.2)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                     <span className="material-icons" style={{ fontSize: 60 * S, color: 'rgba(255,255,255,0.2)' }}>meeting_room</span>
                  </div>
               </div>
               
               <span style={{ color: '#FF3B30', fontSize: 20 * S, fontFamily: FONT_AR, fontWeight: 'bold', opacity: frame > 1385 ? 1 : 0, background: 'rgba(255, 59, 48, 0.15)', padding: \`12px \${30*S}px\`, borderRadius: 24 * S, border: '1px solid rgba(255, 59, 48, 0.3)' }}>يُمنع دخول غير المشتركين تلقائياً</span>
            </div>
          </div>
        </div>
\n`;

const newContent = content.substring(0, startIndex) + replacement + content.substring(endIndex);
fs.writeFileSync(file, newContent);
console.log("Replaced successfully!");
