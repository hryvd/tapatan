import { useEffect, useState } from "react";
import { motion } from "motion/react";
import { ChevronLeft, Settings, Nfc, ShieldCheck, Eye, EyeOff, Camera, ScanFace, Check, ChevronRight } from "lucide-react";
import { useApp, SAVED } from "./store";
import { Btn, Field, NfcTap } from "./ui";

function Liveness({ done, onClose }: { done: () => void; onClose: () => void }) {
  const [s, setS] = useState(0);
  const steps = ["Center your face", "Blink your eyes", "Smile 😊", "Liveness Confirmed ✓"];
  useEffect(() => { if (s < 3) { const t = setTimeout(() => setS(s + 1), 1700); return () => clearTimeout(t); } const t = setTimeout(done, 1200); return () => clearTimeout(t); }, [s]);
  return (
    <div className="absolute inset-0 z-[70] bg-[#0A0E17]/95 backdrop-blur-2xl flex flex-col items-center justify-center px-8">
      <button onClick={onClose} className="absolute top-14 right-5 text-white/60 text-sm">Cancel</button>
      <div className="relative w-52 h-64">
        <svg viewBox="0 0 100 124" className="absolute inset-0 w-full h-full"><ellipse cx="50" cy="62" rx="46" ry="58" fill="none" stroke="rgba(255,255,255,.12)" strokeWidth="2.5" /><ellipse cx="50" cy="62" rx="46" ry="58" fill="none" stroke={s === 3 ? "#34D399" : "#22D3EE"} strokeWidth="2.5" strokeDasharray="330" strokeDashoffset={330 - (s + 1) * 82} strokeLinecap="round" style={{ transition: "all .6s" }} /></svg>
        <div className="absolute inset-3 rounded-[50%] bg-white/[0.06] flex items-center justify-center text-6xl">{s === 1 ? "😑" : s === 2 ? "😊" : s === 3 ? "✅" : "🙂"}</div>
      </div>
      <p className="text-white text-[20px] mt-6" style={{ fontWeight: 800 }}>{steps[s]}</p>
      <p className="text-white/45 text-[12px] mt-1">Step {Math.min(s + 1, 3)} of 3</p>
    </div>
  );
}

