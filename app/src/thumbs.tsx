import { useEffect, useRef } from "react";
import type { Install } from "./types";

// design/thumbnails.js is loaded by index.html and exposes window.SpellbookThumbnails.
declare global {
  interface Window {
    SpellbookThumbnails: {
      PALETTES: string[][];
      thumbnailFor: (input: { packageId: string; skillId: string; packageName?: string; skillNames?: string[]; prose?: string }) => { paletteIndex: number; styleIndex: number; categoryIndex: number; category: string };
      render: (canvas: HTMLCanvasElement, spec: unknown, size: number) => HTMLCanvasElement;
    };
  }
}

const specCache = new Map<string, ReturnType<Window["SpellbookThumbnails"]["thumbnailFor"]>>();
export function specFor(install: Install) {
  let s = specCache.get(install.id);
  if (!s) {
    s = window.SpellbookThumbnails.thumbnailFor({ packageId: install.id, skillId: install.id, packageName: install.name, skillNames: install.skills.map((k) => k.name), prose: install.skills.map((k) => k.description).join(" ") });
    specCache.set(install.id, s);
  }
  return s;
}
export function paletteFor(install: Install): string[] { const T = window.SpellbookThumbnails; return T.PALETTES[specFor(install).paletteIndex % T.PALETTES.length]; }

export function paint(canvas: HTMLCanvasElement, install: Install, size: number, square: boolean) {
  const T = window.SpellbookThumbnails; if (!T) return;
  const spec = specFor(install);
  if (!square) { T.render(canvas, spec, size); return; }
  const r = window.devicePixelRatio || 1;
  const big = document.createElement("canvas"); T.render(big, spec, Math.round(size * 1.45));
  canvas.width = Math.round(size * r); canvas.height = canvas.width; canvas.style.width = size + "px"; canvas.style.height = size + "px";
  const off = Math.round(size * 0.225 * r);
  canvas.getContext("2d")!.drawImage(big, -off, -off);
}

export function Thumb({ install, size, square = false, className, style }: { install: Install; size: number; square?: boolean; className?: string; style?: React.CSSProperties }) {
  const ref = useRef<HTMLCanvasElement>(null);
  useEffect(() => { if (ref.current) paint(ref.current, install, size, square); }, [install.id, size, square]);
  return <canvas ref={ref} className={className} style={style} aria-hidden="true" />;
}
