import { useState } from "react";
import { motion } from "motion/react";
import { ChevronLeft } from "lucide-react";
import { useApp, peso } from "./store";
import { Sheet, Toggle, Field, Btn, Numpad, PinDots, NfcTap } from "./ui";
import { AddCard } from "./AddCard";
import { SecurityScreen } from "./components/SecurityScreen";

const UID = "04:7A:93:E2:10:88:01";

function Unlock({ next }: { next?: any }) {
  const { close, arm, open, say } = useApp();
  const [pin, setPin] = useState("");
  const [step, setStep] = useState(1);
  const [bad, setBad] = useState(false);
  if (step === 2)
    return <NfcTap title="Tap card to arm" apdu={["VERIFY 0x20 · PIN ok", "GET CHALLENGE 0x84", "INTERNAL AUTHENTICATE 0x88", "STORE DATA 0xE2 · arm token"]}
      onCancel={close} doneLabel="Card Armed · 5:00" onSuccess={() => { arm(); say("Card armed for 5 minutes"); next ? open(next) : close(); }} />;
  return (
    <Sheet title="Arm Card · Step 1 of 2" onClose={close}>
      <p className="text-white/55 text-[12.5px]">Enter your card PIN. It's verified on the JCOP4 secure element, never on the phone.</p>
      <PinDots n={pin.length} max={6} />
      {bad && <p className="text-center text-[#F87171] text-[12px] -mt-2 mb-2">Incorrect PIN · 4/5 tries left (demo PIN: 1234)</p>}
      <Numpad value={pin} onChange={(v) => { setPin(v); setBad(false); }} />
      <Btn className="w-full mt-4" disabled={pin.length < 4} onClick={() => (pin === "1234" ? setStep(2) : (setBad(true), setPin("")))}>Verify PIN</Btn>
    </Sheet>
  );
}

function Pay({ amount, title, sare }: { amount: number; title: string; sare?: boolean }) {
  const { close, balance, setBalance, addTxn, setCart, say } = useApp();
  return (
    <NfcTap title={`Pay ${peso(amount)}`} apdu={["SELECT 0xA4 · AID F07461706174616E0101", "TPT4 handshake", "INTERNAL AUTHENTICATE 0x88", "Turing MAC verify"]}
      onCancel={close}
      onSuccess={() => {
        if (amount > balance) { say("Insufficient balance"); close(); return; }
        setBalance(balance - amount); addTxn({ title, sub: "Just now", amount: -amount, kind: sare ? "sare" : "nfc" });
        if (sare) setCart({}); close();
      }}
      successNode={
        <div className="glass !rounded-[22px] p-4 text-center">
          <p className="text-white/50 text-[11px]">{title}</p>
          <p className="text-white text-[28px]" style={{ fontWeight: 800 }}>{peso(amount)}</p>
          <p className="font-mono-ui text-[11px] text-emerald-300 mt-1">TM•8F2A•9000 · MAC verified</p>
        </div>
      } />
  );
}

function CashIn() {
  const { close, balance, setBalance, addTxn, say } = useApp();
  const [amt, setAmt] = useState(500);
  return (
    <Sheet title="Cash In" onClose={close}>
      <div className="flex gap-2 mb-3">
        {[100, 500, 1000].map((a) => (
          <button key={a} onClick={() => setAmt(a)} className={`flex-1 h-12 rounded-[16px] text-[14px] border ${amt === a ? "bg-cyan-400/20 border-cyan-300/60 text-cyan-200" : "bg-white/[0.06] border-white/10 text-white/70"}`} style={{ fontWeight: 700 }}>₱{a.toLocaleString()}</button>
        ))}
      </div>
      <Field label="Custom amount (₱)" type="number" value={amt} onChange={(e) => setAmt(Number(e.target.value))} />
      <Btn className="w-full" disabled={amt <= 0} onClick={() => { setBalance(balance + amt); addTxn({ title: "Cash In · Partner Outlet", sub: "Just now", amount: amt, kind: "cashin" }); say(`${peso(amt)} added`); close(); }}>Confirm Cash In</Btn>
    </Sheet>
  );
}

