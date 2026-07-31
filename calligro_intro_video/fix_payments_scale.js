const fs = require('fs');
const file = '/Users/yazanqattous/Desktop/flutter_projects/calligro_app/calligro_intro_video/src/Intro.tsx';
let content = fs.readFileSync(file, 'utf8');

const startMarker = `      {/* ═══════════════════════════════════════════════════════════════════════════════ */}
      {/* PAYMENT SYSTEMS NARRATIVE: THE HOLOGRAPHIC 3D CARD                          */}`;
const endMarker = `    </AbsoluteFill>`;

const startIndex = content.indexOf(startMarker);
const endIndex = content.indexOf(endMarker);

if (startIndex !== -1 && endIndex !== -1) {
  const paymentBlock = `      {/* ═══════════════════════════════════════════════════════════════════════════════ */}
      {/* PAYMENT SYSTEMS NARRATIVE: THE HOLOGRAPHIC 3D CARD                          */}
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
          
          <div style={{ position: 'relative', width: 300*S, height: 300*S, display: 'flex', alignItems: 'center', justifyContent: 'center', perspective: '1200px' }}>
             
             {/* 3D Holographic Card (SCALED DOWN & ENHANCED) */}
             <div style={{
                position: 'absolute',
                width: 160*S, height: 100*S, borderRadius: 12*S,
                background: 'linear-gradient(135deg, rgba(30,30,40,0.8), rgba(10,10,15,0.9))',
                boxShadow: 'inset 0 1px 1px rgba(255,255,255,0.3), inset 0 0 0 1px rgba(255,255,255,0.1), 0 20px 40px rgba(0,0,0,0.9), 0 0 60px rgba(0,122,255,0.2)',
                backdropFilter: 'blur(30px)', WebkitBackdropFilter: 'blur(30px)',
                display: 'flex', flexDirection: 'column', padding: 12*S,
                transformStyle: 'preserve-3d',
                transform: \`
                  translateY(-20px)
                  rotateX(\${interpolate(spring({ frame: Math.max(0, frame - 1750), fps, config: { damping: 14 } }), [0, 1], [80, 25])}deg)
                  rotateY(\${interpolate(frame, [1750, 2200], [-25, 25])}deg)
                  scale(\${spring({ frame: Math.max(0, frame - 1750), fps, config: { damping: 12 } })})
                \`
             }}>
                 {/* Premium Light Sweep Reflection */}
                 <div style={{
                    position: 'absolute', top: 0, bottom: 0, left: '-50%', width: '30%',
                    background: 'linear-gradient(90deg, rgba(255,255,255,0) 0%, rgba(255,255,255,0.2) 50%, rgba(255,255,255,0) 100%)',
                    transform: \`translateX(\${interpolate(frame, [1780, 1830], [0, 400])}%) skewX(-20deg)\`,
                    opacity: interpolate(frame, [1780, 1805, 1830], [0, 1, 0], {extrapolateRight: 'clamp', extrapolateLeft: 'clamp'})
                 }} />

                 {/* Card Chip */}
                 <div style={{ width: 22*S, height: 16*S, borderRadius: 4*S, background: 'linear-gradient(135deg, #FFD700, #FDB931)', boxShadow: 'inset 0 1px 1px rgba(255,255,255,0.8), 0 1px 2px rgba(0,0,0,0.5)', transform: 'translateZ(1px)' }} />
                 {/* Contactless Icon */}
                 <span className="material-icons" style={{ position: 'absolute', top: 12*S, right: 10*S, color: '#FFF', fontSize: 18*S, transform: 'rotate(90deg) translateZ(1px)', opacity: 0.6 }}>wifi</span>
                 
                 {/* Card Number */}
                 <div style={{ marginTop: 'auto', display: 'flex', gap: 8*S, color: '#FFF', fontSize: 12*S, fontFamily: FONT_BRAND, letterSpacing: 2*S, textShadow: '0 1px 2px rgba(0,0,0,0.8)', opacity: 0.9, transform: 'translateZ(1px)' }}>
                    <span>****</span><span>****</span><span>****</span><span>1234</span>
                 </div>
                 
                 {/* Card Holder */}
                 <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: 8*S, color: '#FFF', opacity: 0.7, fontSize: 7*S, fontFamily: FONT_AR, textTransform: 'uppercase', letterSpacing: 1*S, transform: 'translateZ(1px)' }}>
                    <span>CALLIGRO SECURE</span>
                    <span>12/28</span>
                 </div>

                 {/* Holographic Logos projecting in 3D */}
                 {/* Apple Pay (Top Left) */}
                 <div style={{
                    position: 'absolute', top: -30*S, left: -20*S,
                    transform: \`translateZ(\${interpolate(spring({ frame: Math.max(0, frame - 1780), fps, config: { damping: 10 } }), [0, 1], [0, 60])}px) scale(\${spring({ frame: Math.max(0, frame - 1780), fps })})\`,
                    opacity: frame >= 1780 ? 1 : 0
                 }}>
                    <Img src={staticFile('applepay.svg')} style={{ width: 40*S, height: 40*S, filter: 'drop-shadow(0 4px 10px rgba(0,0,0,0.8)) drop-shadow(0 0 8px rgba(255,255,255,0.8)) invert(1)' }} />
                 </div>
                 
                 {/* Google Pay (Top Right) */}
                 <div style={{
                    position: 'absolute', top: -25*S, right: -20*S,
                    transform: \`translateZ(\${interpolate(spring({ frame: Math.max(0, frame - 1800), fps, config: { damping: 10 } }), [0, 1], [0, 50])}px) scale(\${spring({ frame: Math.max(0, frame - 1800), fps })})\`,
                    opacity: frame >= 1800 ? 1 : 0
                 }}>
                    <Img src={staticFile('googlepay.svg')} style={{ width: 40*S, height: 40*S, filter: 'drop-shadow(0 4px 10px rgba(0,0,0,0.8)) drop-shadow(0 0 8px rgba(255,255,255,0.8)) invert(1)' }} />
                 </div>
                 
                 {/* Visa (Bottom Right) */}
                 <div style={{
                    position: 'absolute', bottom: -20*S, right: -30*S,
                    transform: \`translateZ(\${interpolate(spring({ frame: Math.max(0, frame - 1820), fps, config: { damping: 10 } }), [0, 1], [0, 70])}px) scale(\${spring({ frame: Math.max(0, frame - 1820), fps })})\`,
                    opacity: frame >= 1820 ? 1 : 0
                 }}>
                    <Img src={staticFile('visa.svg')} style={{ width: 50*S, height: 50*S, filter: 'drop-shadow(0 4px 10px rgba(0,0,0,0.8)) drop-shadow(0 0 8px rgba(255,255,255,0.8)) invert(1)' }} />
                 </div>
                 
                 {/* PayPal (Bottom Left) */}
                 <div style={{
                    position: 'absolute', bottom: -25*S, left: -20*S,
                    transform: \`translateZ(\${interpolate(spring({ frame: Math.max(0, frame - 1840), fps, config: { damping: 10 } }), [0, 1], [0, 80])}px) scale(\${spring({ frame: Math.max(0, frame - 1840), fps })})\`,
                    opacity: frame >= 1840 ? 1 : 0
                 }}>
                    <Img src={staticFile('paypal.svg')} style={{ width: 35*S, height: 35*S, filter: 'drop-shadow(0 4px 10px rgba(0,0,0,0.8)) drop-shadow(0 0 8px rgba(255,255,255,0.8)) invert(1)' }} />
                 </div>
                 
                 {/* Green Approval Scanner Ring */}
                 {frame >= 1880 && (
                   <div style={{
                      position: 'absolute', inset: -20*S, borderRadius: 20*S,
                      boxShadow: 'inset 0 0 0 2px rgba(105,240,174,0.9), 0 0 30px rgba(105,240,174,0.6)',
                      transform: \`translateZ(10px) scale(\${interpolate(frame, [1880, 1910], [0.8, 2.5], {extrapolateRight: 'clamp', extrapolateLeft: 'clamp'})})\`,
                      opacity: interpolate(frame, [1880, 1890, 1910], [0, 1, 0], {extrapolateRight: 'clamp', extrapolateLeft: 'clamp'})
                   }} />
                 )}
                 {/* Big Green Checkmark on the card */}
                 {frame >= 1880 && (
                   <div style={{ position: 'absolute', inset: 0, display: 'flex', alignItems: 'center', justifyContent: 'center', transform: 'translateZ(90px)' }}>
                     <span className="material-icons" style={{ 
                        color: '#69F0AE', fontSize: 60*S, 
                        filter: 'drop-shadow(0 5px 15px rgba(0,0,0,0.8)) drop-shadow(0 0 15px rgba(105,240,174,0.9))',
                        opacity: interpolate(frame, [1880, 1885, 1900, 1920], [0, 1, 1, 0], {extrapolateRight: 'clamp', extrapolateLeft: 'clamp'}),
                        transform: \`scale(\${interpolate(spring({ frame: Math.max(0, frame - 1880), fps, config: { damping: 8, stiffness: 400 } }), [0, 1], [0, 1])})\`
                     }}>check_circle</span>
                   </div>
                 )}
             </div>
             
          </div>
          
          {/* Action Text */}
          <div style={{ position: 'absolute', top: '75%', display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 16*S, transform: \`translateY(\${interpolate(spring({ frame: Math.max(0, frame - 1760), fps }), [0, 1], [20, 0])}px)\` }}>
             <span style={{ color: '#FFF', fontSize: 32*S, fontFamily: FONT_AR, fontWeight: 'bold', filter: 'drop-shadow(0 4px 10px rgba(0,0,0,0.5))' }}>بوابات دفع متعددة وآمنة</span>
             <span style={{ 
                color: '#69F0AE', fontSize: 20*S, fontFamily: FONT_AR, fontWeight: 'bold',
                background: 'linear-gradient(135deg, rgba(105, 240, 174, 0.2), rgba(105, 240, 174, 0.05))', 
                padding: \`12px \${30*S}px\`, borderRadius: 24*S, border: '1px solid rgba(105, 240, 174, 0.4)',
                boxShadow: 'inset 0 1px 1px rgba(105, 240, 174, 0.4)', backdropFilter: 'blur(10px)', WebkitBackdropFilter: 'blur(10px)',
                transform: \`scale(\${interpolate(spring({ frame: Math.max(0, frame - 1900), fps, config: { damping: 8, stiffness: 300 } }), [0, 1], [2, 1])})\`,
                opacity: frame >= 1900 ? 1 : 0
             }}>ادفع واستقبل بكل سهولة من أي مكان</span>
          </div>
          
        </div>
      )}
\n`;

  const newContent = content.substring(0, startIndex) + paymentBlock + content.substring(endIndex);
  fs.writeFileSync(file, newContent);
  console.log("3D Hologram Card scaled properly!");
} else {
  console.log("Could not find markers!");
}
