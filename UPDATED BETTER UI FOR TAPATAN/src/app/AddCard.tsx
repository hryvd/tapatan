import { useState } from "react";
import { motion } from "motion/react";
import { QrCode, Barcode, Landmark, Sparkles, ChevronRight, Check, Lock, ShieldCheck } from "lucide-react";
import { useApp, CardT, peso } from "./store";
import { Sheet, Field, Btn } from "./ui";
import { CardFace, MATERIALS } from "./CardFace";

type Kind = "qr" | "barcode" | "bank" | "virtual";
const TYPES: { k: Kind; i: any; t: string; d: string; tag: string }[] = [
  { k: "bank", i: Landmark, t: "Bank / ATM card", d: "Full account: card number, expiry, account no. and PIN.", tag: "Full details" },
  { k: "virtual", i: Sparkles, t: "3D virtual card", d: "Mint a tokenized Visa or Mastercard with a spending limit.", tag: "Instant" },
  { k: "qr", i: QrCode, t: "QR pass", d: "Store a ticket, membership or ID that scans as a QR.", tag: "Pass only" },
  { k: "barcode", i: Barcode, t: "Barcode pass", d: "Loyalty, library or store cards that scan as a barcode.", tag: "Pass only" },
];
const grp = (v: string) => v.replace(/\D/g, "").slice(0, 16).replace(/(.{4})/g, "$1 ").trim();

