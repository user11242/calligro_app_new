const fs = require('fs');
const file = '/Users/yazanqattous/Desktop/flutter_projects/calligro_app/calligro_intro_video/src/Intro.tsx';
let content = fs.readFileSync(file, 'utf8');

// 1. Fade out the Meet Hub
content = content.replace(
  `opacity: meetCardFloatProgress,`,
  `opacity: frame < 1450 ? meetCardFloatProgress : interpolate(frame, [1450, 1470], [1, 0], {extrapolateRight: 'clamp'}),`
);

// 2. Insert Homework Feature
const insertMarker = `      )}
    </AbsoluteFill>
  );
};`;

const homeworkBlock = `
      {/* ═══════════════════════════════════════════════════════════════════════════════ */}
      {/* INTEGRATED HOMEWORK SYSTEM NARRATIVE                                            */}
      {/* ═══════════════════════════════════════════════════════════════════════════════ */}
      {frame >= 1450 && (
        <div style={{
          position: 'absolute', inset: 0,
          background: 'linear-gradient(180deg, rgba(8,8,8,0.95), rgba(20,20,26,0.95))',
          display: 'flex', flexDirection: 'column',
          alignItems: 'center', justifyContent: 'center',
          opacity: interpolate(frame, [1450, 1470], [0, 1], {extrapolateRight: 'clamp'}),
          zIndex: 400
        }}>
          
          {/* SCENE 1: THE PROBLEM (1450 - 1550) - Chaotic External Apps */}
          <div style={{
            position: 'absolute', inset: 0, display: 'flex', alignItems: 'center', justifyContent: 'center',
            opacity: frame < 1550 ? 1 : interpolate(frame, [1550, 1560], [1, 0], {extrapolateRight: 'clamp'})
          }}>
             {/* Floating App Icons (WhatsApp, Drive, Links) */}
             <div style={{ position: 'relative', width: 200*S, height: 200*S }}>
                <span className="material-icons" style={{ position: 'absolute', top: 20*S, left: 30*S, fontSize: 50*S, color: '#25D366', filter: 'drop-shadow(0 0 10px rgba(37,211,102,0.5))', transform: \`translate(\${Math.sin(frame*0.1)*10}px, \${Math.cos(frame*0.1)*10}px) rotate(-15deg)\` }}>chat</span>
                <span className="material-icons" style={{ position: 'absolute', top: 40*S, right: 10*S, fontSize: 60*S, color: '#FF3B30', filter: 'drop-shadow(0 0 10px rgba(255,59,48,0.5))', transform: \`translate(\${Math.sin(frame*0.15)*15}px, \${Math.cos(frame*0.05)*15}px) rotate(10deg)\` }}>picture_as_pdf</span>
                <span className="material-icons" style={{ position: 'absolute', bottom: 30*S, left: 10*S, fontSize: 45*S, color: '#007AFF', filter: 'drop-shadow(0 0 10px rgba(0,122,255,0.5))', transform: \`translate(\${Math.cos(frame*0.1)*10}px, \${Math.sin(frame*0.12)*15}px) rotate(20deg)\` }}>link</span>
                <span className="material-icons" style={{ position: 'absolute', bottom: 10*S, right: 30*S, fontSize: 55*S, color: '#FFD700', filter: 'drop-shadow(0 0 10px rgba(255,215,0,0.5))', transform: \`translate(\${Math.sin(frame*0.08)*20}px, \${Math.cos(frame*0.1)*10}px) rotate(-25deg)\` }}>folder</span>
                
                {/* Confused/Exhausted User in Center */}
                <div style={{ position: 'absolute', inset: 0, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                  <span className="material-icons" style={{ fontSize: 80*S, color: '#FFF', opacity: 0.8, filter: 'drop-shadow(0 0 20px rgba(255,255,255,0.5))', transform: \`scale(\${1 + Math.sin(frame*0.2)*0.05})\` }}>sentiment_dissatisfied</span>
                </div>
             </div>
             
             {/* Problem Text */}
             <div style={{ position: 'absolute', top: '70%', display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 10*S }}>
                <span style={{ color: '#FF3B30', fontSize: 24*S, fontFamily: FONT_AR, fontWeight: 'bold', background: 'rgba(255,59,48,0.1)', padding: \`8px \${20*S}px\`, borderRadius: 20*S, border: '1px dashed #FF3B30' }}>الطريقة التقليدية متعبة</span>
                <span style={{ color: '#FFF', fontSize: 20*S, fontFamily: FONT_AR }}>تطبيقات خارجية وروابط مشتتة للطلاب</span>
             </div>
          </div>
          
          {/* SCENE 2: THE SOLUTION (1550 - 1650) - Unified Hub & Teacher */}
          <div style={{
            position: 'absolute', inset: 0, display: 'flex', alignItems: 'center', justifyContent: 'center',
            opacity: frame < 1550 ? 0 : frame < 1650 ? 1 : interpolate(frame, [1650, 1660], [1, 0], {extrapolateRight: 'clamp'}),
          }}>
             
             {/* Unified Assignment Hub (Glassmorphism) */}
             <div style={{
                position: 'absolute',
                width: 160*S, height: 160*S, borderRadius: 32*S,
                background: 'linear-gradient(135deg, rgba(238,229,147,0.15), rgba(238,229,147,0.02))',
                boxShadow: 'inset 0 2px 2px rgba(238,229,147,0.4), inset 0 0 0 1px rgba(238,229,147,0.1), 0 20px 40px rgba(0,0,0,0.5)',
                backdropFilter: 'blur(30px)', WebkitBackdropFilter: 'blur(30px)',
                display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center',
                transform: \`
                  translateY(-30px)
                  scale(\${spring({ frame: Math.max(0, frame - 1550), fps, config: { damping: 12, stiffness: 200 } })})
                \`
             }}>
                <span className="material-icons" style={{ fontSize: 60*S, color: APP_TEXT_COLOR, filter: 'drop-shadow(0 2px 10px rgba(238,229,147,0.6))', marginBottom: 10*S }}>assignment</span>
                <span style={{ color: '#FFF', fontSize: 16*S, fontFamily: FONT_AR, fontWeight: 'bold' }}>منصة الواجبات</span>
             </div>

             {/* Teacher dropping document */}
             <div style={{
                position: 'absolute', left: 40*S, top: -100*S,
                display: 'flex', alignItems: 'center', gap: 20*S,
                transform: \`
                  translateY(\${interpolate(spring({ frame: Math.max(0, frame - 1560), fps }), [0, 1], [-100, 0])}px)
                  scale(\${spring({ frame: Math.max(0, frame - 1560), fps })})
                \`
             }}>
                <div style={{ width: 60*S, height: 60*S, borderRadius: '50%', background: 'linear-gradient(135deg, rgba(255,255,255,0.2), rgba(255,255,255,0.05))', boxShadow: 'inset 0 1px 2px rgba(255,255,255,0.5)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                   <span className="material-icons" style={{ fontSize: 32*S, color: '#FFF' }}>school</span>
                </div>
                {/* Document Flying into Hub */}
                <span className="material-icons" style={{ 
                   fontSize: 40*S, color: '#69F0AE',
                   position: 'absolute', left: 40*S, top: 40*S,
                   opacity: interpolate(frame, [1580, 1595], [1, 0], {extrapolateRight: 'clamp'}),
                   transform: \`
                     translate(
                        \${interpolate(spring({ frame: Math.max(0, frame - 1575), fps, config: { damping: 12 } }), [0, 1], [0, 80])}px,
                        \${interpolate(spring({ frame: Math.max(0, frame - 1575), fps, config: { damping: 12 } }), [0, 1], [0, 120])}px
                     )
                     scale(\${interpolate(frame, [1580, 1595], [1, 0.2], {extrapolateRight: 'clamp'})})
                   \`
                }}>description</span>
             </div>
             
             {/* Solution Text */}
             <div style={{ position: 'absolute', top: '70%', display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 10*S, transform: \`translateY(\${interpolate(spring({ frame: Math.max(0, frame - 1555), fps }), [0, 1], [20, 0])}px)\` }}>
                <span style={{ color: '#FFF', fontSize: 32*S, fontFamily: FONT_AR, fontWeight: 'bold' }}>نظام واجبات مدمج بالكامل</span>
                <span style={{ color: APP_TEXT_COLOR, fontSize: 20*S, fontFamily: FONT_AR }}>المعلم يرسل الواجب بضغطة زر واحدة</span>
             </div>
          </div>

          {/* SCENE 3: THE ACTION (1650 - 1750+) - Student Submitting */}
          <div style={{
            position: 'absolute', inset: 0, display: 'flex', alignItems: 'center', justifyContent: 'center',
            opacity: frame < 1650 ? 0 : 1,
          }}>
             
             {/* The Hub stays, but scales down a bit */}
             <div style={{
                position: 'absolute',
                width: 120*S, height: 120*S, borderRadius: 24*S,
                background: 'linear-gradient(135deg, rgba(238,229,147,0.15), rgba(238,229,147,0.02))',
                boxShadow: 'inset 0 2px 2px rgba(238,229,147,0.4), inset 0 0 0 1px rgba(238,229,147,0.1), 0 20px 40px rgba(0,0,0,0.5)',
                backdropFilter: 'blur(30px)', WebkitBackdropFilter: 'blur(30px)',
                display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center',
                transform: 'translateY(-30px)'
             }}>
                <span className="material-icons" style={{ fontSize: 50*S, color: APP_TEXT_COLOR, filter: 'drop-shadow(0 2px 10px rgba(238,229,147,0.6))', marginBottom: 5*S }}>assignment_turned_in</span>
             </div>

             {/* Student on left drawing/submitting */}
             <div style={{
                position: 'absolute', right: 50*S, top: -100*S,
                display: 'flex', alignItems: 'center', gap: 20*S,
                transform: \`
                  translateY(\${interpolate(spring({ frame: Math.max(0, frame - 1655), fps }), [0, 1], [-100, 0])}px)
                  scale(\${spring({ frame: Math.max(0, frame - 1655), fps })})
                \`
             }}>
                {/* Pen Drawing Animation */}
                <div style={{ position: 'absolute', right: 50*S, top: 40*S }}>
                  <span className="material-icons" style={{ 
                     fontSize: 30*S, color: '#FFF',
                     transform: \`
                       translate(
                         \${Math.sin(frame*0.5)*10}px,
                         \${Math.cos(frame*0.5)*10}px
                       )
                     \`,
                     opacity: frame > 1665 && frame < 1685 ? 1 : 0
                  }}>draw</span>
                </div>
                
                {/* Finished Document flying in */}
                <span className="material-icons" style={{ 
                   fontSize: 40*S, color: '#69F0AE',
                   position: 'absolute', right: 50*S, top: 40*S,
                   opacity: frame < 1685 ? 0 : interpolate(frame, [1690, 1705], [1, 0], {extrapolateRight: 'clamp'}),
                   transform: \`
                     translate(
                        \${interpolate(spring({ frame: Math.max(0, frame - 1685), fps, config: { damping: 12 } }), [0, 1], [0, -70])}px,
                        \${interpolate(spring({ frame: Math.max(0, frame - 1685), fps, config: { damping: 12 } }), [0, 1], [0, 130])}px
                     )
                     scale(\${interpolate(frame, [1690, 1705], [1, 0.2], {extrapolateRight: 'clamp'})})
                   \`
                }}>task</span>

                <div style={{ width: 60*S, height: 60*S, borderRadius: '50%', background: 'linear-gradient(135deg, rgba(255,255,255,0.2), rgba(255,255,255,0.05))', boxShadow: 'inset 0 1px 2px rgba(255,255,255,0.5)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                   <span className="material-icons" style={{ fontSize: 32*S, color: '#FFF' }}>person</span>
                </div>
             </div>

             {/* Action Text */}
             <div style={{ position: 'absolute', top: '70%', display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 16*S, transform: \`translateY(\${interpolate(spring({ frame: Math.max(0, frame - 1655), fps }), [0, 1], [20, 0])}px)\` }}>
                <span style={{ color: '#FFF', fontSize: 32*S, fontFamily: FONT_AR, fontWeight: 'bold' }}>حل وتسليم فوري للمهام</span>
                <span style={{ 
                   color: '#69F0AE', fontSize: 20*S, fontFamily: FONT_AR, fontWeight: 'bold',
                   background: 'linear-gradient(135deg, rgba(105, 240, 174, 0.2), rgba(105, 240, 174, 0.05))', 
                   padding: \`12px \${30*S}px\`, borderRadius: 24*S, border: '1px solid rgba(105, 240, 174, 0.4)',
                   boxShadow: 'inset 0 1px 1px rgba(105, 240, 174, 0.4)', backdropFilter: 'blur(10px)',
                   transform: \`scale(\${interpolate(spring({ frame: Math.max(0, frame - 1690), fps, config: { damping: 8, stiffness: 300 } }), [0, 1], [2, 1])})\`,
                   opacity: frame >= 1690 ? 1 : 0
                }}>دون الحاجة لأي تطبيقات خارجية</span>
             </div>
          </div>
        </div>
      )}
`;

content = content.replace(insertMarker, homeworkBlock + '\n' + insertMarker);

fs.writeFileSync(file, content);
console.log("Homework added successfully!");
