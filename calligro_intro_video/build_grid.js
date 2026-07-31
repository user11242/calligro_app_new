const fs = require('fs');
const file = '/Users/yazanqattous/Desktop/flutter_projects/calligro_app/calligro_intro_video/src/Intro.tsx';
let content = fs.readFileSync(file, 'utf8');

const startMarker = `      {/* ═══════════════════════════════════════════════════════════════════════════════ */}
      {/* PAYMENT SYSTEMS NARRATIVE: THE HOLOGRAPHIC 3D CARD                          */}`;
const endMarker = `    </AbsoluteFill>`;

const startIndex = content.indexOf(startMarker);
const endIndex = content.lastIndexOf(endMarker);

if (startIndex !== -1 && endIndex !== -1) {
  const paymentBlock = `      {/* ═══════════════════════════════════════════════════════════════════════════════ */}
      {/* PAYMENT SYSTEMS NARRATIVE: SEAMLESS CHECKOUT GRID                             */}
      {/* ═══════════════════════════════════════════════════════════════════════════════ */}
      {frame >= 1750 && (
        <div style={{
          position: 'absolute', inset: 0,
          background: 'linear-gradient(180deg, rgba(8,8,8,0.95), rgba(20,20,26,0.95))',
          display: 'flex', flexDirection: 'column',
          alignItems: 'center', justifyContent: 'center',
          opacity: interpolate(frame, [1750, 1770], [0, 1], {extrapolateRight: 'clamp'}),
          zIndex: 500
        }}>
          
          <div style={{ position: 'relative', width: '100%', height: 500*S, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center' }}>
             
             {/* THE PHONE OUTLINE & CHECKOUT BUTTON (1750 - 1800) */}
             <div style={{
                position: 'absolute',
                width: 140*S, height: 280*S, borderRadius: 24*S,
                border: '2px solid rgba(255,255,255,0.2)',
                background: 'linear-gradient(180deg, rgba(255,255,255,0.05), rgba(255,255,255,0.01))',
                boxShadow: '0 0 40px rgba(0,122,255,0.1)',
                display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'flex-end', paddingBottom: 20*S,
                opacity: frame < 1795 ? 1 : interpolate(frame, [1795, 1805], [1, 0], {extrapolateRight: 'clamp'}),
                transform: \`scale(\${interpolate(frame, [1790, 1810], [1, 1.5], {extrapolateRight: 'clamp', extrapolateLeft: 'clamp'})})\`
             }}>
                {/* Checkout Button */}
                <div style={{
                   width: 100*S, height: 30*S, borderRadius: 15*S, background: '#007AFF',
                   display: 'flex', alignItems: 'center', justifyContent: 'center',
                   boxShadow: '0 4px 10px rgba(0,122,255,0.5)',
                   transform: \`scale(\${interpolate(frame, [1785, 1790, 1795], [1, 0.9, 1.1], {extrapolateRight: 'clamp', extrapolateLeft: 'clamp'})})\`
                }}>
                   <span style={{color: '#FFF', fontSize: 12*S, fontFamily: FONT_AR, fontWeight: 'bold'}}>دفع</span>
                </div>
                {/* Cursor Click */}
                <span className="material-icons" style={{
                   position: 'absolute', bottom: 10*S, right: 30*S, color: '#FFF', fontSize: 24*S,
                   filter: 'drop-shadow(0 2px 4px rgba(0,0,0,0.5))',
                   opacity: frame < 1795 ? 1 : 0,
                   transform: \`translate(\${interpolate(spring({ frame: Math.max(0, frame - 1760), fps }), [0, 1], [50, 0])}px, \${interpolate(spring({ frame: Math.max(0, frame - 1760), fps }), [0, 1], [50, 0])}px)\`
                }}>touch_app</span>
             </div>

             {/* THE 2x2 GRID EXPLOSION (1800+) */}
             <div style={{
                position: 'absolute',
                display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 20*S,
                opacity: frame >= 1800 ? 1 : 0
             }}>
                
                {/* 1. Apple Pay (Top Left) */}
                <div style={{
                   width: 140*S, height: 140*S, borderRadius: 30*S,
                   background: 'linear-gradient(135deg, rgba(255,255,255,0.1), rgba(255,255,255,0.02))',
                   boxShadow: 'inset 0 2px 2px rgba(255,255,255,0.3), inset 0 0 0 1px rgba(255,255,255,0.1), 0 20px 40px rgba(0,0,0,0.5)',
                   backdropFilter: 'blur(20px)', WebkitBackdropFilter: 'blur(20px)',
                   display: 'flex', alignItems: 'center', justifyContent: 'center', overflow: 'hidden', position: 'relative',
                   transform: \`scale(\${spring({ frame: Math.max(0, frame - 1800), fps, config: { damping: 12 } })})\`
                }}>
                   <Img src={staticFile('applepay.svg')} style={{ width: 70*S, height: 70*S, filter: 'drop-shadow(0 4px 10px rgba(255,255,255,0.3)) invert(1)' }} />
                   {/* Light Sweep */}
                   <div style={{ position: 'absolute', inset: 0, background: 'linear-gradient(135deg, rgba(255,255,255,0) 30%, rgba(255,255,255,0.4) 50%, rgba(255,255,255,0) 70%)', transform: \`translateX(\${interpolate(frame, [1830, 1860], [-150, 150])}%)\` }} />
                </div>
                
                {/* 2. Google Pay (Top Right) */}
                <div style={{
                   width: 140*S, height: 140*S, borderRadius: 30*S,
                   background: 'linear-gradient(135deg, rgba(255,255,255,0.1), rgba(255,255,255,0.02))',
                   boxShadow: 'inset 0 2px 2px rgba(255,255,255,0.3), inset 0 0 0 1px rgba(255,255,255,0.1), 0 20px 40px rgba(0,0,0,0.5)',
                   backdropFilter: 'blur(20px)', WebkitBackdropFilter: 'blur(20px)',
                   display: 'flex', alignItems: 'center', justifyContent: 'center', overflow: 'hidden', position: 'relative',
                   transform: \`scale(\${spring({ frame: Math.max(0, frame - 1805), fps, config: { damping: 12 } })})\`
                }}>
                   <Img src={staticFile('googlepay.svg')} style={{ width: 70*S, height: 70*S, filter: 'drop-shadow(0 4px 10px rgba(255,255,255,0.3)) invert(1)' }} />
                   {/* Light Sweep */}
                   <div style={{ position: 'absolute', inset: 0, background: 'linear-gradient(135deg, rgba(255,255,255,0) 30%, rgba(255,255,255,0.4) 50%, rgba(255,255,255,0) 70%)', transform: \`translateX(\${interpolate(frame, [1835, 1865], [-150, 150])}%)\` }} />
                </div>
                
                {/* 3. Visa (Bottom Left) */}
                <div style={{
                   width: 140*S, height: 140*S, borderRadius: 30*S,
                   background: 'linear-gradient(135deg, rgba(255,255,255,0.1), rgba(255,255,255,0.02))',
                   boxShadow: 'inset 0 2px 2px rgba(255,255,255,0.3), inset 0 0 0 1px rgba(255,255,255,0.1), 0 20px 40px rgba(0,0,0,0.5)',
                   backdropFilter: 'blur(20px)', WebkitBackdropFilter: 'blur(20px)',
                   display: 'flex', alignItems: 'center', justifyContent: 'center', overflow: 'hidden', position: 'relative',
                   transform: \`scale(\${spring({ frame: Math.max(0, frame - 1810), fps, config: { damping: 12 } })})\`
                }}>
                   <Img src={staticFile('visa.svg')} style={{ width: 80*S, height: 80*S, filter: 'drop-shadow(0 4px 10px rgba(255,255,255,0.3)) invert(1)' }} />
                   {/* Light Sweep */}
                   <div style={{ position: 'absolute', inset: 0, background: 'linear-gradient(135deg, rgba(255,255,255,0) 30%, rgba(255,255,255,0.4) 50%, rgba(255,255,255,0) 70%)', transform: \`translateX(\${interpolate(frame, [1840, 1870], [-150, 150])}%)\` }} />
                </div>
                
                {/* 4. PayPal (Bottom Right) */}
                <div style={{
                   width: 140*S, height: 140*S, borderRadius: 30*S,
                   background: 'linear-gradient(135deg, rgba(255,255,255,0.1), rgba(255,255,255,0.02))',
                   boxShadow: 'inset 0 2px 2px rgba(255,255,255,0.3), inset 0 0 0 1px rgba(255,255,255,0.1), 0 20px 40px rgba(0,0,0,0.5)',
                   backdropFilter: 'blur(20px)', WebkitBackdropFilter: 'blur(20px)',
                   display: 'flex', alignItems: 'center', justifyContent: 'center', overflow: 'hidden', position: 'relative',
                   transform: \`scale(\${spring({ frame: Math.max(0, frame - 1815), fps, config: { damping: 12 } })})\`
                }}>
                   <Img src={staticFile('paypal.svg')} style={{ width: 60*S, height: 60*S, filter: 'drop-shadow(0 4px 10px rgba(255,255,255,0.3)) invert(1)' }} />
                   {/* Light Sweep */}
                   <div style={{ position: 'absolute', inset: 0, background: 'linear-gradient(135deg, rgba(255,255,255,0) 30%, rgba(255,255,255,0.4) 50%, rgba(255,255,255,0) 70%)', transform: \`translateX(\${interpolate(frame, [1845, 1875], [-150, 150])}%)\` }} />
                </div>
                
             </div>

          </div>
          
          {/* Action Text */}
          <div style={{ position: 'absolute', top: '75%', display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 16*S, transform: \`translateY(\${interpolate(spring({ frame: Math.max(0, frame - 1810), fps }), [0, 1], [20, 0])}px)\` }}>
             <span style={{ color: '#FFF', fontSize: 32*S, fontFamily: FONT_AR, fontWeight: 'bold', filter: 'drop-shadow(0 4px 10px rgba(0,0,0,0.5))' }}>بوابات دفع متعددة وآمنة</span>
             <span style={{ 
                color: '#69F0AE', fontSize: 20*S, fontFamily: FONT_AR, fontWeight: 'bold',
                background: 'linear-gradient(135deg, rgba(105, 240, 174, 0.2), rgba(105, 240, 174, 0.05))', 
                padding: \`12px \${30*S}px\`, borderRadius: 24*S, border: '1px solid rgba(105, 240, 174, 0.4)',
                boxShadow: 'inset 0 1px 1px rgba(105, 240, 174, 0.4)', backdropFilter: 'blur(10px)', WebkitBackdropFilter: 'blur(10px)',
                transform: \`scale(\${interpolate(spring({ frame: Math.max(0, frame - 1880), fps, config: { damping: 8, stiffness: 300 } }), [0, 1], [2, 1])})\`,
                opacity: frame >= 1880 ? 1 : 0
             }}>ادفع واستقبل بكل سهولة من أي مكان</span>
          </div>
          
        </div>
      )}
\n`;

  const newContent = content.substring(0, startIndex) + paymentBlock + content.substring(endIndex);
  fs.writeFileSync(file, newContent);
  console.log("Grid layout created successfully!");
} else {
  console.log("Could not find markers!");
}
