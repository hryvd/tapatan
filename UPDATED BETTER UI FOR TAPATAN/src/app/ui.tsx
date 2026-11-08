import { ReactNode, useEffect, useState } from "react";
import { motion } from "motion/react";
import { X, Check, ShieldAlert, Nfc, Delete } from "lucide-react";

export function Sheet({ title, onClose, children, tall }: { title: string; onClose: () => void; children: ReactNode; tall?: boolean }) {
  return (
    <div className="absolute inset-0 z-[60] flex items-end">
      <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} className="absolute inset-0 bg-black/55 backdrop-blur-sm" onClick={onClose} />
      <motion.div
        initial={{ y: "100%" }} animate={{ y: 0 }} transition={{ type: "spring", damping: 30, stiffness: 320 }}
        className={`relative w-full glass-strong !rounded-b-none !rounded-t-[32px] flex flex-col ${tall ? "h-[88%]" : "max-h-[88%]"}`}
      >
        <div className="mx-auto mt-2 h-1 w-9 rounded-full bg-white/30" />
        <div className="flex items-center justify-between px-5 pt-3 pb-2">
          <h3 className="text-white text-[17px]" style={{ fontWeight: 700 }}>{title}</h3>
          <button onClick={onClose} aria-label="Close" className="w-8 h-8 rounded-full glass-pill flex items-center justify-center text-white/80"><X className="w-4 h-4" /></button>
        </div>
        <div className="overflow-y-auto no-scrollbar px-5 pb-8 pt-1">{children}</div>
      </motion.div>
    </div>
  );
}

export function Toggle({ on, onChange, label, hint }: { on: boolean; onChange: (b: boolean) => void; label: string; hint?: string }) {
  return (
    <button onClick={() => onChange(!on)} className="w-full flex items-center justify-between gap-3 py-2.5 text-left">
      <span><span className="block text-white text-[13px]" style={{ fontWeight: 600 }}>{label}</span>{hint && <span className="block text-white/45 text-[11px]">{hint}</span>}</span>
      <span className={`relative w-[46px] h-[28px] rounded-full flex-shrink-0 transition-colors ${on ? "bg-[#10B981]" : "bg-white/15"}`}>
        <span className={`absolute top-[2px] w-6 h-6 rounded-full bg-white shadow transition-all ${on ? "left-[20px]" : "left-[2px]"}`} />
      </span>
    </button>
  );
}

export function Field({ label, mono, ...p }: { label: string; mono?: boolean } & React.InputHTMLAttributes<HTMLInputElement>) {
  return (
    <label className="block mb-3">
      <span className="block text-white/50 text-[11px] mb-1 ml-1" style={{ fontWeight: 600 }}>{label}</span>
      <input {...p} className={`w-full h-11 rounded-[14px] bg-white/[0.07] border border-white/10 px-3.5 text-white text-[14px] placeholder:text-white/25 outline-none focus:border-cyan-400/70 focus:bg-white/10 transition ${mono ? "font-mono-ui" : ""}`} />
    </label>
  );
}

export function Btn({ children, onClick, disabled, variant = "primary", className = "" }: { children: ReactNode; onClick?: () => void; disabled?: boolean; variant?: "primary" | "glass" | "danger"; className?: string }) {
  const v = variant === "primary" ? "btn-liquid text-white" : variant === "danger" ? "bg-[#EF4444]/25 border border-[#F87171]/40 text-[#FCA5A5]" : "glass-pill text-white";
  return (
    <motion.button whileTap={{ scale: 0.97 }} onClick={onClick} disabled={disabled}
      className={`h-12 px-5 rounded-[18px] text-[14px] flex items-center justify-center gap-2 disabled:opacity-40 ${v} ${className}`} style={{ fontWeight: 700 }}>
      {children}
    </motion.button>
  );
}

export function Numpad({ value, onChange, max = 6 }: { value: string; onChange: (v: string) => void; max?: number }) {
  return (
    <div className="grid grid-cols-3 gap-2.5">
      {["1", "2", "3", "4", "5", "6", "7", "8", "9", "", "0", "⌫"].map((k, i) =>
        k === "" ? <span key={i} /> : (
          <motion.button key={i} whileTap={{ scale: 0.92 }} aria-label={k === "⌫" ? "Backspace" : k}
            onClick={() => onChange(k === "⌫" ? value.slice(0, -1) : value.length < max ? value + k : value)}
            className="h-14 rounded-[20px] glass-pill !rounded-[20px] text-white text-xl flex items-center justify-center" style={{ fontWeight: 600 }}>
            {k === "⌫" ? <Delete className="w-5 h-5" /> : k}
          </motion.button>
        ))}
    </div>
  );
}

export function PinDots({ n, max = 4 }: { n: number; max?: number }) {
  return (
    <div className="flex justify-center gap-3 my-4">
      {Array.from({ length: max }).map((_, i) => (
        <span key={i} className={`w-3.5 h-3.5 rounded-full border transition ${i < n ? "bg-cyan-300 border-cyan-200 shadow-[0_0_12px_#22d3ee]" : "border-white/30"}`} />
      ))}
    </div>
  );
}

