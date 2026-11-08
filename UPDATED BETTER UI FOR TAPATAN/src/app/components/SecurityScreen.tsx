import { useState } from "react";
import {
  ShieldCheck, Brain, Wifi, ChevronDown, ChevronRight,
  CheckCircle, AlertTriangle, Clock, Zap, Target,
  Activity, Lock, Key, RotateCcw, Eye,
  CreditCard, BarChart2, Cpu, Award, Info,
  Database, Layers, GitBranch, TrendingUp,
} from "lucide-react";
import {
  AreaChart, Area, BarChart, Bar, RadarChart, Radar,
  PolarGrid, PolarAngleAxis, XAxis, YAxis, Tooltip,
  ResponsiveContainer, RadialBarChart, RadialBar,
  LineChart, Line,
} from "recharts";
import { motion, AnimatePresence } from "motion/react";

type SubTab = "overview" | "nfc" | "ml";

/* ────────────────────────────────────────────────────────────────
   DATA FROM: manuscript__2_.pdf
   "A Dual-Layered Security Defense System for NFC-Based Hardware
    Key Online Banking using CNN-LSTM for Phishing Detection"
──────────────────────────────────────────────────────────────── */

// STRIDE Threat Resistance Matrix (Table 3.1 from paper)
const strideMatrix = [
  {
    threat: "Spoofing",
    vector: "Forged card via APDU replay",
    layer: "Hardware",
    status: "Mitigated",
    note: "Challenge unique per session",
  },
  {
    threat: "Spoofing",
    vector: "Server impersonation via fraudulent SSL",
    layer: "Application",
    status: "Mitigated",
    note: "Certificate pinning enforced",
  },
  {
    threat: "Tampering",
    vector: "NFC data modification in transit",
    layer: "Hardware",
    status: "Mitigated",
    note: "ECDSA P-256 signature invalidated",
  },
  {
    threat: "Tampering",
    vector: "Firestore public key substitution",
    layer: "Backend",
    status: "Partial",
    note: "Firebase rules restrict writes; key rotation not yet implemented",
  },
  {
    threat: "Repudiation",
    vector: "User denies auth event",
    layer: "Backend",
    status: "Mitigated",
    note: "Signed assertion with session timestamp",
  },
  {
    threat: "Info Disclosure",
    vector: "NFC passive eavesdropping",
    layer: "Hardware",
    status: "Mitigated",
    note: "Eavesdropped assertion cannot be reused",
  },
  {
    threat: "Info Disclosure",
    vector: "Firestore unauthorized read",
    layer: "Backend",
    status: "Mitigated",
    note: "Firebase security rules restrict reads",
  },
  {
    threat: "DoS",
    vector: "Sustained auth request flood",
    layer: "Backend",
    status: "Partial",
    note: "Firebase rate limiting; no additional server throttle",
  },
  {
    threat: "DoS",
    vector: "Card unresponsive after error",
    layer: "Hardware",
    status: "Mitigated",
    note: "Card OS resets APDU state on next select",
  },
  {
    threat: "EoP",
    vector: "Unauthorized admin Firebase access",
    layer: "Backend",
    status: "Mitigated",
    note: "Admin functions protected by auth checks",
  },
  {
    threat: "EoP",
    vector: "Malicious URL injection",
    layer: "Application",
    status: "Mitigated",
    note: "CNN-LSTM blocks navigation to flagged URLs",
  },
];

// ML Model performance targets from paper
const mlMetrics = [
  { subject: "Accuracy", value: 94.7 },
  { subject: "Precision", value: 93.2 },
  { subject: "Recall", value: 95.1 },
  { subject: "F1 Score", value: 94.1 },
  { subject: "AUC-ROC", value: 96.3 },
];

// CNN-LSTM vs baselines (from Gurung et al. 2023 cited in paper)
const modelComparison = [
  { model: "CNN-LSTM", accuracy: 94.7, color: "#2563EB" },
  { model: "Random Forest", accuracy: 70.0, color: "#059669" },
  { model: "Logistic Reg.", accuracy: 62.3, color: "#7C3AED" },
  { model: "Naive Bayes", accuracy: 58.4, color: "#D97706" },
];

// Weekly threat simulation
const weeklyThreats = [
  { day: "Mon", phishing: 8, replay: 3, anomaly: 2 },
  { day: "Tue", phishing: 12, replay: 5, anomaly: 4 },
  { day: "Wed", phishing: 6, replay: 2, anomaly: 1 },
  { day: "Thu", phishing: 19, replay: 7, anomaly: 6 },
  { day: "Fri", phishing: 14, replay: 4, anomaly: 3 },
  { day: "Sat", phishing: 7, replay: 2, anomaly: 1 },
  { day: "Sun", phishing: 4, replay: 1, anomaly: 0 },
];

const layerRadial = [
  { name: "NFC Layer", value: 94, fill: "#2563EB" },
  { name: "CNN-LSTM", value: 94.7, fill: "#059669" },
  { name: "Combined", value: 99.1, fill: "#7C3AED" },
];

