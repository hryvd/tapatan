import { useEffect, useRef, useState } from "react";
import { motion } from "motion/react";
import { RotateCw, Layers, Zap, Snowflake, ChevronDown, Copy, Plus, ChevronUp } from "lucide-react";
import { useApp } from "./store";
import { CardFace, MATERIALS, Code } from "./CardFace";
import { Btn } from "./ui";

const UID = "04:7A:93:E2:10:88:01";

function Back({ card, token }: { card: any; token: number }) {
  const [cvv, setCvv] = useState(0);
  useEffect(() => { if (cvv > 0) { const t = setTimeout(() => setCvv(cvv - 1), 1000); return () => clearTimeout(t); } }, [cvv]);
  const m = MATERIALS[card.material] ?? MATERIALS.obsidian;
  if (card.kind === "pass")
    return (
      <div className="w-full aspect-[1.586] rounded-[22px] overflow-hidden border border-white/20 bg-white flex flex-col items-center justify-center p-3">
        <div className={card.format === "qr" ? "h-[110px] w-[110px]" : "h-[70px] w-[200px]"}><Code kind={card.format ?? "qr"} value={card.code ?? ""} /></div>
        <p className="font-mono-ui text-[11px] text-slate-700 mt-2">{card.code}</p>
        <p className="text-[9px] text-slate-400">Show at the scanner</p>
      </div>
    );
  if (card.kind === "bank")
    return (
      <div className="relative w-full aspect-[1.586] rounded-[22px] overflow-hidden border border-white/20 text-white" style={{ background: m.bg }}>
        <div className="absolute inset-0 bg-black/45" /><div className="relative p-4 pt-5 space-y-2.5 font-mono-ui text-[10px]">
          <div><p className="text-white/50 text-[8px]">BANK</p><p>{card.bank}</p></div>
          <div><p className="text-white/50 text-[8px]">ACCOUNT NO.</p><p>•••• •••• {card.acct?.slice(-4)}</p></div>
          <div className="flex gap-6"><div><p className="text-white/50 text-[8px]">EXPIRES</p><p>{card.expiry}</p></div><div><p className="text-white/50 text-[8px]">CVV</p><p>•••</p></div></div>
          <p className="text-[8px] text-cyan-200">Secured by JCOP4 · tap flip to hide</p>
        </div></div>
    );
  const cells = Array.from({ length: 49 }, (_, i) => ((i * 7 + token * 13 + (i % 5) * token) % 3) === 0);
  return (
    <div className="relative w-full aspect-[1.586] rounded-[22px] overflow-hidden border border-white/20 text-white" style={{ background: m.bg }}>
      <div className="absolute inset-0 bg-black/45" />
      <div className="relative h-full flex flex-col">
        <div className="h-9 mt-4 bg-black/80" />
        <div className="flex gap-3 px-4 mt-3">
          <div className="flex-1 min-w-0">
            <button onClick={() => setCvv(10)} className="h-8 w-full rounded-md bg-white/90 text-slate-900 font-mono-ui text-[11px] flex items-center justify-between px-2.5" style={{ transform: "scaleX(-1)" }}>
              <span style={{ transform: "scaleX(-1)" }}>{cvv ? "CVV 428" : "Tap to reveal 10s"}</span>
              <span style={{ transform: "scaleX(-1)" }} className="text-cyan-700">{cvv ? cvv + "s" : "•••"}</span>
            </button>
            <p className="font-mono-ui text-[8px] text-white/50 mt-2">HARDWARE UID</p>
            <p className="font-mono-ui text-[10px]">{UID}</p>
            <p className="font-mono-ui text-[8px] text-white/50 mt-1.5">APPLET AID</p>
            <p className="font-mono-ui text-[10px]">F07461706174616E0101</p>
          </div>
          <div className="w-[74px] flex-shrink-0">
            <div className="grid grid-cols-7 gap-px p-1 bg-white rounded-md">{cells.map((c, i) => <span key={i} className={`aspect-square ${c ? "bg-slate-900" : "bg-white"}`} />)}</div>
            <p className="font-mono-ui text-[8px] text-center text-cyan-200 mt-1">TM•{(0x8f2a + token).toString(16).toUpperCase()}•9000</p>
          </div>
        </div>
      </div>
    </div>
  );
}

