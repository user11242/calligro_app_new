"use client";
import React, { useRef, useEffect, useState, useCallback } from "react";
import { Eraser, Download, CircleDot, Undo2, Palette } from "lucide-react";

interface Point { x: number; y: number; pressure?: number }
interface BrushProfile {
  id: string;
  name: string;
  shapeAngle: number;      // radians
  paintSize: number;        // 0-1 normalized default size
  maxSize: number;          // 0-1
  minSize: number;          // 0-1
  spacing: number;          // 0-1
  streamline: number;       // 0-1
  taperSize: number;        // 0-1
  taperOpacity: number;     // 0-1
  maxOpacity: number;       // 0-1
  minOpacity: number;       // 0-1
  paintOpacity: number;     // 0-1
  shapeRoundness: number;   // 0-1
  shapeOrientation: number; // 0, 1, or 2
  pressureSize: number;     // 0-1
  speedSize: number;        // -1 to 1
  speedOpacity: number;     // 0-1
  hasThumbnail: boolean;
}

const INK_COLORS = [
  { name: "Black", hex: "#1A1A1A" },
  { name: "Dark Brown", hex: "#3E2723" },
  { name: "Sepia", hex: "#704214" },
  { name: "Dark Blue", hex: "#0D47A1" },
  { name: "Dark Green", hex: "#1B5E20" },
  { name: "Burgundy", hex: "#880E4F" },
  { name: "Gold", hex: "#BF8E2C" },
  { name: "White", hex: "#FFFFFF" },
];

