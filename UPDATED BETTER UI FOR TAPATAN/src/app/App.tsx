import { motion } from "motion/react";
import { Home, CreditCard, Store, BarChart2, User } from "lucide-react";
import { Provider, useApp } from "./store";
import { useState } from "react";
import { LandingScreen } from "./LandingScreen";
import { AuthScreen } from "./AuthScreen";
import { HomeScreen } from "./HomeScreen";
import { CardsScreen } from "./CardsScreen";
import { SarEScreen } from "./SarEScreen";
import { AnalyticsScreen } from "./AnalyticsScreen";
import { ProfileScreen } from "./ProfileScreen";
import { Overlays } from "./Overlays";

const tabs = [
  { l: "Home", i: Home }, { l: "Cards", i: CreditCard }, { l: "Sar-E", i: Store }, { l: "Analytics", i: BarChart2 }, { l: "Profile", i: User },
];
const screens = [HomeScreen, CardsScreen, SarEScreen, AnalyticsScreen, ProfileScreen];

function Shell() {
  const { user, tab, setTab, toast } = useApp();
  const Screen = screens[tab];
  const [stage, setStage] = useState<"landing" | "in" | "up">("landing");
  return (
    <div className="min-h-screen bg-[#02050d] flex items-center justify-center p-0 sm:p-6">
      <div className="aurora relative w-full sm:w-[393px] bg-[#0A0E17] flex flex-col overflow-hidden sm:rounded-[3rem] sm:shadow-2xl sm:shadow-cyan-950/60 sm:ring-[6px] sm:ring-[#14182a]" style={{ height: "100dvh", maxHeight: "852px" }}>
        <div className="relative z-20 flex-shrink-0 h-12 flex items-center justify-between px-7 pt-1">
          <span className="text-white text-[15px]" style={{ fontWeight: 600 }}>9:41</span>
          <div className="absolute left-1/2 -translate-x-1/2 top-2 w-[104px] h-[28px] bg-black rounded-full" />
          <div className="flex items-center gap-1.5">
            <div className="flex gap-0.5 items-end">{[4, 6, 8, 10].map((h) => <div key={h} className="w-[3px] bg-white rounded-sm" style={{ height: h }} />)}</div>
            <div className="w-6 h-3 border border-white/50 rounded-[4px] p-[1.5px]"><div className="h-full w-[80%] bg-white rounded-[2px]" /></div>
          </div>
        </div>

        {user ? (
          <div key={"app" + tab} className="relative z-10 flex-1 overflow-y-auto overflow-x-hidden no-scrollbar pb-28">
            <motion.div initial={{ opacity: 0, y: 8 }} animate={{ opacity: 1, y: 0 }}><Screen /></motion.div>
          </div>
        ) : (
          <div key={stage} className="relative z-10 flex-1 min-h-0">
            {stage === "landing" ? <LandingScreen onStart={setStage} /> : <AuthScreen key={stage} initial={stage} onBack={() => setStage("landing")} />}
          </div>
        )}

        {user && (
          <div className="absolute z-30 left-3 right-3 bottom-3">
            <div className="glass !rounded-[34px] flex items-center justify-around px-1.5 py-1.5 !bg-[rgba(14,22,42,0.6)]">
              {tabs.map(({ l, i: Icon }, n) => {
                const on = tab === n;
                return (
                  <button key={l} onClick={() => setTab(n)} className="relative flex-1 flex flex-col items-center gap-0.5 py-2 rounded-[28px]" aria-label={l}>
                    {on && <motion.div layoutId="lens" transition={{ type: "spring", stiffness: 420, damping: 32 }} className="absolute inset-0 rounded-[28px] bg-white/[0.16] border-[0.5px] border-white/30 shadow-[inset_0_1px_0_rgba(255,255,255,0.45),0_4px_14px_rgba(6,182,212,0.35)]" />}
                    <Icon className={`relative w-[21px] h-[21px] ${on ? "text-cyan-300" : "text-white/55"}`} strokeWidth={on ? 2.4 : 1.9} />
                    <span className={`relative text-[10px] ${on ? "text-cyan-300" : "text-white/55"}`} style={{ fontWeight: on ? 700 : 500 }}>{l}</span>
                  </button>
                );
              })}
            </div>
          </div>
        )}
        <Overlays />
        {toast && <motion.div initial={{ y: -20, opacity: 0 }} animate={{ y: 0, opacity: 1 }} className="absolute z-[90] top-14 left-1/2 -translate-x-1/2 glass-strong !rounded-full px-4 py-2 text-white text-[12px] whitespace-nowrap" style={{ fontWeight: 600 }}>{toast}</motion.div>}
        <div className="absolute z-[95] bottom-1 left-1/2 -translate-x-1/2 w-32 h-1 rounded-full bg-white/70 pointer-events-none" />
      </div>
    </div>
  );
}

export default function App() {
  return <Provider><Shell /></Provider>;
}