// Top features used by CNN-LSTM (from paper methodology)
const features = [
  { name: "URL lexical features", val: 89 },
  { name: "NFC tap pattern", val: 83 },
  { name: "Session time delta", val: 77 },
  { name: "Geographic anomaly", val: 72 },
  { name: "Device fingerprint", val: 68 },
  { name: "Transaction velocity", val: 65 },
];

const nfcKeys = [
  {
    id: "k1", name: "Primary Key Card", uid: "7F:3A:BC:D1",
    status: "active", signal: 88, lastUsed: "2 min ago",
    device: "iPhone 15 Pro",
  },
  {
    id: "k2", name: "Backup Key Card", uid: "A2:51:FF:C3",
    status: "active", signal: 73, lastUsed: "3 days ago",
    device: "Samsung Galaxy S24",
  },
  {
    id: "k3", name: "Test Key", uid: "D1:F0:38:55",
    status: "inactive", signal: 0, lastUsed: "2 weeks ago",
    device: "N/A",
  },
];

/* ── helpers ── */
const card = "glass border border-white/10 rounded-[26px]";

const DarkTooltip = ({ active, payload, label }: any) => {
  if (!active || !payload?.length) return null;
  return (
    <div className="glass-strong rounded-[16px] px-3 py-2 text-xs shadow-xl">
      <p className="text-gray-400 mb-1">{label}</p>
      {payload.map((p: any) => (
        <p key={p.name} style={{ color: p.color || "#60A5FA" }}>{p.name}: {p.value}{typeof p.value === "number" && p.value < 200 ? "%" : ""}</p>
      ))}
    </div>
  );
};

function SignalBars({ strength }: { strength: number }) {
  return (
    <div className="flex items-end gap-0.5 h-3.5">
      {[25, 50, 75, 100].map((t, i) => (
        <div key={i} className="w-1 rounded-sm" style={{ height: (i + 1) * 3.5, background: strength >= t ? "#10B981" : "#1F2937" }} />
      ))}
    </div>
  );
}

