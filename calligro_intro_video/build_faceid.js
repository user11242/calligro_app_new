const fs = require('fs');
const file = '/Users/yazanqattous/Desktop/flutter_projects/calligro_app/calligro_intro_video/src/Intro.tsx';
let content = fs.readFileSync(file, 'utf8');

const startMarker = `      {/* ═══════════════════════════════════════════════════════════════════════════════ */}
      {/* PAYMENT SYSTEMS NARRATIVE: THE APPLE WALLET FAN                             */}`;
const endMarker = `    </AbsoluteFill>`;

const startIndex = content.indexOf(startMarker);
const endIndex = content.lastIndexOf(endMarker);

if (startIndex !== -1 && endIndex !== -1) {
  const paymentBlock = `      {/* ═══════════════════════════════════════════════════════════════════════════════ */}
      {/* PAYMENT SYSTEMS NARRATIVE: THE FACEID CHECKOUT                              */}
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
             
             {/* 1. THE PHONE OUTLINE & DOUBLE CLICK (1750 - 1790) */}
             <div style={{
                position: 'absolute',
                width: 140*S, height: 280*S, borderRadius: 24*S,
                border: '2px solid rgba(255,255,255,0.2)',
                background: 'rgba(255,255,255,0.02)',
                boxShadow: '0 0 40px rgba(0,122,255,0.1)',
                display: 'flex', alignItems: 'center', justifyContent: 'center',
                opacity: frame < 1790 ? 1 : interpolate(frame, [1790, 1800], [1, 0], {extrapolateRight: 'clamp'}),
                transform: \`scale(\${interpolate(frame, [1785, 1800], [1, 1.5], {extrapolateRight: 'clamp', extrapolateLeft: 'clamp'})})\`
             }}>
                {/* The Side Button */}
                <div style={{
                   position: 'absolute', right: -6*S, top: 60*S, width: 4*S, height: 40*S, borderRadius: 2*S,
                   background: '#007AFF',
                   boxShadow: interpolate(frame, [1770, 1775, 1780, 1785], [0, 1, 0, 1], {extrapolateRight: 'clamp', extrapolateLeft: 'clamp'}) === 1 ? '0 0 20px #007AFF' : 'none',
                   transform: \`translateX(\${interpolate(frame, [1770, 1775, 1780, 1785], [0, -2, 0, -2], {extrapolateRight: 'clamp', extrapolateLeft: 'clamp'})}px)\`
                }} />
                
                {/* Screen Content Before Click */}
                <span className="material-icons" style={{ color: 'rgba(255,255,255,0.3)', fontSize: 40*S }}>credit_card</span>

                {/* Cursor Double Click */}
                <span className="material-icons" style={{
                   position: 'absolute', right: -30*S, top: 60*S, color: '#FFF', fontSize: 24*S,
                   filter: 'drop-shadow(0 2px 4px rgba(0,0,0,0.5))',
                   opacity: frame < 1790 ? 1 : 0,
                   transform: \`translate(\${interpolate(spring({ frame: Math.max(0, frame - 1760), fps }), [0, 1], [50, 0])}px, \${interpolate(frame, [1770, 1775, 1780, 1785], [0, -5, 0, -5], {extrapolateRight: 'clamp', extrapolateLeft: 'clamp'})}px)\`
                }}>touch_app</span>
             </div>

             {/* 2. THE WALLET SHEET & CARDS FAN (1790+) */}
             <div style={{
                position: 'absolute',
                width: 320*S, height: 420*S, borderRadius: 32*S,
                background: 'linear-gradient(180deg, rgba(30,30,35,0.95), rgba(15,15,20,0.95))',
                boxShadow: '0 30px 60px rgba(0,0,0,0.8), inset 0 1px 1px rgba(255,255,255,0.1)',
                display: 'flex', justifyContent: 'center', alignItems: 'center',
                opacity: frame >= 1790 ? interpolate(frame, [1790, 1800], [0, 1], {extrapolateRight: 'clamp'}) : 0,
                transform: \`scale(\${spring({ frame: Math.max(0, frame - 1790), fps, config: { damping: 14 } })})\`
             }}>
                
                {/* THE WALLET FAN (1800+) */}
                <div style={{ position: 'relative', width: '100%', height: '100%', display: 'flex', justifyContent: 'center', alignItems: 'flex-end', paddingBottom: 40*S }}>
                   
                   {/* 1. PayPal (Bottom, Blue Holographic) */}
                   <div style={{
                      position: 'absolute', width: 220*S, height: 140*S, borderRadius: 16*S,
                      background: 'linear-gradient(135deg, #003087 0%, #009cde 100%)',
                      boxShadow: 'inset 0 1px 1px rgba(255,255,255,0.4), 0 10px 30px rgba(0,0,0,0.6)',
                      transformOrigin: 'bottom center',
                      transform: \`
                        translateY(\${interpolate(spring({ frame: Math.max(0, frame - 1800), fps, config: { damping: 14 } }), [0, 1], [400, 0])}px)
                        rotateZ(\${interpolate(spring({ frame: Math.max(0, frame - 1820), fps, config: { damping: 12 } }), [0, 1], [0, -18])}deg)
                      \`,
                      zIndex: 1, display: 'flex', flexDirection: 'column', padding: 16*S
                   }}>
                      <Img src={staticFile('paypal.svg')} style={{ width: 60*S, filter: 'drop-shadow(0 2px 4px rgba(0,0,0,0.3)) invert(1)' }} />
                      <div style={{ marginTop: 'auto', display: 'flex', gap: 8*S, color: '#FFF', fontSize: 14*S, fontFamily: FONT_BRAND, letterSpacing: 2*S, opacity: 0.9 }}>
                         <span>****</span><span>****</span><span>****</span><span>5678</span>
                      </div>
                   </div>

                   {/* 2. Google Pay (Middle Low, Frosted White) */}
                   <div style={{
                      position: 'absolute', width: 220*S, height: 140*S, borderRadius: 16*S,
                      background: 'linear-gradient(135deg, rgba(255,255,255,0.9), rgba(240,240,245,1))',
                      boxShadow: 'inset 0 1px 1px #FFF, 0 15px 40px rgba(0,0,0,0.7)',
                      transformOrigin: 'bottom center',
                      transform: \`
                        translateY(\${interpolate(spring({ frame: Math.max(0, frame - 1810), fps, config: { damping: 14 } }), [0, 1], [400, -20])}px)
                        rotateZ(\${interpolate(spring({ frame: Math.max(0, frame - 1830), fps, config: { damping: 12 } }), [0, 1], [0, -6])}deg)
                      \`,
                      zIndex: 2, display: 'flex', flexDirection: 'column', padding: 16*S
                   }}>
                      <Img src={staticFile('googlepay.svg')} style={{ width: 50*S, filter: 'drop-shadow(0 2px 4px rgba(0,0,0,0.1))' }} />
                      <div style={{ marginTop: 'auto', display: 'flex', gap: 8*S, color: '#111', fontSize: 14*S, fontFamily: FONT_BRAND, letterSpacing: 2*S, opacity: 0.9 }}>
                         <span>****</span><span>****</span><span>****</span><span>9012</span>
                      </div>
                   </div>

                   {/* 3. Visa (Middle High, Midnight Blue/Gold) */}
                   <div style={{
                      position: 'absolute', width: 220*S, height: 140*S, borderRadius: 16*S,
                      background: 'linear-gradient(135deg, #1A1F36 0%, #0F1322 100%)',
                      boxShadow: 'inset 0 1px 1px rgba(255,255,255,0.2), 0 20px 50px rgba(0,0,0,0.8)',
                      transformOrigin: 'bottom center',
                      transform: \`
                        translateY(\${interpolate(spring({ frame: Math.max(0, frame - 1820), fps, config: { damping: 14 } }), [0, 1], [400, -40])}px)
                        rotateZ(\${interpolate(spring({ frame: Math.max(0, frame - 1840), fps, config: { damping: 12 } }), [0, 1], [0, 6])}deg)
                      \`,
                      zIndex: 3, display: 'flex', flexDirection: 'column', padding: 16*S
                   }}>
                      <Img src={staticFile('visa.svg')} style={{ width: 60*S, filter: 'drop-shadow(0 2px 4px rgba(0,0,0,0.5)) invert(1)' }} />
                      <div style={{ marginTop: 'auto', display: 'flex', gap: 8*S, color: '#D4AF37', fontSize: 14*S, fontFamily: FONT_BRAND, letterSpacing: 2*S, opacity: 0.9 }}>
                         <span>****</span><span>****</span><span>****</span><span>3456</span>
                      </div>
                   </div>

                   {/* 4. Apple Pay (Top, Matte Black Titanium) */}
                   <div style={{
                      position: 'absolute', width: 220*S, height: 140*S, borderRadius: 16*S,
                      background: 'linear-gradient(135deg, #222 0%, #000 100%)',
                      boxShadow: 'inset 0 1px 1px rgba(255,255,255,0.1), 0 30px 60px rgba(0,0,0,0.9)',
                      border: '1px solid rgba(255,255,255,0.05)',
                      transformOrigin: 'bottom center',
                      transform: \`
                        translateY(\${interpolate(spring({ frame: Math.max(0, frame - 1830), fps, config: { damping: 14 } }), [0, 1], [400, -60])}px)
                        rotateZ(\${interpolate(spring({ frame: Math.max(0, frame - 1850), fps, config: { damping: 12 } }), [0, 1], [0, 18])}deg)
                      \`,
                      zIndex: 4, display: 'flex', flexDirection: 'column', padding: 16*S
                   }}>
                      <Img src={staticFile('applepay.svg')} style={{ width: 50*S, filter: 'drop-shadow(0 2px 4px rgba(0,0,0,0.5)) invert(1)' }} />
                      <div style={{ marginTop: 'auto', display: 'flex', gap: 8*S, color: '#FFF', fontSize: 14*S, fontFamily: FONT_BRAND, letterSpacing: 2*S, opacity: 0.9 }}>
                         <span>****</span><span>****</span><span>****</span><span>1234</span>
                      </div>
                   </div>
                </div>

                {/* 3. FACEID SCAN & APPROVAL (1860+) */}
                {frame >= 1860 && (
                   <div style={{
                      position: 'absolute', top: 60*S, zIndex: 10,
                      width: 80*S, height: 80*S, borderRadius: 20*S,
                      background: 'rgba(0, 0, 0, 0.8)',
                      backdropFilter: 'blur(20px)', WebkitBackdropFilter: 'blur(20px)',
                      border: '1px solid rgba(255,255,255,0.1)',
                      boxShadow: '0 10px 30px rgba(0,0,0,0.8)',
                      display: 'flex', alignItems: 'center', justifyContent: 'center', overflow: 'hidden',
                      transform: \`
                        scale(\${interpolate(spring({ frame: Math.max(0, frame - 1860), fps, config: { damping: 12 } }), [0, 1], [0, 1])})
                        rotateY(\${interpolate(frame, [1890, 1910], [0, 360], {extrapolateRight: 'clamp', extrapolateLeft: 'clamp'})}deg)
                      \`
                   }}>
                      {/* FaceID Icon (Before 1900) */}
                      {frame < 1900 && (
                         <>
                            <span className="material-icons" style={{ color: '#FFF', fontSize: 40*S }}>face</span>
                            {/* Scanning Laser */}
                            <div style={{
                               position: 'absolute', top: 0, left: 0, right: 0, height: 2*S,
                               background: '#FFF', boxShadow: '0 0 10px #FFF',
                               transform: \`translateY(\${interpolate(frame, [1870, 1890], [10*S, 70*S], {extrapolateRight: 'clamp', extrapolateLeft: 'clamp'})}px)\`
                            }} />
                         </>
                      )}

                      {/* Green Checkmark (After 1900) */}
                      {frame >= 1900 && (
                         <span className="material-icons" style={{ color: '#69F0AE', fontSize: 50*S, filter: 'drop-shadow(0 0 10px rgba(105, 240, 174, 0.8))' }}>check</span>
                      )}

                      {/* Approval Shockwave */}
                      {frame >= 1900 && (
                         <div style={{
                            position: 'absolute', inset: 0, borderRadius: 20*S,
                            border: '3px solid #69F0AE',
                            transform: \`scale(\${interpolate(frame, [1900, 1920], [1, 2.5], {extrapolateRight: 'clamp', extrapolateLeft: 'clamp'})})\`,
                            opacity: interpolate(frame, [1900, 1910, 1920], [0, 1, 0], {extrapolateRight: 'clamp', extrapolateLeft: 'clamp'})
                         }} />
                      )}
                   </div>
                )}
             </div>

          </div>
          
          {/* Action Text */}
          <div style={{ position: 'absolute', top: '82%', display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 16*S, transform: \`translateY(\${interpolate(spring({ frame: Math.max(0, frame - 1830), fps }), [0, 1], [20, 0])}px)\` }}>
             <span style={{ color: '#FFF', fontSize: 32*S, fontFamily: FONT_AR, fontWeight: 'bold', filter: 'drop-shadow(0 4px 10px rgba(0,0,0,0.5))' }}>بوابات دفع متعددة وآمنة</span>
             <span style={{ 
                color: '#69F0AE', fontSize: 20*S, fontFamily: FONT_AR, fontWeight: 'bold',
                background: 'linear-gradient(135deg, rgba(105, 240, 174, 0.2), rgba(105, 240, 174, 0.05))', 
                padding: \`12px \${30*S}px\`, borderRadius: 24*S, border: '1px solid rgba(105, 240, 174, 0.4)',
                boxShadow: 'inset 0 1px 1px rgba(105, 240, 174, 0.4)', backdropFilter: 'blur(10px)', WebkitBackdropFilter: 'blur(10px)',
                transform: \`scale(\${interpolate(spring({ frame: Math.max(0, frame - 1910), fps, config: { damping: 8, stiffness: 300 } }), [0, 1], [2, 1])})\`,
                opacity: frame >= 1910 ? 1 : 0
             }}>ادفع واستقبل بكل سهولة من أي مكان</span>
          </div>
          
        </div>
      )}
\n`;

  const newContent = content.substring(0, startIndex) + paymentBlock + content.substring(endIndex);
  fs.writeFileSync(file, newContent);
  console.log("FaceID Checkout Layout created successfully!");
} else {
  console.log("Could not find markers!");
}
