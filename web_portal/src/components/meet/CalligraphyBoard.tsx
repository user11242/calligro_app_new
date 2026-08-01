"use client";
import React, { useRef, useEffect, useState, useCallback } from "react";
import { Eraser, Download, Undo2 } from "lucide-react";

interface Point { x: number; y: number }

interface BrushProfile {
  id: string;
  name: string;
  // Orientation behavior
  oriented: boolean;        // TRUE = stamp rotates with stroke direction (key for thick/thin!)
  shapeOrientation: number; // 1=fixed, 2=azimuth, 3=random, 4=external
  shapeAngle: number;       // Fixed offset angle added to stroke direction (radians)
  // Size
  paintSize: number;        // 0-1: default size as fraction of ~2048px canvas
  maxSize: number;
  minSize: number;
  // Opacity
  paintOpacity: number;
  maxOpacity: number;
  minOpacity: number;
  // Stroke
  plotSpacing: number;      // 0-1: gap between stamps (0=very dense)
  plotSmoothing: number;    // 0-1: stroke smoothing
  // Shape
  shapeRoundness: number;   // 0-1: 1=rectangular, 0.1=very flat (chisel!)
  shapeCount: number;       // 0-1: multiple tips per stamp for thick brushes
  // Taper
  taperSize: number;
  taperOpacity: number;
  taperStartLength: number;
  taperEndLength: number;
  // Dynamics (speed-based)
  dynamicsSpeedSize: number;   // negative = gets thinner when faster (calligraphy behavior!)
  dynamicsSpeedOpacity: number;
  dynamicsPressureSize: number;
  dynamicsPressureOpacity: number;
  hasThumbnail: boolean;
}

const INK_COLORS = [
  { name: "Ink Black", hex: "#0A0A0A" },
  { name: "Dark Brown", hex: "#3E2723" },
  { name: "Sepia", hex: "#6B4226" },
  { name: "Indigo", hex: "#1A237E" },
  { name: "Forest", hex: "#1B5E20" },
  { name: "Crimson", hex: "#7B0000" },
  { name: "Gold", hex: "#7D5A00" },
  { name: "White", hex: "#FFFFFF" },
];

interface BrushMask {
  canvas: HTMLCanvasElement;
  naturalW: number;
  naturalH: number;
}