function Send() {
  const { close, balance, setBalance, addTxn, say } = useApp();
  const [to, setTo] = useState(""); const [amt, setAmt] = useState(""); const [note, setNote] = useState("");
  const n = Number(amt);
  return (
    <Sheet title="Send Money · P2P" onClose={close}>
      <Field label="Recipient email or phone" placeholder="juan@email.com" value={to} onChange={(e) => setTo(e.target.value)} />
      <Field label="Amount (₱)" type="number" placeholder="0.00" value={amt} onChange={(e) => setAmt(e.target.value)} />
      <Field label="Note" placeholder="Pamasahe" value={note} onChange={(e) => setNote(e.target.value)} />
      <Btn className="w-full" disabled={!to || !(n > 0) || n > balance} onClick={() => { setBalance(balance - n); addTxn({ title: "To " + to, sub: "Just now", amount: -n, kind: "p2p" }); say("Sent via tap@tan"); close(); }}>Send via tap@tan</Btn>
      {n > balance && <p className="text-[#F87171] text-[12px] text-center mt-2">Amount exceeds balance</p>}
    </Sheet>
  );
}

function QR() {
  const { close, say } = useApp();
  return (
    <Sheet title="Scan QR" onClose={close}>
      <div className="relative h-64 rounded-[24px] bg-black/50 overflow-hidden border border-white/10 flex items-center justify-center">
        {["top-4 left-4 border-t-2 border-l-2", "top-4 right-4 border-t-2 border-r-2", "bottom-4 left-4 border-b-2 border-l-2", "bottom-4 right-4 border-b-2 border-r-2"].map((c) => <span key={c} className={`absolute w-8 h-8 border-cyan-300 rounded-sm ${c}`} />)}
        <motion.span animate={{ y: [-90, 90, -90] }} transition={{ duration: 3, repeat: Infinity, ease: "easeInOut" }} className="absolute w-44 h-0.5 bg-cyan-300 shadow-[0_0_14px_#22d3ee]" />
        <p className="text-white/40 text-[12px]">Align the QR inside the frame</p>
      </div>
      <Btn variant="glass" className="w-full mt-4" onClick={() => { say("Merchant QR detected · Aling Nena's"); close(); }}>Simulate scan</Btn>
    </Sheet>
  );
}

function Backend() {
  const { close, say } = useApp();
  const [remote, setRemote] = useState(true);
  const [t, setT] = useState<null | number>(null);
  const [p, setP] = useState([true, true, false, true]);
  const [bal, setBal] = useState(5000); const [retry, setRetry] = useState(5);
  const labels = ["Require PIN on Email Login", "Strict Card-to-Account UID Binding", "Allow Card Rebind on Signup", "Sync Cardholder Name with Account"];
  return (
    <Sheet title="Account Backend" onClose={close} tall>
      <Toggle on={remote} onChange={setRemote} label="Use Remote Node.js Backend" hint={remote ? "HTTP server" : "Offline local DB"} />
      <div className="flex gap-2 items-end mt-1">
        <div className="flex-1"><Field mono label="Backend URL" defaultValue="http://192.168.1.100:4180" disabled={!remote} /></div>
        <Btn variant="glass" className="!h-11 mb-3 !px-4" onClick={() => setT(Math.round(18 + Math.random() * 30))}>Test</Btn>
      </div>
      {t && <p className="font-mono-ui text-[11px] text-emerald-300 -mt-1 mb-2">● Connected · {t}ms</p>}
      <div className="divide-y divide-white/10 border-y border-white/10 my-2">
        {labels.map((l, i) => <Toggle key={l} label={l} on={p[i]} onChange={(b) => setP(p.map((x, j) => (j === i ? b : x)))} />)}
      </div>
      <label className="block mt-3 text-white/60 text-[12px]">Initial wallet balance: <b className="text-white">{peso(bal)}</b>
        <input type="range" min={0} max={20000} step={500} value={bal} onChange={(e) => setBal(+e.target.value)} className="w-full accent-cyan-400" /></label>
      <label className="block mt-2 text-white/60 text-[12px]">Max PIN retries: <b className="text-white">{retry}</b>
        <input type="range" min={3} max={10} value={retry} onChange={(e) => setRetry(+e.target.value)} className="w-full accent-cyan-400" /></label>
      <div className="flex gap-2 mt-4">
        <Btn variant="glass" className="flex-1 !text-[12px]" onClick={() => say("Synced 2 local accounts")}>Sync Accounts</Btn>
        <Btn variant="glass" className="flex-1 !text-[12px]" onClick={() => { setRemote(false); setBal(5000); setRetry(5); }}>Reset</Btn>
      </div>
      <Btn className="w-full mt-2" onClick={() => { say("Configuration saved"); close(); }}>Save Configuration</Btn>
    </Sheet>
  );
}