/** Full-screen NFC tap simulation: Scanning → Verifying → Approved | Unauthorized(5s retry) */
export function NfcTap({ title, apdu, onSuccess, onCancel, doneLabel = "Done", successNode }: {
  title: string; apdu: string[]; onSuccess: () => void; onCancel: () => void; doneLabel?: string; successNode?: ReactNode;
}) {
  const [phase, setPhase] = useState<"scan" | "verify" | "ok" | "fail">("scan");
  const [step, setStep] = useState(0);
  const [left, setLeft] = useState(5);
  const [forceFail, setForceFail] = useState(false);

  useEffect(() => {
    if (phase === "scan") {
      const t = setTimeout(() => { if (forceFail) { setForceFail(false); setLeft(5); setPhase("fail"); } else { setStep(0); setPhase("verify"); } }, 2400);
      return () => clearTimeout(t);
    }
    if (phase === "verify") {
      if (step < apdu.length) { const t = setTimeout(() => setStep(step + 1), 650); return () => clearTimeout(t); }
      const t = setTimeout(() => setPhase("ok"), 400); return () => clearTimeout(t);
    }
    if (phase === "fail") {
      if (left <= 0) { setPhase("scan"); return; }
      const t = setTimeout(() => setLeft(left - 1), 1000); return () => clearTimeout(t);
    }
  }, [phase, step, left, forceFail, apdu.length]);

  const fail = phase === "fail";
  const tone = fail ? "#F87171" : phase === "ok" ? "#34D399" : "#22D3EE";
  return (
    <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} className="absolute inset-0 z-[70] bg-[#0A0E17]/90 backdrop-blur-2xl flex flex-col items-center px-6 pt-14 pb-8">
      <button onClick={onCancel} aria-label="Cancel" className="absolute top-14 right-5 w-9 h-9 rounded-full glass-pill flex items-center justify-center text-white/80"><X className="w-4 h-4" /></button>
      <p className="font-mono-ui text-[11px] tracking-widest text-white/45 uppercase">ISO 14443-4 · JCOP4 J3R150</p>
      <h2 className="text-white text-[22px] mt-1 text-center" style={{ fontWeight: 800 }}>{phase === "ok" ? "Approved ✓" : fail ? "Unauthorized Card" : phase === "verify" ? "Verifying TPT4 & TMAC…" : title}</h2>

      <div className="relative flex-1 w-full flex items-center justify-center" style={fail ? { animation: "shake .5s" } : undefined}>
        {!fail && phase !== "ok" && [0, 1, 2].map((i) => (
          <span key={i} className="absolute w-52 h-52 rounded-full border-2" style={{ borderColor: tone, animation: `ring 2.4s ${i * 0.8}s infinite ease-out` }} />
        ))}
        {fail && (
          <svg className="absolute w-56 h-56 -rotate-90" viewBox="0 0 100 100">
            <circle cx="50" cy="50" r="45" fill="none" stroke="rgba(255,255,255,.1)" strokeWidth="3" />
            <circle cx="50" cy="50" r="45" fill="none" stroke="#F59E0B" strokeWidth="3" strokeLinecap="round" strokeDasharray="283" style={{ animation: "dash 5s linear forwards" }} />
          </svg>
        )}
        <motion.div animate={{ scale: phase === "ok" ? 1.1 : 1 }} className="relative w-32 h-32 rounded-full glass flex items-center justify-center" style={{ boxShadow: `0 0 60px ${tone}55, inset 0 1px 0 rgba(255,255,255,.4)` }}>
          {phase === "ok" ? <Check className="w-14 h-14" style={{ color: tone }} strokeWidth={2.5} /> : fail ? <ShieldAlert className="w-14 h-14" style={{ color: tone }} /> : <Nfc className="w-14 h-14" style={{ color: tone }} />}
        </motion.div>
      </div>

      <div className="w-full">
        {phase === "scan" && (
          <>
            <p className="text-center text-white/60 text-[13px] mb-3">Hold your tap@tan JCOP4 card to the back of your phone</p>
            <button onClick={() => setForceFail(true)} className="mx-auto block text-[11px] text-white/35 underline underline-offset-2">Demo: simulate unauthorized card</button>
          </>
        )}
        {phase === "verify" && (
          <div className="glass !rounded-[22px] p-3.5 space-y-1.5">
            {apdu.map((a, i) => (
              <div key={a} className="flex items-center gap-2 font-mono-ui text-[11.5px]" style={{ color: i < step ? "#34D399" : i === step ? "#22D3EE" : "rgba(255,255,255,.3)" }}>
                {i < step ? <Check className="w-3.5 h-3.5" /> : <span className="w-3.5 text-center">›</span>}{a}{i < step && <span className="ml-auto text-white/40">9000</span>}
              </div>
            ))}
          </div>
        )}
        {fail && (
          <div className="text-center">
            <p className="font-mono-ui text-[#F87171] text-[12px] mb-1">SW 0x6982 · SECURITY_STATUS_NOT_SATISFIED</p>
            <p className="text-white/55 text-[12px] mb-3">Auto-rescanning in {left}s…</p>
            <Btn variant="glass" className="w-full" onClick={() => setPhase("scan")}>Retry Now ({left}s)</Btn>
          </div>
        )}
        {phase === "ok" && (
          <div>
            {successNode}
            <Btn className="w-full mt-3" onClick={onSuccess}>{doneLabel}</Btn>
          </div>
        )}
      </div>
    </motion.div>
  );
}
