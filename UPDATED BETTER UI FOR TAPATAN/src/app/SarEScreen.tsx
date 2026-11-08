import { useState } from "react";
import { motion } from "motion/react";
import { ShoppingBasket, Plus, Minus, ChevronDown } from "lucide-react";
import { useApp, peso } from "./store";
import { Btn } from "./ui";

export const PRODUCTS = [
  { id: "p1", n: "Nescafé 3-in-1", e: "☕", price: 9, stock: 40, c: "Snacks & Drinks" },
  { id: "p2", n: "Piattos Cheese", e: "🥔", price: 25, stock: 18, c: "Snacks & Drinks" },
  { id: "p3", n: "Coke Mismo", e: "🥤", price: 22, stock: 6, c: "Snacks & Drinks" },
  { id: "p4", n: "Skyflakes", e: "🍘", price: 8, stock: 30, c: "Snacks & Drinks" },
  { id: "p5", n: "Jasmine Rice 1kg", e: "🍚", price: 58, stock: 12, c: "Pantry" },
  { id: "p6", n: "Itlog (6 pcs)", e: "🥚", price: 54, stock: 4, c: "Pantry" },
  { id: "p7", n: "Lucky Me Pancit", e: "🍜", price: 16, stock: 50, c: "Pantry" },
  { id: "p8", n: "Datu Puti Suka", e: "🍶", price: 19, stock: 14, c: "Pantry" },
  { id: "p9", n: "Globe Load ₱50", e: "📱", price: 50, stock: 99, c: "Load & Bills" },
  { id: "p10", n: "Meralco Bill Pay", e: "💡", price: 100, stock: 99, c: "Load & Bills" },
];
const STORES = ["Aling Nena's Sari-Sari", "Campus Coop", "Tapat Express"];

export function SarEScreen() {
  const { cart, setCart, payArmed } = useApp();
  const [store, setStore] = useState(0);
  const [cat, setCat] = useState("All");
  const [menu, setMenu] = useState(false);
  const count = Object.values(cart).reduce((a, b) => a + b, 0);
  const total = Object.entries(cart).reduce((s, [id, q]) => s + PRODUCTS.find((p) => p.id === id)!.price * q, 0);
  const set = (id: string, d: number) => { const q = Math.max(0, (cart[id] ?? 0) + d); const n = { ...cart, [id]: q }; if (!q) delete n[id]; setCart(n); };
  return (
    <div className="px-5 pt-2 relative">
      <div className="flex items-center justify-between mb-3">
        <div className="relative">
          <button onClick={() => setMenu(!menu)} className="flex items-center gap-1.5 text-white text-[20px]" style={{ fontWeight: 800 }}>{STORES[store]}<ChevronDown className="w-4 h-4 text-white/60" /></button>
          {menu && <div className="absolute z-20 mt-2 glass-strong p-1.5 w-56">{STORES.map((s, i) => <button key={s} onClick={() => { setStore(i); setMenu(false); }} className="w-full text-left px-3 py-2 rounded-xl text-white text-[13px] hover:bg-white/10">{s}</button>)}</div>}
          <p className="text-white/45 text-[12px]">Neighborhood store · NFC checkout</p>
        </div>
        <div className="relative w-11 h-11 rounded-full glass-pill flex items-center justify-center text-white"><ShoppingBasket className="w-5 h-5" />{count > 0 && <span className="absolute -top-1 -right-1 min-w-5 h-5 px-1 rounded-full bg-cyan-400 text-[#0A0E17] text-[11px] flex items-center justify-center" style={{ fontWeight: 800 }}>{count}</span>}</div>
      </div>
      <div className="flex gap-2 mb-4 overflow-x-auto no-scrollbar">
        {["All", "Snacks & Drinks", "Pantry", "Load & Bills"].map((c) => <button key={c} onClick={() => setCat(c)} className={`px-3.5 h-8 rounded-full text-[12px] flex-shrink-0 border ${cat === c ? "bg-cyan-400/20 border-cyan-300/60 text-cyan-100" : "border-white/10 text-white/60 bg-white/[0.05]"}`} style={{ fontWeight: 600 }}>{c}</button>)}
      </div>
      <div className="grid grid-cols-2 gap-3 pb-24">
        {PRODUCTS.filter((p) => cat === "All" || p.c === cat).map((p) => {
          const q = cart[p.id] ?? 0;
          return (
            <div key={p.id} className="glass p-3 flex flex-col">
              <div className="h-20 rounded-[18px] bg-white/[0.07] flex items-center justify-center text-4xl relative">{p.e}
                <span className={`absolute top-1.5 right-1.5 text-[9px] px-1.5 py-0.5 rounded-full ${p.stock < 8 ? "bg-amber-400/20 text-amber-300" : "bg-emerald-400/15 text-emerald-300"}`} style={{ fontWeight: 700 }}>{p.stock < 8 ? `${p.stock} left` : "In stock"}</span>
              </div>
              <p className="text-white text-[13px] mt-2 truncate" style={{ fontWeight: 600 }}>{p.n}</p>
              <div className="flex items-center justify-between mt-1.5">
                <span className="text-cyan-200 text-[14px]" style={{ fontWeight: 800 }}>{peso(p.price)}</span>
                {q === 0 ? (
                  <motion.button whileTap={{ scale: 0.9 }} onClick={() => set(p.id, 1)} className="h-8 px-3 rounded-full btn-liquid text-white text-[12px] flex items-center gap-1" style={{ fontWeight: 700 }}><Plus className="w-3 h-3" />Add</motion.button>
                ) : (
                  <span className="flex items-center gap-1.5 glass-pill !rounded-full h-8 px-1">
                    <button aria-label="Remove one" onClick={() => set(p.id, -1)} className="w-6 h-6 flex items-center justify-center text-white"><Minus className="w-3.5 h-3.5" /></button>
                    <span className="text-white text-[12px] w-3 text-center" style={{ fontWeight: 700 }}>{q}</span>
                    <button aria-label="Add one" onClick={() => p.stock > q && set(p.id, 1)} className="w-6 h-6 flex items-center justify-center text-white"><Plus className="w-3.5 h-3.5" /></button>
                  </span>
                )}
              </div>
            </div>
          );
        })}
      </div>
      {count > 0 && (
        <motion.div initial={{ y: 30, opacity: 0 }} animate={{ y: 0, opacity: 1 }} className="sticky bottom-2 glass-strong !rounded-[24px] p-2.5 pl-4 flex items-center gap-3 -mt-20 mb-16">
          <div className="flex-1"><p className="text-white/55 text-[11px]">{count} item{count > 1 ? "s" : ""}</p><p className="text-white text-[17px]" style={{ fontWeight: 800 }}>{peso(total)}</p></div>
          <Btn className="!h-11 !text-[13px]" onClick={() => payArmed(total, STORES[store], true)}>Checkout with NFC →</Btn>
        </motion.div>
      )}
    </div>
  );
}
