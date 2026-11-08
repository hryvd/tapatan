import { createContext, useContext, useEffect, useState, ReactNode, useCallback } from "react";

export type Txn = { id: number; title: string; sub: string; amount: number; kind: "nfc" | "sare" | "cashin" | "p2p"; time: string; mac: string };
export type CardT = { id: string; name: string; tag: string; material: string; network: string; num: string; physical?: boolean; limit: number;
  kind?: "virtual" | "pass" | "bank"; format?: "qr" | "barcode"; code?: string; bank?: string; acct?: string; expiry?: string; holder?: string };
export type Overlay =
  | null
  | { type: "unlock"; next?: Overlay }
  | { type: "pay"; amount: number; title: string; sare?: boolean }
  | { type: "cashin" } | { type: "send" } | { type: "qr" } | { type: "backend" }
  | { type: "secinfo" } | { type: "thesis" } | { type: "create" } | { type: "bind" } | { type: "sync" };

export const SAVED = [
  { name: "Maria Clara Reyes", email: "maria@tapatan.ph", uid: "04:7A:93:E2:10:88:01" },
  { name: "Andres Bonifacio Jr.", email: "andres@campus.edu.ph", uid: "04:5C:11:A0:7F:39:02" },
];

const mk = (i: number, title: string, sub: string, amount: number, kind: Txn["kind"], time: string): Txn => ({
  id: i, title, sub, amount, kind, time, mac: "TM•" + (0x8f2a + i * 37).toString(16).toUpperCase().slice(0, 4),
});

const initialCards: CardT[] = [
  { id: "c1", name: "Tapat JCOP4 Master Card", tag: "Physical · J3R150", material: "obsidian", network: "ISO 14443-4", num: "4532 •••• •••• 8821", physical: true, limit: 50000 },
  { id: "c2", name: "Sar-E Daily Spend", tag: "Virtual · Tokenized", material: "emerald", network: "Visa Tokenized", num: "4716 •••• •••• 2204", limit: 2000 },
  { id: "c3", name: "Online Subscriptions", tag: "Virtual · Tokenized", material: "indigo", network: "Mastercard Tokenized", num: "5412 •••• •••• 7730", limit: 5000 },
  { id: "c4", name: "One-Time Burner Card", tag: "Virtual · Single use", material: "amber", network: "Visa Tokenized", num: "4929 •••• •••• 0519", limit: 1000 },
];

type Ctx = {
  user: (typeof SAVED)[0] | null;
  signIn: (u: (typeof SAVED)[0]) => void;
  signOut: () => void;
  balance: number; setBalance: (n: number) => void;
  txns: Txn[]; addTxn: (t: Omit<Txn, "id" | "mac" | "time">) => void;
  armedUntil: number | null; arm: () => void; disarm: () => void; armedLeft: number;
  cart: Record<string, number>; setCart: (c: Record<string, number>) => void;
  cards: CardT[]; addCard: (c: CardT) => void;
  overlay: Overlay; open: (o: Overlay) => void; close: () => void;
  toast: string | null; say: (m: string) => void;
  revoked: boolean; setRevoked: (b: boolean) => void;
  tab: number; setTab: (n: number) => void;
  payArmed: (amount: number, title: string, sare?: boolean) => void;
};
const C = createContext<Ctx>(null as any);
export const useApp = () => useContext(C);
export const peso = (n: number) => (n < 0 ? "-" : "") + "₱" + Math.abs(n).toLocaleString("en-PH", { minimumFractionDigits: 2, maximumFractionDigits: 2 });

export function Provider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<Ctx["user"]>(null);
  const [balance, setBalance] = useState(5000);
  const [txns, setTxns] = useState<Txn[]>([
    mk(1, "Aling Nena's Sari-Sari", "Today · 8:42 AM", -145, "sare", "8:42 AM"),
    mk(2, "Cash In · GCash Partner", "Today · 7:10 AM", 1000, "cashin", "7:10 AM"),
    mk(3, "Campus Coop Canteen", "Yesterday · 12:31 PM", -88, "nfc", "12:31 PM"),
    mk(4, "Jeepney Fare · Beep Tap", "Yesterday · 6:55 AM", -13, "nfc", "6:55 AM"),
    mk(5, "From Lola Remedios", "Mon · 4:20 PM", 500, "p2p", "4:20 PM"),
  ]);
  const [armedUntil, setArmed] = useState<number | null>(null);
  const [now, setNow] = useState(Date.now());
  const [cart, setCart] = useState<Record<string, number>>({});
  const [cards, setCards] = useState(initialCards);
  const [overlay, setOverlay] = useState<Overlay>(null);
  const [toast, setToast] = useState<string | null>(null);
  const [revoked, setRevoked] = useState(false);
  const [tab, setTab] = useState(0);

  useEffect(() => { const t = setInterval(() => setNow(Date.now()), 1000); return () => clearInterval(t); }, []);
  const armedLeft = armedUntil ? Math.max(0, Math.round((armedUntil - now) / 1000)) : 0;
  useEffect(() => { if (armedUntil && armedLeft === 0) setArmed(null); }, [armedLeft, armedUntil]);

  const say = useCallback((m: string) => { setToast(m); setTimeout(() => setToast(null), 2200); }, []);
  const value: Ctx = {
    user, signIn: (u) => { setUser(u); setTab(0); }, signOut: () => { setUser(null); setArmed(null); setOverlay(null); },
    balance, setBalance, txns,
    addTxn: (t) => setTxns((p) => [mk(Date.now(), t.title, t.sub, t.amount, t.kind, "Just now"), ...p]),
    armedUntil, arm: () => setArmed(Date.now() + 300000), disarm: () => setArmed(null), armedLeft,
    cart, setCart, cards, addCard: (c) => setCards((p) => [...p, c]),
    overlay, open: setOverlay, close: () => setOverlay(null), toast, say, revoked, setRevoked, tab, setTab,
    payArmed: (amount, title, sare) => {
      const pay: Overlay = { type: "pay", amount, title, sare };
      setOverlay(armedUntil ? pay : { type: "unlock", next: pay });
    },
  };
  return <C.Provider value={value}>{children}</C.Provider>;
}