function SecInfo() {
  const { close, open } = useApp();
  const rows = [["SELECT", "0xA4", "Select applet by AID"], ["VERIFY", "0x20", "Card PIN check"], ["GET CHALLENGE", "0x84", "8-byte nonce"], ["INTERNAL AUTH", "0x88", "Turing MAC response"], ["STORE DATA", "0xE2", "Write identity / token"]];
  return (
    <Sheet title="JCOP4 Applet Security" onClose={close} tall>
      <p className="text-white/45 text-[11px]">APPLET AID</p>
      <p className="font-mono-ui text-cyan-300 text-[15px] mb-4">F07461706174616E0101</p>
      <p className="text-white/45 text-[11px] mb-2">TURING 2-TAPE CIPHER</p>
      <div className="glass !rounded-[20px] p-3 mb-4 font-mono-ui text-[11px] text-white/80">
        {["TAPE A (key)   ▒▓░▒█▓░░▒▓█", "TAPE B (data)  ░▒█▓▒░▓█░▒▓", "HEAD ► δ(q,a,b) → MAC[8]"].map((l, i) => <p key={i} className={i === 2 ? "text-emerald-300 mt-1" : ""}>{l}</p>)}
      </div>
      <p className="text-white/45 text-[11px] mb-2">ISO-7816 APDU TABLE</p>
      <div className="glass !rounded-[20px] divide-y divide-white/10 mb-4">
        {rows.map(([a, b, c]) => <div key={a} className="flex items-center gap-3 px-3.5 py-2.5"><span className="font-mono-ui text-cyan-300 text-[12px] w-12">{b}</span><span className="text-white text-[12px] flex-1" style={{ fontWeight: 600 }}>{a}</span><span className="text-white/45 text-[11px]">{c}</span></div>)}
      </div>
      <Btn variant="glass" className="w-full" onClick={() => open({ type: "thesis" })}>Open thesis security metrics →</Btn>
    </Sheet>
  );
}

function Thesis() {
  const { close } = useApp();
  return (
    <motion.div initial={{ x: "100%" }} animate={{ x: 0 }} transition={{ type: "spring", damping: 32, stiffness: 320 }} className="absolute inset-0 z-[60] bg-[#0A0E17] overflow-y-auto no-scrollbar pt-12">
      <button onClick={close} className="absolute top-12 left-4 z-10 h-8 pl-1 pr-3 rounded-full glass-pill flex items-center text-white text-[12px]"><ChevronLeft className="w-4 h-4" />Back</button>
      <div className="pt-6 pb-10"><SecurityScreen /></div>
    </motion.div>
  );
}

function Bind() {
  const { close, say } = useApp();
  return <NfcTap title="Tap to bind card" apdu={["SELECT 0xA4", "TPT4 handshake", "STORE DATA 0xE2 · CardIdentity", "Lock UID " + UID]} onCancel={close} doneLabel="Done" onSuccess={() => { say("Card provisioned & UID locked"); close(); }} />;
}
function Sync() {
  const { close, say } = useApp();
  return <NfcTap title="Tap to sync JCOP4" apdu={["SELECT 0xA4", "GET DATA · UID", "STORE DATA 0xE2 · identity", "Signature counter #43"]} onCancel={close} doneLabel="Done" onSuccess={() => { say("JCOP4 synced · counter #43"); close(); }} />;
}

export function Overlays() {
  const { overlay: o } = useApp();
  if (!o) return null;
  switch (o.type) {
    case "unlock": return <Unlock next={o.next} />;
    case "pay": return <Pay amount={o.amount} title={o.title} sare={o.sare} />;
    case "cashin": return <CashIn />;
    case "send": return <Send />;
    case "qr": return <QR />;
    case "backend": return <Backend />;
    case "secinfo": return <SecInfo />;
    case "thesis": return <Thesis />;
    case "create": return <AddCard />;
    case "bind": return <Bind />;
    case "sync": return <Sync />;
  }
}