export function AuthScreen({ initial = "in", onBack }: { initial?: "in" | "up"; onBack: () => void }) {
  const { signIn, open, say } = useApp();
  const [mode, setMode] = useState<"in" | "up">(initial);
  const [tap, setTap] = useState<null | "auth" | "bind">(null);
  const [email, setEmail] = useState(""); const [pin, setPin] = useState(""); const [show, setShow] = useState(false);
  const [step, setStep] = useState(1);
  const [f, setF] = useState({ name: "", email: "", phone: "", addr: "", pin: "", pin2: "" });
  const [cam, setCam] = useState(false); const [id, setId] = useState(false); const [live, setLive] = useState(false); const [faceOk, setFaceOk] = useState(false);
  const up = (k: string) => (e: any) => setF({ ...f, [k]: e.target.value });
  const step1ok = f.name && f.email && f.pin.length >= 4 && f.pin === f.pin2;

  return (
    <div className="relative h-full">
    <div className="h-full overflow-y-auto no-scrollbar px-5 pt-1 pb-10">
      <div className="flex items-center justify-between">
        <button aria-label="Back" onClick={onBack} className="w-10 h-10 rounded-full glass-pill flex items-center justify-center text-white"><ChevronLeft className="w-5 h-5" /></button>
        <button aria-label="Backend settings" onClick={() => open({ type: "backend" })} className="w-10 h-10 rounded-full glass-pill flex items-center justify-center text-white"><Settings className="w-[18px] h-[18px]" /></button>
      </div>
      <div className="mt-4 flex items-start justify-between">
        <div className="flex items-center gap-3">
          <span className="w-12 h-12 rounded-[16px] glass flex items-center justify-center shadow-[0_0_30px_rgba(6,182,212,.5)]"><ShieldCheck className="w-6 h-6 text-cyan-300" /></span>
          <div><p className="text-white text-[24px] leading-none" style={{ fontWeight: 800 }}>tap<span className="text-cyan-300">@</span>tan</p><p className="text-white/50 text-[11px] mt-1">JCOP4 Turing-Composed NFC Wallet</p></div>
        </div>
      </div>
      <h1 className="text-white text-[28px] leading-tight mt-6" style={{ fontWeight: 800 }}>{mode === "in" ? "Welcome back." : "Create your wallet."}</h1>
      <p className="text-white/55 text-[13px] mt-1">{mode === "in" ? "Tap your card or use email and PIN." : "Three quick steps to bind your hardware key."}</p>

      <div className="flex gap-1 glass-pill !rounded-[18px] p-1 my-5">
        {[["in", "Sign In"], ["up", "Create Account / KYC"]].map(([k, l]) => <button key={k} onClick={() => setMode(k as any)} className={`flex-1 h-10 rounded-[14px] text-[12.5px] ${mode === k ? "bg-white/20 text-white shadow-[inset_0_1px_0_rgba(255,255,255,.4)]" : "text-white/55"}`} style={{ fontWeight: 700 }}>{l}</button>)}
      </div>

      {mode === "in" ? (
        <>
          <motion.button whileTap={{ scale: 0.98 }} onClick={() => setTap("auth")} className="glass-tint w-full p-6 flex flex-col items-center relative overflow-hidden">
            <span className="relative w-24 h-24 flex items-center justify-center">
              {[0, 1, 2].map((i) => <span key={i} className="absolute inset-0 rounded-full border border-cyan-300" style={{ animation: `ring 2.4s ${i * 0.8}s infinite ease-out` }} />)}
              <span className="w-16 h-16 rounded-full btn-liquid flex items-center justify-center"><Nfc className="w-8 h-8 text-white" /></span>
            </span>
            <span className="text-white text-[16px] mt-3" style={{ fontWeight: 800 }}>Tap JCOP4 Card to Sign In</span>
            <span className="text-white/55 text-[11.5px]">One tap · hardware-verified</span>
          </motion.button>

          <p className="text-white/45 text-[11px] mt-5 mb-2 ml-1 tracking-wider">SAVED ACCOUNTS</p>
          <div className="flex gap-2 overflow-x-auto no-scrollbar">
            {SAVED.map((a) => (
              <button key={a.email} onClick={() => setEmail(a.email)} className={`glass-pill !rounded-[18px] flex items-center gap-2 pl-1.5 pr-3.5 py-1.5 flex-shrink-0 ${email === a.email ? "!border-cyan-300" : ""}`}>
                <span className="w-8 h-8 rounded-full btn-liquid text-white text-[11px] flex items-center justify-center" style={{ fontWeight: 800 }}>{a.name.split(" ").map((w) => w[0]).slice(0, 2).join("")}</span>
                <span className="text-left"><span className="block text-white text-[12px]" style={{ fontWeight: 600 }}>{a.name.split(" ")[0]}</span><span className="block text-white/45 text-[10px]">{a.email}</span></span>
              </button>
            ))}
          </div>
          <div className="mt-4">
            <Field label="Email address" type="email" placeholder="you@email.com" value={email} onChange={(e) => setEmail(e.target.value)} />
            <div className="relative">
              <Field label="PIN (4–6 digits)" type={show ? "text" : "password"} inputMode="numeric" maxLength={6} placeholder="••••" value={pin} onChange={(e) => setPin(e.target.value.replace(/\D/g, ""))} />
              <button aria-label="Toggle PIN" onClick={() => setShow(!show)} className="absolute right-3 bottom-[22px] text-white/50">{show ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}</button>
            </div>
            <Btn className="w-full" disabled={!email || pin.length < 4} onClick={() => { const a = SAVED.find((s) => s.email === email) ?? { ...SAVED[0], email, name: email.split("@")[0] }; signIn(a); }}>Sign In with Email &amp; PIN</Btn>
            <p className="text-white/35 text-[10.5px] text-center mt-2">Demo: any email + 4-digit PIN works.</p>
          </div>
        </>
      ) : (
        <div>
          <div className="flex items-center gap-2 mb-4">
            {[1, 2, 3].map((n) => <div key={n} className="flex-1"><div className={`h-1 rounded-full ${n <= step ? "bg-cyan-300 shadow-[0_0_8px_#22d3ee]" : "bg-white/15"}`} /><p className={`text-[10px] mt-1 ${n === step ? "text-cyan-200" : "text-white/35"}`} style={{ fontWeight: 600 }}>{["Details & PIN", "ID & Face", "Bind Card"][n - 1]}</p></div>)}
          </div>
          {step === 1 && (
            <>
              <Field label="Full name" value={f.name} onChange={up("name")} /><Field label="Email" type="email" value={f.email} onChange={up("email")} />
              <Field label="Phone" type="tel" value={f.phone} onChange={up("phone")} /><Field label="Home address" value={f.addr} onChange={up("addr")} />
              <div className="grid grid-cols-2 gap-2"><Field label="Create PIN" type="password" inputMode="numeric" maxLength={6} value={f.pin} onChange={up("pin")} /><Field label="Confirm PIN" type="password" inputMode="numeric" maxLength={6} value={f.pin2} onChange={up("pin2")} /></div>
              {f.pin2 && f.pin !== f.pin2 && <p className="text-[#F87171] text-[11px] -mt-1 mb-2">PINs don't match</p>}
              <Btn className="w-full" disabled={!step1ok} onClick={() => setStep(2)}>Next: Biometric KYC <ChevronRight className="w-4 h-4" /></Btn>
            </>
          )}
          {step === 2 && (
            <div className="space-y-3">
              <button onClick={() => setCam(true)} className="glass w-full p-4 flex items-center gap-3 text-left"><span className="w-11 h-11 rounded-[14px] bg-cyan-400/15 text-cyan-300 flex items-center justify-center">{id ? <Check /> : <Camera />}</span><span className="flex-1"><span className="block text-white text-[14px]" style={{ fontWeight: 700 }}>Capture valid ID photo</span><span className="text-white/45 text-[11px]">{id ? "UMID captured ✓" : "Passport, UMID or driver's license"}</span></span></button>
              <button onClick={() => setLive(true)} className="glass w-full p-4 flex items-center gap-3 text-left"><span className="w-11 h-11 rounded-[14px] bg-emerald-400/15 text-emerald-300 flex items-center justify-center">{faceOk ? <Check /> : <ScanFace />}</span><span className="flex-1"><span className="block text-white text-[14px]" style={{ fontWeight: 700 }}>Start live face verification</span><span className="text-white/45 text-[11px]">{faceOk ? "Liveness confirmed ✓" : "Center → Blink → Smile"}</span></span></button>
              <Btn className="w-full" disabled={!id || !faceOk} onClick={() => setStep(3)}>Continue <ChevronRight className="w-4 h-4" /></Btn>
            </div>
          )}
          {step === 3 && (
            <div className="glass-tint p-6 text-center">
              <Nfc className="w-10 h-10 text-cyan-200 mx-auto mb-2" /><p className="text-white text-[16px]" style={{ fontWeight: 800 }}>Bind your JCOP4 card</p>
              <p className="text-white/55 text-[12px] mb-4">Writes your identity to the chip and locks UID <span className="font-mono-ui text-white">04:7A:93:E2:10:88:01</span> to this account.</p>
              <Btn className="w-full" onClick={() => setTap("bind")}>Tap &amp; Bind JCOP4 Smart Card</Btn>
            </div>
          )}
        </div>
      )}

    </div>
      {tap === "auth" && <NfcTap title="Tap card to sign in" apdu={["SELECT 0xA4 · AID F07461…0101", "TPT4 handshake", "GET DATA · cardholder identity"]} onCancel={() => setTap(null)} doneLabel="Continue" onSuccess={() => { signIn(SAVED[0]); }} />}
      {tap === "bind" && <NfcTap title="Tap card to bind" apdu={["SELECT 0xA4", "TPT4 handshake", "STORE DATA 0xE2 · CardIdentity", "Lock UID 04:7A:93:E2:10:88:01"]} onCancel={() => setTap(null)} doneLabel="Enter tap@tan" onSuccess={() => { signIn({ name: f.name, email: f.email, uid: SAVED[0].uid }); say("Welcome to tap@tan"); }} />}
      {live && <Liveness onClose={() => setLive(false)} done={() => { setFaceOk(true); setLive(false); }} />}
      {cam && (
        <div className="absolute inset-0 z-[70] bg-black/90 flex flex-col items-center justify-center px-6">
          <div className="relative w-full aspect-[1.586] rounded-2xl border-2 border-dashed border-cyan-300/80 flex items-center justify-center text-white/50 text-[12px]">Align ID inside frame</div>
          <button aria-label="Shutter" onClick={() => { setId(true); setCam(false); }} className="mt-10 w-[72px] h-[72px] rounded-full border-4 border-white p-1"><span className="block w-full h-full rounded-full bg-white" /></button>
        </div>
      )}
    </div>
  );
}