export default function CalligraphyBoard() {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const [isDrawing, setIsDrawing] = useState(false);
  const [brushes, setBrushes] = useState<BrushProfile[]>([]);
  const [activeBrush, setActiveBrush] = useState<BrushProfile | null>(null);
  const [brushImage, setBrushImage] = useState<HTMLImageElement | null>(null);
  const [inkColor, setInkColor] = useState("#1A1A1A");
  const [showColorPicker, setShowColorPicker] = useState(false);

  // User-adjustable controls
  const [userSize, setUserSize] = useState(50);       // 1 to 100
  const [userOpacity, setUserOpacity] = useState(100); // 1 to 100

  // History for undo
  const historyRef = useRef<ImageData[]>([]);
  const lastPoint = useRef<Point | null>(null);
  const ctxRef = useRef<CanvasRenderingContext2D | null>(null);

  // Load Brushes JSON
  useEffect(() => {
    fetch("/brushes/brushes.json")
      .then(res => res.json())
      .then((data: BrushProfile[]) => {
        setBrushes(data);
        if (data.length > 0) setActiveBrush(data[0]);
      })
      .catch(err => console.error("Error loading brushes:", err));
  }, []);

  // Load specific Shape.png when active brush changes
  useEffect(() => {
    if (!activeBrush) return;
    setBrushImage(null);
    const img = new Image();
    img.crossOrigin = "anonymous";
    img.src = `/brushes/${activeBrush.id}.png`;
    img.onload = () => {
      // Tint the brush image to match ink color
      const tinted = tintImage(img, inkColor);
      setBrushImage(tinted);
    };
  }, [activeBrush, inkColor]);

  // Tint a grayscale brush shape to match ink color
  const tintImage = (img: HTMLImageElement, color: string): HTMLImageElement => {
    const offscreen = document.createElement("canvas");
    offscreen.width = img.width;
    offscreen.height = img.height;
    const octx = offscreen.getContext("2d");
    if (!octx) return img;

    // Draw original shape
    octx.drawImage(img, 0, 0);

    // Apply color tint using multiply blend mode
    octx.globalCompositeOperation = "source-in";
    octx.fillStyle = color;
    octx.fillRect(0, 0, offscreen.width, offscreen.height);

    const tintedImg = new (window as any).Image() as HTMLImageElement;
    tintedImg.src = offscreen.toDataURL();
    return tintedImg;
  };

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

    // Save initial state
    historyRef.current = [ctx.getImageData(0, 0, canvas.width, canvas.height)];
  }, []);

  const saveHistory = () => {
    const canvas = canvasRef.current;
    const ctx = ctxRef.current;
    if (!canvas || !ctx) return;
    const snap = ctx.getImageData(0, 0, canvas.width, canvas.height);
    historyRef.current.push(snap);
    if (historyRef.current.length > 30) historyRef.current.shift();
  };

  const undo = () => {
    const ctx = ctxRef.current;
    if (!ctx || historyRef.current.length <= 1) return;
    historyRef.current.pop();
    const prev = historyRef.current[historyRef.current.length - 1];
    ctx.putImageData(prev, 0, 0);
  };

  // ── DRAWING ENGINE ──
  const stampBrush = useCallback((ctx: CanvasRenderingContext2D, x: number, y: number, img: HTMLImageElement, brush: BrushProfile) => {
    // Convert brush paintSize (0-1) to pixel size, modulated by user slider
    const basePx = brush.paintSize * 800; // paintSize 0.05 => 40px base
    const sizeMultiplier = userSize / 50;  // user 50 = 1x, 100 = 2x
    const w = Math.max(2, basePx * sizeMultiplier);
    // Use shapeRoundness to determine height relative to width
    const h = w * Math.max(0.1, brush.shapeRoundness);

    // Opacity from brush settings * user slider
    const finalOpacity = brush.paintOpacity * brush.maxOpacity * (userOpacity / 100);

    ctx.save();
    ctx.globalAlpha = Math.max(0.01, Math.min(1, finalOpacity));
    ctx.translate(x, y);
    ctx.rotate(brush.shapeAngle); // Already in radians from Procreate!
    ctx.drawImage(img, -w / 2, -h / 2, w, h);
    ctx.restore();
  }, [userSize, userOpacity]);

  const drawStroke = useCallback((x: number, y: number) => {
    const ctx = ctxRef.current;
    if (!ctx || !brushImage || !activeBrush) return;

    if (lastPoint.current) {
      const dist = Math.hypot(x - lastPoint.current.x, y - lastPoint.current.y);
      // Spacing: higher spacing => fewer stamps. 0 spacing => stamp every 1-2 px
      const gap = Math.max(1, activeBrush.spacing * 20 + 1);
      const steps = Math.max(1, Math.floor(dist / gap));

      for (let i = 0; i <= steps; i++) {
        const t = i / steps;
        const tx = lastPoint.current.x + (x - lastPoint.current.x) * t;
        const ty = lastPoint.current.y + (y - lastPoint.current.y) * t;
        stampBrush(ctx, tx, ty, brushImage, activeBrush);
      }
    } else {
      stampBrush(ctx, x, y, brushImage, activeBrush);
    }

    lastPoint.current = { x, y };
  }, [activeBrush, brushImage, stampBrush]);

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
    drawStroke(x, y);
  };

  const onPointerMove = (e: React.PointerEvent<HTMLCanvasElement>) => {
    if (!isDrawing) return;
    const { x, y } = getCoords(e);
    drawStroke(x, y);
  };

  const onPointerUp = () => {
    setIsDrawing(false);
    lastPoint.current = null;
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
    const link = document.createElement("a");
    link.download = "calligro-artwork.png";
    link.href = canvas.toDataURL("image/png");
    link.click();
  };

  return (
    <div className="w-full h-full relative flex rounded-3xl overflow-hidden shadow-2xl border border-white/10 bg-[#FDFBF7]">

      {/* ── LEFT: SIZE & OPACITY VERTICAL SLIDERS ── */}
      <div className="w-14 h-full bg-[#0A0907] border-r border-white/5 flex flex-col items-center py-6 z-30 shrink-0 gap-4">
        {/* Undo */}
        <button onClick={undo} className="w-9 h-9 rounded-xl bg-white/5 hover:bg-white/10 flex items-center justify-center text-white/50 hover:text-white transition-colors" title="Undo">
          <Undo2 className="w-4 h-4" />
        </button>

        {/* Color picker */}
        <div className="relative">
          <button
            onClick={() => setShowColorPicker(!showColorPicker)}
            className="w-9 h-9 rounded-xl border-2 border-white/20 hover:border-white/40 transition-colors"
            style={{ backgroundColor: inkColor }}
            title="Ink Color"
          />
          {showColorPicker && (
            <div className="absolute left-12 top-0 bg-[#13110C] border border-white/10 rounded-2xl p-3 grid grid-cols-4 gap-2 z-50 shadow-2xl">
              {INK_COLORS.map((c) => (
                <button
                  key={c.hex}
                  onClick={() => { setInkColor(c.hex); setShowColorPicker(false); }}
                  className={`w-7 h-7 rounded-full border-2 transition-all ${inkColor === c.hex ? "border-blue-500 scale-110" : "border-white/10 hover:border-white/30"}`}
                  style={{ backgroundColor: c.hex }}
                  title={c.name}
                />
              ))}
            </div>
          )}
        </div>

        {/* Size Slider */}
        <div className="flex-1 flex flex-col items-center justify-center relative group">
          <span className="text-[9px] text-white/30 font-bold uppercase tracking-widest mb-2">Size</span>
          <input
            type="range" min="1" max="100"
            value={userSize}
            onChange={(e) => setUserSize(parseInt(e.target.value))}
            className="h-32 w-1.5 appearance-none bg-white/10 rounded-full outline-none cursor-ns-resize [&::-webkit-slider-thumb]:appearance-none [&::-webkit-slider-thumb]:w-3.5 [&::-webkit-slider-thumb]:h-3.5 [&::-webkit-slider-thumb]:bg-white [&::-webkit-slider-thumb]:rounded-full [&::-webkit-slider-thumb]:shadow-lg"
            style={{ writingMode: "vertical-lr", direction: "rtl" }}
          />
          <span className="text-[9px] text-white/50 font-mono mt-1">{userSize}%</span>
        </div>

        {/* Opacity Slider */}
        <div className="flex-1 flex flex-col items-center justify-center relative group">
          <span className="text-[9px] text-white/30 font-bold uppercase tracking-widest mb-2">Opacity</span>
          <input
            type="range" min="1" max="100"
            value={userOpacity}
            onChange={(e) => setUserOpacity(parseInt(e.target.value))}
            className="h-32 w-1.5 appearance-none bg-white/10 rounded-full outline-none cursor-ns-resize [&::-webkit-slider-thumb]:appearance-none [&::-webkit-slider-thumb]:w-3.5 [&::-webkit-slider-thumb]:h-3.5 [&::-webkit-slider-thumb]:bg-blue-500 [&::-webkit-slider-thumb]:rounded-full [&::-webkit-slider-thumb]:shadow-lg"
            style={{ writingMode: "vertical-lr", direction: "rtl" }}
          />
          <span className="text-[9px] text-white/50 font-mono mt-1">{userOpacity}%</span>
        </div>
      </div>

      {/* ── BRUSH PICKER PANEL ── */}
      <div className="w-72 h-full bg-[#13110C] border-r border-white/5 flex flex-col z-20 shrink-0">
        <div className="px-5 pt-5 pb-3 border-b border-white/5">
          <h2 className="text-lg font-black font-outfit text-white">فرش الخط العربي</h2>
          <p className="text-white/30 text-[10px] font-bold uppercase tracking-widest mt-1">{brushes.length} Procreate Brushes</p>
        </div>

        <div className="flex-1 overflow-y-auto py-2 px-3 space-y-1.5" style={{ scrollbarWidth: "thin", scrollbarColor: "#333 transparent" }}>
          {brushes.length === 0 ? (
            <div className="text-white/30 text-center py-10 text-sm animate-pulse">Loading brushes...</div>
          ) : (
            brushes.map((brush) => {
              const isActive = activeBrush?.id === brush.id;
              return (
                <button
                  key={brush.id}
                  onClick={() => setActiveBrush(brush)}
                  className={`w-full flex flex-col rounded-xl transition-all duration-200 border overflow-hidden ${
                    isActive
                      ? "bg-blue-600 border-blue-500 shadow-[0_0_15px_rgba(37,99,235,0.3)]"
                      : "bg-white/[0.03] border-transparent hover:bg-white/[0.06]"
                  }`}
                >
                  {/* Brush name */}
                  <div className="px-3 pt-2.5 pb-1 text-right w-full">
                    <span className={`text-base font-bold ${isActive ? "text-white" : "text-white/70"}`} style={{ fontFamily: "'Noto Sans Arabic', sans-serif" }}>
                      {brush.name}
                    </span>
                  </div>

                  {/* Thumbnail stroke preview from Procreate */}
                  {brush.hasThumbnail ? (
                    <div className="w-full h-10 px-2 pb-2 flex items-center justify-center">
                      <img
                        src={`/brushes/${brush.id}_thumb.png`}
                        alt={brush.name}
                        className={`w-full h-full object-contain ${isActive ? "brightness-200" : "brightness-75"}`}
                        style={{ filter: isActive ? "brightness(2) contrast(0.8)" : "brightness(0.7)" }}
                      />
                    </div>
                  ) : (
                    <div className="w-full h-8 px-3 pb-2">
                      <svg width="100%" height="100%" viewBox="0 0 200 30" preserveAspectRatio="xMidYMid slice">
                        <path d="M 190 15 Q 140 3, 100 15 T 10 15" fill="none" stroke={isActive ? "#fff" : "#555"} strokeWidth={Math.max(2, brush.paintSize * 80)} strokeLinecap="round" />
                      </svg>
                    </div>
                  )}
                </button>
              );
            })
          )}
        </div>

        {/* Bottom Actions */}
        <div className="p-3 border-t border-white/5 grid grid-cols-3 gap-1.5">
          <button onClick={clearCanvas} className="flex items-center justify-center gap-1.5 p-2.5 rounded-lg bg-red-500/10 text-red-400 hover:bg-red-500/20 transition-colors">
            <Eraser className="w-3.5 h-3.5" /> <span className="text-[10px] font-bold">Clear</span>
          </button>
          <button onClick={undo} className="flex items-center justify-center gap-1.5 p-2.5 rounded-lg bg-white/5 text-white/60 hover:bg-white/10 transition-colors">
            <Undo2 className="w-3.5 h-3.5" /> <span className="text-[10px] font-bold">Undo</span>
          </button>
          <button onClick={downloadCanvas} className="flex items-center justify-center gap-1.5 p-2.5 rounded-lg bg-white/5 text-white/60 hover:bg-white/10 transition-colors">
            <Download className="w-3.5 h-3.5" /> <span className="text-[10px] font-bold">Save</span>
          </button>
        </div>
      </div>

      {/* ── THE CALLIGRAPHY CANVAS ── */}
      <div className="flex-1 relative bg-[#FDFBF7] cursor-crosshair h-full overflow-hidden">
        {!brushImage && (
          <div className="absolute inset-0 flex items-center justify-center pointer-events-none z-10 bg-[#FDFBF7]/80 backdrop-blur-sm">
            <div className="animate-pulse flex flex-col items-center gap-3">
              <div className="w-8 h-8 rounded-full border-4 border-black/10 border-t-black/50 animate-spin" />
              <span className="text-black/30 font-bold uppercase tracking-widest text-[10px]">Loading Brush Shape...</span>
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
        {/* Faint watermark */}
        <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 text-[25rem] font-bold text-black/[0.015] pointer-events-none select-none z-0" style={{ fontFamily: "'Noto Sans Arabic', sans-serif" }}>
          بسم
        </div>
      </div>
    </div>
  );
}