export default function CalligraphyBoard() {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const [isDrawing, setIsDrawing] = useState(false);
  const [brushes, setBrushes] = useState<BrushProfile[]>([]);
  const [activeBrush, setActiveBrush] = useState<BrushProfile | null>(null);
  const brushMaskRef = useRef<BrushMask | null>(null);
  const [brushLoaded, setBrushLoaded] = useState(false);

  const [inkColor, setInkColor] = useState("#0A0A0A");
  const [showColorPicker, setShowColorPicker] = useState(false);
  const [userSize, setUserSize] = useState(50);
  const [userOpacity, setUserOpacity] = useState(100);

  const historyRef = useRef<ImageData[]>([]);
  const lastPoint = useRef<Point | null>(null);
  // Track stroke speed for dynamicsSpeedSize
  const lastTimestamp = useRef<number>(0);
  const lastSpeed = useRef<number>(0);
  const strokeLength = useRef<number>(0);
  const ctxRef = useRef<CanvasRenderingContext2D | null>(null);

  // Load brush list
  useEffect(() => {
    fetch("/brushes/brushes.json")
      .then(r => r.json())
      .then((data: BrushProfile[]) => {
        setBrushes(data);
        if (data.length > 0) setActiveBrush(data[0]);
      });
  }, []);

  // Build alpha mask from Shape.png
  useEffect(() => {
    if (!activeBrush) return;
    setBrushLoaded(false);
    brushMaskRef.current = null;

    const img = new Image();
    img.crossOrigin = "anonymous";
    img.src = `/brushes/${activeBrush.id}.png`;

    img.onload = () => {
      const oc = document.createElement("canvas");
      oc.width = img.width;
      oc.height = img.height;
      const octx = oc.getContext("2d")!;
      octx.drawImage(img, 0, 0);

      // Convert brightness → alpha mask
      // Dark pixels = ink (opaque), white pixels = transparent
      const id = octx.getImageData(0, 0, oc.width, oc.height);
      const d = id.data;
      for (let i = 0; i < d.length; i += 4) {
        const brightness = (d[i] + d[i+1] + d[i+2]) / 3;
        const darkness = 255 - brightness;
        d[i] = 0; d[i+1] = 0; d[i+2] = 0;
        // Blend with existing alpha (PNG might already have transparency)
        d[i+3] = Math.max(darkness, d[i+3] > 128 ? 255 - brightness : 0);
      }
      octx.putImageData(id, 0, 0);

      brushMaskRef.current = { canvas: oc, naturalW: oc.width, naturalH: oc.height };
      setBrushLoaded(true);
    };

    img.onerror = () => {
      // Fallback: create a chisel-shaped mask manually
      const oc = document.createElement("canvas");
      oc.width = 120; oc.height = 20;
      const octx = oc.getContext("2d")!;
      // Tapered chisel shape
      octx.beginPath();
      octx.moveTo(0, 10);
      octx.lineTo(10, 0);
      octx.lineTo(110, 0);
      octx.lineTo(120, 10);
      octx.lineTo(110, 20);
      octx.lineTo(10, 20);
      octx.closePath();
      octx.fillStyle = "black";
      octx.fill();
      const id = octx.getImageData(0, 0, 120, 20);
      const d = id.data;
      for (let i = 0; i < d.length; i += 4) {
        d[i+3] = d[i] === 0 ? 255 : 0;
        d[i] = 0; d[i+1] = 0; d[i+2] = 0;
      }
      octx.putImageData(id, 0, 0);
      brushMaskRef.current = { canvas: oc, naturalW: 120, naturalH: 20 };
      setBrushLoaded(true);
    };
  }, [activeBrush]);

  // Initialize Canvas
  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext("2d", { willReadFrequently: true });
    if (!ctx) return;
    const dpr = window.devicePixelRatio || 1;
    const rect = canvas.parentElement?.getBoundingClientRect();
    if (rect) {
      canvas.width = rect.width * dpr;
      canvas.height = rect.height * dpr;
      ctx.scale(dpr, dpr);
      canvas.style.width = `${rect.width}px`;
      canvas.style.height = `${rect.height}px`;
    }
    ctx.fillStyle = "#FDFBF7";
    ctx.fillRect(0, 0, canvas.width, canvas.height);
    ctxRef.current = ctx;
    historyRef.current = [ctx.getImageData(0, 0, canvas.width, canvas.height)];
  }, []);

  const saveHistory = useCallback(() => {
    const canvas = canvasRef.current;
    const ctx = ctxRef.current;
    if (!canvas || !ctx) return;
    historyRef.current.push(ctx.getImageData(0, 0, canvas.width, canvas.height));
    if (historyRef.current.length > 30) historyRef.current.shift();
  }, []);

  const undo = useCallback(() => {
    const ctx = ctxRef.current;
    if (!ctx || historyRef.current.length <= 1) return;
    historyRef.current.pop();
    ctx.putImageData(historyRef.current[historyRef.current.length - 1], 0, 0);
  }, []);

  // ── CORE STAMP FUNCTION ──
  // This is where the calligraphy magic happens:
  // - If brush is ORIENTED: stamp rotates with stroke direction → automatic thick/thin!
  // - shapeAngle is the nib offset (e.g., 0.43 rad ≈ 25° for Thuluth)
  // - Stamp width = full brush size, height = width × natural aspect ratio
  //   → as you rotate, the projected width changes → thick/thin variation!
  const stamp = useCallback((
    ctx: CanvasRenderingContext2D,
    x: number, y: number,
    strokeAngle: number,  // current movement direction in radians
    speed: number,        // normalized 0-1 speed
    tapFactor: number,    // 0-1 taper factor at start/end
    brush: BrushProfile
  ) => {
    const mask = brushMaskRef.current;
    if (!mask) return;

    const canvasEl = canvasRef.current;
    if (!canvasEl) return;
    const displayW = canvasEl.getBoundingClientRect().width;

    // Base stamp size: paintSize is a Procreate fraction of ~2048px canvas
    // We scale it to our actual canvas width. Typical paintSize=0.05 → ~5% of 500px = 25px
    const baseW = brush.paintSize * displayW * 0.55; 
    const sizeScale = (userSize / 100) * 1.5 + 0.2; // 1% → 0.21x, 100% → 1.7x

    // Speed dynamics: dynamicsSpeedSize < 0 means brush gets THINNER when faster
    // This is the key calligraphy behavior!
    const speedEffect = brush.dynamicsSpeedSize * speed * baseW * sizeScale;
    const finalW = Math.max(0.5, baseW * sizeScale + speedEffect);

    // Height: use natural aspect ratio of the Shape.png (chisel proportions)
    // Most calligraphy brushes have a wide flat chisel, naturalW >> naturalH
    const aspectRatio = mask.naturalH / mask.naturalW;
    const finalH = Math.max(0.5, finalW * aspectRatio);

    // ROTATION:
    // oriented=true: stamp rotates with stroke direction (thick/thin variation)
    // oriented=false: stamp stays at fixed angle
    let stampAngle: number;
    if (brush.oriented) {
      // Stroke direction + nib offset = final stamp angle
      // This gives automatic thick/thin as direction changes!
      stampAngle = strokeAngle + brush.shapeAngle;
    } else {
      // Fixed angle brush (decorative, dotted, etc.)
      stampAngle = brush.shapeAngle;
    }

    // Opacity
    const baseOpacity = brush.paintOpacity * brush.maxOpacity * (userOpacity / 100);
    const speedOpacityEffect = brush.dynamicsSpeedOpacity !== 1 
      ? (brush.dynamicsSpeedOpacity - 1) * speed * 0.3 
      : 0;
    const taperOpacity = brush.taperOpacity + (1 - brush.taperOpacity) * (1 - tapFactor);
    const finalOpacity = Math.max(0.01, Math.min(1, baseOpacity + speedOpacityEffect)) * taperOpacity;

    // Build colorized stamp on tiny offscreen canvas
    const sw = Math.max(1, Math.ceil(finalW));
    const sh = Math.max(1, Math.ceil(finalH));
    const stampCanvas = document.createElement("canvas");
    stampCanvas.width = sw;
    stampCanvas.height = sh;
    const sctx = stampCanvas.getContext("2d")!;

    // Fill with ink color
    sctx.fillStyle = inkColor;
    sctx.fillRect(0, 0, sw, sh);
    // Mask it with the brush shape
    sctx.globalCompositeOperation = "destination-in";
    sctx.drawImage(mask.canvas, 0, 0, sw, sh);

    // Stamp onto main canvas at calculated angle
    ctx.save();
    ctx.globalAlpha = finalOpacity;
    ctx.translate(x, y);
    ctx.rotate(stampAngle);
    ctx.drawImage(stampCanvas, -sw / 2, -sh / 2);
    ctx.restore();

    // Multi-tip: shapeCount > 0 means scatter additional stamps for richer texture
    if (brush.shapeCount > 0.15) {
      const extraCount = Math.round(brush.shapeCount * 3);
      for (let i = 0; i < extraCount; i++) {
        const jitter = (Math.random() - 0.5) * finalW * 0.15;
        ctx.save();
        ctx.globalAlpha = finalOpacity * 0.4;
        ctx.translate(x + jitter, y + (Math.random() - 0.5) * finalH * 0.15);
        ctx.rotate(stampAngle);
        ctx.drawImage(stampCanvas, -sw / 2, -sh / 2);
        ctx.restore();
      }
    }
  }, [userSize, userOpacity, inkColor]);

  // ── STROKE DRAWING ──
  const drawStroke = useCallback((x: number, y: number, timestamp: number) => {
    const ctx = ctxRef.current;
    if (!ctx || !brushLoaded || !activeBrush) return;

    if (lastPoint.current) {
      const dx = x - lastPoint.current.x;
      const dy = y - lastPoint.current.y;
      const dist = Math.hypot(dx, dy);
      if (dist < 0.5) return;

      // Calculate stroke direction angle (this is what makes thick/thin happen!)
      const strokeAngle = Math.atan2(dy, dx);

      // Calculate speed (pixels per ms)
      const dt = Math.max(1, timestamp - lastTimestamp.current);
      const rawSpeed = dist / dt;
      // Smooth speed and normalize to 0-1
      lastSpeed.current = lastSpeed.current * 0.7 + rawSpeed * 0.3;
      const normalizedSpeed = Math.min(1, lastSpeed.current / 8);

      strokeLength.current += dist;

      // Spacing between stamps
      const gap = Math.max(1.5, activeBrush.plotSpacing * 40 + 1.5);
      const steps = Math.max(1, Math.floor(dist / gap));

      for (let i = 0; i <= steps; i++) {
        const t = i / steps;
        const tx = lastPoint.current.x + dx * t;
        const ty = lastPoint.current.y + dy * t;

        // Taper factor (1 = full, fades at start/end)
        let tapFactor = 1;
        if (activeBrush.taperSize > 0.1 || activeBrush.taperStartLength > 0) {
          const startFade = Math.min(1, strokeLength.current / (50 * activeBrush.taperStartLength + 1));
          tapFactor = startFade;
        }

        stamp(ctx, tx, ty, strokeAngle, normalizedSpeed, tapFactor, activeBrush);
      }
    } else {
      // First point of stroke
      strokeLength.current = 0;
      lastSpeed.current = 0;
      // For first point, use 0 as angle (will update on next move)
      stamp(ctx, x, y, 0, 0, 0.5, activeBrush);
    }

    lastPoint.current = { x, y };
    lastTimestamp.current = timestamp;
  }, [activeBrush, brushLoaded, stamp]);

  const getCoords = (e: React.PointerEvent<HTMLCanvasElement>) => {
    const rect = canvasRef.current?.getBoundingClientRect();
    if (!rect) return { x: 0, y: 0 };
    return { x: e.clientX - rect.left, y: e.clientY - rect.top };
  };

  const onPointerDown = (e: React.PointerEvent<HTMLCanvasElement>) => {
    (e.target as Element).setPointerCapture(e.pointerId);
    saveHistory();
    setIsDrawing(true);
    lastPoint.current = null;
    const { x, y } = getCoords(e);
    drawStroke(x, y, e.timeStamp);
  };

  const onPointerMove = (e: React.PointerEvent<HTMLCanvasElement>) => {
    if (!isDrawing) return;
    const { x, y } = getCoords(e);
    drawStroke(x, y, e.timeStamp);
  };

  const onPointerUp = () => {
    setIsDrawing(false);
    lastPoint.current = null;
    strokeLength.current = 0;
  };

  const clearCanvas = () => {
    const canvas = canvasRef.current;
    const ctx = ctxRef.current;
    if (!canvas || !ctx) return;
    saveHistory();
    ctx.globalAlpha = 1.0;
    ctx.fillStyle = "#FDFBF7";
    ctx.fillRect(0, 0, canvas.width, canvas.height);
  };

  const downloadCanvas = () => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const a = document.createElement("a");
    a.download = "calligro-artwork.png";
    a.href = canvas.toDataURL("image/png");
    a.click();
  };

  return (
    <div className="w-full h-full relative flex rounded-3xl overflow-hidden shadow-2xl border border-white/10 bg-[#FDFBF7]">

      {/* LEFT: Size & Opacity Sliders */}
      <div className="w-14 h-full bg-[#0A0907] border-r border-white/5 flex flex-col items-center py-5 z-30 shrink-0 gap-3">
        <button onClick={undo} title="Undo" className="w-9 h-9 rounded-xl bg-white/5 hover:bg-white/15 flex items-center justify-center text-white/50 hover:text-white transition-colors">
          <Undo2 className="w-4 h-4" />
        </button>
        <div className="relative">
          <button
            onClick={() => setShowColorPicker(v => !v)}
            className="w-9 h-9 rounded-xl border-2 border-white/20 hover:border-white/50 transition-all shadow-lg"
            style={{ backgroundColor: inkColor }}
            title="Ink Color"
          />
          {showColorPicker && (
            <div className="absolute left-12 top-0 bg-[#13110C] border border-white/10 rounded-2xl p-3 grid grid-cols-4 gap-2 z-50 shadow-2xl">
              {INK_COLORS.map((c) => (
                <button key={c.hex} onClick={() => { setInkColor(c.hex); setShowColorPicker(false); }}
                  title={c.name}
                  className={`w-7 h-7 rounded-full border-2 transition-all ${inkColor === c.hex ? "border-blue-500 scale-125" : "border-white/10 hover:border-white/40"}`}
                  style={{ backgroundColor: c.hex }}
                />
              ))}
            </div>
          )}
        </div>

        <div className="flex-1 flex flex-col items-center justify-center gap-2">
          <span className="text-[9px] text-white/30 font-bold uppercase tracking-wider">Size</span>
          <input type="range" min="1" max="100" value={userSize} onChange={e => setUserSize(+e.target.value)}
            className="h-28 w-1.5 appearance-none bg-white/10 rounded-full outline-none cursor-ns-resize [&::-webkit-slider-thumb]:appearance-none [&::-webkit-slider-thumb]:w-3.5 [&::-webkit-slider-thumb]:h-3.5 [&::-webkit-slider-thumb]:bg-white [&::-webkit-slider-thumb]:rounded-full"
            style={{ writingMode: "vertical-lr", direction: "rtl" }}
          />
          <span className="text-[9px] text-white/40 font-mono">{userSize}%</span>
        </div>

        <div className="flex-1 flex flex-col items-center justify-center gap-2">
          <span className="text-[9px] text-white/30 font-bold uppercase tracking-wider">Opacity</span>
          <input type="range" min="1" max="100" value={userOpacity} onChange={e => setUserOpacity(+e.target.value)}
            className="h-28 w-1.5 appearance-none bg-white/10 rounded-full outline-none cursor-ns-resize [&::-webkit-slider-thumb]:appearance-none [&::-webkit-slider-thumb]:w-3.5 [&::-webkit-slider-thumb]:h-3.5 [&::-webkit-slider-thumb]:bg-blue-500 [&::-webkit-slider-thumb]:rounded-full"
            style={{ writingMode: "vertical-lr", direction: "rtl" }}
          />
          <span className="text-[9px] text-white/40 font-mono">{userOpacity}%</span>
        </div>
      </div>

      {/* Brush Picker */}
      <div className="w-64 h-full bg-[#13110C] border-r border-white/5 flex flex-col z-20 shrink-0">
        <div className="px-4 pt-4 pb-3 border-b border-white/5">
          <h2 className="text-base font-black font-outfit text-white">فرش الخط العربي</h2>
          <p className="text-white/30 text-[10px] font-bold uppercase tracking-widest mt-0.5">{brushes.length} Procreate Brushes</p>
        </div>
        <div className="flex-1 overflow-y-auto py-1.5 px-2 space-y-1" style={{ scrollbarWidth: "thin", scrollbarColor: "#333 transparent" }}>
          {brushes.map((brush) => {
            const isActive = activeBrush?.id === brush.id;
            return (
              <button key={brush.id} onClick={() => setActiveBrush(brush)}
                className={`w-full flex flex-col rounded-xl transition-all duration-200 border overflow-hidden ${
                  isActive ? "bg-blue-600 border-blue-500 shadow-[0_0_12px_rgba(37,99,235,0.35)]" : "bg-white/[0.03] border-transparent hover:bg-white/[0.07]"
                }`}
              >
                <div className="px-3 pt-2 pb-0.5 text-right w-full">
                  <span className={`text-sm font-bold ${isActive ? "text-white" : "text-white/70"}`}
                    style={{ fontFamily: "'Noto Sans Arabic', 'Segoe UI', sans-serif" }}>
                    {brush.name}
                  </span>
                </div>
                <div className="w-full h-9 px-2 pb-1.5">
                  {brush.hasThumbnail ? (
                    <img src={`/brushes/${brush.id}_thumb.png`} alt={brush.name}
                      className="w-full h-full object-contain"
                      style={{ filter: isActive ? "brightness(2)" : "brightness(0.6) contrast(1.3)" }}
                    />
                  ) : (
                    <svg width="100%" height="100%" viewBox="0 0 200 30">
                      <path d="M 190 15 Q 140 3, 100 15 T 10 15" fill="none" stroke={isActive ? "#fff" : "#555"} strokeWidth="3" strokeLinecap="round" />
                    </svg>
                  )}
                </div>
              </button>
            );
          })}
        </div>
        <div className="p-2.5 border-t border-white/5 grid grid-cols-3 gap-1.5">
          <button onClick={clearCanvas} className="flex items-center justify-center gap-1 p-2.5 rounded-lg bg-red-500/10 text-red-400 hover:bg-red-500/20 transition-colors">
            <Eraser className="w-3.5 h-3.5" /><span className="text-[10px] font-bold">Clear</span>
          </button>
          <button onClick={undo} className="flex items-center justify-center gap-1 p-2.5 rounded-lg bg-white/5 text-white/60 hover:bg-white/10 transition-colors">
            <Undo2 className="w-3.5 h-3.5" /><span className="text-[10px] font-bold">Undo</span>
          </button>
          <button onClick={downloadCanvas} className="flex items-center justify-center gap-1 p-2.5 rounded-lg bg-white/5 text-white/60 hover:bg-white/10 transition-colors">
            <Download className="w-3.5 h-3.5" /><span className="text-[10px] font-bold">Save</span>
          </button>
        </div>
      </div>

      {/* Canvas */}
      <div className="flex-1 relative bg-[#FDFBF7] cursor-crosshair h-full overflow-hidden">
        {!brushLoaded && (
          <div className="absolute inset-0 flex items-center justify-center z-10 bg-[#FDFBF7]/80 pointer-events-none">
            <div className="flex flex-col items-center gap-3">
              <div className="w-7 h-7 rounded-full border-4 border-black/10 border-t-black/40 animate-spin" />
              <span className="text-black/30 font-bold uppercase text-[10px] tracking-widest">Loading Brush...</span>
            </div>
          </div>
        )}
        <canvas
          ref={canvasRef}
          onPointerDown={onPointerDown}
          onPointerMove={onPointerMove}
          onPointerUp={onPointerUp}
          onPointerLeave={onPointerUp}
          className="absolute inset-0 touch-none w-full h-full"
        />
        <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 text-[18rem] text-black/[0.015] pointer-events-none select-none" style={{ fontFamily: "'Noto Naskh Arabic', serif" }}>
          ب
        </div>
      </div>
    </div>
  );
}
