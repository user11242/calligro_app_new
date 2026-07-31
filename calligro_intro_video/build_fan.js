const fs = require('fs');
const file = '/Users/yazanqattous/Desktop/flutter_projects/calligro_app/calligro_intro_video/src/Intro.tsx';
let content = fs.readFileSync(file, 'utf8');

const startMarker = `      {/* ═══════════════════════════════════════════════════════════════════════════════ */}
      {/* PAYMENT SYSTEMS NARRATIVE: SEAMLESS CHECKOUT GRID                             */}`;
const endMarker = `    </AbsoluteFill>`;

const startIndex = content.indexOf(startMarker);
const endIndex = content.lastIndexOf(endMarker);

if (startIndex !== -1 && endIndex !== -1) {
  const paymentBlock = `      {/* ═══════════════════════════════════════════════════════════════════════════════ */}
      {/* PAYMENT SYSTEMS NARRATIVE: THE APPLE WALLET FAN                             */}
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
          
          {/* THE WALLET FAN (1750+) */}
          <div style={{ position: 'relative', width: 300*S, height: 400*S, display: 'flex', justifyContent: 'center', alignItems: 'center' }}>
             
             {/* 1. PayPal (Bottom, Blue Holographic) */}
             <div style={{
                position: 'absolute', width: 260*S, height: 160*S, borderRadius: 16*S,
                background: 'linear-gradient(135deg, #003087 0%, #009cde 100%)',
                boxShadow: 'inset 0 1px 1px rgba(255,255,255,0.4), 0 10px 30px rgba(0,0,0,0.6)',
                transformOrigin: 'bottom center',
                transform: \`
                  translateY(\${interpolate(spring({ frame: Math.max(0, frame - 1750), fps, config: { damping: 14 } }), [0, 1], [400, 0])}px)
                  rotateZ(\${interpolate(spring({ frame: Math.max(0, frame - 1770), fps, config: { damping: 12 } }), [0, 1], [0, -18])}deg)
                \`,
                zIndex: 1, display: 'flex', flexDirection: 'column', padding: 20*S
             }}>
                <Img src={staticFile('paypal.svg')} style={{ width: 80*S, filter: 'drop-shadow(0 2px 4px rgba(0,0,0,0.3)) invert(1)' }} />
                <div style={{ marginTop: 'auto', display: 'flex', gap: 10*S, color: '#FFF', fontSize: 16*S, fontFamily: FONT_BRAND, letterSpacing: 2*S, opacity: 0.9 }}>
                   <span>****</span><span>****</span><span>****</span><span>5678</span>
                </div>
             </div>

             {/* 2. Google Pay (Middle Low, Frosted White) */}
             <div style={{
                position: 'absolute', width: 260*S, height: 160*S, borderRadius: 16*S,
                background: 'linear-gradient(135deg, rgba(255,255,255,0.9), rgba(240,240,245,1))',
                boxShadow: 'inset 0 1px 1px #FFF, 0 15px 40px rgba(0,0,0,0.7)',
                transformOrigin: 'bottom center',
                transform: \`
                  translateY(\${interpolate(spring({ frame: Math.max(0, frame - 1760), fps, config: { damping: 14 } }), [0, 1], [400, -20])}px)
                  rotateZ(\${interpolate(spring({ frame: Math.max(0, frame - 1785), fps, config: { damping: 12 } }), [0, 1], [0, -6])}deg)
                \`,
                zIndex: 2, display: 'flex', flexDirection: 'column', padding: 20*S
             }}>
                <Img src={staticFile('googlepay.svg')} style={{ width: 60*S, filter: 'drop-shadow(0 2px 4px rgba(0,0,0,0.1))' }} />
                <div style={{ marginTop: 'auto', display: 'flex', gap: 10*S, color: '#111', fontSize: 16*S, fontFamily: FONT_BRAND, letterSpacing: 2*S, opacity: 0.9 }}>
                   <span>****</span><span>****</span><span>****</span><span>9012</span>
                </div>
             </div>

             {/* 3. Visa (Middle High, Midnight Blue/Gold) */}
             <div style={{
                position: 'absolute', width: 260*S, height: 160*S, borderRadius: 16*S,
                background: 'linear-gradient(135deg, #1A1F36 0%, #0F1322 100%)',
                boxShadow: 'inset 0 1px 1px rgba(255,255,255,0.2), 0 20px 50px rgba(0,0,0,0.8)',
                transformOrigin: 'bottom center',
                transform: \`
                  translateY(\${interpolate(spring({ frame: Math.max(0, frame - 1770), fps, config: { damping: 14 } }), [0, 1], [400, -40])}px)
                  rotateZ(\${interpolate(spring({ frame: Math.max(0, frame - 1800), fps, config: { damping: 12 } }), [0, 1], [0, 6])}deg)
                \`,
                zIndex: 3, display: 'flex', flexDirection: 'column', padding: 20*S
             }}>
                <Img src={staticFile('visa.svg')} style={{ width: 70*S, filter: 'drop-shadow(0 2px 4px rgba(0,0,0,0.5)) invert(1)' }} />
                <div style={{ marginTop: 'auto', display: 'flex', gap: 10*S, color: '#D4AF37', fontSize: 16*S, fontFamily: FONT_BRAND, letterSpacing: 2*S, opacity: 0.9 }}>
                   <span>****</span><span>****</span><span>****</span><span>3456</span>
                </div>
             </div>

             {/* 4. Apple Pay (Top, Matte Black Titanium) */}
             <div style={{
                position: 'absolute', width: 260*S, height: 160*S, borderRadius: 16*S,
                background: 'linear-gradient(135deg, #222 0%, #000 100%)',
                boxShadow: 'inset 0 1px 1px rgba(255,255,255,0.1), 0 30px 60px rgba(0,0,0,0.9)',
                border: '1px solid rgba(255,255,255,0.05)',
                transformOrigin: 'bottom center',
                transform: \`
                  translateY(\${interpolate(spring({ frame: Math.max(0, frame - 1780), fps, config: { damping: 14 } }), [0, 1], [400, -60])}px)
                  rotateZ(\${interpolate(spring({ frame: Math.max(0, frame - 1815), fps, config: { damping: 12 } }), [0, 1], [0, 18])}deg)
                \`,
                zIndex: 4, display: 'flex', flexDirection: 'column', padding: 20*S
             }}>
                <Img src={staticFile('applepay.svg')} style={{ width: 60*S, filter: 'drop-shadow(0 2px 4px rgba(0,0,0,0.5)) invert(1)' }} />
                <div style={{ marginTop: 'auto', display: 'flex', gap: 10*S, color: '#FFF', fontSize: 16*S, fontFamily: FONT_BRAND, letterSpacing: 2*S, opacity: 0.9 }}>
                   <span>****</span><span>****</span><span>****</span><span>1234</span>
                </div>
             </div>

             {/* Secure Badge Stamp */}
             {frame >= 1840 && (
                <div style={{
                   position: 'absolute', zIndex: 10,
                   width: 100*S, height: 100*S, borderRadius: 50*S,
                   background: 'rgba(20, 20, 26, 0.8)',
                   backdropFilter: 'blur(20px)', WebkitBackdropFilter: 'blur(20px)',
                   border: '2px solid rgba(105, 240, 174, 0.5)',
                   boxShadow: '0 10px 30px rgba(0,0,0,0.8), 0 0 60px rgba(105, 240, 174, 0.3)',
                   display: 'flex', alignItems: 'center', justifyContent: 'center',
                   transform: \`translateY(-40px) scale(\${interpolate(spring({ frame: Math.max(0, frame - 1840), fps, config: { damping: 10, stiffness: 250 } }), [0, 1], [3, 1])})\`,
                   opacity: interpolate(frame, [1840, 1845], [0, 1], {extrapolateRight: 'clamp'})
                }}>
                   <span className="material-icons" style={{ color: '#69F0AE', fontSize: 60*S, filter: 'drop-shadow(0 2px 10px rgba(105, 240, 174, 0.8))' }}>verified_user</span>
                   
                   {/* Shockwave */}
                   <div style={{
                      position: 'absolute', inset: 0, borderRadius: 50*S,
                      border: '4px solid #69F0AE',
                      transform: \`scale(\${interpolate(frame, [1845, 1865], [1, 2.5], {extrapolateRight: 'clamp', extrapolateLeft: 'clamp'})})\`,
                      opacity: interpolate(frame, [1845, 1855, 1865], [0, 1, 0], {extrapolateRight: 'clamp', extrapolateLeft: 'clamp'})
                   }} />
                </div>
             )}
          </div>
          
          {/* Action Text */}
          <div style={{ position: 'absolute', top: '75%', display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 16*S, transform: \`translateY(\${interpolate(spring({ frame: Math.max(0, frame - 1800), fps }), [0, 1], [20, 0])}px)\` }}>
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
  console.log("Wallet Fan Layout created successfully!");
} else {
  console.log("Could not find markers!");
}
