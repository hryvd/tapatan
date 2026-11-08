import { useState } from "react";
import { motion } from "motion/react";
import { Nfc, ShieldCheck, Zap, Fingerprint } from "lucide-react";
import { CardFace } from "./CardFace";
import { CardT } from "./store";
import { Btn } from "./ui";

const card: CardT = { id: "l", name: "Tapat JCOP4", tag: "", material: "obsidian", network: "ISO 14443-4", num: "4532 •••• •••• 8821", physical: true, limit: 0 };

function Art({ i }: { i: number }) {
  if (i === 0)
    return (
      <div style={{ perspective: 1000 }} className="w-[280px]">
        <motion.div animate={{ rotateY: [-18, 12, -18], rotateX: [10, 4, 10], y: [0, -8, 0] }} transition={{ duration: 7, repeat: Infinity, ease: "easeInOut" }} style={{ transformStyle: "preserve-3d" }}>
          <CardFace card={card} holder="YOUR NAME HERE" tilt={{ x: 0.3, y: 0 }} />
        </motion.div>
      </div>
    );
  if (i === 1)
    return (
      <div className="relative w-64 h-64 flex items-center justify-center">
        {[0, 1, 2, 3].map((n) => <span key={n} className="absolute inset-0 rounded-full border border-cyan-300" style={{ animation: `ring 3.2s ${n * 0.8}s infinite ease-out` }} />)}
        <div className="glass !rounded-[34px] w-28 h-44 rotate-[-8deg] flex items-end justify-center pb-4 -translate-x-8"><span className="w-10 h-1 rounded-full bg-white/50" /></div>
        <motion.div animate={{ x: [30, 0, 30], y: [10, -4, 10] }} transition={{ duration: 3.5, repeat: Infinity, ease: "easeInOut" }} className="absolute w-[130px] translate-x-6 translate-y-6" style={{ rotate: 12 }}>
          <CardFace card={card} holder="" small />
        </motion.div>
        <span className="absolute w-14 h-14 rounded-full btn-liquid flex items-center justify-center -translate-x-8 -translate-y-6"><Nfc className="w-7 h-7 text-white" /></span>
      </div>
    );
  return (
    <div className="relative w-64 h-64 flex items-center justify-center">
      <div className="absolute inset-4 rounded-full bg-gradient-to-br from-cyan-400/25 to-emerald-400/20 blur-2xl" />
      <div className="glass !rounded-[36px] w-60 p-5 relative">
        <div className="flex items-center gap-2 text-emerald-300 text-[11px] mb-3" style={{ fontWeight: 700 }}><ShieldCheck className="w-4 h-4" />CNN-LSTM THREAT ENGINE</div>
        <p className="text-white text-[44px] leading-none" style={{ fontWeight: 800 }}>94.7<span className="text-cyan-300 text-2xl">%</span></p>
        <p className="text-white/55 text-[11px] mb-3">detection accuracy · AUC-ROC 96.3%</p>
        <div className="flex items-end gap-1 h-10">{[40, 62, 50, 80, 66, 92, 74, 96].map((h, n) => <motion.span key={n} initial={{ height: 0 }} animate={{ height: `${h}%` }} transition={{ delay: n * 0.06 }} className="flex-1 rounded-sm bg-gradient-to-t from-cyan-500 to-emerald-300" />)}</div>
      </div>
    </div>
  );
}

const PAGES = [
  { icon: Fingerprint, k: "HARDWARE KEY", t: "Your card is your password.", d: "A JCOP4 NFC key holds your credentials in a secure chip. Phishing can't copy what never leaves the hardware." },
  { icon: Zap, k: "TAP TO PAY", t: "One tap. Proven twice.", d: "Arm your card with a PIN, tap at the store, and every payment is signed by a Turing MAC in under a second." },
  { icon: ShieldCheck, k: "SECOND LAYER", t: "An AI that watches your back.", d: "A CNN-LSTM engine scores every session for phishing and anomalies, so threats are caught before money moves." },
];

export function LandingScreen({ onStart }: { onStart: (m: "in" | "up") => void }) {
  const [p, setP] = useState(0);
  const page = PAGES[p];
  const go = (d: number) => setP((x) => Math.min(2, Math.max(0, x + d)));
  return (
    <div className="h-full flex flex-col px-6 pb-6">
      <div className="flex items-center justify-between pt-1">
        <p className="text-white text-[20px]" style={{ fontWeight: 800 }}>tap<span className="text-cyan-300">@</span>tan</p>
        <button onClick={() => setP(2)} className="text-white/55 text-[13px]" style={{ fontWeight: 600 }}>Skip</button>
      </div>

      <motion.div className="flex-1 flex items-center justify-center" drag="x" dragConstraints={{ left: 0, right: 0 }} dragElastic={0.2}
        onDragEnd={(_, i) => { if (i.offset.x < -50) go(1); else if (i.offset.x > 50) go(-1); }}>
        <motion.div key={p} initial={{ opacity: 0, x: 40 }} animate={{ opacity: 1, x: 0 }} transition={{ type: "spring", damping: 24, stiffness: 220 }}><Art i={p} /></motion.div>
      </motion.div>

      <motion.div key={"t" + p} initial={{ opacity: 0, y: 12 }} animate={{ opacity: 1, y: 0 }} className="min-h-[158px]">
        <p className="font-mono-ui text-cyan-300 text-[11px] tracking-[.18em] mb-2">{page.k}</p>
        <h1 className="text-white text-[32px] leading-[1.08]" style={{ fontWeight: 800, letterSpacing: "-0.03em" }}>{page.t}</h1>
        <p className="text-white/60 text-[14px] leading-relaxed mt-3">{page.d}</p>
      </motion.div>

      <div className="flex items-center justify-center gap-1.5 my-4">
        {PAGES.map((_, i) => <button key={i} aria-label={`Page ${i + 1}`} onClick={() => setP(i)} className={`h-1.5 rounded-full transition-all ${i === p ? "w-6 bg-cyan-300" : "w-1.5 bg-white/25"}`} />)}
      </div>

      {p < 2 ? (
        <Btn className="w-full" onClick={() => go(1)}>Continue</Btn>
      ) : (
        <div className="space-y-2.5">
          <Btn className="w-full" onClick={() => onStart("up")}>Get Started</Btn>
          <Btn variant="glass" className="w-full" onClick={() => onStart("in")}>I already have an account</Btn>
        </div>
      )}
    </div>
  );
}
