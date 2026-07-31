const fs = require('fs');
const file = '/Users/yazanqattous/Desktop/flutter_projects/calligro_app/calligro_intro_video/src/Intro.tsx';
let content = fs.readFileSync(file, 'utf8');

const startMarker = "{/* ═══════════════════════════════════════════════════════════════════════════════ */}\n            {/* THE 3D HOLOGRAPHIC STUDIO";
const endMarker = "              </div>\n            </div>\n          </div>\n        </div>\n      )}\n    </AbsoluteFill>\n  );\n};";

const startIndex = content.indexOf(startMarker);
const endIndex = content.indexOf(endMarker);

if (startIndex === -1 || endIndex === -1) {
  console.log("Could not find markers!");
  process.exit(1);
}

const replacement = `            {/* ═══════════════════════════════════════════════════════════════════════════════ */}
            {/* WORKFLOW & SECURITY ANIMATION (Replaces 3D Studio)                            */}
            {/* ═══════════════════════════════════════════════════════════════════════════════ */}
            <div style={{
              marginTop: meetCardFloatProgress > 0 ? 24 * S : 0,
              height: meetCardFloatProgress * 420 * S,
              width: '100%',
              opacity: meetCardFloatProgress,
              background: 'linear-gradient(180deg, #0a0a0f, #15151a)',
              borderRadius: 24 * S,
              position: 'relative',
              overflow: 'hidden',
              display: 'flex', flexDirection: 'column',
              alignItems: 'center', justifyContent: 'center',
              border: meetCardFloatProgress > 0 ? \`1.5px solid rgba(238, 229, 147, 0.4)\` : 'none',
              boxShadow: \`inset 0 0 60px rgba(0,0,0,0.8)\`
            }}>
              
              {/* Scene 1: Scheduled Sessions (1170 to 1230) */}
              <div style={{
                 position: 'absolute', opacity: frame >= 1170 && frame < 1230 ? Math.min(1, (frame-1170)/10) * Math.min(1, (1230-frame)/10) : 0,
                 display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 20 * S,
                 transform: \`translateY(\${(1190 - Math.min(1190, Math.max(1170, frame)))*2}px)\`
              }}>
                 <span className="material-icons" style={{ fontSize: 70 * S, color: APP_TEXT_COLOR, filter: 'drop-shadow(0 0 15px rgba(238, 229, 147, 0.4))' }}>event_available</span>
                 <span style={{ color: '#FFF', fontSize: 26 * S, fontFamily: FONT_AR, fontWeight: 'bold' }}>حصص مجدولة مسبقاً</span>
                 <div style={{ background: 'rgba(105, 240, 174, 0.1)', padding: \`10px \${20*S}px\`, borderRadius: 30 * S, border: '1px solid #69F0AE', display: 'flex', alignItems: 'center', gap: 10*S, opacity: frame > 1195 ? 1 : 0, transform: \`scale(\${frame > 1195 ? 1 : 0.8})\`, transition: 'all 0.3s ease' }}>
                    <div style={{width: 10*S, height: 10*S, borderRadius: '50%', background: '#69F0AE'}} />
                    <span style={{ color: '#69F0AE', fontFamily: FONT_AR, fontWeight: 'bold', fontSize: 16 * S }}>الغرفة مفتوحة الآن</span>
                 </div>
              </div>

              {/* Scene 2: Teacher Access (1230 to 1290) */}
              <div style={{
                 position: 'absolute', opacity: frame >= 1230 && frame < 1290 ? Math.min(1, (frame-1230)/10) * Math.min(1, (1290-frame)/10) : 0,
                 display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 20 * S
              }}>
                 <div style={{ position: 'relative', transform: \`scale(\${Math.min(1, Math.max(0, (frame-1230)/10))})\` }}>
                    <div style={{ width: 90 * S, height: 90 * S, borderRadius: '50%', background: 'rgba(238, 229, 147, 0.15)', display: 'flex', alignItems: 'center', justifyContent: 'center', border: \`3px solid \${APP_TEXT_COLOR}\`, boxShadow: \`0 0 30px rgba(238, 229, 147, 0.2)\` }}>
                       <span className="material-icons" style={{ fontSize: 45 * S, color: APP_TEXT_COLOR }}>school</span>
                    </div>
                    {/* Crown popping in */}
                    <span className="material-icons" style={{ position: 'absolute', top: -20 * S, right: -15 * S, fontSize: 40 * S, color: '#FFD700', transform: \`scale(\${Math.min(1, Math.max(0, (frame-1245)/10))}) rotate(15deg)\`, filter: 'drop-shadow(0 4px 8px rgba(0,0,0,0.5))' }}>workspace_premium</span>
                 </div>
                 <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 8 * S }}>
                   <span style={{ color: '#FFF', fontSize: 26 * S, fontFamily: FONT_AR, fontWeight: 'bold' }}>دخول فوري للمعلم</span>
                   <span style={{ color: APP_TEXT_COLOR, fontSize: 18 * S, fontFamily: FONT_AR, opacity: frame > 1255 ? 1 : 0 }}>بصلاحيات تحكم كاملة في الجلسة</span>
                 </div>
              </div>

              {/* Scene 3: Easy Join (1290 to 1350) */}
              <div style={{
                 position: 'absolute', opacity: frame >= 1290 && frame < 1350 ? Math.min(1, (frame-1290)/10) * Math.min(1, (1350-frame)/10) : 0,
                 display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 28 * S
              }}>
                 <span style={{ color: '#FFF', fontSize: 26 * S, fontFamily: FONT_AR, fontWeight: 'bold', transform: \`translateY(\${(1 - Math.min(1, Math.max(0, (frame-1290)/10))) * -20}px)\` }}>انضمام الطلاب بضغطة زر</span>
                 
                 <div style={{ display: 'flex', gap: 20 * S, alignItems: 'center' }}>
                    {/* Student sliding in */}
                    <div style={{ 
                       width: 70 * S, height: 70 * S, borderRadius: '50%', background: 'rgba(255,255,255,0.1)', display: 'flex', alignItems: 'center', justifyContent: 'center', border: '2px solid rgba(255,255,255,0.3)',
                       transform: \`translateX(\${(1 - Math.min(1, Math.max(0, (frame-1300)/15))) * -120}px)\`, opacity: Math.min(1, Math.max(0, (frame-1300)/15))
                    }}>
                       <span className="material-icons" style={{ fontSize: 36 * S, color: '#FFF' }}>person</span>
                       <span className="material-icons" style={{ position: 'absolute', bottom: -5*S, right: -5*S, color: '#69F0AE', fontSize: 24*S, background: '#000', borderRadius: '50%', boxShadow: '0 0 10px rgba(105, 240, 174, 0.5)' }}>check_circle</span>
                    </div>
                    <span className="material-icons" style={{ color: '#69F0AE', fontSize: 40 * S, transform: \`scale(\${frame > 1315 ? 1 : 0})\`, transition: 'transform 0.3s cubic-bezier(0.175, 0.885, 0.32, 1.275)' }}>arrow_forward</span>
                    <div style={{ width: 90 * S, height: 90 * S, borderRadius: 20 * S, background: 'rgba(105, 240, 174, 0.1)', border: '2px solid #69F0AE', display: 'flex', alignItems: 'center', justifyContent: 'center', boxShadow: '0 0 30px rgba(105, 240, 174, 0.2)' }}>
                       <span className="material-icons" style={{ fontSize: 45 * S, color: '#69F0AE' }}>meeting_room</span>
                    </div>
                 </div>
                 
                 <span style={{ color: '#FF3B30', fontSize: 18 * S, fontFamily: FONT_AR, textDecoration: 'line-through', opacity: frame > 1325 ? 1 : 0, background: 'rgba(255, 59, 48, 0.1)', padding: \`6px \${16*S}px\`, borderRadius: 16 * S }}>لا حاجة لإرسال روابط خارجية</span>
              </div>

              {/* Scene 4: Blocked Access (1350 to 1420+) */}
              <div style={{
                 position: 'absolute', opacity: frame >= 1350 ? Math.min(1, (frame-1350)/10) : 0,
                 display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 28 * S
              }}>
                 <span style={{ color: '#FFF', fontSize: 26 * S, fontFamily: FONT_AR, fontWeight: 'bold' }}>حماية تامة من الدخلاء</span>
                 
                 <div style={{ display: 'flex', gap: 20 * S, alignItems: 'center' }}>
                    {/* Stranger sliding in */}
                    <div style={{ 
                       width: 70 * S, height: 70 * S, borderRadius: '50%', background: 'rgba(255, 59, 48, 0.15)', display: 'flex', alignItems: 'center', justifyContent: 'center', border: '2px solid #FF3B30',
                       transform: \`translateX(\${(1 - Math.min(1, Math.max(0, (frame-1360)/10))) * -60}px)\`
                    }}>
                       <span className="material-icons" style={{ fontSize: 36 * S, color: '#FF3B30' }}>person_off</span>
                    </div>
                    {/* The shield block */}
                    <div style={{ 
                       transform: \`scale(\${Math.min(1, Math.max(0, (frame-1375)/5))})\`,
                       opacity: Math.min(1, Math.max(0, (frame-1375)/5)),
                       zIndex: 10
                    }}>
                       <span className="material-icons" style={{ color: '#FF3B30', fontSize: 50 * S, filter: 'drop-shadow(0 0 15px rgba(255, 59, 48, 0.5))' }}>gpp_bad</span>
                    </div>
                    
                    <div style={{ width: 90 * S, height: 90 * S, borderRadius: 20 * S, background: 'rgba(255,255,255,0.05)', border: '2px dashed rgba(255,255,255,0.2)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                       <span className="material-icons" style={{ fontSize: 45 * S, color: 'rgba(255,255,255,0.2)' }}>meeting_room</span>
                    </div>
                 </div>
                 
                 <span style={{ color: '#FF3B30', fontSize: 18 * S, fontFamily: FONT_AR, fontWeight: 'bold', opacity: frame > 1385 ? 1 : 0, background: 'rgba(255, 59, 48, 0.15)', padding: \`8px \${20*S}px\`, borderRadius: 20 * S, border: '1px solid rgba(255, 59, 48, 0.3)' }}>يُمنع دخول غير المشتركين تلقائياً</span>
              </div>
\n`;

const newContent = content.substring(0, startIndex) + replacement + content.substring(endIndex);
fs.writeFileSync(file, newContent);
console.log("Replaced successfully!");
