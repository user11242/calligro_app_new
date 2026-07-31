const fs = require('fs');
const file = '/Users/yazanqattous/Desktop/flutter_projects/calligro_app/calligro_intro_video/src/Intro.tsx';
const lines = fs.readFileSync(file, 'utf8').split('\n');
const startIdx = 3879; // line 3880
const endIdx = 4336; // line 4336

const replacement = `                  <div
                    style={{
                      display: "flex",
                      flexDirection: "column",
                      alignItems: "flex-end",
                      gap: 5,
                    }}
                  >
                    <span
                      style={{
                        color: "#FFF",
                        fontSize: 50,
                        fontWeight: "bold",
                      }}
                    >
                      مرحباً، المعلم
                    </span>
                    <span style={{ color: "#999", fontSize: 30 }}>
                      .لنقم بتدريس شيء جميل اليوم
                    </span>
                  </div>
                  <div
                    style={{
                      width: 120,
                      height: 120,
                      borderRadius: 60,
                      background: "#FFF",
                    }}
                  />
                </div>
              </div>

              {/* HERO COURSE CARD (Moved up) */}
              <div
                style={{
                  marginTop: 40,
                  width: "100%",
                  height: 750,
                  borderRadius: 60,
                  overflow: "hidden",
                  position: "relative",
                  background: "#000",
                  transform: \`translateY(\${interpolate(spring({ frame: Math.max(0, frame - 2000), fps }), [0, 1], [50, 0])}px)\`,
                  opacity: interpolate(frame, [2000, 2020], [0, 1], { extrapolateRight: "clamp" }),
                }}
              >
                <Img
                  src={staticFile("normal_writing.jpg")}
                  style={{
                    position: "absolute",
                    inset: 0,
                    width: "100%",
                    height: "100%",
                    objectFit: "cover",
                    opacity: 0.8,
                  }}
                />
                <div
                  style={{
                    position: "absolute",
                    inset: 0,
                    background: "linear-gradient(to bottom, rgba(0,0,0,0.5) 0%, rgba(0,0,0,1) 100%)",
                  }}
                />

                <div
                  style={{
                    position: "absolute",
                    inset: 0,
                    padding: 50,
                    display: "flex",
                    flexDirection: "column",
                  }}
                >
                  <div style={{ display: "flex", justifyContent: "space-between", width: "100%" }}>
                    <div style={{ background: "rgba(255,255,255,0.15)", padding: "20px 30px", borderRadius: 30, display: "flex", alignItems: "center", gap: 15, backdropFilter: "blur(10px)" }}>
                      <span className="material-icons" style={{ color: "#FFF", fontSize: 35 }}>event</span>
                      <span style={{ color: "#FFF", fontSize: 30 }}>غداً، ٣:٤٩ م</span>
                    </div>
                    <div style={{ background: "#D4AF37", padding: "20px 50px", borderRadius: 40 }}>
                      <span style={{ color: "#000", fontSize: 35, fontWeight: "bold" }}>قادم</span>
                    </div>
                  </div>

                  <span style={{ color: "#FFF", fontSize: 60, fontWeight: "bold", textAlign: "center", marginTop: 120, lineHeight: 1.5, textShadow: "0 4px 10px rgba(0,0,0,0.8)" }}>
                    دورة تحسين الكتابة بالقلم العادي للمستوى المبتدئ
                  </span>

                  <div style={{ display: "flex", justifyContent: "center", gap: 60, marginTop: 100, background: "rgba(0,0,0,0.6)", padding: "30px 60px", borderRadius: 40, alignSelf: "center", backdropFilter: "blur(10px)", border: "1px solid rgba(255,255,255,0.1)" }}>
                    <div style={{ display: "flex", flexDirection: "column", alignItems: "center" }}>
                      <span style={{ color: "#FFF", fontSize: 70, fontWeight: "bold" }}>
                        {Math.max(0, 54 - Math.floor(Math.max(0, frame - 2000) / fps)).toString().padStart(2, "0")}
                      </span>
                      <span style={{ color: "#D4AF37", fontSize: 30 }}>ثانية</span>
                    </div>
                    <div style={{ width: 2, height: 100, background: "rgba(255,255,255,0.2)", marginTop: 20 }} />
                    <div style={{ display: "flex", flexDirection: "column", alignItems: "center" }}>
                      <span style={{ color: "#FFF", fontSize: 70, fontWeight: "bold" }}>20</span>
                      <span style={{ color: "#D4AF37", fontSize: 30 }}>دقيقة</span>
                    </div>
                    <div style={{ width: 2, height: 100, background: "rgba(255,255,255,0.2)", marginTop: 20 }} />
                    <div style={{ display: "flex", flexDirection: "column", alignItems: "center" }}>
                      <span style={{ color: "#FFF", fontSize: 70, fontWeight: "bold" }}>15</span>
                      <span style={{ color: "#D4AF37", fontSize: 30 }}>ساعة</span>
                    </div>
                    <div style={{ width: 2, height: 100, background: "rgba(255,255,255,0.2)", marginTop: 20 }} />
                    <div style={{ display: "flex", flexDirection: "column", alignItems: "center" }}>
                      <span style={{ color: "#FFF", fontSize: 70, fontWeight: "bold" }}>1</span>
                      <span style={{ color: "#D4AF37", fontSize: 30 }}>أيام</span>
                    </div>
                  </div>

                  <div style={{ width: "100%", height: 130, background: "#D4AF37", borderRadius: 40, marginTop: "auto", display: "flex", alignItems: "center", justifyContent: "center", gap: 20 }}>
                    <span style={{ color: "#000", fontSize: 50, fontWeight: "bold" }}>تجهيز الحصة</span>
                    <span style={{ fontSize: 50 }}>🚀</span>
                  </div>
                </div>
              </div>

              {/* SECTION TITLE: QUICK ACTIONS */}
              <div
                style={{
                  marginTop: 60,
                  width: "100%",
                  display: "flex",
                  justifyContent: "flex-end",
                  transform: \`translateY(\${interpolate(spring({ frame: Math.max(0, frame - 2050), fps }), [0, 1], [50, 0])}px)\`,
                  opacity: interpolate(frame, [2050, 2070], [0, 1], { extrapolateRight: "clamp" }),
                }}
              >
                <span style={{ color: "#FFF", fontSize: 50, fontWeight: "bold" }}>إجراءات سريعة</span>
              </div>

              {/* QUICK ACTIONS 2x2 GRID */}
              <div
                style={{
                  marginTop: 40,
                  display: "grid",
                  gridTemplateColumns: "1fr 1fr",
                  gap: 30,
                  width: "100%",
                }}
              >
                {/* Top Left: Financials */}
                <div
                  style={{
                    background: "#2A2A2A",
                    height: 350,
                    borderRadius: 40,
                    display: "flex",
                    flexDirection: "column",
                    alignItems: "center",
                    justifyContent: "center",
                    gap: 20,
                    transform: \`scale(\${spring({ frame: Math.max(0, frame - 2070), fps, config: { damping: 12 } })} * \${frame >= 2150 && frame < 2160 ? 0.95 : 1})\`,
                    boxShadow: frame >= 2150 && frame < 2160 ? "0 0 40px rgba(0,0,0,0.8)" : "none",
                    border: "2px solid #333",
                  }}
                >
                  <span className="material-icons" style={{ color: "#FFF", fontSize: 80 }}>attach_money</span>
                  <span style={{ color: "#FFF", fontSize: 35, fontWeight: "bold" }}>المالية</span>
                </div>

                {/* Top Right: New Course */}
                <div
                  style={{
                    background: "#D4AF37",
                    height: 350,
                    borderRadius: 40,
                    display: "flex",
                    flexDirection: "column",
                    alignItems: "center",
                    justifyContent: "center",
                    gap: 20,
                    transform: \`scale(\${spring({ frame: Math.max(0, frame - 2080), fps, config: { damping: 12 } })})\`,
                  }}
                >
                  <span className="material-icons" style={{ color: "#000", fontSize: 80 }}>add_circle_outline</span>
                  <span style={{ color: "#000", fontSize: 35, fontWeight: "bold" }}>دورة جديدة</span>
                </div>

                {/* Bottom Left: Gallery */}
                <div
                  style={{
                    background: "#2A2A2A",
                    height: 350,
                    borderRadius: 40,
                    display: "flex",
                    flexDirection: "column",
                    alignItems: "center",
                    justifyContent: "center",
                    gap: 20,
                    transform: \`scale(\${spring({ frame: Math.max(0, frame - 2090), fps, config: { damping: 12 } })})\`,
                    border: "2px solid #333",
                  }}
                >
                  <span className="material-icons" style={{ color: "#FFF", fontSize: 80 }}>insert_photo</span>
                  <span style={{ color: "#FFF", fontSize: 35, fontWeight: "bold" }}>المعرض</span>
                </div>

                {/* Bottom Right: Manage Courses */}
                <div
                  style={{
                    background: "#2A2A2A",
                    height: 350,
                    borderRadius: 40,
                    display: "flex",
                    flexDirection: "column",
                    alignItems: "center",
                    justifyContent: "center",
                    gap: 20,
                    transform: \`scale(\${spring({ frame: Math.max(0, frame - 2100), fps, config: { damping: 12 } })})\`,
                    border: "2px solid #333",
                  }}
                >
                  <span className="material-icons" style={{ color: "#FFF", fontSize: 80 }}>dashboard_customize</span>
                  <span style={{ color: "#FFF", fontSize: 35, fontWeight: "bold" }}>إدارة الدورات</span>
                </div>
              </div>`;

const newLines = [...lines.slice(0, startIdx), replacement, ...lines.slice(endIdx)];
fs.writeFileSync(file, newLines.join('\n'));
console.log('Restructure applied.');