function XRay() {
  const layer = "absolute inset-0 rounded-[18px] border";
  return (
    <div className="relative w-full aspect-[1.586] preserve-3d" style={{ transform: "rotateX(58deg) rotateZ(-32deg) scale(.78)", transformStyle: "preserve-3d" }}>
      <div className={`${layer} border-white/30 bg-gradient-to-br from-white/20 to-cyan-300/10 backdrop-blur-[2px]`} style={{ transform: "translateZ(70px)" }}>
        <span className="absolute left-3 top-3 text-white text-[11px]" style={{ fontWeight: 800 }}>tap@tan · polycarbonate + hologram</span>
      </div>
      <div className={`${layer} border-amber-300/50 bg-amber-500/5`} style={{ transform: "translateZ(0px)" }}>
        <svg viewBox="0 0 100 63" className="w-full h-full p-2">
          {[0, 4, 8, 12].map((o, i) => <rect key={o} x={4 + o} y={4 + o} width={92 - o * 2} height={55 - o * 2} rx="6" fill="none" stroke="#F59E0B" strokeWidth=".9" />)}
          <rect x="4" y="4" width="92" height="55" rx="6" fill="none" stroke="#22D3EE" strokeWidth="1.6" strokeDasharray="6 94" pathLength="100">
            <animate attributeName="stroke-dashoffset" from="100" to="0" dur="2s" repeatCount="indefinite" />
          </rect>
        </svg>
      </div>
      <div className={`${layer} border-cyan-300/50 bg-[#06141f]/80 flex items-center justify-center`} style={{ transform: "translateZ(-70px)" }}>
        <div className="w-28 h-20 rounded-md border border-cyan-300 bg-cyan-400/10 p-2 font-mono-ui text-[8px] text-cyan-200 leading-snug shadow-[0_0_24px_#22d3ee66]">
          <p className="text-white text-[9px]">NXP J3R150 DIE</p>
          TapatMFAApplet<br />EEPROM ● OK<br />PIN 5/5 tries<br />TMAC tape: idle
        </div>
      </div>
    </div>
  );
}

