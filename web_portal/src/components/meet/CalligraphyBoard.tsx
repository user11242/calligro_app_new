"use client";
/**
 * CalligraphyBoard — Stamp-Based Arabic Calligraphy Engine (Fixed)
 *
 * Uses the ACTUAL Shape.png files from the brushes folder as stamps.
 * Each stamp is:
 *   1. Pre-cropped to only the ink region (not full 2048x2048)
 *   2. Tinted to the selected ink color
 *   3. Placed at the brush's FIXED shapeAngle (NOT rotating with stroke)
 *   4. Stamped every ~1px along the smoothed path for seamless coverage
 *
 * The thick/thin effect comes naturally from the shape:
 *   - The Shape.png is a tall thin slit (chisel nib shape)
 *   - At a FIXED angle, moving in different directions overlaps different
 *     amounts of the slit → natural thick/thin
 */

import React, { useRef, useEffect, useState, useCallback } from "react";
import { Eraser, Download, Undo2, Sliders, X, RotateCcw, Paintbrush, PenLine } from "lucide-react";

// ── Types ────────────────────────────────────────────────────────────────────

interface BrushProfile {
  id: string;
  name: string;
  shapeAngle: number;
  paintSize: number;
  plotSmoothing: number;
  slitWidthPct: number;
  dynamicsSpeedSize: number;
  hasThumbnail: boolean;
  hasShape: boolean;
  maxOpacity: number;
  paintOpacity: number;
  shapeSize: number[];
  [key: string]: unknown;
}

interface StrokeRecord {
  points: number[][];
  color: string;
  brushId: string;
  brushSize: number;
  nibAngle: number;
  opacity: number;
}

const INK_COLORS = [
  { name: "Ink Black",  hex: "#000000" },
  { name: "Charcoal",   hex: "#1a1a1a" },
  { name: "Umber",      hex: "#3E2723" },
  { name: "Sepia",      hex: "#6B4226" },
  { name: "Navy",       hex: "#1A237E" },
  { name: "Forest",     hex: "#1B5E20" },
  { name: "Crimson",    hex: "#7B0000" },
  { name: "Gold",       hex: "#7D5A00" },
  { name: "White",      hex: "#FFFFFF" },
];

type StudioTab = "stroke" | "shape";

// ── Helpers ──────────────────────────────────────────────────────────────────

/** Catmull-Rom interpolation between p1 and p2, with control points p0 and p3 */
function catmullRom(p0: number[], p1: number[], p2: number[], p3: number[], t: number): number[] {
  const t2 = t * t;
  const t3 = t2 * t;
  return [
    0.5 * ((2 * p1[0]) + (-p0[0] + p2[0]) * t + (2 * p0[0] - 5 * p1[0] + 4 * p2[0] - p3[0]) * t2 + (-p0[0] + 3 * p1[0] - 3 * p2[0] + p3[0]) * t3),
    0.5 * ((2 * p1[1]) + (-p0[1] + p2[1]) * t + (2 * p0[1] - 5 * p1[1] + 4 * p2[1] - p3[1]) * t2 + (-p0[1] + 3 * p1[1] - 3 * p2[1] + p3[1]) * t3),
  ];
}

/** Interpolate path points to get smooth dense points every ~spacing px */
function smoothPath(rawPoints: number[][], spacing: number): number[][] {
  if (rawPoints.length < 2) return rawPoints;
  
  const result: number[][] = [rawPoints[0]];
  const pts = rawPoints;
  
  for (let i = 0; i < pts.length - 1; i++) {
    const p0 = pts[Math.max(0, i - 1)];
    const p1 = pts[i];
    const p2 = pts[i + 1];
    const p3 = pts[Math.min(pts.length - 1, i + 2)];
    
    const dx = p2[0] - p1[0];
    const dy = p2[1] - p1[1];
    const segLen = Math.sqrt(dx * dx + dy * dy);
    const steps = Math.max(1, Math.ceil(segLen / spacing));
    
    for (let s = 1; s <= steps; s++) {
      const t = s / steps;
      result.push(catmullRom(p0, p1, p2, p3, t));
    }
  }
  
  return result;
}

// ── Component ────────────────────────────────────────────────────────────────

interface CalligraphyBoardProps {
  isTeacher?: boolean;
}

