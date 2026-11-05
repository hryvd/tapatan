import { useState } from "react";
import { motion, AnimatePresence } from "motion/react";
import {
  BarChart,
  Bar,
  XAxis,
  YAxis,
  Tooltip,
  ResponsiveContainer,
  AreaChart,
  Area,
  Cell,
} from "recharts";
import {
  TrendingUp,
  Zap,
  Shield,
  CheckCircle,
  XCircle,
  Clock,
  Wifi,
  Activity,
  ChevronDown,
  ChevronUp,
  CreditCard,
  Cpu,
  BarChart2,
} from "lucide-react";
import { getUseCount, getLastTap } from "../services/cardRevocationService";

// ── Mock data ──────────────────────────────────────────────────────────────────

const dailyTxns = [
  { day: "Mon", success: 5, failed: 0, amount: 3200 },
  { day: "Tue", success: 8, failed: 1, amount: 5820 },
  { day: "Wed", success: 6, failed: 0, amount: 4100 },
  { day: "Thu", success: 9, failed: 1, amount: 8750 },
  { day: "Fri", success: 7, failed: 1, amount: 6440 },
  { day: "Sat", success: 5, failed: 0, amount: 2980 },
  { day: "Sun", success: 4, failed: 0, amount: 1900 },
];

const nfcAuthTimes = [
  { range: "<0.5s", count: 12 },
  { range: "0.5–1s", count: 21 },
  { range: "1–1.5s", count: 10 },
  { range: "1.5–2s", count: 4 },
  { range: ">2s", count: 1 },
];

const recentLogs = [
  { id: "TXN-92817364", type: "Send", recipient: "Maria Santos", amount: 2500, status: "success", authTime: 0.8, totalTime: 1.4, time: "2 hrs ago" },
  { id: "TXN-92817312", type: "NFC Pay", recipient: "7-Eleven POS", amount: 185, status: "success", authTime: 0.6, totalTime: 1.1, time: "5 hrs ago" },
  { id: "TXN-92816890", type: "Send", recipient: "Jose Reyes", amount: 800, status: "success", authTime: 0.9, totalTime: 1.6, time: "Yesterday" },
  { id: "TXN-92816441", type: "NFC Pay", recipient: "SM Mall POS", amount: 1240, status: "failed", authTime: 1.8, totalTime: 2.1, time: "Yesterday" },
  { id: "TXN-92815997", type: "Send", recipient: "Ana Gonzalez", amount: 1200, status: "success", authTime: 0.7, totalTime: 1.3, time: "2 days ago" },
  { id: "TXN-92815620", type: "NFC Pay", recipient: "Jollibee POS", amount: 320, status: "success", authTime: 0.5, totalTime: 0.9, time: "2 days ago" },
];

// ── Benchmark data ─────────────────────────────────────────────────────────────

const benchmarkData = [
  { method: "NFC Card", avgMs: 820, p95Ms: 1400, failRate: 6.4, securityRating: 95 },
  { method: "SMS OTP", avgMs: 4200, p95Ms: 12000, failRate: 18.2, securityRating: 55 },
  { method: "Biometric", avgMs: 950, p95Ms: 1800, failRate: 8.1, securityRating: 82 },
];

const benchmarkBarData = benchmarkData.map((d) => ({
  name: d.method,
  avgMs: d.avgMs,
  p95Ms: d.p95Ms,
}));

// ── Stats ──────────────────────────────────────────────────────────────────────

const totalTxns = 47;
const successTxns = 44;
const failedTxns = 3;
const successRate = ((successTxns / totalTxns) * 100).toFixed(1);
const avgAuthTime = 0.82;
const totalProcessed = 125840;

// ── Tooltips ──────────────────────────────────────────────────────────────────

function CustomBarTooltip({ active, payload, label }: any) {
  if (!active || !payload?.length) return null;
  return (
    <div className="rounded-xl px-3 py-2" style={{ background: "rgba(13,2,48,0.95)", border: "1px solid rgba(255,255,255,0.12)", backdropFilter: "blur(20px)" }}>
      <p className="text-white/60" style={{ fontSize: 11, fontWeight: 600 }}>{label}</p>
      {payload.map((p: any) => (
        <p key={p.name} style={{ fontSize: 12, fontWeight: 700, color: p.fill }}>
          {p.name}: {p.value}
        </p>
      ))}
    </div>
  );
}