export function AddCard() {
  const { close, addCard, say, user } = useApp();
  const [step, setStep] = useState(0); // 0 type 1 details 2 review 3 done
  const [kind, setKind] = useState<Kind>("bank");
  const [dlg, setDlg] = useState(false);
  const [f, setF] = useState({ name: "", code: "", bank: "", acct: "", num: "", exp: "", cvv: "", pin: "", holder: (user?.name ?? "").toUpperCase(), mat: "cyber", net: "Visa Tokenized", limit: 3000 });
  const set = (k: string) => (e: any) => setF({ ...f, [k]: e.target.value });
  const pass = kind === "qr" || kind === "barcode";

  const valid =
    kind === "bank" ? !!f.bank && f.acct.length >= 8 && f.num.replace(/\s/g, "").length === 16 && /^\d\d\/\d\d$/.test(f.exp) && f.cvv.length >= 3 && f.pin.length === 4 && !!f.holder
    : pass ? !!f.name && f.code.length >= 4
    : !!f.name && !!f.holder;

  const last4 = f.num.replace(/\s/g, "").slice(-4);
  const card: CardT = pass
    ? { id: "n", name: f.name || "New pass", tag: "Pass", material: "cyber", network: "", num: "", kind: "pass", format: kind as any, code: f.code || "000000", limit: 0 }
    : kind === "bank"
    ? { id: "n", name: f.bank ? `${f.bank} ATM` : "Bank card", tag: "Bank · ATM account", material: "indigo", network: "Debit", num: f.num ? f.num.slice(0, 4) + " •••• •••• " + (last4 || "0000") : "0000 •••• •••• 0000", kind: "bank", bank: f.bank, acct: f.acct, expiry: f.exp, holder: f.holder, limit: 0 }
    : { id: "n", name: f.name || "Virtual card", tag: "Virtual · Tokenized", material: f.mat, network: f.net, num: "4000 •••• •••• 0000", kind: "virtual", limit: f.limit };

  const next = () => setStep(step + 1);
  const back = () => (step === 0 ? close() : setStep(step - 1));
  const rows: [string, string][] = pass
    ? [["Type", kind === "qr" ? "QR pass" : "Barcode pass"], ["Name", f.name], ["Code", f.code]]
    : kind === "bank"
    ? [["Bank", f.bank], ["Account no.", "•••• " + f.acct.slice(-4)], ["Card", "•••• " + last4], ["Expires", f.exp], ["Holder", f.holder], ["PIN", "••••  (stored on secure element)"]]
    : [["Network", f.net], ["Limit", peso(f.limit)], ["Nickname", f.name], ["Holder", f.holder]];

  const confirm = () => {
    addCard({ ...card, id: "v" + Date.now(), num: card.num.includes("0000 •••• •••• 0000") ? "4" + Math.floor(100 + Math.random() * 899) + " •••• •••• " + Math.floor(1000 + Math.random() * 8999) : card.num });
    setDlg(false); setStep(3); say("Added to your wallet");
  };

  return (
    <Sheet title={["Add to wallet", pass ? "Pass details" : kind === "bank" ? "Account details" : "Card studio", "Review", "All set"][step]} onClose={close} tall>
      {step < 3 && (
        <div className="flex items-center gap-2 mb-4 -mt-1">
          {step > 0 && <button onClick={back} className="text-cyan-300 text-[12px] mr-1" style={{ fontWeight: 700 }}>‹ Back</button>}
          <div className="flex-1 flex gap-1.5">{[0, 1, 2].map((n) => <span key={n} className={`h-1 flex-1 rounded-full transition-all ${n <= step ? "bg-cyan-300" : "bg-white/15"}`} />)}</div>
        </div>
      )}
      <motion.div key={step} initial={{ opacity: 0, x: 24 }} animate={{ opacity: 1, x: 0 }} transition={{ type: "spring", damping: 26, stiffness: 260 }}>
        {step === 0 && (
          <div className="space-y-2.5">
            <p className="text-white/55 text-[12.5px] mb-1">What do you want to add?</p>
            {TYPES.map(({ k, i: I, t, d, tag }) => (
              <motion.button key={k} whileTap={{ scale: 0.98 }} onClick={() => { setKind(k); next(); }} className="glass !rounded-[22px] w-full p-3.5 flex items-center gap-3 text-left">
                <span className="w-12 h-12 rounded-[16px] bg-cyan-400/15 text-cyan-300 flex items-center justify-center flex-shrink-0"><I className="w-6 h-6" /></span>
                <span className="flex-1 min-w-0"><span className="flex items-center gap-2 text-white text-[14px]" style={{ fontWeight: 700 }}>{t}<span className="text-[9px] px-1.5 py-0.5 rounded-full bg-white/10 text-white/60">{tag}</span></span><span className="block text-white/50 text-[11.5px] leading-snug">{d}</span></span>
                <ChevronRight className="w-4 h-4 text-white/30" />
              </motion.button>
            ))}
          </div>
        )}

        {step === 1 && (
          <>
            <div className="mb-4 mx-auto w-[260px]"><CardFace card={card} holder={f.holder} small /></div>
            {pass && <>
              <Field label="Pass name" placeholder={kind === "qr" ? "Concert ticket" : "SM Advantage"} value={f.name} onChange={set("name")} />
              <Field mono label={kind === "qr" ? "QR content / link" : "Barcode number"} placeholder={kind === "qr" ? "https://…" : "4800016644801"} value={f.code} onChange={set("code")} />
              <button onClick={() => setF({ ...f, code: kind === "qr" ? "TAPAT-" + Math.floor(Math.random() * 1e6) : String(Math.floor(4.8e12 + Math.random() * 9e11)) })} className="text-cyan-300 text-[12px] mb-3" style={{ fontWeight: 600 }}>Scan from camera (demo fill)</button>
            </>}
            {kind === "bank" && <>
              <Field label="Bank" placeholder="BDO, BPI, Landbank…" value={f.bank} onChange={set("bank")} />
              <Field mono label="Account number" inputMode="numeric" placeholder="0012 3456 7890" value={f.acct} onChange={(e) => setF({ ...f, acct: e.target.value.replace(/\D/g, "").slice(0, 14) })} />
              <Field mono label="Card number" inputMode="numeric" placeholder="0000 0000 0000 0000" value={f.num} onChange={(e) => setF({ ...f, num: grp(e.target.value) })} />
              <div className="grid grid-cols-3 gap-2">
                <Field mono label="Expiry" placeholder="MM/YY" maxLength={5} value={f.exp} onChange={(e) => { let v = e.target.value.replace(/[^\d]/g, "").slice(0, 4); if (v.length > 2) v = v.slice(0, 2) + "/" + v.slice(2); setF({ ...f, exp: v }); }} />
                <Field mono label="CVV" type="password" inputMode="numeric" maxLength={3} value={f.cvv} onChange={(e) => setF({ ...f, cvv: e.target.value.replace(/\D/g, "") })} />
                <Field mono label="ATM PIN" type="password" inputMode="numeric" maxLength={4} value={f.pin} onChange={(e) => setF({ ...f, pin: e.target.value.replace(/\D/g, "") })} />
              </div>
              <Field label="Name on card" value={f.holder} onChange={(e) => setF({ ...f, holder: e.target.value.toUpperCase() })} />
            </>}
            {kind === "virtual" && <>
              <p className="text-white/50 text-[11px] mb-1.5 ml-1">Material</p>
              <div className="grid grid-cols-4 gap-2 mb-3">{["obsidian", "cyber", "chrome", "emerald"].map((k) => <button key={k} onClick={() => setF({ ...f, mat: k })} className={`rounded-[14px] p-1.5 border text-[10px] text-white/80 ${f.mat === k ? "border-cyan-300" : "border-white/10"}`}><span className="block h-7 rounded-[8px] mb-1" style={{ background: MATERIALS[k].bg }} />{MATERIALS[k].label}</button>)}</div>
              <div className="flex gap-2 mb-3">{["Visa Tokenized", "Mastercard Tokenized"].map((n) => <button key={n} onClick={() => setF({ ...f, net: n })} className={`flex-1 h-10 rounded-full text-[12px] border ${f.net === n ? "bg-cyan-400/20 border-cyan-300/60 text-cyan-200" : "border-white/10 text-white/60"}`} style={{ fontWeight: 600 }}>{n.split(" ")[0]}</button>)}</div>
              <label className="block mb-3 text-white/60 text-[12px]">Spending limit: <b className="text-white">{peso(f.limit)}</b><input type="range" min={500} max={20000} step={500} value={f.limit} onChange={(e) => setF({ ...f, limit: +e.target.value })} className="w-full accent-cyan-400" /></label>
              <Field label="Nickname" placeholder="Grocery card" value={f.name} onChange={set("name")} />
              <Field label="Cardholder name" value={f.holder} onChange={(e) => setF({ ...f, holder: e.target.value.toUpperCase() })} />
            </>}
            <Btn className="w-full mt-1" disabled={!valid} onClick={next}>Review</Btn>
          </>
        )}

        {step === 2 && (
          <>
            <div className="mb-4 mx-auto w-[280px]"><CardFace card={card} holder={f.holder} small /></div>
            <div className="glass !rounded-[22px] divide-y divide-white/10 mb-3">
              {rows.map(([k, v]) => <div key={k} className="flex justify-between gap-3 px-4 py-2.5 text-[12.5px]"><span className="text-white/50">{k}</span><span className="text-white text-right truncate" style={{ fontWeight: 600 }}>{v}</span></div>)}
            </div>
            <p className="flex items-start gap-2 text-white/50 text-[11px] mb-4"><Lock className="w-3.5 h-3.5 mt-0.5 flex-shrink-0 text-cyan-300" />{kind === "bank" ? "Card number, CVV and PIN are encrypted and bound to your JCOP4 key. They never appear in plain text again." : "Stored locally and encrypted on this device."}</p>
            <Btn className="w-full" onClick={() => setDlg(true)}>Add to wallet</Btn>
          </>
        )}

        {step === 3 && (
          <div className="text-center pt-6 pb-2">
            <motion.span initial={{ scale: 0 }} animate={{ scale: 1 }} transition={{ type: "spring", damping: 12 }} className="mx-auto w-20 h-20 rounded-full bg-emerald-400/20 border border-emerald-300/50 flex items-center justify-center shadow-[0_0_40px_rgba(16,185,129,.4)]"><Check className="w-10 h-10 text-emerald-300" strokeWidth={3} /></motion.span>
            <h3 className="text-white text-[22px] mt-4" style={{ fontWeight: 800 }}>{card.name} added</h3>
            <p className="text-white/55 text-[13px] mt-1 mb-6">It's ready in your Cards tab.</p>
            <Btn className="w-full" onClick={close}>View card</Btn>
          </div>
        )}
      </motion.div>

      {dlg && (
        <div className="fixed inset-0 z-[80] flex items-center justify-center p-8" style={{ position: "absolute" }}>
          <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} className="absolute inset-0 bg-black/60 backdrop-blur-sm" onClick={() => setDlg(false)} />
          <motion.div initial={{ scale: 0.9, opacity: 0 }} animate={{ scale: 1, opacity: 1 }} transition={{ type: "spring", damping: 22, stiffness: 300 }} className="relative glass-strong !rounded-[28px] p-5 w-full text-center">
            <span className="mx-auto w-12 h-12 rounded-full bg-cyan-400/15 flex items-center justify-center mb-2"><ShieldCheck className="w-6 h-6 text-cyan-300" /></span>
            <p className="text-white text-[17px]" style={{ fontWeight: 800 }}>Add this card?</p>
            <p className="text-white/55 text-[12.5px] mt-1 mb-4">{card.name} will be linked to your wallet and your hardware key.</p>
            <div className="flex gap-2"><Btn variant="glass" className="flex-1" onClick={() => setDlg(false)}>Cancel</Btn><Btn className="flex-1" onClick={confirm}>Confirm</Btn></div>
          </motion.div>
        </div>
      )}
    </Sheet>
  );
}