export default function CalligraphyBoard({ isTeacher = false }: CalligraphyBoardProps) {
  const canvasRef  = useRef<HTMLCanvasElement>(null);
  const ctxRef     = useRef<CanvasRenderingContext2D | null>(null);

  const strokesRef = useRef<StrokeRecord[]>([]);
  const currentStrokeRef = useRef<StrokeRecord | null>(null);
  const lastDrawnIndexRef = useRef(0);

  const [isDrawing, setIsDrawing] = useState(false);
  const [brushes, setBrushes]   = useState<BrushProfile[]>([]);
  const [activeBrush, setActiveBrush] = useState<BrushProfile | null>(null);
  const [localBrush, setLocalBrush] = useState<BrushProfile | null>(null);

  const [inkColor, setInkColor]     = useState("#000000");
  const [showColors, setShowColors] = useState(false);
  const [userSize, setUserSize]     = useState(40);
  const [userOpacity, setUserOpacity] = useState(100);

  const [showStudio, setShowStudio] = useState(false);
  const [studioTab, setStudioTab] = useState<StudioTab>("stroke");
  const [stylusOnly, setStylusOnly] = useState(false);

  const dprRef = useRef(1);

  // Cached tinted stamp canvases: key = brushId + color + size
  const stampCacheRef = useRef<Map<string, HTMLCanvasElement>>(new Map());
  // Loaded crop images: key = brushId
  const cropImagesRef = useRef<Map<string, HTMLImageElement>>(new Map());

  // ── Load brush list ─────────────────────────────────────────────────────
  useEffect(() => {
    fetch("/brushes/brushes.json")
      .then(r => r.json())
      .then((data: BrushProfile[]) => {
        setBrushes(data);
        if (data.length > 0) {
          setActiveBrush(data[0]);
          setLocalBrush({ ...data[0] });
        }
        // Preload all crop images
        data.forEach(brush => {
          if (brush.hasShape) {
            const img = new Image();
            img.src = `/brushes/${brush.id}_crop.png`;
            img.onload = () => {
              cropImagesRef.current.set(brush.id, img);
            };
            // Fallback: try original shape
            img.onerror = () => {
              const fallback = new Image();
              fallback.src = `/brushes/${brush.id}.png`;
              fallback.onload = () => {
                cropImagesRef.current.set(brush.id, fallback);
              };
            };
          }
        });
      });
  }, []);

  useEffect(() => {
    if (activeBrush) {
      setLocalBrush({ ...activeBrush });
      stampCacheRef.current.clear(); // Clear cache when brush changes
    }
  }, [activeBrush]);

  // ── Init canvas ─────────────────────────────────────────────────────────
  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext("2d", { willReadFrequently: false })!;
    const dpr = window.devicePixelRatio || 1;
    dprRef.current = dpr;
    const rect = canvas.parentElement?.getBoundingClientRect();
    if (rect) {
      canvas.width  = rect.width  * dpr;
      canvas.height = rect.height * dpr;
      canvas.style.width  = `${rect.width}px`;
      canvas.style.height = `${rect.height}px`;
    }
    ctx.scale(dpr, dpr);
    ctx.fillStyle = "#FDFBF7";
    ctx.fillRect(0, 0, canvas.width, canvas.height);
    ctxRef.current = ctx;
  }, []);

  // ── Get or create tinted stamp ─────────────────────────────────────────
  const getTintedStamp = useCallback((brushId: string, color: string, size: number): HTMLCanvasElement | null => {
    const cacheKey = `${brushId}_${color}_${size}`;
    const cached = stampCacheRef.current.get(cacheKey);
    if (cached) return cached;

    const cropImg = cropImagesRef.current.get(brushId);
    if (!cropImg) return null;

    // Scale the crop image to the target size
    // The crop image height represents the full nib length
    const scale = size / cropImg.height;
    const sw = Math.max(1, Math.round(cropImg.width * scale));
    const sh = Math.max(1, Math.round(cropImg.height * scale));

    const stamp = document.createElement("canvas");
    stamp.width = sw;
    stamp.height = sh;
    const sctx = stamp.getContext("2d")!;

    // Draw the scaled crop image
    sctx.drawImage(cropImg, 0, 0, sw, sh);

    // Tint: the crop image has white pixels with alpha = brightness
    // We need to replace white with the ink color
    // Use 'source-in' compositing: draw color rect, keeping only where stamp has alpha
    sctx.globalCompositeOperation = "source-in";
    sctx.fillStyle = color;
    sctx.fillRect(0, 0, sw, sh);
    sctx.globalCompositeOperation = "source-over";

    stampCacheRef.current.set(cacheKey, stamp);
    return stamp;
  }, []);

  // ── Render all strokes ─────────────────────────────────────────────────
  const renderAllStrokes = useCallback(() => {
    const ctx = ctxRef.current;
    const canvas = canvasRef.current;
    if (!ctx || !canvas) return;

    const dpr = dprRef.current;
    const w = canvas.width / dpr;
    const h = canvas.height / dpr;

    ctx.save();
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    ctx.fillStyle = "#FDFBF7";
    ctx.fillRect(0, 0, w, h);

    const allStrokes = [...strokesRef.current];
    if (currentStrokeRef.current) allStrokes.push(currentStrokeRef.current);

    for (const stroke of allStrokes) {
      renderStroke(ctx, stroke);
    }
    ctx.restore();
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [getTintedStamp]);

  // ── Render a single stroke ─────────────────────────────────────────────
  const renderStroke = (ctx: CanvasRenderingContext2D, stroke: StrokeRecord) => {
    if (stroke.points.length < 2) return;

    const { color, brushId, brushSize, nibAngle, opacity } = stroke;
    const stamp = getTintedStamp(brushId, color, brushSize);
    if (!stamp) return;

    // Smooth the path - interpolate to get a point every ~1.5px
    const smoothed = smoothPath(stroke.points, 1.5);

    ctx.save();
    ctx.globalAlpha = Math.max(0.05, opacity);

    const halfW = stamp.width / 2;
    const halfH = stamp.height / 2;

    for (let i = 0; i < smoothed.length; i++) {
      const [x, y] = smoothed[i];

      ctx.save();
      ctx.translate(x, y);
      // Fixed nib angle — this is the key: the pen angle does NOT change
      ctx.rotate(nibAngle);
      ctx.drawImage(stamp, -halfW, -halfH);
      ctx.restore();
    }

    ctx.restore();
  };

  // ── Incremental render (only new points during drawing) ─────────────────
  const renderIncremental = useCallback(() => {
    const ctx = ctxRef.current;
    const stroke = currentStrokeRef.current;
    if (!ctx || !stroke || stroke.points.length < 2) return;

    const { color, brushId, brushSize, nibAngle, opacity } = stroke;
    const stamp = getTintedStamp(brushId, color, brushSize);
    if (!stamp) return;

    // Only interpolate and draw the segment from last drawn point to end
    const startIdx = Math.max(0, lastDrawnIndexRef.current - 1);
    const segmentPts = stroke.points.slice(startIdx);
    
    if (segmentPts.length < 2) return;
    
    const smoothed = smoothPath(segmentPts, 1.5);

    const dpr = dprRef.current;
    ctx.save();
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    ctx.globalAlpha = Math.max(0.05, opacity);

    const halfW = stamp.width / 2;
    const halfH = stamp.height / 2;

    for (let i = 0; i < smoothed.length; i++) {
      const [x, y] = smoothed[i];
      ctx.save();
      ctx.translate(x, y);
      ctx.rotate(nibAngle);
      ctx.drawImage(stamp, -halfW, -halfH);
      ctx.restore();
    }

    ctx.restore();
    lastDrawnIndexRef.current = stroke.points.length - 1;
  }, [getTintedStamp]);

  // ── Pointer events ──────────────────────────────────────────────────────
  const getPos = (e: React.PointerEvent<HTMLCanvasElement>) => {
    const rect = canvasRef.current?.getBoundingClientRect();
    if (!rect) return [0, 0];
    return [e.clientX - rect.left, e.clientY - rect.top];
  };

  const onPointerDown = (e: React.PointerEvent<HTMLCanvasElement>) => {
    if (stylusOnly && e.pointerType !== "pen") return;
    
    (e.target as Element).setPointerCapture(e.pointerId);
    const brush = localBrush;
    if (!brush) return;

    const [x, y] = getPos(e);

    // Brush size: paintSize (0-1) scaled by user slider
    // paintSize 0.5 at userSize 40 → ~25px nib
    const baseSize = 6 + brush.paintSize * 60 * (userSize / 50);

    currentStrokeRef.current = {
      points: [[x, y]],
      color: inkColor,
      brushId: brush.id,
      brushSize: Math.max(4, baseSize),
      nibAngle: brush.shapeAngle,
      opacity: brush.paintOpacity * (brush.maxOpacity || 1) * (userOpacity / 100),
    };

    lastDrawnIndexRef.current = 0;
    setIsDrawing(true);
  };

  const onPointerMove = (e: React.PointerEvent<HTMLCanvasElement>) => {
    if (!isDrawing || !currentStrokeRef.current) return;
    const [x, y] = getPos(e);
    
    // Simple input smoothing: average with previous point
    const pts = currentStrokeRef.current.points;
    if (pts.length > 0) {
      const [lx, ly] = pts[pts.length - 1];
      const smoothFactor = localBrush?.plotSmoothing ?? 0.5;
      const sx = lx + (x - lx) * (1 - smoothFactor * 0.5);
      const sy = ly + (y - ly) * (1 - smoothFactor * 0.5);
      currentStrokeRef.current.points.push([sx, sy]);
    } else {
      currentStrokeRef.current.points.push([x, y]);
    }
    
    renderIncremental();
  };

  const onPointerUp = () => {
    if (currentStrokeRef.current && currentStrokeRef.current.points.length > 1) {
      strokesRef.current.push(currentStrokeRef.current);
    }
    currentStrokeRef.current = null;
    lastDrawnIndexRef.current = 0;
    setIsDrawing(false);
    renderAllStrokes();
  };

  const undo = useCallback(() => {
    strokesRef.current.pop();
    renderAllStrokes();
  }, [renderAllStrokes]);

  const clearCanvas = useCallback(() => {
    strokesRef.current = [];
    currentStrokeRef.current = null;
    renderAllStrokes();
  }, [renderAllStrokes]);

  const downloadCanvas = () => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const a = document.createElement("a");
    a.download = "calligro-artwork.png";
    a.href = canvas.toDataURL("image/png");
    a.click();
  };

  const resetBrush = () => {
    if (activeBrush) {
      setLocalBrush({ ...activeBrush });
      stampCacheRef.current.clear();
    }
  };

  // ── UI ──────────────────────────────────────────────────────────────────
  return (
    <div className="w-full h-full flex rounded-3xl overflow-hidden shadow-2xl border border-white/10 relative">

      {/* ── LEFT SIDEBAR ── */}
      <div className="w-14 h-full bg-[#0D0B08] border-r border-white/5 flex flex-col items-center py-4 gap-3 shrink-0 z-30">
        <button onClick={undo} title="Undo"
          className="w-9 h-9 rounded-xl bg-white/5 hover:bg-white/15 flex items-center justify-center text-white/40 hover:text-white transition-all">
          <Undo2 className="w-4 h-4" />
        </button>

        <div className="relative">
          <button onClick={() => setShowColors(v => !v)}
            style={{ background: inkColor }}
            className="w-9 h-9 rounded-xl border-2 border-white/20 hover:border-white/60 shadow-lg transition-all" />
        </div>

        {/* Full-screen Overlay for Radial Menu */}
        {showColors && (
          <div className="fixed inset-0 z-[100]" onClick={() => setShowColors(false)}>
            <div 
              className="absolute ltr:left-[280px] rtl:right-[280px] top-1/2 -translate-y-1/2 w-64 h-64 animate-in fade-in zoom-in-95 duration-200"
              onClick={e => e.stopPropagation()} // prevent closing when clicking menu
            >
              <div className="absolute inset-0 bg-[#13151A]/95 backdrop-blur-2xl border border-white/10 rounded-full shadow-[0_0_50px_rgba(0,0,0,0.6)]"></div>
              
              {/* Inner concentric lines for the "radial menu" look */}
              <div className="absolute inset-10 border border-white/5 rounded-full pointer-events-none"></div>
              <div className="absolute inset-20 border border-white/[0.02] rounded-full pointer-events-none"></div>
              
              {/* Color Buttons */}
              {[...INK_COLORS, { name: "Custom", hex: "custom" }].map((c, i, arr) => {
                const angle = (i / arr.length) * 360 - 90; 
                const radius = 95; // distance from center
                const center = 128; // w-64 is 256px, half is 128
                const x = center + Math.cos((angle * Math.PI) / 180) * radius;
                const y = center + Math.sin((angle * Math.PI) / 180) * radius;
                
                const isCustom = c.hex === "custom";
                
                return (
                  <div key={c.name}
                    className={`absolute w-12 h-12 rounded-full border-[3px] transition-all duration-300 hover:scale-125 hover:z-20 flex items-center justify-center overflow-hidden ${
                      inkColor === c.hex || (isCustom && !INK_COLORS.find(ic => ic.hex === inkColor)) ? "border-blue-400 scale-110 shadow-[0_0_25px_rgba(96,165,250,0.5)] z-10" : "border-white/10 shadow-lg"
                    }`}
                    style={{ 
                      background: isCustom ? "conic-gradient(red, yellow, lime, aqua, blue, magenta, red)" : c.hex,
                      left: `${x}px`,
                      top: `${y}px`,
                      transform: 'translate(-50%, -50%)'
                    }}
                    title={c.name}
                  >
                    {!isCustom && (
                      <button 
                        className="w-full h-full"
                        onClick={() => { setInkColor(c.hex); stampCacheRef.current.clear(); setShowColors(false); }}
                      />
                    )}
                    {isCustom && (
                      <input 
                        type="color" 
                        value={inkColor}
                        onChange={(e) => {
                          setInkColor(e.target.value);
                          stampCacheRef.current.clear();
                        }}
                        className="opacity-0 absolute inset-0 w-full h-full cursor-pointer"
                      />
                    )}
                  </div>
                );
              })}
              
              {/* Center close button */}
              <button 
                onClick={() => setShowColors(false)}
                className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-14 h-14 rounded-full bg-white/5 hover:bg-white/20 border border-white/10 flex items-center justify-center transition-all text-white/50 hover:text-white"
              >
                <X className="w-6 h-6" />
              </button>
            </div>
          </div>
        )}

        <button onClick={() => setShowStudio(v => !v)}
          className={`w-9 h-9 rounded-xl flex items-center justify-center transition-all ${
            showStudio ? "bg-blue-600 text-white" : "bg-white/5 text-white/40 hover:bg-white/15 hover:text-white"
          }`} title="Brush Studio">
          <Sliders className="w-4 h-4" />
        </button>

        <button onClick={() => setStylusOnly(s => !s)}
          className={`w-9 h-9 rounded-xl flex items-center justify-center transition-all ${
            stylusOnly ? "bg-emerald-500/20 text-emerald-400 border border-emerald-500/30 shadow-[0_0_15px_rgba(16,185,129,0.3)]" : "bg-white/5 text-white/40 hover:bg-white/15 hover:text-white"
          }`} title="Stylus Only Mode (Palm Rejection)">
          <PenLine className="w-4 h-4" />
        </button>

        <div className="flex-1 flex flex-col items-center justify-center gap-1.5">
          <span className="text-[8px] text-white/25 font-bold uppercase tracking-widest">Size</span>
          <input type="range" min="5" max="150" value={userSize}
            onChange={e => { setUserSize(+e.target.value); stampCacheRef.current.clear(); }}
            className="h-32 w-1 appearance-none bg-white/10 rounded-full cursor-ns-resize
              [&::-webkit-slider-thumb]:appearance-none [&::-webkit-slider-thumb]:w-4
              [&::-webkit-slider-thumb]:h-4 [&::-webkit-slider-thumb]:bg-white
              [&::-webkit-slider-thumb]:rounded-full [&::-webkit-slider-thumb]:shadow"
            style={{ writingMode: "vertical-lr", direction: "rtl" }} />
          <span className="text-[8px] text-white/30 font-mono">{userSize}</span>
        </div>

        <div className="flex-1 flex flex-col items-center justify-center gap-1.5">
          <span className="text-[8px] text-white/25 font-bold uppercase tracking-widest">Opac</span>
          <input type="range" min="5" max="100" value={userOpacity}
            onChange={e => setUserOpacity(+e.target.value)}
            className="h-32 w-1 appearance-none bg-white/10 rounded-full cursor-ns-resize
              [&::-webkit-slider-thumb]:appearance-none [&::-webkit-slider-thumb]:w-4
              [&::-webkit-slider-thumb]:h-4 [&::-webkit-slider-thumb]:bg-blue-400
              [&::-webkit-slider-thumb]:rounded-full [&::-webkit-slider-thumb]:shadow"
            style={{ writingMode: "vertical-lr", direction: "rtl" }} />
          <span className="text-[8px] text-white/30 font-mono">{userOpacity}%</span>
        </div>
      </div>

      {/* ── BRUSH LIST ── */}
      <div className="w-[200px] h-full bg-[#100E0A] border-r border-white/5 flex flex-col shrink-0 z-20">
        <div className="px-4 pt-4 pb-2.5 border-b border-white/5">
          <h2 className="text-[12px] font-black text-white">فرش الخط العربي</h2>
          <p className="text-white/25 text-[8px] font-bold uppercase tracking-widest mt-0.5">
            {brushes.length} BRUSHES
          </p>
        </div>

        <div className="flex-1 overflow-y-auto py-1.5 px-1.5 space-y-0.5"
          style={{ scrollbarWidth: "thin", scrollbarColor: "#2a2520 transparent" }}>
          {brushes.map(brush => {
            const isActive = activeBrush?.id === brush.id;
            return (
              <button key={brush.id} onClick={() => setActiveBrush(brush)}
                className={`w-full rounded-xl border overflow-hidden transition-all duration-150 text-right ${
                  isActive
                    ? "bg-blue-600/90 border-blue-500/70 shadow-[0_0_16px_rgba(37,99,235,0.25)]"
                    : "bg-white/[0.025] border-transparent hover:bg-white/[0.06]"
                }`}>
                <div className="px-3 pt-2 pb-1">
                  <span className={`text-[11px] font-bold ${isActive ? "text-white" : "text-white/65"}`}
                    style={{ fontFamily: "'Noto Sans Arabic', sans-serif" }}>
                    {brush.name}
                  </span>
                </div>
                {brush.hasThumbnail && (
                  <div className="w-full h-8 px-3 pb-1.5">
                    <img src={`/brushes/${brush.id}_thumb.png`} alt={brush.name}
                      className="w-full h-full object-contain"
                      style={{ filter: isActive ? "brightness(3) contrast(0.7)" : "brightness(0.55) contrast(1.4)" }} />
                  </div>
                )}
              </button>
            );
          })}
        </div>

        <div className="p-1.5 border-t border-white/5 grid grid-cols-3 gap-1">
          <button onClick={clearCanvas}
            className="flex items-center justify-center gap-1 py-2 rounded-lg bg-red-500/10 text-red-400/80 hover:bg-red-500/20 hover:text-red-300 transition-all">
            <Eraser className="w-3 h-3" /><span className="text-[9px] font-bold">Clear</span>
          </button>
          <button onClick={undo}
            className="flex items-center justify-center gap-1 py-2 rounded-lg bg-white/5 text-white/40 hover:bg-white/10 hover:text-white transition-all">
            <Undo2 className="w-3 h-3" /><span className="text-[9px] font-bold">Undo</span>
          </button>
          <button onClick={downloadCanvas}
            className="flex items-center justify-center gap-1 py-2 rounded-lg bg-white/5 text-white/40 hover:bg-white/10 hover:text-white transition-all">
            <Download className="w-3 h-3" /><span className="text-[9px] font-bold">Save</span>
          </button>
        </div>
      </div>

      {/* ── CANVAS ── */}
      <div className="flex-1 h-full relative overflow-hidden bg-[#FDFBF7] flex">
        <div className="flex-1 relative h-full">
          {/* Watermark */}
          <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 pointer-events-none select-none"
            style={{ fontSize: "20rem", color: "rgba(0,0,0,0.015)", fontFamily: "'Noto Naskh Arabic', serif", lineHeight: 1 }}>
            ب
          </div>

          {/* Active brush info */}
          {localBrush && (
            <div className="absolute top-3 left-4 z-10 pointer-events-none">
              <div className="bg-black/70 backdrop-blur-md rounded-full px-4 py-1.5 flex items-center gap-2 text-white border border-white/10 shadow-lg">
                <Paintbrush className="w-3.5 h-3.5 text-blue-400" />
                <span className="text-xs font-bold" style={{ fontFamily: "'Noto Sans Arabic', sans-serif" }}>
                  {localBrush.name}
                </span>
                <span className="text-white/35 text-[9px] font-mono">
                  angle {Math.round(localBrush.shapeAngle * 180 / Math.PI)}° · nib {Math.round(localBrush.slitWidthPct)}%
                </span>
              </div>
            </div>
          )}

          <canvas ref={canvasRef}
            onPointerDown={onPointerDown}
            onPointerMove={onPointerMove}
            onPointerUp={onPointerUp}
            onPointerLeave={onPointerUp}
            className="absolute inset-0 w-full h-full touch-none cursor-crosshair"
          />
        </div>

        {/* ── BRUSH STUDIO PANEL ── */}
        {showStudio && localBrush && (
          <div className="w-[320px] h-full bg-[#12100C]/95 backdrop-blur-md border-l border-white/10 flex flex-col z-30 shrink-0 text-white">
            <div className="p-4 border-b border-white/10 flex items-center justify-between">
              <div className="flex items-center gap-2">
                <Sliders className="w-4 h-4 text-blue-400" />
                <span className="text-sm font-bold uppercase tracking-wider">Brush Studio</span>
              </div>
              <button onClick={() => setShowStudio(false)} className="text-white/50 hover:text-white p-1 hover:bg-white/10 rounded-lg">
                <X className="w-4 h-4" />
              </button>
            </div>

            <div className="grid grid-cols-2 border-b border-white/10 text-center text-xs">
              {(["stroke", "shape"] as StudioTab[]).map(tab => (
                <button key={tab} onClick={() => setStudioTab(tab)}
                  className={`py-2.5 font-bold capitalize ${studioTab === tab ? "border-b-2 border-blue-500 text-blue-400" : "text-white/60"}`}>
                  {tab}
                </button>
              ))}
            </div>

            <div className="flex-1 overflow-y-auto p-4 space-y-5">

              {studioTab === "stroke" && (
                <>
                  <StudioSlider label="Smoothing (تثبيت)" labelAr="Stabilizer"
                    value={localBrush.plotSmoothing} min={0} max={1} step={0.01}
                    displayValue={`${Math.round(localBrush.plotSmoothing * 100)}%`}
                    onChange={v => setLocalBrush({ ...localBrush, plotSmoothing: v })}
                    desc="High = silky smooth curves, low = responsive raw input" />
                </>
              )}

              {studioTab === "shape" && (
                <>
                  <StudioSlider label="Nib Angle (زاوية القلم)" labelAr="Pen angle"
                    value={localBrush.shapeAngle} min={-1.57} max={1.57} step={0.05}
                    displayValue={`${Math.round(localBrush.shapeAngle * 180 / Math.PI)}°`}
                    onChange={v => { setLocalBrush({ ...localBrush, shapeAngle: v }); stampCacheRef.current.clear(); }}
                    desc="Fixed pen-hold angle — changes where thick/thin appears" />

                  {/* Shape preview */}
                  <div className="space-y-2">
                    <span className="text-xs text-white/60">Shape Preview</span>
                    <div className="w-full h-24 bg-white/5 rounded-xl flex items-center justify-center border border-white/10 overflow-hidden">
                      <img src={`/brushes/${localBrush.id}_crop.png`} alt="Brush shape"
                        className="max-h-20 max-w-full object-contain"
                        style={{ filter: "invert(1)", transform: `rotate(${localBrush.shapeAngle}rad)` }} />
                    </div>
                  </div>
                </>
              )}
            </div>

            <div className="p-4 border-t border-white/10">
              <button onClick={resetBrush}
                className="w-full flex items-center justify-center gap-2 py-2.5 rounded-xl border border-white/20 bg-white/5 hover:bg-white/10 transition-all font-bold text-xs uppercase tracking-wider">
                <RotateCcw className="w-3.5 h-3.5" />
                Reset Defaults
              </button>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}

// ── Studio Slider sub-component ──────────────────────────────────────────────

function StudioSlider({ label, desc, value, min, max, step, displayValue, onChange }: {
  label: string; labelAr?: string; value: number;
  min: number; max: number; step: number; displayValue: string;
  onChange: (v: number) => void; desc: string;
}) {
  return (
    <div className="space-y-2">
      <div className="flex justify-between text-xs">
        <span className="text-white/60">{label}</span>
        <span className="font-mono text-blue-400">{displayValue}</span>
      </div>
      <input type="range" min={min} max={max} step={step} value={value}
        onChange={e => onChange(+e.target.value)}
        className="w-full h-1 bg-white/10 rounded-lg appearance-none cursor-pointer accent-blue-500" />
      <p className="text-[10px] text-white/30">{desc}</p>
    </div>
  );
}