function CustomBenchmarkTooltip({ active, payload, label }: any) {
  if (!active || !payload?.length) return null;
  return (
    <div className="rounded-xl px-3 py-2" style={{ background: "rgba(13,2,48,0.95)", border: "1px solid rgba(255,255,255,0.12)" }}>
      <p className="text-white/60" style={{ fontSize: 11 }}>{label}</p>
      {payload.map((p: any) => (
        <p key={p.name} style={{ fontSize: 12, fontWeight: 700, color: p.fill ?? p.stroke }}>
          {p.name}: {p.value}ms
        </p>
      ))}
    </div>
  );
}

function CustomAreaTooltip({ active, payload, label }: any) {
  if (!active || !payload?.length) return null;
  return (
    <div className="rounded-xl px-3 py-2" style={{ background: "rgba(13,2,48,0.95)", border: "1px solid rgba(255,255,255,0.12)" }}>
      <p className="text-white/60" style={{ fontSize: 11 }}>{label}</p>
      <p style={{ fontSize: 12, fontWeight: 700, color: "#a78bfa" }}>₱{payload[0]?.value?.toLocaleString()}</p>
    </div>
  );
}

// ── Main Component ─────────────────────────────────────────────────────────────

type Tab = "overview" | "benchmark" | "health";

export function AnalyticsScreen() {
  const [expandedId, setExpandedId] = useState<string | null>(null);
  const [activeTab, setActiveTab] = useState<Tab>("overview");

  // Card health data (from service — uses localStorage counts set during real use)
  const DEMO_CARD_IDS = ["gcash-1", "maya-1"];
  const cardHealthData = DEMO_CARD_IDS.map((id) => {
    const useCount = getUseCount(id);
    const lastTapTs = getLastTap(id);
    return {
      id,
      label: id === "gcash-1" ? "GCash Card" : "Maya Card",
      useCount,
      lastTap: lastTapTs
        ? new Date(lastTapTs).toLocaleString()
        : "Never",
      appletVersion: "v2.1.0",
      memoryUsed: `${Math.min(100, useCount * 12 + 24)}%`,
      status: useCount === 0 ? "Unused" : "Active",
    };
  });

  return (
    <div className="pt-14 pb-6 px-5 space-y-5">
      {/* Header */}
      <div>
        <h2 className="text-white" style={{ fontSize: 22, fontWeight: 900 }}>Analytics</h2>
        <p className="text-white/40" style={{ fontSize: 12, marginTop: 2 }}>Security & transaction performance</p>
      </div>

      {/* Tab switcher */}
      <div
        className="flex p-1 rounded-2xl gap-1"
        style={{ background: "rgba(255,255,255,0.04)", border: "1px solid rgba(255,255,255,0.08)" }}
      >
        {([
          { id: "overview" as Tab, label: "Overview", icon: Activity },
          { id: "benchmark" as Tab, label: "Benchmark", icon: BarChart2 },
          { id: "health" as Tab, label: "Card Health", icon: CreditCard },
        ] as const).map(({ id, label, icon: Icon }) => (
          <button
            key={id}
            onClick={() => setActiveTab(id)}
            className="flex-1 flex items-center justify-center gap-1.5 py-2 rounded-xl transition-all"
            style={{
              background: activeTab === id ? "rgba(124,58,237,0.35)" : "transparent",
              border: activeTab === id ? "1px solid rgba(124,58,237,0.4)" : "1px solid transparent",
              color: activeTab === id ? "#a78bfa" : "rgba(255,255,255,0.35)",
              fontSize: 11,
              fontWeight: activeTab === id ? 700 : 500,
            }}
          >
            <Icon size={13} />
            {label}
          </button>
        ))}
      </div>

      {/* ── OVERVIEW TAB ── */}
      <AnimatePresence mode="wait">
        {activeTab === "overview" && (
          <motion.div key="overview" initial={{ opacity: 0, y: 8 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0 }} className="space-y-5">
            {/* Top stats 2×2 */}
            <div className="grid grid-cols-2 gap-3">
              {[
                { label: "Total Transactions", value: totalTxns.toString(), sub: "Last 30 days", icon: Activity, color: "#7c3aed", gradFrom: "#7c3aed22", gradTo: "#2563eb11" },
                { label: "Success Rate", value: `${successRate}%`, sub: `${successTxns} of ${totalTxns}`, icon: TrendingUp, color: "#10b981", gradFrom: "#10b98122", gradTo: "#05966911" },
                { label: "Avg NFC Auth", value: `${avgAuthTime}s`, sub: "Card tap speed", icon: Zap, color: "#f59e0b", gradFrom: "#f59e0b22", gradTo: "#d9770611" },
                { label: "Total Processed", value: `₱${(totalProcessed / 1000).toFixed(0)}K`, sub: "Tokenized payments", icon: Shield, color: "#06b6d4", gradFrom: "#06b6d422", gradTo: "#0891b211" },
              ].map(({ label, value, sub, icon: Icon, color, gradFrom, gradTo }, i) => (
                <motion.div
                  key={label}
                  initial={{ opacity: 0, y: 12 }}
                  animate={{ opacity: 1, y: 0 }}
                  transition={{ delay: i * 0.06 }}
                  className="p-4 rounded-3xl"
                  style={{ background: `linear-gradient(135deg, ${gradFrom}, ${gradTo})`, border: `1px solid ${color}33`, backdropFilter: "blur(16px)" }}
                >
                  <div className="w-8 h-8 rounded-xl flex items-center justify-center mb-2" style={{ background: `${color}22` }}>
                    <Icon size={16} style={{ color }} />
                  </div>
                  <p className="text-white" style={{ fontSize: 22, fontWeight: 900, lineHeight: 1.1 }}>{value}</p>
                  <p className="text-white/60" style={{ fontSize: 11, marginTop: 2, fontWeight: 600 }}>{label}</p>
                  <p className="text-white/30" style={{ fontSize: 10, marginTop: 1 }}>{sub}</p>
                </motion.div>
              ))}
            </div>

            {/* Daily transactions chart */}
            <div className="p-4 rounded-3xl" style={{ background: "rgba(255,255,255,0.04)", border: "1px solid rgba(255,255,255,0.08)" }}>
              <div className="flex items-center justify-between mb-4">
                <div>
                  <p className="text-white" style={{ fontSize: 14, fontWeight: 800 }}>Daily Transactions</p>
                  <p className="text-white/40" style={{ fontSize: 11 }}>Last 7 days · success vs failed</p>
                </div>
                <div className="flex items-center gap-3">
                  <div className="flex items-center gap-1"><div className="w-2 h-2 rounded-full" style={{ background: "#7c3aed" }} /><span className="text-white/50" style={{ fontSize: 10 }}>OK</span></div>
                  <div className="flex items-center gap-1"><div className="w-2 h-2 rounded-full" style={{ background: "#ef4444" }} /><span className="text-white/50" style={{ fontSize: 10 }}>Fail</span></div>
                </div>
              </div>
              <ResponsiveContainer width="100%" height={120}>
                <BarChart data={dailyTxns} barGap={2}>
                  <XAxis dataKey="day" tick={{ fill: "rgba(255,255,255,0.35)", fontSize: 11 }} axisLine={false} tickLine={false} />
                  <Tooltip content={<CustomBarTooltip />} cursor={{ fill: "rgba(255,255,255,0.04)" }} />
                  <Bar dataKey="success" name="Success" fill="#7c3aed" radius={[3, 3, 0, 0]} maxBarSize={18} />
                  <Bar dataKey="failed" name="Failed" fill="#ef4444" radius={[3, 3, 0, 0]} maxBarSize={18} />
                </BarChart>
              </ResponsiveContainer>
            </div>

            {/* Amount area chart */}
            <div className="p-4 rounded-3xl" style={{ background: "rgba(255,255,255,0.04)", border: "1px solid rgba(255,255,255,0.08)" }}>
              <div className="mb-3">
                <p className="text-white" style={{ fontSize: 14, fontWeight: 800 }}>Transaction Volume</p>
                <p className="text-white/40" style={{ fontSize: 11 }}>PHP processed per day</p>
              </div>
              <ResponsiveContainer width="100%" height={100}>
                <AreaChart data={dailyTxns}>
                  <defs>
                    <linearGradient id="amtGrad" x1="0" y1="0" x2="0" y2="1">
                      <stop offset="5%" stopColor="#a78bfa" stopOpacity={0.35} />
                      <stop offset="95%" stopColor="#a78bfa" stopOpacity={0.02} />
                    </linearGradient>
                  </defs>
                  <XAxis dataKey="day" tick={{ fill: "rgba(255,255,255,0.35)", fontSize: 11 }} axisLine={false} tickLine={false} />
                  <Tooltip content={<CustomAreaTooltip />} />
                  <Area type="monotone" dataKey="amount" stroke="#a78bfa" strokeWidth={2} fill="url(#amtGrad)" dot={false} />
                </AreaChart>
              </ResponsiveContainer>
            </div>

            {/* NFC auth speed distribution */}
            <div className="p-4 rounded-3xl" style={{ background: "rgba(255,255,255,0.04)", border: "1px solid rgba(255,255,255,0.08)" }}>
              <p className="text-white mb-1" style={{ fontSize: 14, fontWeight: 800 }}>NFC Auth Speed Distribution</p>
              <p className="text-white/40 mb-4" style={{ fontSize: 11 }}>Time from tap to authentication</p>
              <div className="flex flex-col gap-2">
                {nfcAuthTimes.map(({ range, count }) => {
                  const pct = (count / 48) * 100;
                  const isGood = range === "<0.5s" || range === "0.5–1s";
                  const color = isGood ? "#10b981" : range === "1–1.5s" ? "#f59e0b" : "#ef4444";
                  return (
                    <div key={range} className="flex items-center gap-3">
                      <span className="text-white/50 w-12 flex-shrink-0" style={{ fontSize: 11 }}>{range}</span>
                      <div className="flex-1 rounded-full overflow-hidden" style={{ height: 6, background: "rgba(255,255,255,0.08)" }}>
                        <motion.div
                          initial={{ width: 0 }}
                          animate={{ width: `${pct}%` }}
                          transition={{ duration: 0.6 }}
                          className="h-full rounded-full"
                          style={{ background: color }}
                        />
                      </div>
                      <span className="text-white/40 w-6 text-right flex-shrink-0" style={{ fontSize: 11 }}>{count}</span>
                    </div>
                  );
                })}
              </div>
            </div>

            {/* Security metrics row */}
            <div className="grid grid-cols-3 gap-2">
              {[
                { label: "Failed Auths", value: failedTxns.toString(), color: "#ef4444", icon: XCircle },
                { label: "Card Activations", value: "52", color: "#a78bfa", icon: Wifi },
                { label: "Avg Tx Time", value: "1.3s", color: "#06b6d4", icon: Clock },
              ].map(({ label, value, color, icon: Icon }) => (
                <div key={label} className="p-3 rounded-2xl flex flex-col items-center gap-1.5" style={{ background: "rgba(255,255,255,0.04)", border: "1px solid rgba(255,255,255,0.08)" }}>
                  <Icon size={16} style={{ color }} />
                  <p className="text-white" style={{ fontSize: 18, fontWeight: 900 }}>{value}</p>
                  <p className="text-white/40 text-center" style={{ fontSize: 10, fontWeight: 600 }}>{label}</p>
                </div>
              ))}
            </div>

            {/* Recent auth log */}
            <div className="space-y-2">
              <div className="flex items-center justify-between">
                <p className="text-white" style={{ fontSize: 14, fontWeight: 800 }}>Recent Auth Log</p>
                <span className="text-white/30" style={{ fontSize: 11 }}>{recentLogs.length} entries</span>
              </div>
              {recentLogs.map((log, i) => (
                <motion.div key={log.id} initial={{ opacity: 0, y: 6 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: 0.05 + i * 0.04 }}>
                  <button onClick={() => setExpandedId(expandedId === log.id ? null : log.id)} className="w-full text-left">
                    <div className="p-3 rounded-2xl" style={{ background: "rgba(255,255,255,0.04)", border: log.status === "failed" ? "1px solid rgba(239,68,68,0.2)" : "1px solid rgba(255,255,255,0.07)" }}>
                      <div className="flex items-center gap-3">
                        <div className="w-8 h-8 rounded-xl flex items-center justify-center flex-shrink-0" style={{ background: log.status === "success" ? "rgba(16,185,129,0.15)" : "rgba(239,68,68,0.15)" }}>
                          {log.status === "success" ? <CheckCircle size={15} style={{ color: "#34d399" }} /> : <XCircle size={15} style={{ color: "#f87171" }} />}
                        </div>
                        <div className="flex-1 min-w-0">
                          <p className="text-white truncate" style={{ fontSize: 13, fontWeight: 700 }}>{log.type} → {log.recipient}</p>
                          <p className="text-white/40" style={{ fontSize: 11 }}>₱{log.amount.toLocaleString()} · {log.time}</p>
                        </div>
                        <div className="flex flex-col items-end gap-1">
                          <span style={{ fontSize: 12, fontWeight: 800, color: log.status === "success" ? "#34d399" : "#f87171" }}>{log.totalTime}s</span>
                          {expandedId === log.id ? <ChevronUp size={12} style={{ color: "rgba(255,255,255,0.3)" }} /> : <ChevronDown size={12} style={{ color: "rgba(255,255,255,0.3)" }} />}
                        </div>
                      </div>
                      {expandedId === log.id && (
                        <motion.div initial={{ opacity: 0, height: 0 }} animate={{ opacity: 1, height: "auto" }} exit={{ opacity: 0, height: 0 }} className="mt-3 pt-3 flex flex-col gap-1.5" style={{ borderTop: "1px solid rgba(255,255,255,0.07)" }}>
                          {[
                            { label: "Transaction ID", value: log.id },
                            { label: "NFC Auth Time", value: `${log.authTime}s` },
                            { label: "Total Time", value: `${log.totalTime}s` },
                            { label: "Status", value: log.status === "success" ? "Completed" : "Failed" },
                          ].map(({ label, value }) => (
                            <div key={label} className="flex items-center justify-between">
                              <span className="text-white/40" style={{ fontSize: 11 }}>{label}</span>
                              <span className="text-white/70" style={{ fontSize: 11, fontFamily: label === "Transaction ID" ? "monospace" : "inherit", fontWeight: 600 }}>{value}</span>
                            </div>
                          ))}
                        </motion.div>
                      )}
                    </div>
                  </button>
                </motion.div>
              ))}
            </div>

            {/* Security assessment */}
            <div className="p-4 rounded-3xl" style={{ background: "linear-gradient(135deg, rgba(16,185,129,0.08), rgba(6,182,212,0.05))", border: "1px solid rgba(16,185,129,0.2)" }}>
              <div className="flex items-center gap-2 mb-2">
                <Shield size={16} style={{ color: "#34d399" }} />
                <span className="text-emerald-400" style={{ fontSize: 13, fontWeight: 800 }}>Security Assessment</span>
              </div>
              <div className="flex flex-col gap-1.5">
                {[
                  { label: "Auth Reliability", value: `${successRate}%`, color: "#34d399" },
                  { label: "Avg NFC Response", value: `${avgAuthTime}s`, color: "#a78bfa" },
                  { label: "Token Integrity", value: "100%", color: "#34d399" },
                  { label: "Failed Auth Rate", value: `${((failedTxns / totalTxns) * 100).toFixed(1)}%`, color: "#f59e0b" },
                ].map(({ label, value, color }) => (
                  <div key={label} className="flex items-center justify-between">
                    <span className="text-white/50" style={{ fontSize: 12 }}>{label}</span>
                    <span style={{ fontSize: 12, fontWeight: 800, color }}>{value}</span>
                  </div>
                ))}
              </div>
            </div>
          </motion.div>
        )}

        {/* ── BENCHMARK TAB ── */}
        {activeTab === "benchmark" && (
          <motion.div key="benchmark" initial={{ opacity: 0, y: 8 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0 }} className="space-y-5">
            <div className="p-4 rounded-3xl" style={{ background: "rgba(255,255,255,0.04)", border: "1px solid rgba(255,255,255,0.08)" }}>
              <div className="flex items-center gap-2 mb-1">
                <Cpu size={14} className="text-violet-400" />
                <p className="text-white" style={{ fontSize: 14, fontWeight: 800 }}>Authentication Method Comparison</p>
              </div>
              <p className="text-white/40 mb-4" style={{ fontSize: 11 }}>
                Side-by-side timing data: NFC Card vs SMS OTP vs Biometric. Lower is better.
              </p>
              <ResponsiveContainer width="100%" height={160}>
                <BarChart data={benchmarkBarData} barGap={4} barCategoryGap="30%">
                  <XAxis dataKey="name" tick={{ fill: "rgba(255,255,255,0.5)", fontSize: 10 }} axisLine={false} tickLine={false} />
                  <YAxis tick={{ fill: "rgba(255,255,255,0.3)", fontSize: 10 }} axisLine={false} tickLine={false} unit="ms" width={42} />
                  <Tooltip content={<CustomBenchmarkTooltip />} cursor={{ fill: "rgba(255,255,255,0.04)" }} />
                  <Bar dataKey="avgMs" name="Avg" radius={[4, 4, 0, 0]} maxBarSize={28}>
                    {benchmarkBarData.map((_, index) => (
                      <Cell key={`avg-${index}`} fill={index === 0 ? "#7c3aed" : index === 1 ? "#f59e0b" : "#06b6d4"} />
                    ))}
                  </Bar>
                  <Bar dataKey="p95Ms" name="p95" radius={[4, 4, 0, 0]} maxBarSize={28} opacity={0.45}>
                    {benchmarkBarData.map((_, index) => (
                      <Cell key={`p95-${index}`} fill={index === 0 ? "#7c3aed" : index === 1 ? "#f59e0b" : "#06b6d4"} />
                    ))}
                  </Bar>
                </BarChart>
              </ResponsiveContainer>
              <div className="flex items-center gap-4 mt-2" style={{ borderTop: "1px solid rgba(255,255,255,0.06)", paddingTop: 8 }}>
                <div className="flex items-center gap-1.5"><div className="w-3 h-3 rounded" style={{ background: "rgba(124,58,237,0.9)" }} /><span className="text-white/40" style={{ fontSize: 10 }}>Avg latency</span></div>
                <div className="flex items-center gap-1.5"><div className="w-3 h-3 rounded" style={{ background: "rgba(124,58,237,0.4)" }} /><span className="text-white/40" style={{ fontSize: 10 }}>p95 latency</span></div>
              </div>
            </div>

            {/* Comparison table */}
            <div className="p-4 rounded-3xl space-y-3" style={{ background: "rgba(255,255,255,0.04)", border: "1px solid rgba(255,255,255,0.08)" }}>
              <p className="text-white" style={{ fontSize: 14, fontWeight: 800 }}>Detailed Comparison</p>
              <div className="grid grid-cols-4 gap-1" style={{ fontSize: 10 }}>
                {["Method", "Avg", "Fail %", "Security"].map((h) => (
                  <div key={h} className="text-white/40 font-bold pb-1" style={{ borderBottom: "1px solid rgba(255,255,255,0.08)" }}>{h}</div>
                ))}
                {benchmarkData.map((d, i) => {
                  const color = i === 0 ? "#7c3aed" : i === 1 ? "#f59e0b" : "#06b6d4";
                  return (
                    <>
                      <div key={`${d.method}-name`} className="py-2" style={{ color: "white", fontWeight: 700, fontSize: 11 }}>{d.method}</div>
                      <div key={`${d.method}-avg`} className="py-2" style={{ color, fontWeight: 700, fontSize: 11 }}>{d.avgMs}ms</div>
                      <div key={`${d.method}-fail`} className="py-2" style={{ color: d.failRate > 10 ? "#f87171" : "#34d399", fontWeight: 700, fontSize: 11 }}>{d.failRate}%</div>
                      <div key={`${d.method}-sec`} className="py-2" style={{ color: d.securityRating >= 90 ? "#34d399" : d.securityRating >= 70 ? "#f59e0b" : "#f87171", fontWeight: 700, fontSize: 11 }}>{d.securityRating}/100</div>
                    </>
                  );
                })}
              </div>
            </div>

            {/* Research finding */}
            <div className="p-4 rounded-3xl" style={{ background: "linear-gradient(135deg, rgba(124,58,237,0.12), rgba(37,99,235,0.08))", border: "1px solid rgba(124,58,237,0.25)" }}>
              <p className="text-violet-400 mb-2" style={{ fontSize: 13, fontWeight: 800 }}>📊 Research Finding</p>
              <p className="text-white/60" style={{ fontSize: 12, lineHeight: 1.6 }}>
                NFC Card authentication is <span className="text-violet-300 font-bold">5.1× faster</span> than SMS OTP on average 
                and achieves a <span className="text-emerald-300 font-bold">93.6% success rate</span> vs 81.8% for SMS OTP — 
                while offering significantly stronger security properties due to physical possession requirements.
              </p>
            </div>
          </motion.div>
        )}

        {/* ── CARD HEALTH TAB ── */}
        {activeTab === "health" && (
          <motion.div key="health" initial={{ opacity: 0, y: 8 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0 }} className="space-y-4">
            <p className="text-white/40" style={{ fontSize: 12 }}>
              Real-time card health data from your registered NFC cards.
            </p>
            {cardHealthData.map((card, i) => (
              <motion.div
                key={card.id}
                initial={{ opacity: 0, y: 10 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ delay: i * 0.08 }}
                className="p-4 rounded-3xl space-y-3"
                style={{
                  background: "rgba(255,255,255,0.04)",
                  border: "1px solid rgba(255,255,255,0.08)",
                }}
              >
                <div className="flex items-center justify-between">
                  <div className="flex items-center gap-2">
                    <div className="w-8 h-8 rounded-xl flex items-center justify-center" style={{ background: i === 0 ? "rgba(0,70,213,0.25)" : "rgba(74,14,143,0.25)" }}>
                      <CreditCard size={15} style={{ color: i === 0 ? "#60a5fa" : "#a78bfa" }} />
                    </div>
                    <div>
                      <p className="text-white" style={{ fontSize: 13, fontWeight: 700 }}>{card.label}</p>
                      <p className="text-white/30 font-mono" style={{ fontSize: 10 }}>{card.id}</p>
                    </div>
                  </div>
                  <span
                    className="px-2 py-0.5 rounded-full"
                    style={{
                      background: card.status === "Active" ? "rgba(16,185,129,0.15)" : "rgba(255,255,255,0.06)",
                      border: `1px solid ${card.status === "Active" ? "rgba(16,185,129,0.35)" : "rgba(255,255,255,0.10)"}`,
                      color: card.status === "Active" ? "#34d399" : "rgba(255,255,255,0.35)",
                      fontSize: 10,
                      fontWeight: 700,
                    }}
                  >
                    {card.status}
                  </span>
                </div>
                <div className="grid grid-cols-2 gap-2">
                  {[
                    { label: "Times Used", value: card.useCount.toString() },
                    { label: "Last Tapped", value: card.lastTap },
                    { label: "Applet Version", value: card.appletVersion },
                    { label: "Memory Used", value: card.memoryUsed },
                  ].map(({ label, value }) => (
                    <div key={label} className="p-2.5 rounded-xl" style={{ background: "rgba(255,255,255,0.04)", border: "1px solid rgba(255,255,255,0.06)" }}>
                      <p className="text-white/40" style={{ fontSize: 10 }}>{label}</p>
                      <p className="text-white" style={{ fontSize: 12, fontWeight: 700 }}>{value}</p>
                    </div>
                  ))}
                </div>
                {/* Memory bar */}
                <div>
                  <div className="flex items-center justify-between mb-1">
                    <span className="text-white/40" style={{ fontSize: 10 }}>Memory Usage</span>
                    <span className="text-white/60" style={{ fontSize: 10, fontWeight: 700 }}>{card.memoryUsed}</span>
                  </div>
                  <div className="w-full rounded-full overflow-hidden" style={{ height: 4, background: "rgba(255,255,255,0.08)" }}>
                    <div
                      className="h-full rounded-full"
                      style={{
                        width: card.memoryUsed,
                        background: parseInt(card.memoryUsed) < 50 ? "#34d399" : parseInt(card.memoryUsed) < 80 ? "#f59e0b" : "#ef4444",
                        transition: "width 0.8s ease",
                      }}
                    />
                  </div>
                </div>
              </motion.div>
            ))}

            <div className="p-3 rounded-2xl" style={{ background: "rgba(245,158,11,0.08)", border: "1px solid rgba(245,158,11,0.2)" }}>
              <p className="text-amber-400" style={{ fontSize: 11 }}>
                ⚡ Memory usage is estimated based on tap count. Actual Java Card memory varies by applet version.
              </p>
            </div>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}
