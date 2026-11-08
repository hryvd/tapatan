import { Nfc, Lock } from "lucide-react";
import { CardT } from "./store";

export const MATERIALS: Record<string, { label: string; bg: string; accent: string }> = {
  obsidian: { label: "Obsidian", bg: "radial-gradient(120% 90% at 85% 0%, rgba(6,182,212,.55), transparent 55%), linear-gradient(145deg,#1b2433,#05080f 70%)", accent: "#22D3EE" },
  cyber: { label: "Cyber Glass", bg: "radial-gradient(110% 90% at 10% 0%, rgba(34,211,238,.6), transparent 55%), radial-gradient(90% 90% at 100% 100%, rgba(99,102,241,.6), transparent 60%), #0b1424", accent: "#67E8F9" },
  chrome: { label: "Holo Chrome", bg: "linear-gradient(135deg,#cbd5e1,#64748b 30%,#e2e8f0 50%,#94a3b8 70%,#475569)", accent: "#0f172a" },
  emerald: { label: "Emerald", bg: "radial-gradient(100% 80% at 90% 0%, rgba(52,211,153,.6), transparent 55%), linear-gradient(145deg,#064e3b,#022c22)", accent: "#6EE7B7" },
  indigo: { label: "Indigo", bg: "radial-gradient(100% 80% at 90% 0%, rgba(167,139,250,.7), transparent 55%), linear-gradient(145deg,#312e81,#1e1b4b)", accent: "#C4B5FD" },
  amber: { label: "Amber", bg: "radial-gradient(100% 80% at 90% 0%, rgba(251,191,36,.65), transparent 55%), linear-gradient(145deg,#3a2a0a,#0c0a05)", accent: "#FCD34D" },
};

export function Chip({ className = "" }: { className?: string }) {
  return (
    <div className={`w-11 h-8 rounded-[7px] relative overflow-hidden ${className}`} style={{ background: "linear-gradient(135deg,#fde68a,#d4a63a 45%,#f5d77a)", boxShadow: "inset 0 0 0 .5px rgba(0,0,0,.4)" }}>
      <span className="absolute inset-y-0 left-1/3 w-px bg-black/25" /><span className="absolute inset-y-0 left-2/3 w-px bg-black/25" /><span className="absolute inset-x-0 top-1/2 h-px bg-black/25" />
    </div>
  );
}

export function Code({ kind, value, dark }: { kind: "qr" | "barcode"; value: string; dark?: boolean }) {
  let h = 2166136261; for (const ch of value || "x") h = Math.imul(h ^ ch.charCodeAt(0), 16777619);
  const rnd = (i: number) => { const x = Math.sin(h + i * 12.9898) * 43758.5453; return x - Math.floor(x); };
  if (kind === "barcode")
    return <svg viewBox="0 0 120 40" preserveAspectRatio="none" className="w-full h-full">{(() => { let x = 2; const out: any[] = []; for (let i = 0; i < 48 && x < 118; i++) { const w = 1 + Math.floor(rnd(i) * 3); if (i % 2 === 0) out.push(<rect key={i} x={x} y="0" width={w} height="40" fill={dark ? "#fff" : "#0f172a"} />); x += w + 0.4; } return out; })()}</svg>;
  const n = 21; const fin = (x: number, y: number) => (x < 7 && y < 7) || (x > 13 && y < 7) || (x < 7 && y > 13);
  const ring = (x: number, y: number) => { const f = (a: number, b: number) => { const dx = Math.min(a, 6 - a), dy = Math.min(b, 6 - b); const m = Math.min(dx, dy); return m === 0 || (m >= 2); }; const lx = x % 14 > 6 && x > 13 ? x - 14 : x, ly = y > 13 ? y - 14 : y; return f(lx, ly); };
  return <svg viewBox={`0 0 ${n} ${n}`} className="w-full h-full">{Array.from({ length: n * n }, (_, i) => { const x = i % n, y = Math.floor(i / n); const on = fin(x, y) ? ring(x, y) : rnd(i) > 0.52; return on ? <rect key={i} x={x} y={y} width="1.02" height="1.02" fill={dark ? "#fff" : "#0f172a"} /> : null; })}</svg>;
}

