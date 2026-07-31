const fs = require('fs');
const file = '/Users/yazanqattous/Desktop/flutter_projects/calligro_app/calligro_intro_video/src/Intro.tsx';
let content = fs.readFileSync(file, 'utf8');

// 1. Fade out the Homework Hub
const homeworkOpacityTarget = `opacity: interpolate(frame, [1450, 1470], [0, 1], {extrapolateRight: 'clamp'}),`;
const homeworkOpacityReplace = `opacity: frame < 1750 ? interpolate(frame, [1450, 1470], [0, 1], {extrapolateRight: 'clamp'}) : interpolate(frame, [1750, 1770], [1, 0], {extrapolateRight: 'clamp'}),`;
content = content.replace(homeworkOpacityTarget, homeworkOpacityReplace);

// 2. Insert Payment Feature
const insertMarker = `      )}
    </AbsoluteFill>
  );
};`;

const paymentBlock = `
      {/* ═══════════════════════════════════════════════════════════════════════════════ */}
      {/* PAYMENT SYSTEMS NARRATIVE                                                     */}
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
          
          <div style={{ position: 'relative', width: 400*S, height: 400*S, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
             
             {/* Central Secure Wallet Hub */}
             <div style={{
                width: 160*S, height: 160*S, borderRadius: '50%',
                background: 'linear-gradient(135deg, rgba(0,122,255,0.2), rgba(0,122,255,0.02))',
                boxShadow: 'inset 0 2px 2px rgba(0,122,255,0.5), inset 0 0 0 1px rgba(0,122,255,0.2), 0 20px 40px rgba(0,0,0,0.5), 0 0 60px rgba(0,122,255,0.2)',
                backdropFilter: 'blur(30px)', WebkitBackdropFilter: 'blur(30px)',
                display: 'flex', alignItems: 'center', justifyContent: 'center',
                transform: \`
                  translateY(-20px)
                  scale(\${spring({ frame: Math.max(0, frame - 1750), fps, config: { damping: 12, stiffness: 150 } })})
                \`
             }}>
                <span className="material-icons" style={{ fontSize: 70*S, color: '#007AFF', filter: 'drop-shadow(0 2px 10px rgba(0,122,255,0.8))' }}>account_balance_wallet</span>
             </div>

             {/* Orbiting Payment Badges */}
             
             {/* 1. Visa (Top Right) */}
             <div style={{
                position: 'absolute', top: 40*S, right: 0,
                opacity: frame >= 1770 ? 1 : 0,
                transform: \`
                  translate(\${interpolate(spring({ frame: Math.max(0, frame - 1770), fps, config: { damping: 10 } }), [0, 1], [50, 0])}px, \${Math.sin(frame*0.05)*10}px)
                  scale(\${spring({ frame: Math.max(0, frame - 1770), fps })})
                \`
             }}>
                <div style={{
                   background: 'linear-gradient(135deg, rgba(255,255,255,0.15), rgba(255,255,255,0.02))',
                   borderRadius: 40*S, padding: \`8px \${20*S}px\`,
                   boxShadow: 'inset 0 1px 2px rgba(255,255,255,0.4), inset 0 0 0 1px rgba(255,255,255,0.1), 0 10px 20px rgba(0,0,0,0.3)',
                   backdropFilter: 'blur(20px)', WebkitBackdropFilter: 'blur(20px)',
                   display: 'flex', alignItems: 'center', gap: 8*S
                }}>
                   <span style={{fontSize: 22*S}}>💳</span>
                   <span style={{color: '#FFF', fontSize: 18*S, fontWeight: 'bold', fontFamily: FONT_BRAND, filter: 'drop-shadow(0 2px 4px rgba(0,0,0,0.5))'}}>Visa</span>
                </div>
             </div>

             {/* 2. Apple Pay (Bottom Left) */}
             <div style={{
                position: 'absolute', bottom: 60*S, left: 10*S,
                opacity: frame >= 1780 ? 1 : 0,
                transform: \`
                  translate(\${interpolate(spring({ frame: Math.max(0, frame - 1780), fps, config: { damping: 10 } }), [0, 1], [-50, 0])}px, \${Math.cos(frame*0.06)*10}px)
                  scale(\${spring({ frame: Math.max(0, frame - 1780), fps })})
                \`
             }}>
                <div style={{
                   background: 'linear-gradient(135deg, rgba(255,255,255,0.15), rgba(255,255,255,0.02))',
                   borderRadius: 40*S, padding: \`8px \${20*S}px\`,
                   boxShadow: 'inset 0 1px 2px rgba(255,255,255,0.4), inset 0 0 0 1px rgba(255,255,255,0.1), 0 10px 20px rgba(0,0,0,0.3)',
                   backdropFilter: 'blur(20px)', WebkitBackdropFilter: 'blur(20px)',
                   display: 'flex', alignItems: 'center', gap: 8*S
                }}>
                   <span style={{fontSize: 22*S}}>🍎</span>
                   <span style={{color: '#FFF', fontSize: 18*S, fontWeight: 'bold', fontFamily: FONT_BRAND, filter: 'drop-shadow(0 2px 4px rgba(0,0,0,0.5))'}}>Apple Pay</span>
                </div>
             </div>

             {/* 3. Google Pay (Top Left) */}
             <div style={{
                position: 'absolute', top: 60*S, left: -20*S,
                opacity: frame >= 1790 ? 1 : 0,
                transform: \`
                  translate(\${interpolate(spring({ frame: Math.max(0, frame - 1790), fps, config: { damping: 10 } }), [0, 1], [-50, 0])}px, \${Math.sin(frame*0.07)*10}px)
                  scale(\${spring({ frame: Math.max(0, frame - 1790), fps })})
                \`
             }}>
                <div style={{
                   background: 'linear-gradient(135deg, rgba(255,255,255,0.15), rgba(255,255,255,0.02))',
                   borderRadius: 40*S, padding: \`8px \${20*S}px\`,
                   boxShadow: 'inset 0 1px 2px rgba(255,255,255,0.4), inset 0 0 0 1px rgba(255,255,255,0.1), 0 10px 20px rgba(0,0,0,0.3)',
                   backdropFilter: 'blur(20px)', WebkitBackdropFilter: 'blur(20px)',
                   display: 'flex', alignItems: 'center', gap: 8*S
                }}>
                   <span style={{fontSize: 22*S}}>🇬</span>
                   <span style={{color: '#FFF', fontSize: 18*S, fontWeight: 'bold', fontFamily: FONT_BRAND, filter: 'drop-shadow(0 2px 4px rgba(0,0,0,0.5))'}}>Google Pay</span>
                </div>
             </div>

             {/* 4. PayPal (Bottom Right) */}
             <div style={{
                position: 'absolute', bottom: 80*S, right: -10*S,
                opacity: frame >= 1800 ? 1 : 0,
                transform: \`
                  translate(\${interpolate(spring({ frame: Math.max(0, frame - 1800), fps, config: { damping: 10 } }), [0, 1], [50, 0])}px, \${Math.cos(frame*0.04)*10}px)
                  scale(\${spring({ frame: Math.max(0, frame - 1800), fps })})
                \`
             }}>
                <div style={{
                   background: 'linear-gradient(135deg, rgba(255,255,255,0.15), rgba(255,255,255,0.02))',
                   borderRadius: 40*S, padding: \`8px \${20*S}px\`,
                   boxShadow: 'inset 0 1px 2px rgba(255,255,255,0.4), inset 0 0 0 1px rgba(255,255,255,0.1), 0 10px 20px rgba(0,0,0,0.3)',
                   backdropFilter: 'blur(20px)', WebkitBackdropFilter: 'blur(20px)',
                   display: 'flex', alignItems: 'center', gap: 8*S
                }}>
                   <span style={{fontSize: 22*S}}>🅿️</span>
                   <span style={{color: '#FFF', fontSize: 18*S, fontWeight: 'bold', fontFamily: FONT_BRAND, filter: 'drop-shadow(0 2px 4px rgba(0,0,0,0.5))'}}>PayPal</span>
                </div>
             </div>
             
          </div>
          
          {/* Action Text */}
          <div style={{ position: 'absolute', top: '70%', display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 16*S, transform: \`translateY(\${interpolate(spring({ frame: Math.max(0, frame - 1760), fps }), [0, 1], [20, 0])}px)\` }}>
             <span style={{ color: '#FFF', fontSize: 32*S, fontFamily: FONT_AR, fontWeight: 'bold', filter: 'drop-shadow(0 4px 10px rgba(0,0,0,0.5))' }}>بوابات دفع متعددة وآمنة</span>
             <span style={{ 
                color: '#007AFF', fontSize: 20*S, fontFamily: FONT_AR, fontWeight: 'bold',
                background: 'linear-gradient(135deg, rgba(0, 122, 255, 0.2), rgba(0, 122, 255, 0.05))', 
                padding: \`12px \${30*S}px\`, borderRadius: 24*S, border: '1px solid rgba(0, 122, 255, 0.4)',
                boxShadow: 'inset 0 1px 1px rgba(0, 122, 255, 0.4)', backdropFilter: 'blur(10px)', WebkitBackdropFilter: 'blur(10px)',
                transform: \`scale(\${interpolate(spring({ frame: Math.max(0, frame - 1820), fps, config: { damping: 8, stiffness: 300 } }), [0, 1], [2, 1])})\`,
                opacity: frame >= 1820 ? 1 : 0
             }}>استقبل مدفوعاتك بكل سهولة من أي مكان</span>
          </div>
          
        </div>
      )}
`;

content = content.replace(insertMarker, paymentBlock + '\n' + insertMarker);

fs.writeFileSync(file, content);
console.log("Payments added successfully!");