export function SecurityScreen() {
  const [subTab, setSubTab] = useState<SubTab>("overview");
  const [expandedKey, setExpandedKey] = useState<string | null>(null);
  const [expandedStride, setExpandedStride] = useState<number | null>(null);

  return (
    <div className="flex flex-col min-h-full">
      {/* Header */}
      <div className="bg-transparent px-5 pt-5 pb-8 overflow-hidden relative">
        <div className="absolute inset-0 bg-[radial-gradient(ellipse_at_top_right,rgba(59,130,246,0.12),transparent_60%)]" />

        <div className="relative flex items-center justify-between mb-5">
          <div className="flex items-center gap-2">
            <ShieldCheck className="w-5 h-5 text-white" />
            <h1 className="text-white" style={{ fontSize: "1.1rem", fontWeight: 700 }}>Security Center</h1>
          </div>
          <div className="flex items-center gap-1.5 bg-emerald-500/20 border border-emerald-500/30 rounded-full px-3 py-1">
            <span className="w-1.5 h-1.5 rounded-full bg-emerald-400 animate-pulse" />
            <span className="text-emerald-300 text-[11px]" style={{ fontWeight: 600 }}>Protected</span>
          </div>
        </div>

        {/* Security score */}
        <div className="relative flex items-center gap-4 mb-5">
          <div className="relative w-20 h-20 flex-shrink-0">
            <svg viewBox="0 0 80 80" className="w-full h-full -rotate-90">
              <circle cx="40" cy="40" r="34" fill="none" stroke="rgba(255,255,255,0.08)" strokeWidth="7" />
              <circle cx="40" cy="40" r="34" fill="none" stroke="white" strokeWidth="7"
                strokeDasharray={`${0.947 * 2 * Math.PI * 34} ${2 * Math.PI * 34}`} strokeLinecap="round" />
            </svg>
            <div className="absolute inset-0 flex flex-col items-center justify-center">
              <p className="text-white" style={{ fontSize: "1.2rem", fontWeight: 800, lineHeight: 1 }}>94.7</p>
              <p className="text-white/50 text-[9px]">% acc.</p>
            </div>
          </div>
          <div className="flex-1">
            <p className="text-white" style={{ fontWeight: 700 }}>CNN-LSTM Accuracy</p>
            <p className="text-white/50 text-xs mt-0.5">PhishTank + UCI datasets · 80/20 split</p>
            <div className="flex gap-2 mt-2 flex-wrap">
              <span className="bg-white/10 text-white text-[10px] px-2 py-0.5 rounded-full">2.4M samples</span>
              <span className="bg-white/10 text-white text-[10px] px-2 py-0.5 rounded-full">&lt; 500ms latency</span>
            </div>
          </div>
        </div>

        {/* Sub-tabs */}
        <div className="relative flex gap-1 bg-white/10 backdrop-blur-xl border border-white/10 rounded-[16px] p-1">
          {([
            { key: "overview", label: "Overview", icon: ShieldCheck },
            { key: "nfc", label: "NFC Key", icon: Wifi },
            { key: "ml", label: "ML Model", icon: Brain },
          ] as { key: SubTab; label: string; icon: any }[]).map(({ key, label, icon: Icon }) => (
            <button key={key} onClick={() => setSubTab(key)}
              className={`flex-1 flex items-center justify-center gap-1.5 py-2 rounded-lg text-xs transition-all ${subTab === key ? "bg-white text-[#1541A6]" : "text-white/60"}`}
              style={{ fontWeight: subTab === key ? 700 : 400 }}>
              <Icon className="w-3.5 h-3.5" />
              {label}
            </button>
          ))}
        </div>
      </div>

      {/* Content */}
      <div className="mx-4 -mt-4 relative z-10 pb-6">
        <AnimatePresence mode="wait">

          {/* ══════════ OVERVIEW ══════════ */}
          {subTab === "overview" && (
            <motion.div key="ov" initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0 }} className="space-y-3">

              {/* Dual-layer summary cards */}
              <div className="grid grid-cols-3 gap-2">
                {[
                  { label: "NFC Layer", val: "94.1%", sub: "ECDSA P-256", icon: Wifi, color: "text-blue-400", glow: "shadow-blue-900/40" },
                  { label: "ML Layer", val: "94.7%", sub: "CNN-LSTM", icon: Brain, color: "text-emerald-400", glow: "shadow-emerald-900/40" },
                  { label: "Combined", val: "99.1%", sub: "Dual-Layer", icon: ShieldCheck, color: "text-violet-400", glow: "shadow-violet-900/40" },
                ].map((s) => {
                  const Icon = s.icon;
                  return (
                    <div key={s.label} className={`${card} p-3 text-center shadow-lg ${s.glow}`}>
                      <Icon className={`w-4 h-4 ${s.color} mx-auto mb-1.5`} />
                      <p className={`text-sm ${s.color}`} style={{ fontWeight: 800 }}>{s.val}</p>
                      <p className="text-gray-500 text-[9px]">{s.label}</p>
                      <p className="text-gray-600 text-[9px]">{s.sub}</p>
                    </div>
                  );
                })}
              </div>

              {/* Weekly threat activity */}
              <div className={`${card} p-4`}>
                <p className="text-white text-sm mb-0.5" style={{ fontWeight: 700 }}>Weekly Threat Activity</p>
                <p className="text-gray-500 text-xs mb-3">Phishing · Replay · Anomaly (all blocked)</p>
                <ResponsiveContainer width="100%" height={130}>
                  <BarChart data={weeklyThreats} barGap={2} barSize={6}>
                    <XAxis dataKey="day" tick={{ fill: "#4B5563", fontSize: 10 }} axisLine={false} tickLine={false} />
                    <YAxis hide />
                    <Tooltip content={<DarkTooltip />} />
                    <Bar dataKey="phishing" name="Phishing" fill="#2563EB" radius={[3, 3, 0, 0]} />
                    <Bar dataKey="replay" name="Replay" fill="#059669" radius={[3, 3, 0, 0]} />
                    <Bar dataKey="anomaly" name="Anomaly" fill="#7C3AED" radius={[3, 3, 0, 0]} />
                  </BarChart>
                </ResponsiveContainer>
                <div className="flex gap-3 mt-1 flex-wrap">
                  {[["#2563EB","Phishing"],["#059669","Replay"],["#7C3AED","Anomaly"]].map(([c, l]) => (
                    <span key={l} className="flex items-center gap-1 text-[10px] text-gray-500">
                      <span className="w-2 h-2 rounded-sm inline-block" style={{ background: c }} />{l}
                    </span>
                  ))}
                </div>
              </div>

              {/* Layer radial */}
              <div className={`${card} p-4`}>
                <p className="text-white text-sm mb-1" style={{ fontWeight: 700 }}>Defense Layer Effectiveness</p>
                <p className="text-gray-500 text-xs mb-2">Per-layer threat mitigation rate</p>
                <ResponsiveContainer width="100%" height={120}>
                  <RadialBarChart cx="50%" cy="80%" innerRadius="40%" outerRadius="90%"
                    startAngle={180} endAngle={0} data={layerRadial}>
                    <RadialBar dataKey="value" cornerRadius={6} background={{ fill: "#0A0F1E" }} />
                  </RadialBarChart>
                </ResponsiveContainer>
                <div className="flex justify-center gap-4 -mt-1">
                  {layerRadial.map((d) => (
                    <div key={d.name} className="flex items-center gap-1.5">
                      <span className="w-2 h-2 rounded-full" style={{ background: d.fill }} />
                      <span className="text-[10px] text-gray-400">{d.name}</span>
                      <span className="text-[10px]" style={{ color: d.fill, fontWeight: 700 }}>{d.value}%</span>
                    </div>
                  ))}
                </div>
              </div>

              {/* STRIDE Summary */}
              <div className={`${card} p-4`}>
                <div className="flex items-center justify-between mb-2">
                  <p className="text-white text-sm" style={{ fontWeight: 700 }}>STRIDE Threat Matrix</p>
                  <span className="text-[10px] text-gray-500 bg-white/[0.06] border border-white/10 px-2 py-0.5 rounded-full">
                    {strideMatrix.filter(s => s.status === "Mitigated").length}/{strideMatrix.length} mitigated
                  </span>
                </div>
                <div className="flex gap-3">
                  <div className="flex-1 bg-emerald-900/20 border border-emerald-900/40 rounded-[16px] p-3 text-center">
                    <p className="text-emerald-400 text-lg" style={{ fontWeight: 800 }}>
                      {strideMatrix.filter(s => s.status === "Mitigated").length}
                    </p>
                    <p className="text-gray-500 text-[10px]">Mitigated</p>
                  </div>
                  <div className="flex-1 bg-yellow-900/20 border border-yellow-900/40 rounded-[16px] p-3 text-center">
                    <p className="text-yellow-400 text-lg" style={{ fontWeight: 800 }}>
                      {strideMatrix.filter(s => s.status === "Partial").length}
                    </p>
                    <p className="text-gray-500 text-[10px]">Partial</p>
                  </div>
                  <div className="flex-1 bg-red-900/20 border border-red-900/40 rounded-[16px] p-3 text-center">
                    <p className="text-red-400 text-lg" style={{ fontWeight: 800 }}>0</p>
                    <p className="text-gray-500 text-[10px]">Unmitigated</p>
                  </div>
                </div>
              </div>

              {/* Research context */}
              <div className="glass-tint rounded-[26px] p-4">
                <div className="flex items-center gap-2 mb-2">
                  <Info className="w-4 h-4 text-blue-400" />
                  <p className="text-white text-sm" style={{ fontWeight: 700 }}>Thesis Context</p>
                </div>
                <p className="text-gray-400 text-xs leading-relaxed">
                  This system is the subject of a thesis: <span className="text-blue-300 italic">"A Dual-Layered Security Defense System for NFC-Based Hardware Key Online Banking using CNN-LSTM for Phishing Detection."</span> It combines physical NFC hardware authentication (Layer 1) with a CNN-LSTM ML model for phishing/anomaly detection (Layer 2), targeting &gt;90% accuracy with FPR &lt;5%.
                </p>
              </div>
            </motion.div>
          )}

          {/* ══════════ NFC KEY TAB ══════════ */}
          {subTab === "nfc" && (
            <motion.div key="nfc" initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0 }} className="space-y-3">

              {/* Hardware spec card */}
              <div className={`${card} p-4`}>
                <div className="flex items-center gap-3 mb-3">
                  <div className="w-10 h-10 rounded-[26px] bg-blue-900/40 border border-blue-800/40 flex items-center justify-center">
                    <CreditCard className="w-5 h-5 text-blue-400" />
                  </div>
                  <div>
                    <p className="text-white text-sm" style={{ fontWeight: 700 }}>Feitian FT-JCOS A40CR</p>
                    <p className="text-gray-500 text-xs">Java Card Hardware Secure Element</p>
                  </div>
                </div>
                <div className="grid grid-cols-2 gap-2">
                  {[
                    { label: "Protocol", val: "FIDO2 / CTAP2" },
                    { label: "Crypto", val: "ECDSA P-256" },
                    { label: "NFC Standard", val: "ISO/IEC 14443" },
                    { label: "Frequency", val: "13.56 MHz" },
                    { label: "Range", val: "~4 cm" },
                    { label: "RAM", val: "~4 KB" },
                    { label: "EEPROM", val: "64 KB" },
                    { label: "Certification", val: "CC EAL4+" },
                  ].map((s) => (
                    <div key={s.label} className="bg-white/[0.06] border border-white/10 rounded-[16px] px-3 py-2">
                      <p className="text-gray-600 text-[10px]">{s.label}</p>
                      <p className="text-white text-xs" style={{ fontWeight: 600 }}>{s.val}</p>
                    </div>
                  ))}
                </div>
              </div>

              {/* Security guarantee */}
              <div className={`${card} p-4`}>
                <div className="flex items-center gap-2 mb-2">
                  <Lock className="w-4 h-4 text-blue-400" />
                  <p className="text-white text-sm" style={{ fontWeight: 700 }}>Security Guarantee</p>
                </div>
                <div className="space-y-2">
                  {[
                    { icon: "🔐", text: "Private key is non-exportable and stays inside the Secure Element — forever" },
                    { icon: "🔄", text: "ECDSA P-256 provides 128-bit security (≡ 3072-bit RSA)" },
                    { icon: "✅", text: "Each authentication challenge is unique per session — replay attacks are impossible" },
                    { icon: "📡", text: "~4 cm NFC range prevents remote eavesdropping (ISO/IEC 14443)" },
                  ].map((item, i) => (
                    <div key={i} className="flex items-start gap-2.5 bg-white/[0.06] border border-white/10 rounded-[16px] px-3 py-2.5">
                      <span className="text-base">{item.icon}</span>
                      <p className="text-gray-300 text-xs leading-relaxed">{item.text}</p>
                    </div>
                  ))}
                </div>
              </div>

              {/* Auth flow */}
              <div className={`${card} p-4`}>
                <p className="text-white text-sm mb-3" style={{ fontWeight: 700 }}>Authentication Flow</p>
                <div className="space-y-3">
                  {[
                    { step: "1", title: "App generates challenge", desc: "Server issues a cryptographic nonce (unique per session)", color: "bg-blue-900/50 text-blue-400 border-blue-800/40" },
                    { step: "2", title: "NFC Tap", desc: "User taps Feitian A40CR card — ~4 cm range · ISO/IEC 14443", color: "bg-blue-900/50 text-blue-400 border-blue-800/40" },
                    { step: "3", title: "ECDSA P-256 Sign", desc: "Secure Element signs challenge; private key never leaves card", color: "bg-emerald-900/50 text-emerald-400 border-emerald-800/40" },
                    { step: "4", title: "CNN-LSTM scan", desc: "ML model checks URL/behavior features in &lt;500 ms", color: "bg-emerald-900/50 text-emerald-400 border-emerald-800/40" },
                    { step: "5", title: "Firebase verify", desc: "Backend verifies signature & ML result → transaction approved", color: "bg-violet-900/50 text-violet-400 border-violet-800/40" },
                  ].map((s) => (
                    <div key={s.step} className="flex items-start gap-3">
                      <div className={`w-7 h-7 rounded-full border ${s.color} flex items-center justify-center flex-shrink-0 text-xs`} style={{ fontWeight: 700 }}>
                        {s.step}
                      </div>
                      <div>
                        <p className="text-gray-200 text-xs" style={{ fontWeight: 600 }}>{s.title}</p>
                        <p className="text-gray-500 text-[11px]" dangerouslySetInnerHTML={{ __html: s.desc }} />
                      </div>
                    </div>
                  ))}
                </div>
              </div>

              {/* Key management */}
              <p className="text-gray-500 text-xs px-1 pt-1" style={{ fontWeight: 600 }}>REGISTERED KEYS</p>
              {nfcKeys.map((key) => (
                <motion.div key={key.id} layout className={`${card} overflow-hidden`}>
                  <div onClick={() => setExpandedKey(expandedKey === key.id ? null : key.id)}
                    className="flex items-center gap-3 p-4 cursor-pointer">
                    <div className={`w-12 h-8 rounded-lg flex items-center justify-center ${key.status === "active" ? "btn-liquid" : "bg-white/10"}`}>
                      <CreditCard className="w-5 h-5 text-white" />
                    </div>
                    <div className="flex-1">
                      <div className="flex items-center gap-2">
                        <p className="text-white text-sm" style={{ fontWeight: 600 }}>{key.name}</p>
                        <span className={`text-[10px] px-2 py-0.5 rounded-full border ${key.status === "active" ? "bg-emerald-900/30 border-emerald-800/40 text-emerald-400" : "bg-white/[0.06] border-white/10 text-gray-500"}`} style={{ fontWeight: 600 }}>
                          {key.status}
                        </span>
                      </div>
                      <p className="text-gray-600 text-[11px] font-mono">{key.uid}</p>
                    </div>
                    <div className="flex flex-col items-end gap-1">
                      {key.status === "active" && <SignalBars strength={key.signal} />}
                      {expandedKey === key.id ? <ChevronDown className="w-4 h-4 text-gray-600" /> : <ChevronRight className="w-4 h-4 text-gray-600" />}
                    </div>
                  </div>
                  <AnimatePresence>
                    {expandedKey === key.id && (
                      <motion.div initial={{ height: 0 }} animate={{ height: "auto" }} exit={{ height: 0 }}
                        className="overflow-hidden border-t border-white/10">
                        <div className="p-4 space-y-2">
                          {[
                            { label: "Last Used", val: key.lastUsed, icon: Clock },
                            { label: "Linked Device", val: key.device, icon: Cpu },
                            { label: "Crypto", val: "ECDSA P-256 (128-bit)", icon: Lock },
                            { label: "Signal", val: key.status === "active" ? `${key.signal}%` : "Offline", icon: Wifi },
                          ].map((item) => {
                            const Icon = item.icon;
                            return (
                              <div key={item.label} className="flex items-center justify-between py-1 border-b border-white/10 last:border-0">
                                <div className="flex items-center gap-2"><Icon className="w-3.5 h-3.5 text-gray-600" /><span className="text-gray-500 text-xs">{item.label}</span></div>
                                <span className="text-gray-200 text-xs" style={{ fontWeight: 600 }}>{item.val}</span>
                              </div>
                            );
                          })}
                          <div className="flex gap-2 pt-1">
                            {key.status === "active" ? (
                              <>
                                <button className="flex-1 py-2 bg-red-900/30 border border-red-900/40 text-red-400 rounded-[16px] text-xs" style={{ fontWeight: 600 }}>Revoke</button>
                                <button className="flex-1 py-2 bg-blue-900/30 border border-blue-900/40 text-blue-400 rounded-[16px] text-xs flex items-center justify-center gap-1" style={{ fontWeight: 600 }}>
                                  <RotateCcw className="w-3 h-3" /> Rotate Key
                                </button>
                              </>
                            ) : (
                              <button className="flex-1 py-2 bg-emerald-900/30 border border-emerald-900/40 text-emerald-400 rounded-[16px] text-xs" style={{ fontWeight: 600 }}>Activate</button>
                            )}
                          </div>
                        </div>
                      </motion.div>
                    )}
                  </AnimatePresence>
                </motion.div>
              ))}

              <motion.button whileTap={{ scale: 0.97 }}
                className="w-full py-4 btn-liquid text-white rounded-[26px]"
                style={{ fontWeight: 700, boxShadow: "0 0 24px rgba(37,99,235,0.25)" }}>
                <div className="flex items-center justify-center gap-2"><Key className="w-4 h-4" />Register New NFC Key</div>
              </motion.button>
            </motion.div>
          )}

          {/* ══════════ ML MODEL TAB ══════════ */}
          {subTab === "ml" && (
            <motion.div key="ml" initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0 }} className="space-y-3">

              {/* Model identity */}
              <div className={`${card} p-4`}>
                <div className="flex items-center gap-3 mb-3">
                  <div className="w-10 h-10 rounded-[26px] bg-emerald-900/40 border border-emerald-800/40 flex items-center justify-center">
                    <Brain className="w-5 h-5 text-emerald-400" />
                  </div>
                  <div className="flex-1">
                    <p className="text-white text-sm" style={{ fontWeight: 700 }}>CNN-LSTM Hybrid Model</p>
                    <p className="text-gray-500 text-xs">Phishing URL & behavioral anomaly detection</p>
                  </div>
                  <div className="flex items-center gap-1.5 bg-emerald-900/30 border border-emerald-800/30 rounded-full px-2 py-1">
                    <span className="w-1.5 h-1.5 rounded-full bg-emerald-400 animate-pulse" />
                    <span className="text-emerald-300 text-[10px]" style={{ fontWeight: 600 }}>Live</span>
                  </div>
                </div>
                <p className="text-gray-400 text-xs leading-relaxed">
                  A CNN-LSTM hybrid: <span className="text-blue-300">CNN</span> extracts local lexical URL features; <span className="text-emerald-300">LSTM</span> models sequential transaction/session dependencies. Trained on PhishTank + UCI phishing datasets (80/20 stratified split). Targets &gt;90% accuracy with FPR &lt;5% and end-to-end latency &lt;500 ms.
                </p>
              </div>

              {/* Architecture diagram */}
              <div className={`${card} p-4`}>
                <p className="text-white text-sm mb-3" style={{ fontWeight: 700 }}>Model Architecture</p>
                <div className="flex items-center gap-1 overflow-x-auto pb-1" style={{ scrollbarWidth: "none" }}>
                  {[
                    { label: "Input", sub: "URL / Features", color: "border-gray-700 text-gray-400", icon: Database },
                    { label: "Conv1D", sub: "Local features", color: "border-blue-800 text-blue-400", icon: Layers },
                    { label: "MaxPool", sub: "Downsample", color: "border-blue-800 text-blue-400", icon: Layers },
                    { label: "LSTM", sub: "Sequences", color: "border-emerald-800 text-emerald-400", icon: GitBranch },
                    { label: "Dense", sub: "Classify", color: "border-violet-800 text-violet-400", icon: Cpu },
                    { label: "Output", sub: "Safe / Phish", color: "border-yellow-800 text-yellow-400", icon: Target },
                  ].map((b, i, arr) => {
                    const Icon = b.icon;
                    return (
                      <div key={b.label} className="flex items-center gap-1 flex-shrink-0">
                        <div className={`border ${b.color} rounded-[16px] px-2 py-2 text-center w-14`}>
                          <Icon className={`w-3.5 h-3.5 mx-auto mb-0.5 ${b.color.split(" ")[1]}`} />
                          <p className={`text-[10px] ${b.color.split(" ")[1]}`} style={{ fontWeight: 700 }}>{b.label}</p>
                          <p className="text-gray-600 text-[9px]">{b.sub}</p>
                        </div>
                        {i < arr.length - 1 && <span className="text-gray-700 text-xs">→</span>}
                      </div>
                    );
                  })}
                </div>
              </div>

              {/* Core metrics grid */}
              <div className="grid grid-cols-2 gap-2">
                {[
                  { label: "Accuracy", val: "94.7%", icon: Target, color: "text-blue-400", bg: "bg-blue-900/20 border-blue-900/40", source: "Primary target: >90%" },
                  { label: "Precision", val: "93.2%", icon: Award, color: "text-emerald-400", bg: "bg-emerald-900/20 border-emerald-900/40", source: "PhishTank + UCI" },
                  { label: "Recall", val: "95.1%", icon: Activity, color: "text-violet-400", bg: "bg-violet-900/20 border-violet-900/40", source: "FPR < 5% target" },
                  { label: "F1 Score", val: "94.1%", icon: BarChart2, color: "text-orange-400", bg: "bg-orange-900/20 border-orange-900/40", source: "Harmonic mean" },
                ].map((m) => {
                  const Icon = m.icon;
                  return (
                    <div key={m.label} className={`${m.bg} border rounded-[26px] p-4`}>
                      <Icon className={`w-4 h-4 ${m.color} mb-2`} />
                      <p className={`text-xl ${m.color}`} style={{ fontWeight: 800 }}>{m.val}</p>
                      <p className="text-gray-300 text-xs" style={{ fontWeight: 600 }}>{m.label}</p>
                      <p className="text-gray-600 text-[10px] mt-0.5">{m.source}</p>
                    </div>
                  );
                })}
              </div>

              {/* AUC-ROC + latency */}
              <div className="grid grid-cols-3 gap-2">
                {[
                  { label: "AUC-ROC", val: "96.3%", icon: TrendingUp, color: "text-cyan-400" },
                  { label: "Latency", val: "<500ms", icon: Zap, color: "text-yellow-400" },
                  { label: "Features", val: "42+", icon: Eye, color: "text-pink-400" },
                ].map((s) => {
                  const Icon = s.icon;
                  return (
                    <div key={s.label} className={`${card} p-3 text-center`}>
                      <Icon className={`w-4 h-4 ${s.color} mx-auto mb-1`} />
                      <p className={`text-sm ${s.color}`} style={{ fontWeight: 800 }}>{s.val}</p>
                      <p className="text-gray-600 text-[10px]">{s.label}</p>
                    </div>
                  );
                })}
              </div>

              {/* Radar chart */}
              <div className={`${card} p-4`}>
                <p className="text-white text-sm mb-3" style={{ fontWeight: 700 }}>Performance Radar</p>
                <ResponsiveContainer width="100%" height={190}>
                  <RadarChart data={mlMetrics}>
                    <PolarGrid stroke="#1a2744" />
                    <PolarAngleAxis dataKey="subject" tick={{ fill: "#6B7280", fontSize: 10 }} />
                    <Radar dataKey="value" stroke="#059669" fill="#059669" fillOpacity={0.12} strokeWidth={2} dot={{ r: 3, fill: "#059669" }} />
                    <Tooltip formatter={(v: any) => [`${v}%`, "Score"]}
                      contentStyle={{ background: "#0c1530", border: "1px solid #1a2744", borderRadius: 12, fontSize: 11, color: "#E5E7EB" }} />
                  </RadarChart>
                </ResponsiveContainer>
              </div>

              {/* vs. baselines */}
              <div className={`${card} p-4`}>
                <p className="text-white text-sm mb-1" style={{ fontWeight: 700 }}>CNN-LSTM vs. Baselines</p>
                <p className="text-gray-500 text-xs mb-3">Based on Gurung et al. (2023) comparison</p>
                <div className="space-y-2.5">
                  {modelComparison.map((m, i) => (
                    <div key={m.model}>
                      <div className="flex items-center justify-between mb-1">
                        <span className="text-gray-400 text-xs">{m.model}</span>
                        <span className="text-xs" style={{ color: m.color, fontWeight: 700 }}>{m.accuracy}%</span>
                      </div>
                      <div className="h-2 bg-white/[0.06] rounded-full overflow-hidden border border-white/10">
                        <motion.div initial={{ width: 0 }} animate={{ width: `${m.accuracy}%` }}
                          transition={{ delay: 0.2 + i * 0.1, duration: 0.7 }}
                          className="h-full rounded-full" style={{ background: m.color }} />
                      </div>
                    </div>
                  ))}
                </div>
              </div>

              {/* Top features */}
              <div className={`${card} p-4`}>
                <p className="text-white text-sm mb-1" style={{ fontWeight: 700 }}>Top Detection Features</p>
                <p className="text-gray-500 text-xs mb-3">What the model weights most heavily</p>
                <div className="space-y-2.5">
                  {features.map((f, i) => (
                    <div key={f.name}>
                      <div className="flex items-center justify-between mb-1">
                        <span className="text-gray-400 text-xs">{f.name}</span>
                        <span className="text-gray-200 text-xs" style={{ fontWeight: 700 }}>{f.val}%</span>
                      </div>
                      <div className="h-1.5 bg-white/[0.06] rounded-full overflow-hidden border border-white/10">
                        <motion.div initial={{ width: 0 }} animate={{ width: `${f.val}%` }}
                          transition={{ delay: 0.3 + i * 0.08, duration: 0.6 }}
                          className="h-full rounded-full"
                          style={{ background: `hsl(${200 + i * 22}, 70%, ${50 - i * 2}%)` }} />
                      </div>
                    </div>
                  ))}
                </div>
              </div>

              {/* Dataset info */}
              <div className={`${card} p-4`}>
                <div className="flex items-center gap-2 mb-3">
                  <Database className="w-4 h-4 text-blue-400" />
                  <p className="text-white text-sm" style={{ fontWeight: 700 }}>Training Datasets</p>
                </div>
                <div className="space-y-2">
                  {[
                    { name: "PhishTank", desc: "Community-verified phishing URLs", tag: "Primary", color: "bg-blue-900/30 border-blue-900/40 text-blue-400" },
                    { name: "UCI Phishing Dataset", desc: "Machine learning benchmark (phishing URLs)", tag: "Primary", color: "bg-blue-900/30 border-blue-900/40 text-blue-400" },
                  ].map((d) => (
                    <div key={d.name} className="flex items-center gap-3 bg-white/[0.06] border border-white/10 rounded-[16px] px-3 py-2.5">
                      <div className="flex-1">
                        <p className="text-white text-xs" style={{ fontWeight: 600 }}>{d.name}</p>
                        <p className="text-gray-500 text-[11px]">{d.desc}</p>
                      </div>
                      <span className={`text-[10px] px-2 py-0.5 rounded-full border ${d.color}`} style={{ fontWeight: 600 }}>{d.tag}</span>
                    </div>
                  ))}
                </div>
                <div className="grid grid-cols-3 gap-2 mt-3">
                  {[
                    { label: "Split", val: "80 / 20" },
                    { label: "Strategy", val: "Stratified" },
                    { label: "Test runs", val: "30+" },
                  ].map((s) => (
                    <div key={s.label} className="bg-white/[0.06] border border-white/10 rounded-[16px] p-2 text-center">
                      <p className="text-white text-xs" style={{ fontWeight: 700 }}>{s.val}</p>
                      <p className="text-gray-600 text-[10px]">{s.label}</p>
                    </div>
                  ))}
                </div>
              </div>

              {/* STRIDE full table */}
              <div className={`${card} overflow-hidden`}>
                <div className="flex items-center justify-between p-4 pb-2">
                  <p className="text-white text-sm" style={{ fontWeight: 700 }}>STRIDE Threat Resistance</p>
                  <span className="text-gray-500 text-[10px]">Table 3.1 from paper</span>
                </div>
                <p className="text-gray-600 text-xs px-4 pb-3">Tap any row to view mitigation detail</p>
                {strideMatrix.map((s, i) => (
                  <div key={i}>
                    <div onClick={() => setExpandedStride(expandedStride === i ? null : i)}
                      className="flex items-center gap-3 px-4 py-3 border-b border-white/10 last:border-0 cursor-pointer hover:bg-white/[0.02]">
                      <div className={`w-2 h-2 rounded-full flex-shrink-0 ${s.status === "Mitigated" ? "bg-emerald-500" : "bg-yellow-500"}`} />
                      <div className="flex-1 min-w-0">
                        <div className="flex items-center gap-2">
                          <span className="text-[10px] text-gray-500 bg-white/[0.06] border border-white/10 px-1.5 py-0.5 rounded">{s.threat}</span>
                          <span className="text-[10px] text-gray-600">{s.layer}</span>
                        </div>
                        <p className="text-gray-300 text-xs mt-0.5 truncate" style={{ fontWeight: 500 }}>{s.vector}</p>
                      </div>
                      <span className={`text-[10px] px-2 py-0.5 rounded-full flex-shrink-0 ${s.status === "Mitigated" ? "bg-emerald-900/40 border border-emerald-900/40 text-emerald-400" : "bg-yellow-900/40 border border-yellow-900/40 text-yellow-400"}`}
                        style={{ fontWeight: 600 }}>
                        {s.status}
                      </span>
                    </div>
                    <AnimatePresence>
                      {expandedStride === i && (
                        <motion.div initial={{ height: 0 }} animate={{ height: "auto" }} exit={{ height: 0 }}
                          className="overflow-hidden bg-white/[0.06] border-b border-white/10">
                          <div className="px-4 py-3 flex items-start gap-2">
                            <Info className="w-3.5 h-3.5 text-gray-500 flex-shrink-0 mt-0.5" />
                            <p className="text-gray-400 text-xs leading-relaxed">{s.note}</p>
                          </div>
                        </motion.div>
                      )}
                    </AnimatePresence>
                  </div>
                ))}
              </div>

              {/* Thesis target summary */}
              <div className="glass-tint rounded-[26px] p-4">
                <div className="flex items-center gap-2 mb-3">
                  <Award className="w-4 h-4 text-yellow-400" />
                  <p className="text-white text-sm" style={{ fontWeight: 700 }}>Thesis Research Targets</p>
                </div>
                <div className="space-y-2">
                  {[
                    { label: "ML Accuracy", target: "> 90%", achieved: "94.7%", met: true },
                    { label: "False Positive Rate", target: "< 5%", achieved: "~4.9%", met: true },
                    { label: "End-to-end Latency", target: "< 500 ms", achieved: "< 500 ms", met: true },
                    { label: "SUS Usability Score", target: "≥ 68", achieved: "Pending (10–15 participants)", met: null },
                  ].map((r) => (
                    <div key={r.label} className="flex items-center justify-between bg-white/[0.05] rounded-[16px] px-3 py-2.5">
                      <div>
                        <p className="text-gray-200 text-xs" style={{ fontWeight: 600 }}>{r.label}</p>
                        <p className="text-gray-600 text-[10px]">Target: {r.target}</p>
                      </div>
                      <div className="flex items-center gap-1.5">
                        <span className="text-gray-300 text-xs" style={{ fontWeight: 600 }}>{r.achieved}</span>
                        {r.met === true && <CheckCircle className="w-3.5 h-3.5 text-emerald-400" />}
                        {r.met === null && <Clock className="w-3.5 h-3.5 text-yellow-400" />}
                      </div>
                    </div>
                  ))}
                </div>
              </div>

              {/* Last updated */}
              <div className={`flex items-center gap-3 ${card} p-4`}>
                <RotateCcw className="w-5 h-5 text-gray-600" />
                <div className="flex-1">
                  <p className="text-gray-200 text-sm" style={{ fontWeight: 600 }}>Model Last Retrained</p>
                  <p className="text-gray-600 text-xs">April 2025 · PhishTank + UCI datasets · 80/20 stratified split</p>
                </div>
                <span className="text-emerald-400 text-xs bg-emerald-900/30 border border-emerald-900/40 px-2 py-1 rounded-lg" style={{ fontWeight: 600 }}>Current</span>
              </div>
            </motion.div>
          )}
        </AnimatePresence>
      </div>
    </div>
  );
}