export function PassFace({ card }: { card: CardT }) {
  const m = MATERIALS[card.material] ?? MATERIALS.cyber;
  return (
    <div className="relative w-full aspect-[1.586] rounded-[22px] overflow-hidden border border-white/20 text-white flex" style={{ background: m.bg }}>
      <div className="absolute inset-0 opacity-[.12] mix-blend-overlay" style={{ backgroundImage: "repeating-linear-gradient(90deg,#fff 0 1px,transparent 1px 3px)" }} />
      <div className="relative flex-1 p-4 flex flex-col justify-between min-w-0">
        <div><p className="font-mono-ui text-[8.5px] tracking-widest opacity-70">{card.format === "qr" ? "QR PASS" : "BARCODE PASS"}</p><p className="text-[17px] leading-tight mt-1 truncate" style={{ fontWeight: 800 }}>{card.name}</p></div>
        <div><p className="font-mono-ui text-[8px] opacity-60">CODE</p><p className="font-mono-ui text-[11px] truncate">{card.code}</p></div>
      </div>
      <div className={`relative my-3 mr-3 rounded-[14px] bg-white p-2 flex items-center justify-center ${card.format === "qr" ? "w-[86px] h-[86px] self-center" : "w-[96px] self-center h-[60px]"}`}><Code kind={card.format ?? "qr"} value={card.code ?? ""} /></div>
      <span className="absolute left-[calc(100%-110px)] -top-2 w-4 h-4 rounded-full bg-[#0A0E17]" /><span className="absolute left-[calc(100%-110px)] -bottom-2 w-4 h-4 rounded-full bg-[#0A0E17]" />
    </div>
  );
}

export function CardFace({ card, holder, tilt = { x: 0, y: 0 }, frozen, small }: { card: CardT; holder: string; tilt?: { x: number; y: number }; frozen?: boolean; small?: boolean }) {
  if (card.kind === "pass") return <PassFace card={card} />;
  const m = MATERIALS[card.material] ?? MATERIALS.obsidian;
  const dark = card.material === "chrome";
  const txt = dark ? "text-slate-900" : "text-white";
  return (
    <div className="relative w-full aspect-[1.586] rounded-[22px] overflow-hidden preserve-3d border border-white/20" style={{ background: m.bg, boxShadow: "inset 0 1px 0 rgba(255,255,255,.45), inset 0 0 40px rgba(255,255,255,.04)" }}>
      {/* brushed grain */}
      <div className="absolute inset-0 opacity-[.13] mix-blend-overlay" style={{ backgroundImage: "repeating-linear-gradient(90deg,#fff 0 1px,transparent 1px 3px)" }} />
      {/* holographic foil */}
      <div className="absolute inset-0 mix-blend-color-dodge opacity-60 pointer-events-none" style={{
        background: `linear-gradient(${115 + tilt.x * 40}deg, transparent ${30 + tilt.x * 25}%, rgba(255,0,200,.35) ${42 + tilt.x * 25}%, rgba(0,255,220,.4) ${50 + tilt.x * 25}%, rgba(255,230,0,.3) ${58 + tilt.x * 25}%, transparent ${70 + tilt.x * 25}%)` }} />
      <div className="absolute -top-16 -right-10 w-48 h-48 rounded-full bg-white/10 blur-2xl pointer-events-none" style={{ transform: `translate(${tilt.x * -30}px,${tilt.y * -20}px)` }} />
      <div className={`relative h-full p-4 flex flex-col justify-between ${txt}`}>
        <div className="flex items-start justify-between" style={{ transform: "translateZ(18px)" }}>
          <div>
            <p className={`${small ? "text-[15px]" : "text-[17px]"} leading-none`} style={{ fontWeight: 800, textShadow: dark ? "none" : "0 1px 0 rgba(0,0,0,.4)" }}>tap<span style={{ color: m.accent }}>@</span>tan</p>
            <p className="font-mono-ui text-[8.5px] opacity-70 mt-1 tracking-wider">{card.physical ? "JCOP4 J3R150" : card.kind === "bank" ? (card.bank ?? "BANK").toUpperCase() : "VIRTUAL"}</p>
          </div>
          <Nfc className="w-5 h-5 opacity-80" />
        </div>
        <div style={{ transform: "translateZ(30px)" }}>
          <Chip className="mb-2.5" />
          <p className="font-mono-ui text-[13.5px] tracking-[.12em]">{card.num}</p>
        </div>
        <div className="flex items-end justify-between" style={{ transform: "translateZ(14px)" }}>
          <p className="text-[10.5px] tracking-wider truncate max-w-[150px]" style={{ fontWeight: 600 }}>{holder}</p>
          {card.physical
            ? <span className="font-mono-ui text-[8.5px] px-2 py-0.5 rounded-full bg-emerald-400/20 border border-emerald-300/50 text-emerald-200">ENROLLED · TPT4</span>
            : <span className="text-[10px] opacity-80" style={{ fontWeight: 700 }}>{card.network.split(" ")[0].toUpperCase()}</span>}
        </div>
      </div>
      {frozen && (
        <div className="absolute inset-0 flex items-center justify-center bg-sky-100/25 backdrop-blur-[5px]" style={{ backgroundImage: "linear-gradient(135deg,rgba(255,255,255,.4),rgba(186,230,253,.1) 40%,rgba(255,255,255,.35))" }}>
          <span className="w-12 h-12 rounded-full bg-white/30 border border-white/60 flex items-center justify-center"><Lock className="w-5 h-5 text-white" /></span>
        </div>
      )}
    </div>
  );
}
