import { useState } from "react";
import { AreaChart, Area, XAxis, Tooltip, ResponsiveContainer, PieChart, Pie, Cell } from "recharts";
import { ShieldCheck } from "lucide-react";
import { useApp } from "./store";

const DATA: Record<string, { n: string; inc: number; spend: number }[]> = {
  "7 Days": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"].map((n, i) => ({ n, inc: [0, 500, 0, 1000, 0, 250, 0][i], spend: [145, 88, 210, 13, 330, 175, 96][i] })),
  "30 Days": ["W1", "W2", "W3", "W4"].map((n, i) => ({ n, inc: [1500, 800, 2500, 1750][i], spend: [920, 1240, 780, 1105][i] })),
  Year: ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug"].map((n, i) => ({ n, inc: [5200, 4800, 6100, 5500, 7000, 6400, 5900, 6800][i], spend: [3900, 4100, 4600, 3800, 5200, 4700, 4400, 5100][i] })),
};
const CATS = [["Food & Sar-E", 46, "#22D3EE"], ["Transit", 22, "#34D399"], ["Utilities", 20, "#818CF8"], ["Transfers", 12, "#F59E0B"]] as const;

export function AnalyticsScreen() {
  const [tf, setTf] = useState("7 Days");
  const { txns } = useApp();
  const taps = txns.filter((t) => t.kind === "nfc" || t.kind === "sare").length + 38;
  return (
    <div className="px-5 pt-2">
      <h1 className="text-white text-[24px] mb-3" style={{ fontWeight: 800 }}>Analytics</h1>
      <div className="flex gap-1 glass-pill !rounded-[16px] p-1 mb-4">
        {Object.keys(DATA).map((k) => <button key={k} onClick={() => setTf(k)} className={`flex-1 h-9 rounded-[12px] text-[12.5px] ${tf === k ? "bg-white/20 text-white shadow-[inset_0_1px_0_rgba(255,255,255,.4)]" : "text-white/55"}`} style={{ fontWeight: 600 }}>{k}</button>)}
      </div>
      <div className="glass p-4 mb-4">
        <div className="flex items-center justify-between mb-2">
          <p className="text-white text-[14px]" style={{ fontWeight: 700 }}>Income vs. NFC spend</p>
          <span className="flex gap-3 text-[10px] text-white/60"><i className="not-italic">● <span className="text-emerald-300">Income</span></i><i className="not-italic">● <span className="text-cyan-300">Spend</span></i></span>
        </div>
        <div className="h-44">
          <ResponsiveContainer width="100%" height="100%">
            <AreaChart key={tf} data={DATA[tf].map((d, i) => ({ ...d, i }))} margin={{ left: 0, right: 0, top: 6, bottom: 0 }}>
              <defs>
                <linearGradient id="gInc" x1="0" y1="0" x2="0" y2="1"><stop offset="0%" stopColor="#34D399" stopOpacity={0.5} /><stop offset="100%" stopColor="#34D399" stopOpacity={0} /></linearGradient>
                <linearGradient id="gSpend" x1="0" y1="0" x2="0" y2="1"><stop offset="0%" stopColor="#22D3EE" stopOpacity={0.5} /><stop offset="100%" stopColor="#22D3EE" stopOpacity={0} /></linearGradient>
              </defs>
              <XAxis dataKey="i" interval={0} tickFormatter={(i: number) => DATA[tf][i]?.n} tick={{ fill: "rgba(255,255,255,.5)", fontSize: 11 }} axisLine={false} tickLine={false} />
              <Tooltip labelFormatter={(i: any) => DATA[tf][i]?.n} contentStyle={{ background: "rgba(20,28,50,.85)", border: "1px solid rgba(255,255,255,.2)", borderRadius: 14, color: "#fff", fontSize: 12 }} cursor={{ stroke: "rgba(255,255,255,.3)" }} />
              <Area type="monotone" dataKey="inc" name="Income" stroke="#34D399" strokeWidth={2.5} fill="url(#gInc)" />
              <Area type="monotone" dataKey="spend" name="Spend" stroke="#22D3EE" strokeWidth={2.5} fill="url(#gSpend)" />
            </AreaChart>
          </ResponsiveContainer>
        </div>
      </div>
      <div className="glass p-4 mb-4">
        <p className="text-white text-[14px] mb-2" style={{ fontWeight: 700 }}>Where it goes</p>
        <div className="flex items-center gap-3">
          <div className="w-32 h-32 flex-shrink-0">
            <ResponsiveContainer width="100%" height="100%"><PieChart><Pie data={CATS.map(([n, v]) => ({ n, v }))} dataKey="v" innerRadius={38} outerRadius={60} paddingAngle={3} stroke="none">{CATS.map(([n, , c]) => <Cell key={n} fill={c} />)}</Pie></PieChart></ResponsiveContainer>
          </div>
          <div className="flex-1 space-y-2.5">
            {CATS.map(([n, v, c]) => (
              <div key={n}><div className="flex justify-between text-[11px] text-white/75 mb-1"><span>{n}</span><span style={{ fontWeight: 700 }}>{v}%</span></div>
                <div className="h-1.5 rounded-full bg-white/10"><div className="h-full rounded-full" style={{ width: `${v * 2}%`, background: c }} /></div></div>
            ))}
          </div>
        </div>
      </div>
      <div className="glass-tint p-4 mb-2">
        <div className="flex items-center gap-2 mb-3 text-white text-[14px]" style={{ fontWeight: 700 }}><ShieldCheck className="w-4 h-4 text-emerald-300" />Card security &amp; tap telemetry</div>
        <div className="grid grid-cols-2 gap-3">
          <div className="bg-black/20 rounded-[18px] p-3"><p className="text-white/50 text-[11px]">Turing-verified taps</p><p className="font-mono-ui text-emerald-300 text-[24px]">{taps}</p></div>
          <div className="bg-black/20 rounded-[18px] p-3"><p className="text-white/50 text-[11px]">Rejected MACs</p><p className="font-mono-ui text-white text-[24px]">0</p></div>
        </div>
      </div>
    </div>
  );
}
