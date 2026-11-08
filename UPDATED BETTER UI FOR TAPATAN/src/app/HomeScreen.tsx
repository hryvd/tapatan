import { useState } from "react";
import { motion } from "motion/react";
import { Bell, Eye, EyeOff, BadgeCheck, Banknote, Send, Nfc, ScanLine, ShoppingBasket, Store, ArrowDownLeft, ArrowUpRight } from "lucide-react";
import { useApp, peso } from "./store";
import { CardFace } from "./CardFace";
import { Btn } from "./ui";
import { PRODUCTS } from "./SarEScreen";

const mmss = (s: number) => `${Math.floor(s / 60)}:${String(s % 60).padStart(2, "0")}`;

export function HomeScreen() {
  const { user, balance, armedUntil, armedLeft, open, disarm, txns, cart, setTab, cards, payArmed, say } = useApp();
  const [hide, setHide] = useState(false);
  const [f, setF] = useState("all");
  const armed = !!armedUntil;
  const cartTotal = Object.entries(cart).reduce((s, [id, q]) => s + (PRODUCTS.find((p) => p.id === id)?.price ?? 0) * q, 0);
  const list = txns.filter((t) => f === "all" || t.kind === f);
  const hour = new Date().getHours();
  const actions = [
    { i: Banknote, l: "Cash In", fn: () => open({ type: "cashin" }) },
    { i: Send, l: "Send / P2P", fn: () => open({ type: "send" }) },
    { i: Nfc, l: "Tap to Pay", fn: () => payArmed(145, "Tap to Pay · POS Terminal") },
    { i: ScanLine, l: "Scan QR", fn: () => open({ type: "qr" }) },
  ];
  return (
    <div className="px-5 pt-2">
      <div className="flex items-center justify-between mb-4">
        <div>
          <p className="text-white/55 text-[12px]">{hour < 12 ? "Good morning" : hour < 18 ? "Good afternoon" : "Good evening"},</p>
          <p className="text-white text-[20px] leading-tight" style={{ fontWeight: 800 }}>{user?.name.split(" ")[0]}</p>
          <span className="inline-flex items-center gap-1 mt-1 text-[10px] text-emerald-300 bg-emerald-400/15 border border-emerald-300/30 rounded-full px-2 py-0.5" style={{ fontWeight: 600 }}><BadgeCheck className="w-3 h-3" />KYC Verified</span>
        </div>
        <div className="flex items-center gap-2">
          <button aria-label="Notifications" onClick={() => say("No new alerts · 0 rejected MACs")} className="relative w-10 h-10 rounded-full glass-pill flex items-center justify-center text-white"><Bell className="w-[18px] h-[18px]" /><span className="absolute top-2 right-2.5 w-2 h-2 rounded-full bg-[#F87171]" /></button>
          <button aria-label="Profile" onClick={() => setTab(4)} className="w-10 h-10 rounded-full btn-liquid text-white text-[13px]" style={{ fontWeight: 800 }}>{user?.name.split(" ").map((w) => w[0]).slice(0, 2).join("")}</button>
        </div>
      </div>

      {/* hero card */}
      <div className={`relative rounded-[30px] p-3 glass ${armed ? "!border-emerald-300/70 shadow-[0_0_40px_rgba(16,185,129,.35)]" : ""}`} style={armed ? { borderColor: "rgba(110,231,183,.7)" } : undefined}>
        <div style={{ perspective: 1000 }}>
          <motion.div animate={{ rotateX: 5, rotateY: -6 }} whileHover={{ rotateX: 0, rotateY: 0 }}><CardFace card={cards[0]} holder={user?.name.toUpperCase() ?? ""} /></motion.div>
        </div>
        <div className="flex items-end justify-between px-2 pt-3 pb-1">
          <div>
            <p className="text-white/50 text-[11px]">Wallet balance</p>
            <p className="text-white text-[28px] leading-none" style={{ fontWeight: 800 }}>{hide ? "₱ ••••••" : peso(balance)}</p>
          </div>
          <button aria-label="Toggle balance" onClick={() => setHide(!hide)} className="w-9 h-9 rounded-full glass-pill flex items-center justify-center text-white/80">{hide ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}</button>
        </div>
        <div className="px-1 pt-2">
          {!armed ? (
            <Btn className="w-full" onClick={() => open({ type: "unlock" })}><Nfc className="w-4 h-4" />Arm Card for NFC Payment</Btn>
          ) : (
            <div className="flex items-center gap-2">
              <span className="font-mono-ui text-[12px] text-[#F59E0B] bg-amber-400/15 border border-amber-300/40 rounded-full px-3 h-12 flex items-center">{mmss(armedLeft)}</span>
              <Btn className="flex-1 !px-3" onClick={() => payArmed(145, "Tap to Pay · POS Terminal")}>Tap to Pay Now</Btn>
              <Btn variant="glass" className="!px-4" onClick={disarm}>Disarm</Btn>
            </div>
          )}
        </div>
      </div>

      <div className="grid grid-cols-4 gap-2.5 mt-4">
        {actions.map(({ i: I, l, fn }) => (
          <motion.button key={l} whileTap={{ scale: 0.93 }} onClick={fn} className="glass !rounded-[22px] py-3.5 flex flex-col items-center gap-1.5 text-white text-[10.5px]" style={{ fontWeight: 600 }}>
            <I className="w-[22px] h-[22px] text-cyan-300" />{l}
          </motion.button>
        ))}
      </div>

      {cartTotal > 0 && (
        <div className="glass-tint mt-4 p-4 flex items-center gap-3">
          <ShoppingBasket className="w-6 h-6 text-cyan-200" />
          <div className="flex-1"><p className="text-white/60 text-[11px]">Pending Sar-E order</p><p className="text-white text-[17px]" style={{ fontWeight: 800 }}>{peso(cartTotal)}</p></div>
          <Btn className="!h-10 !px-4 !text-[12px]" onClick={() => payArmed(cartTotal, "Sar-E Order", true)}>Pay with Card</Btn>
        </div>
      )}

      <div className="flex items-center justify-between mt-6 mb-2">
        <h2 className="text-white text-[17px]" style={{ fontWeight: 800 }}>Recent activity</h2>
      </div>
      <div className="flex gap-2 mb-3 overflow-x-auto no-scrollbar">
        {[["all", "All"], ["nfc", "NFC Tap"], ["sare", "Sar-E"], ["cashin", "Cash In"]].map(([k, l]) => (
          <button key={k} onClick={() => setF(k)} className={`px-3.5 h-8 rounded-full text-[12px] flex-shrink-0 border ${f === k ? "bg-cyan-400/20 border-cyan-300/60 text-cyan-100" : "border-white/10 text-white/60 bg-white/[0.05]"}`} style={{ fontWeight: 600 }}>{l}</button>
        ))}
      </div>
      <div className="glass divide-y divide-white/10">
        {list.length === 0 && <p className="text-white/45 text-[12px] text-center py-6">No transactions yet</p>}
        {list.map((t) => (
          <div key={t.id} className="flex items-center gap-3 px-4 py-3">
            <span className={`w-10 h-10 rounded-full flex items-center justify-center ${t.amount > 0 ? "bg-emerald-400/15 text-emerald-300" : "bg-white/10 text-white/80"}`}>
              {t.kind === "sare" ? <Store className="w-4 h-4" /> : t.amount > 0 ? <ArrowDownLeft className="w-4 h-4" /> : <ArrowUpRight className="w-4 h-4" />}
            </span>
            <div className="flex-1 min-w-0">
              <p className="text-white text-[13px] truncate" style={{ fontWeight: 600 }}>{t.title}</p>
              <p className="text-white/45 text-[11px]">{t.sub} <span className="font-mono-ui text-cyan-300/80 ml-1">{t.mac}</span></p>
            </div>
            <p className={`text-[13px] ${t.amount > 0 ? "text-emerald-300" : "text-white"}`} style={{ fontWeight: 700 }}>{t.amount > 0 ? "+" : ""}{peso(t.amount)}</p>
          </div>
        ))}
      </div>
    </div>
  );
}