export function CardsScreen() {
  const { cards, user, open, say, setTab } = useApp();
  const [idx, setIdx] = useState(0);
  const [flip, setFlip] = useState(false);
  const [xray, setXray] = useState(false);
  const [frozen, setFrozen] = useState<Record<string, boolean>>({});
  const [tilt, setTilt] = useState({ x: 0, y: 0 });
  const [token, setToken] = useState(0);
  const [drawer, setDrawer] = useState(true);
  const [pulse, setPulse] = useState(0);
  const startY = useRef<number | null>(null);
  const card = cards[Math.min(idx, cards.length - 1)];
  const holder = (user?.name ?? "CARDHOLDER").toUpperCase();

  useEffect(() => { const t = setInterval(() => setToken((n) => n + 1), 3000); return () => clearInterval(t); }, []);
  const [prev, setPrev] = useState(cards.length);
  useEffect(() => { if (cards.length > prev) { setIdx(cards.length - 1); setFlip(false); setXray(false); } setPrev(cards.length); }, [cards.length]);
  const go = (d: number) => { setIdx((i) => (i + d + cards.length) % cards.length); setFlip(false); setXray(false); };

  const onMove = (e: React.PointerEvent<HTMLDivElement>) => {
    const r = e.currentTarget.getBoundingClientRect();
    setTilt({ x: ((e.clientX - r.left) / r.width - 0.5) * 2, y: ((e.clientY - r.top) / r.height - 0.5) * 2 });
  };
  const baseX = 8 - tilt.y * 12, baseY = -12 + tilt.x * 18;

  const dock = [
    { icon: RotateCw, label: "Flip 180°", on: flip, fn: () => { setXray(false); setFlip(!flip); } },
    { icon: Layers, label: "X-Ray", on: xray, fn: () => card.physical ? (setFlip(false), setXray(!xray)) : say("X-Ray is for the physical JCOP4 card") },
    { icon: Zap, label: "Sync", on: false, fn: () => { setPulse((n) => n + 1); open({ type: "sync" }); } },
    { icon: Snowflake, label: frozen[card.id] ? "Unfreeze" : "Freeze", on: !!frozen[card.id], fn: () => setFrozen({ ...frozen, [card.id]: !frozen[card.id] }) },
  ];

  return (
    <div className="px-5 pt-2">
      <div className="flex items-center justify-between mb-1">
        <div><p className="text-white/50 text-[12px]">{card.tag}</p><h1 className="text-white text-[22px] leading-tight" style={{ fontWeight: 800 }}>{card.name}</h1></div>
        <div className="flex gap-1.5">
          <button aria-label="Add card" onClick={() => open({ type: "create" })} className="w-9 h-9 rounded-full btn-liquid flex items-center justify-center text-white"><Plus className="w-4 h-4" /></button>
          <button aria-label="Previous card" onClick={() => go(-1)} className="w-9 h-9 rounded-full glass-pill flex items-center justify-center text-white"><ChevronUp className="w-4 h-4" /></button>
          <button aria-label="Next card" onClick={() => go(1)} className="w-9 h-9 rounded-full glass-pill flex items-center justify-center text-white"><ChevronDown className="w-4 h-4" /></button>
        </div>
      </div>

      {/* 3D stage */}
      <div className="relative h-[270px] touch-none select-none" style={{ perspective: 1200 }}
        onPointerMove={onMove} onPointerLeave={() => setTilt({ x: 0, y: 0 })}
        onPointerDown={(e) => { startY.current = e.clientY; }}
        onPointerUp={(e) => { if (startY.current !== null) { const d = e.clientY - startY.current; if (Math.abs(d) > 60) go(d < 0 ? 1 : -1); } startY.current = null; }}
        onDoubleClick={() => { setXray(false); setFlip(!flip); }}>
        {/* fan deck behind */}
        {[2, 1].map((o) => {
          const c = cards[(idx + o) % cards.length];
          if (cards.length <= o) return null;
          return (
            <div key={c.id + o} className="absolute left-1/2 top-[34px] w-[290px] pointer-events-none" style={{ transform: `translateX(-50%) translateY(${-o * 20}px) scale(${1 - o * 0.07}) rotateX(-18deg)`, opacity: 0.75 - o * 0.2, filter: "brightness(.6)" }}>
              <CardFace card={c} holder={holder} />
            </div>
          );
        })}
        <div className="absolute left-1/2 -translate-x-1/2 bottom-3 w-52 h-6 rounded-full blur-2xl" style={{ background: "radial-gradient(#06b6d4aa,#6366f155,transparent)" }} />
        <motion.div key={card.id} initial={{ y: 60, opacity: 0, rotateX: 40 }}
          animate={{ y: 0, opacity: 1, rotateX: xray ? 0 : baseX, rotateY: xray ? 0 : baseY + (flip ? 180 : 0), z: 24 }}
          transition={{ type: "spring", stiffness: 140, damping: 16 }}
          className="absolute left-1/2 top-[44px] w-[290px] -ml-[145px] preserve-3d" style={{ transformStyle: "preserve-3d" }}>
          {xray ? <XRay /> : (
            <>
              <div className="bf-hidden"><CardFace card={card} holder={holder} tilt={tilt} frozen={frozen[card.id]} /></div>
              <div className="absolute inset-0 bf-hidden" style={{ transform: "rotateY(180deg)" }}><Back card={card} token={token} /></div>
            </>
          )}
        </motion.div>
        {pulse > 0 && <span key={pulse} className="absolute left-1/2 top-[110px] -ml-24 w-48 h-48 rounded-full border-2 border-cyan-300 pointer-events-none" style={{ animation: "ring 1.4s ease-out forwards" }} />}
      </div>

      <div className="flex justify-center gap-1.5 -mt-1 mb-3">
        {cards.map((c, i) => <button key={c.id} aria-label={c.name} onClick={() => { setIdx(i); setFlip(false); setXray(false); }} className={`h-1.5 rounded-full transition-all ${i === idx ? "w-5 bg-cyan-300" : "w-1.5 bg-white/25"}`} />)}
      </div>

      {/* control dock */}
      <div className="glass !rounded-[26px] grid grid-cols-4 gap-1 p-1.5 mb-4">
        {dock.map(({ icon: Icon, label, on, fn }) => (
          <motion.button key={label} whileTap={{ scale: 0.92 }} onClick={fn} className={`py-2.5 rounded-[20px] flex flex-col items-center gap-1 text-[10.5px] ${on ? "bg-cyan-400/25 text-cyan-200 border border-cyan-300/40" : "text-white/75 border border-transparent"}`} style={{ fontWeight: 600 }}>
            <Icon className="w-[18px] h-[18px]" />{label}
          </motion.button>
        ))}
      </div>

      {/* telemetry */}
      {card.physical ? (
      <div className="glass mb-4 overflow-hidden">
        <button onClick={() => setDrawer(!drawer)} className="w-full flex items-center justify-between px-4 py-3.5">
          <span className="flex items-center gap-2 text-white text-[14px]" style={{ fontWeight: 700 }}><span className="w-2 h-2 rounded-full bg-emerald-400 animate-pulse" />Live JCOP4 Telemetry</span>
          <ChevronDown className={`w-4 h-4 text-white/60 transition ${drawer ? "rotate-180" : ""}`} />
        </button>
        {drawer && (
          <div className="px-4 pb-4 space-y-3 text-[12px]">
            <Row k="Lifecycle State" v={<span className="text-emerald-300 font-mono-ui">PERSONALIZED / ENROLLED</span>} />
            <Row k="Hardware UID" v={<span className="flex items-center gap-1.5 font-mono-ui text-white">{UID}<button aria-label="Copy UID" onClick={() => { navigator.clipboard?.writeText(UID); say("UID copied"); }}><Copy className="w-3.5 h-3.5 text-cyan-300" /></button></span>} />
            <Row k="PIN Retries" v={<span className="flex items-center gap-1.5"><span className="flex gap-1">{[0, 1, 2, 3, 4].map((i) => <span key={i} className="w-4 h-2 rounded-full bg-cyan-400 shadow-[0_0_8px_#22d3ee]" />)}</span><span className="text-white font-mono-ui">5/5</span></span>} />
            <Row k="Last APDU SW" v={<span className="font-mono-ui text-white">0x9000 · #{42 + pulse}</span>} />
          </div>
        )}
      </div>
      ) : (
        <div className="glass mb-4 p-4 space-y-3 text-[12px]">
          <Row k="Type" v={<span className="text-white" style={{ fontWeight: 600 }}>{card.kind === "pass" ? (card.format === "qr" ? "QR pass" : "Barcode pass") : card.kind === "bank" ? "Bank / ATM account" : card.network}</span>} />
          {card.kind === "bank" && <Row k="Account" v={<span className="font-mono-ui text-white">•••• {card.acct?.slice(-4)}</span>} />}
          {card.kind === "virtual" && <Row k="Spending limit" v={<span className="text-white" style={{ fontWeight: 600 }}>₱{card.limit.toLocaleString()}</span>} />}
          <Row k="Status" v={<span className={frozen[card.id] ? "text-sky-300" : "text-emerald-300"}>{frozen[card.id] ? "Frozen" : "Active"}</span>} />
        </div>
      )}

      <Btn className="w-full mb-2" onClick={() => open({ type: "create" })}><Plus className="w-4 h-4" />Add Card or Pass</Btn>
    </div>
  );
}
const Row = ({ k, v }: { k: string; v: React.ReactNode }) => <div className="flex items-center justify-between gap-3"><span className="text-white/50">{k}</span>{v}</div>;
