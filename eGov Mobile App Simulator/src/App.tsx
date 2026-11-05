import { useState, useEffect, useCallback } from "react"

// ─── Types ────────────────────────────────────────────────────────────────────
type Step =
  | "idle"
  | "bank-transfer"
  | "deeplink"
  | "egov-notify"
  | "egov-review"
  | "egov-liveness"
  | "egov-verifying"
  | "egov-success"
  | "bank-done"

const SEQ: Step[] = [
  "idle",
  "bank-transfer",
  "deeplink",
  "egov-notify",
  "egov-review",
  "egov-liveness",
  "egov-verifying",
  "egov-success",
  "bank-done",
]

// ─── Mock data ────────────────────────────────────────────────────────────────
const TX = {
  amount: "₱10,000.00",
  recipient: "Jane Doe",
  acct: "BDO ****-9921",
  hash: "0x8f2a7b3c…d391c",
  block: "849,201",
  ts: "Jul 21, 2026 · 2:14 PM",
  ip: "112.198.xxx.xxx",
  loc: "Quezon City, NCR",
}

const USER = {
  name: "Juan Santos Dela Cruz",
  id: "PSN-0042-8819-3301",
  img: "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=80&h=80&fit=crop&auto=format",
  balance: "₱47,820.00",
}

// ─── Phone Frame ──────────────────────────────────────────────────────────────
function PhoneFrame({ children, glowColor }: { children: React.ReactNode; glowColor: string }) {
  return (
    <div className="relative flex-shrink-0" style={{ width: 296, height: 616 }}>
      <div
        className="absolute inset-0 rounded-[44px]"
        style={{
          background: "linear-gradient(160deg, #2e2e32 0%, #1a1a1e 100%)",
          boxShadow: `0 0 0 1.5px rgba(255,255,255,0.11), 0 40px 90px rgba(0,0,0,0.75), 0 0 70px ${glowColor}38`,
          padding: 9,
        }}
      >
        <div className="w-full h-full rounded-[36px] overflow-hidden relative bg-white">
          {/* Notch */}
          <div className="absolute top-0 left-1/2 -translate-x-1/2 w-24 h-[22px] bg-[#1a1a1e] rounded-b-[14px] z-[100]" />
          {/* Status bar */}
          <div className="absolute top-0 left-0 right-0 h-[22px] z-[90] flex items-center justify-between px-5">
            <span className="text-[8px] font-semibold opacity-50">9:41</span>
            <span className="text-[8px] font-semibold opacity-50">●●● ▮</span>
          </div>
          {/* Content */}
          <div className="absolute inset-0 top-[22px] overflow-hidden">{children}</div>
        </div>
      </div>
      {/* Buttons */}
      <div className="absolute right-[-2px] top-24 w-[3px] h-14 bg-[#252528] rounded-r-sm" />
      <div className="absolute left-[-2px] top-20 w-[3px] h-8 bg-[#252528] rounded-l-sm" />
      <div className="absolute left-[-2px] top-32 w-[3px] h-14 bg-[#252528] rounded-l-sm" />
    </div>
  )
}

// ─── Bank App ─────────────────────────────────────────────────────────────────
function BankApp({ step, onNext }: { step: Step; onNext: () => void }) {
  if (step === "bank-done") return <BankAuthorized onNext={onNext} />
  if (step === "deeplink") return <BankConnecting />
  if (["egov-notify", "egov-review", "egov-liveness", "egov-verifying", "egov-success"].includes(step))
    return <BankWaiting step={step} />
  return <BankDashboard showTransfer={step === "bank-transfer"} onNext={onNext} />
}

function BankDashboard({ showTransfer, onNext }: { showTransfer: boolean; onNext: () => void }) {
  const [transfer, setTransfer] = useState(showTransfer)
  useEffect(() => { if (showTransfer) setTransfer(true) }, [showTransfer])

  return (
    <div className="h-full flex flex-col bg-white">
      {/* Header */}
      <div style={{ background: "linear-gradient(135deg, #005DA6 0%, #0082CC 100%)" }} className="px-4 pt-3 pb-5">
        <div className="flex items-center justify-between mb-3">
          <div>
            <div className="flex items-center gap-1.5">
              <div className="w-5 h-5 rounded-md bg-white/20 flex items-center justify-center">
                <svg viewBox="0 0 20 20" fill="white" className="w-3 h-3">
                  <path d="M10 1L2 5v2h16V5L10 1zm-7 8v5h2v-5H3zm4 0v5h2v-5H7zm4 0v5h2v-5h-2zm4 0v5h2v-5h-2zM2 17h16v2H2v-2z" />
                </svg>
              </div>
              <span className="text-white font-black text-sm tracking-widest">TAPAT</span>
            </div>
            <p className="text-white/60 text-[9px] mt-0.5">Good afternoon, Juan</p>
          </div>
          <div className="w-8 h-8 rounded-full overflow-hidden border-2 border-white/30">
            <img src={USER.img} alt="Profile" className="w-full h-full object-cover" />
          </div>
        </div>
        {/* Balance */}
        <div
          className="rounded-2xl p-3"
          style={{
            background: "rgba(255,255,255,0.13)",
            backdropFilter: "blur(12px)",
            border: "1px solid rgba(255,255,255,0.2)",
          }}
        >
          <p className="text-white/60 text-[9px] uppercase tracking-widest">Available Balance</p>
          <p className="text-white font-black text-xl mt-0.5">{USER.balance}</p>
          <p className="text-white/50 text-[8px] mt-0.5">Acct: **** **** 4821 · Savings</p>
        </div>
      </div>

      {/* Quick actions */}
      <div className="px-4 py-2.5 flex gap-2">
        {[
          { icon: "↑", label: "Send", color: "#005DA6", action: () => setTransfer(true) },
          { icon: "↓", label: "Receive", color: "#0082CC", action: undefined },
          { icon: "⊞", label: "QR Pay", color: "#006B9F", action: undefined },
          { icon: "⋯", label: "More", color: "#7A9DB8", action: undefined },
        ].map((a) => (
          <button key={a.label} onClick={a.action} className="flex-1 flex flex-col items-center gap-1">
            <div
              className="w-9 h-9 rounded-full flex items-center justify-center text-white font-bold text-sm"
              style={{ background: a.color }}
            >
              {a.icon}
            </div>
            <span className="text-[8px] text-gray-500">{a.label}</span>
          </button>
        ))}
      </div>

      {/* Body */}
      <div className="flex-1 overflow-y-auto px-4 pb-2">
        {transfer ? (
          <div style={{ animation: "fadeInUp 0.3s ease-out" }}>
            <p className="text-[10px] font-bold text-gray-600 mb-2.5">New Transfer</p>
            <div className="space-y-2">
              {[
                { label: "Recipient", value: "Jane Doe · BDO ****9921" },
                { label: "Amount", value: "₱ 10,000.00", bold: true },
                { label: "Note", value: "Payment for services", muted: true },
              ].map((f) => (
                <div key={f.label}>
                  <p className="text-[8px] text-gray-400 uppercase tracking-widest">{f.label}</p>
                  <div
                    className={`mt-0.5 border border-gray-200 rounded-xl px-3 py-2 text-[11px] ${f.bold ? "font-bold text-gray-800" : f.muted ? "text-gray-400" : "text-gray-700"}`}
                  >
                    {f.value}
                  </div>
                </div>
              ))}
            </div>
            <button
              onClick={onNext}
              className="mt-4 w-full py-3 rounded-2xl text-white text-[11px] font-bold flex items-center justify-center gap-2"
              style={{
                background: "linear-gradient(135deg, #003087 0%, #1B5FC1 100%)",
                boxShadow: "0 4px 20px rgba(0,48,135,0.35)",
              }}
            >
              <svg viewBox="0 0 24 24" fill="white" className="w-3.5 h-3.5">
                <path d="M12 1L3 5v6c0 5.55 3.84 10.74 9 12 5.16-1.26 9-6.45 9-12V5l-9-4z" />
              </svg>
              Authenticate with eGovPH
            </button>
            <p className="text-center text-[8px] text-gray-400 mt-1.5">
              Secured via eGovPH SSO · Face Liveness
            </p>
          </div>
        ) : (
          <>
            <p className="text-[8px] font-semibold text-gray-400 uppercase tracking-widest mb-2">Recent Transactions</p>
            {[
              { name: "Grab Philippines", amt: "-₱450.00", time: "11:32 AM", icon: "🛵" },
              { name: "Juan Miguel Reyes", amt: "+₱2,000.00", time: "Yesterday", icon: "👤" },
              { name: "Meralco", amt: "-₱1,890.00", time: "Jul 18", icon: "⚡" },
              { name: "Globe Telecom", amt: "-₱599.00", time: "Jul 16", icon: "📱" },
            ].map((t) => (
              <div key={t.name} className="flex items-center gap-2.5 py-2 border-b border-gray-50">
                <div className="w-8 h-8 rounded-full bg-gray-100 flex items-center justify-center text-xs shrink-0">
                  {t.icon}
                </div>
                <div className="flex-1 min-w-0">
                  <p className="text-[10px] font-medium text-gray-800 truncate">{t.name}</p>
                  <p className="text-[8px] text-gray-400">{t.time}</p>
                </div>
                <p className={`text-[10px] font-semibold shrink-0 ${t.amt.startsWith("+") ? "text-green-600" : "text-gray-700"}`}>
                  {t.amt}
                </p>
              </div>
            ))}
            <button
              onClick={() => setTransfer(true)}
              className="mt-3 w-full py-2.5 rounded-xl text-white text-[11px] font-semibold"
              style={{ background: "linear-gradient(135deg, #005DA6, #0082CC)" }}
            >
              + New Transfer
            </button>
          </>
        )}
      </div>

      {/* Bottom nav */}
      <div className="flex items-center justify-around px-4 py-2 border-t border-gray-100">
        {["🏠", "📊", "💳", "👤"].map((icon, i) => (
          <button key={i} className={`p-2 ${i === 0 ? "opacity-100" : "opacity-35"}`}>
            <span className="text-base">{icon}</span>
          </button>
        ))}
      </div>
    </div>
  )
}

function BankConnecting() {
  return (
    <div className="h-full flex flex-col items-center justify-center bg-white px-8">
      <div
        className="w-16 h-16 rounded-2xl flex items-center justify-center mb-4"
        style={{
          background: "linear-gradient(135deg, #003087 0%, #1B5FC1 100%)",
          animation: "glowPulse 1.5s ease-in-out infinite",
          boxShadow: "0 0 30px rgba(0,48,135,0.4)",
        }}
      >
        <svg viewBox="0 0 24 24" fill="white" className="w-8 h-8">
          <path d="M12 1L3 5v6c0 5.55 3.84 10.74 9 12 5.16-1.26 9-6.45 9-12V5l-9-4z" />
        </svg>
      </div>
      <p className="text-sm font-bold text-gray-800 text-center">Connecting to eGovPH</p>
      <p className="text-[10px] text-gray-400 mt-1 text-center">Initiating SSO handshake…</p>
      <div className="flex gap-1.5 mt-4">
        {[0, 1, 2].map((i) => (
          <div
            key={i}
            className="w-2 h-2 rounded-full bg-blue-600"
            style={{ animation: `bounceDot 0.9s ease-in-out ${i * 0.18}s infinite` }}
          />
        ))}
      </div>
      <div
        className="mt-5 px-4 py-2 rounded-lg text-center"
        style={{ background: "rgba(0,48,135,0.06)", border: "1px solid rgba(0,48,135,0.12)" }}
      >
        <p className="text-[8px] font-mono text-blue-700">tapatan://auth?client=tapatan</p>
        <p className="text-[7px] text-gray-400 mt-0.5">↓ deep-linking to egovph://</p>
      </div>
    </div>
  )
}

function BankWaiting({ step }: { step: Step }) {
  const serviceStatus: Record<string, string> = {
    "egov-notify": "waiting",
    "egov-review": "active",
    "egov-liveness": "active",
    "egov-verifying": "active",
    "egov-success": "completing",
  }
  const services = [
    { name: "eGovPH SSO", active: true },
    { name: "eVerify", active: ["egov-review", "egov-liveness", "egov-verifying", "egov-success"].includes(step) },
    { name: "Face Liveness", active: ["egov-liveness", "egov-verifying", "egov-success"].includes(step) },
    { name: "eGovChain", active: step === "egov-success" },
  ]
  return (
    <div className="h-full flex flex-col items-center justify-center bg-[#F7FAFF] px-6">
      <div
        className="w-12 h-12 rounded-full border-2 border-blue-200 border-t-blue-600 mb-4"
        style={{ animation: "spinSlow 1s linear infinite" }}
      />
      <p className="text-sm font-bold text-gray-700 text-center">Awaiting eGovPH</p>
      <p className="text-[10px] text-gray-400 mt-1 text-center">
        {serviceStatus[step] === "completing" ? "Signing transaction on chain…" : "Biometric verification in progress…"}
      </p>
      <div className="mt-5 w-full space-y-1.5">
        {services.map((s) => (
          <div
            key={s.name}
            className="flex items-center justify-between px-3 py-2 rounded-xl"
            style={{ background: s.active ? "rgba(0,93,166,0.06)" : "#fff", border: "1px solid rgba(0,0,0,0.06)" }}
          >
            <span className="text-[9px] font-medium text-gray-600">{s.name}</span>
            <span
              className="text-[8px] font-bold"
              style={{ color: s.active ? "#16A34A" : "#9CA3AF" }}
            >
              {s.active ? "● active" : "○ waiting"}
            </span>
          </div>
        ))}
      </div>
    </div>
  )
}

function BankAuthorized({ onNext }: { onNext: () => void }) {
  return (
    <div className="h-full flex flex-col bg-white" style={{ animation: "fadeInUp 0.4s ease-out" }}>
      <div
        className="px-4 pt-3 pb-5"
        style={{ background: "linear-gradient(135deg, #16A34A 0%, #22C55E 100%)" }}
      >
        <p className="text-white/70 text-[9px] uppercase tracking-widest">Transaction</p>
        <p className="text-white font-black text-base mt-0.5">Transfer Authorized ✓</p>
        <div className="flex items-center gap-1.5 mt-1">
          <div className="w-1.5 h-1.5 rounded-full bg-white/60" />
          <span className="text-white/70 text-[9px]">eGovPH biometric signature verified</span>
        </div>
      </div>
      <div className="flex-1 overflow-y-auto px-4 py-4 space-y-3">
        <div
          className="rounded-2xl p-4"
          style={{
            background: "linear-gradient(135deg, #ECFDF5 0%, #F0FFF4 100%)",
            border: "1px solid #A7F3D0",
          }}
        >
          <div className="flex items-center gap-3 mb-3">
            <div
              className="w-9 h-9 rounded-full bg-green-500 flex items-center justify-center"
              style={{ animation: "pulseRing 2s ease-in-out infinite" }}
            >
              <svg viewBox="0 0 24 24" fill="none" stroke="white" strokeWidth="2.5" className="w-5 h-5">
                <polyline points="20 6 9 17 4 12" />
              </svg>
            </div>
            <div>
              <p className="text-xs font-bold text-green-800">Verified by eGovPH</p>
              <p className="text-[8px] text-green-600">Face Liveness + PhilSys eVerify</p>
            </div>
          </div>
          {[
            { k: "Amount", v: TX.amount, bold: true },
            { k: "Recipient", v: TX.recipient },
            { k: "Account", v: TX.acct },
            { k: "Auth Method", v: "Face Liveness", green: true },
          ].map((r) => (
            <div key={r.k} className="flex justify-between py-1.5 border-b border-green-50 last:border-0">
              <span className="text-[9px] text-gray-500">{r.k}</span>
              <span
                className={`text-[9px] ${r.bold ? "font-bold text-gray-800" : r.green ? "font-semibold text-green-700" : "text-gray-600"}`}
              >
                {r.v}
              </span>
            </div>
          ))}
        </div>
        <div
          className="rounded-xl p-3"
          style={{ background: "#080E1C", border: "1px solid rgba(99,102,241,0.3)" }}
        >
          <p className="text-[8px] text-indigo-400 font-semibold uppercase tracking-widest mb-1.5">
            eGovChain Anchor
          </p>
          <p className="text-[8px] text-gray-300 font-mono">Hash: {TX.hash}</p>
          <p className="text-[8px] text-gray-500 font-mono mt-0.5">Block: #{TX.block}</p>
        </div>
        <button
          onClick={onNext}
          className="w-full py-3 rounded-2xl text-white text-[11px] font-bold"
          style={{ background: "linear-gradient(135deg, #005DA6, #0082CC)" }}
        >
          Return to Dashboard
        </button>
      </div>
    </div>
  )
}

// ─── eGov App ─────────────────────────────────────────────────────────────────
function EGovApp({ step, onNext }: { step: Step; onNext: () => void }) {
  if (step === "egov-notify") return <EGovDashboardWithNotif onNext={onNext} />
  if (step === "egov-review") return <EGovReview onNext={onNext} />
  if (step === "egov-liveness" || step === "egov-verifying") return <EGovLiveness step={step} />
  if (step === "egov-success") return <EGovSuccess onNext={onNext} />
  return <EGovDashboard showLastAuth={step === "bank-done"} />
}

function EGovDashboard({ showLastAuth = false }: { showLastAuth?: boolean }) {
  return (
    <div className="h-full flex flex-col" style={{ background: "#FAFBFF" }}>
      <div
        style={{ background: "linear-gradient(135deg, #003087 0%, #1B5FC1 100%)" }}
        className="px-4 pt-2.5 pb-3"
      >
        <div className="flex items-center justify-between">
          <div>
            <div className="flex items-center gap-1.5">
              <div
                className="w-5 h-5 rounded flex items-center justify-center"
                style={{ background: "#FFD700" }}
              >
                <span className="text-[7px] font-black text-blue-900">PH</span>
              </div>
              <span className="text-white font-black text-xs tracking-widest">eGovPH</span>
            </div>
            <p className="text-white/50 text-[8px] mt-0.5">Bagong Pilipinas Digital ID</p>
          </div>
          <div className="w-7 h-7 rounded-full overflow-hidden border-2 border-white/30">
            <img src={USER.img} alt="" className="w-full h-full object-cover" />
          </div>
        </div>
      </div>

      {/* Digital ID Card */}
      <div className="px-3 pt-2.5">
        <div
          className="rounded-2xl p-3.5"
          style={{
            background: "linear-gradient(140deg, #002E7D 0%, #1A5DC5 60%, #0055AA 100%)",
            boxShadow: "0 8px 28px rgba(0,46,125,0.4)",
          }}
        >
          {/* Decorative pattern */}
          <div className="flex items-start gap-3">
            <div className="w-11 h-13 rounded-lg overflow-hidden border-2 border-white/25 shrink-0" style={{ height: 52 }}>
              <img src={USER.img} alt="ID" className="w-full h-full object-cover" />
            </div>
            <div className="flex-1 min-w-0">
              <p className="text-[7px] font-black text-[#FFD700] tracking-widest uppercase mb-0.5">
                Philippine National ID
              </p>
              <p className="text-white font-bold text-[10px] leading-snug">{USER.name}</p>
              <p className="text-white/50 text-[8px] mt-0.5 font-mono">{USER.id}</p>
            </div>
          </div>
          <div
            className="mt-2.5 inline-flex items-center gap-1.5 px-2 py-1 rounded-lg"
            style={{
              background: "rgba(22,163,74,0.22)",
              border: "1px solid rgba(134,239,172,0.35)",
            }}
          >
            <svg viewBox="0 0 24 24" fill="#86EFAC" className="w-3 h-3">
              <path d="M12 1L3 5v6c0 5.55 3.84 10.74 9 12 5.16-1.26 9-6.45 9-12V5l-9-4z" />
            </svg>
            <span className="text-[8px] font-bold text-green-300">Verified for Transactions</span>
          </div>
        </div>
      </div>

      {/* Activity */}
      <div className="flex-1 overflow-y-auto px-3 pt-3">
        <p className="text-[8px] font-semibold text-gray-400 uppercase tracking-widest mb-2">
          {showLastAuth ? "Latest Activity" : "Recent Auth Activity"}
        </p>
        {showLastAuth && (
          <div
            className="mb-2 px-3 py-2 rounded-xl"
            style={{ background: "#ECFDF5", border: "1px solid #A7F3D0", animation: "fadeInUp 0.4s ease-out" }}
          >
            <p className="text-[9px] font-bold text-green-700">✓ Tapat Bank — Transfer Signed</p>
            <p className="text-[8px] text-green-600 mt-0.5">{TX.amount} · eGovChain anchored · Just now</p>
          </div>
        )}
        {[
          { app: "SSS Online", action: "Identity Verified", time: "Jul 20, 3:12 PM", icon: "🏛️" },
          { app: "PhilHealth iConsult", action: "Signed Consent Form", time: "Jul 19, 9:45 AM", icon: "🏥" },
          { app: "LTO Online", action: "License Renewal Auth", time: "Jul 15, 2:00 PM", icon: "🚗" },
        ].map((a) => (
          <div key={a.app} className="flex items-start gap-2.5 py-2 border-b border-gray-100">
            <span className="text-sm shrink-0">{a.icon}</span>
            <div>
              <p className="text-[9px] font-medium text-gray-700">{a.app}</p>
              <p className="text-[8px] text-gray-400">{a.action} · {a.time}</p>
            </div>
          </div>
        ))}
      </div>

      {/* Bottom nav */}
      <div className="flex items-center justify-around px-2 py-2 border-t border-gray-100">
        {[
          { icon: "🏠", label: "Home", active: true },
          { icon: "📰", label: "News", active: false },
          { icon: "🪪", label: "Mobile ID", active: false },
          { icon: "📷", label: "Scan QR", active: false },
          { icon: "👤", label: "Account", active: false },
        ].map((n) => (
          <button key={n.label} className="flex flex-col items-center gap-0.5">
            <span className={`text-sm ${n.active ? "opacity-100" : "opacity-30"}`}>{n.icon}</span>
            <span
              className={`text-[6px] ${n.active ? "font-bold text-blue-700" : "text-gray-400"}`}
            >
              {n.label}
            </span>
          </button>
        ))}
      </div>
    </div>
  )
}

function EGovDashboardWithNotif({ onNext }: { onNext: () => void }) {
  return (
    <div className="h-full relative">
      <EGovDashboard />
      <button
        onClick={onNext}
        className="absolute top-1 left-2 right-2 z-50 rounded-2xl p-3 text-left"
        style={{
          background: "rgba(12,18,40,0.93)",
          backdropFilter: "blur(20px)",
          border: "1px solid rgba(255,215,0,0.25)",
          boxShadow: "0 8px 32px rgba(0,0,0,0.5)",
          animation: "slideDown 0.45s cubic-bezier(0.34,1.56,0.64,1) forwards",
        }}
      >
        <div className="flex items-start gap-2.5">
          <div
            className="w-8 h-8 rounded-xl flex items-center justify-center shrink-0"
            style={{ background: "#003087" }}
          >
            <span className="text-[8px] font-black text-[#FFD700]">PH</span>
          </div>
          <div className="flex-1 min-w-0">
            <div className="flex justify-between items-center">
              <span className="text-[9px] font-bold text-white">eGovPH Security Alert</span>
              <span className="text-[7px] text-gray-400">now</span>
            </div>
            <p className="text-[8px] text-gray-300 mt-0.5 leading-relaxed">
              <span className="text-yellow-400 font-semibold">Action Required:</span> Tapat Bank
              is requesting authorization for a{" "}
              <span className="text-white font-semibold">{TX.amount}</span> transfer. Tap to
              review.
            </p>
          </div>
        </div>
        <p className="text-right text-[7px] text-blue-400 mt-1.5">Tap to Review →</p>
      </button>
    </div>
  )
}

function EGovReview({ onNext }: { onNext: () => void }) {
  const [open, setOpen] = useState(false)
  return (
    <div className="h-full flex flex-col" style={{ background: "#FAFBFF", animation: "fadeInUp 0.3s ease-out" }}>
      <div
        className="px-4 pt-2.5 pb-3 flex items-center gap-2"
        style={{ background: "linear-gradient(135deg, #003087 0%, #1B5FC1 100%)" }}
      >
        <svg viewBox="0 0 24 24" fill="none" stroke="white" strokeWidth="2" className="w-4 h-4 shrink-0">
          <path d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z" />
        </svg>
        <div>
          <p className="text-white font-bold text-sm">Review Transaction</p>
          <p className="text-white/50 text-[8px]">Confirm before signing</p>
        </div>
      </div>

      <div className="flex-1 overflow-y-auto px-3 py-3 space-y-2.5">
        {/* eGovAI Card */}
        <div
          className="rounded-2xl p-3"
          style={{
            background: "rgba(10,14,36,0.97)",
            border: "1px solid rgba(139,92,246,0.45)",
            boxShadow: "0 0 24px rgba(139,92,246,0.14), 0 0 50px rgba(59,130,246,0.07)",
          }}
        >
          <div className="flex items-center gap-1.5 mb-2">
            <div
              className="w-4 h-4 rounded flex items-center justify-center text-[8px] text-white font-bold"
              style={{ background: "linear-gradient(135deg, #8B5CF6, #6366F1)" }}
            >
              ✦
            </div>
            <span className="text-[9px] font-bold text-purple-300">eGovAI Security Summary</span>
          </div>
          <p className="text-[9px] text-gray-300 leading-relaxed">
            You are about to authorize a transfer of{" "}
            <span className="text-white font-bold">{TX.amount}</span> to{" "}
            <span className="text-white font-bold">{TX.recipient}</span> via Tapat Bank.{" "}
            <span className="text-green-400 font-semibold">No anomalies detected.</span> Location
            and IP match your typical behavior.
          </p>
          <div className="mt-2 flex gap-1.5 flex-wrap">
            {["✓ Normal IP", "✓ No Travel Flag", "✓ Low Risk"].map((tag) => (
              <span
                key={tag}
                className="px-2 py-0.5 rounded-full text-[7px] font-bold"
                style={{ background: "rgba(22,163,74,0.18)", color: "#86EFAC" }}
              >
                {tag}
              </span>
            ))}
          </div>
        </div>

        {/* TX Details */}
        <div className="rounded-xl p-3 bg-white border border-gray-100">
          {[
            { k: "Amount", v: TX.amount, bold: true },
            { k: "Recipient", v: TX.recipient },
            { k: "Account", v: TX.acct },
            { k: "Requesting App", v: "Tapat Bank" },
          ].map((r) => (
            <div key={r.k} className="flex justify-between py-1.5 border-b border-gray-50 last:border-0">
              <span className="text-[9px] text-gray-400">{r.k}</span>
              <span className={`text-[9px] ${r.bold ? "font-bold text-gray-800" : "text-gray-600"}`}>{r.v}</span>
            </div>
          ))}
        </div>

        {/* Crypto accordion */}
        <button
          onClick={() => setOpen(!open)}
          className="w-full text-left px-3 py-2 rounded-xl bg-gray-50 border border-gray-200"
        >
          <div className="flex justify-between items-center">
            <span className="text-[8px] font-medium text-gray-500">View Cryptographic Details</span>
            <span className="text-gray-400 text-[10px]">{open ? "▲" : "▼"}</span>
          </div>
          {open && (
            <div className="mt-2 space-y-0.5">
              {[
                ["timestamp", TX.ts],
                ["ip_addr", TX.ip],
                ["location", TX.loc],
                ["nonce", "0x4a9f31e7"],
                ["challenge", "0xb72d…9001"],
              ].map(([k, v]) => (
                <p key={k} className="text-[7px] text-gray-400 font-mono">
                  {k}: {v}
                </p>
              ))}
            </div>
          )}
        </button>
      </div>

      {/* Actions */}
      <div className="px-3 pb-3 space-y-1.5">
        <button
          onClick={onNext}
          className="w-full py-3 rounded-2xl text-white font-bold text-[11px] flex items-center justify-center gap-2"
          style={{
            background: "linear-gradient(135deg, #003087 0%, #1B5FC1 100%)",
            boxShadow: "0 4px 20px rgba(0,48,135,0.4)",
          }}
        >
          <svg viewBox="0 0 24 24" fill="none" stroke="white" strokeWidth="2" className="w-3.5 h-3.5">
            <circle cx="12" cy="12" r="3" />
            <path d="M3 12s3-7 9-7 9 7 9 7-3 7-9 7-9-7-9-7z" />
          </svg>
          Authorize with Face Liveness
        </button>
        <button className="w-full py-2 text-red-500 text-[10px] font-semibold">
          Reject Request
        </button>
      </div>
    </div>
  )
}

function EGovLiveness({ step }: { step: Step }) {
  const isVerifying = step === "egov-verifying"
  return (
    <div className="h-full flex flex-col" style={{ background: "#000" }}>
      {/* Camera simulation */}
      <div
        className="flex-1 relative flex items-center justify-center overflow-hidden"
        style={{
          background:
            "radial-gradient(ellipse at 42% 38%, #1a2830 0%, #0b1520 55%, #050c14 100%)",
        }}
      >
        {/* Noise layer */}
        <div
          className="absolute inset-0 opacity-[0.08]"
          style={{
            backgroundImage:
              "url(\"data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='300' height='300'%3E%3Cfilter id='n'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='0.8' numOctaves='4'/%3E%3C/filter%3E%3Crect width='300' height='300' filter='url(%23n)'/%3E%3C/svg%3E\")",
            backgroundSize: "200px 200px",
          }}
        />

        {/* Face frame container */}
        <div className="relative" style={{ width: 160, height: 200 }}>
          {/* SVG overlay with oval and corner brackets */}
          <svg
            viewBox="0 0 160 200"
            className="absolute inset-0 w-full h-full"
            style={{ filter: `drop-shadow(0 0 12px ${isVerifying ? "rgba(34,197,94,0.6)" : "rgba(0,140,255,0.5)"})` }}
          >
            {/* Dark overlay outside oval */}
            <defs>
              <mask id="ov">
                <rect width="160" height="200" fill="white" />
                <ellipse cx="80" cy="100" rx="66" ry="83" fill="black" />
              </mask>
            </defs>
            <rect width="160" height="200" fill="rgba(0,0,0,0.45)" mask="url(#ov)" />
            {/* Oval border */}
            <ellipse
              cx="80"
              cy="100"
              rx="66"
              ry="83"
              fill="none"
              stroke={isVerifying ? "#22C55E" : "#3B9EFF"}
              strokeWidth="1.5"
              strokeDasharray={isVerifying ? "none" : "7 3"}
            />
            {/* Corner brackets */}
            <path d="M10 28 L10 10 L28 10" fill="none" stroke={isVerifying ? "#22C55E" : "#3B9EFF"} strokeWidth="2.5" strokeLinecap="round" />
            <path d="M132 10 L150 10 L150 28" fill="none" stroke={isVerifying ? "#22C55E" : "#3B9EFF"} strokeWidth="2.5" strokeLinecap="round" />
            <path d="M10 172 L10 190 L28 190" fill="none" stroke={isVerifying ? "#22C55E" : "#3B9EFF"} strokeWidth="2.5" strokeLinecap="round" />
            <path d="M150 172 L150 190 L132 190" fill="none" stroke={isVerifying ? "#22C55E" : "#3B9EFF"} strokeWidth="2.5" strokeLinecap="round" />
          </svg>

          {/* Laser sweep */}
          {!isVerifying && (
            <div
              className="absolute"
              style={{
                left: 14,
                right: 14,
                height: 2,
                top: "10%",
                background:
                  "linear-gradient(90deg, transparent, rgba(0,140,255,0.4) 20%, rgba(0,200,255,1) 50%, rgba(0,140,255,0.4) 80%, transparent)",
                boxShadow: "0 0 10px 2px rgba(0,180,255,0.5)",
                animation: "laserSweep 2s ease-in-out infinite",
              }}
            />
          )}

          {/* Success checkmark overlay */}
          {isVerifying && (
            <div className="absolute inset-0 flex items-center justify-center">
              <svg viewBox="0 0 60 60" className="w-12 h-12" style={{ animation: "scaleIn 0.3s ease-out" }}>
                <circle cx="30" cy="30" r="28" fill="rgba(22,163,74,0.2)" stroke="#22C55E" strokeWidth="1.5" />
                <polyline
                  points="18 30 26 38 42 22"
                  fill="none"
                  stroke="#22C55E"
                  strokeWidth="3"
                  strokeLinecap="round"
                  strokeLinejoin="round"
                />
              </svg>
            </div>
          )}
        </div>

        {/* Top status pill */}
        <div className="absolute top-3 left-0 right-0 flex justify-center">
          <span
            className="inline-block px-3 py-1 rounded-full text-[8px] font-bold"
            style={{
              background: isVerifying ? "rgba(22,163,74,0.25)" : "rgba(0,120,255,0.25)",
              color: isVerifying ? "#86EFAC" : "#93C5FD",
              border: `1px solid ${isVerifying ? "rgba(134,239,172,0.35)" : "rgba(147,197,253,0.35)"}`,
            }}
          >
            {isVerifying ? "● LIVENESS CONFIRMED" : "◉ FACE LIVENESS ACTIVE"}
          </span>
        </div>

        {/* Bottom status */}
        <div className="absolute bottom-5 left-0 right-0 text-center px-6">
          {isVerifying ? (
            <div style={{ animation: "fadeInUp 0.3s ease-out" }}>
              <p className="text-green-400 font-bold text-[11px]">Real person confirmed</p>
              <p className="text-white/50 text-[9px] mt-1">Submitting to eVerify + PhilSys…</p>
              <div className="flex justify-center gap-1 mt-1.5">
                {[0, 1, 2].map((i) => (
                  <div
                    key={i}
                    className="w-1.5 h-1.5 rounded-full bg-green-400"
                    style={{ animation: `bounceDot 0.7s ease-in-out ${i * 0.12}s infinite` }}
                  />
                ))}
              </div>
            </div>
          ) : (
            <div>
              <p className="text-white font-semibold text-[11px]">Position your face in the frame</p>
              <p className="text-white/40 text-[9px] mt-1">Checking liveness — do not blink</p>
            </div>
          )}
        </div>
      </div>

      {/* Bottom bar */}
      <div
        className="px-4 py-3 flex items-center gap-3"
        style={{ background: "rgba(4,8,18,0.96)", borderTop: "1px solid rgba(255,255,255,0.08)" }}
      >
        <svg viewBox="0 0 24 24" fill="none" className="w-4 h-4 shrink-0">
          <path
            d="M12 1L3 5v6c0 5.55 3.84 10.74 9 12 5.16-1.26 9-6.45 9-12V5l-9-4z"
            fill="rgba(59,158,255,0.2)"
            stroke="#3B9EFF"
            strokeWidth="1.5"
          />
        </svg>
        <div>
          <p className="text-[9px] text-white font-semibold">eGovPH Face Liveness API</p>
          <p className="text-[7px] text-gray-500">Anti-spoofing · Anti-deepfake · Liveness 3D</p>
        </div>
      </div>
    </div>
  )
}

function EGovSuccess({ onNext }: { onNext: () => void }) {
  return (
    <div className="h-full flex flex-col bg-white" style={{ animation: "fadeInUp 0.35s ease-out" }}>
      <div
        className="px-4 pt-3 pb-4 flex flex-col items-center"
        style={{ background: "linear-gradient(160deg, #002E7D 0%, #1A5DC5 100%)" }}
      >
        <div
          className="w-14 h-14 rounded-full flex items-center justify-center mb-2"
          style={{
            background: "rgba(22,163,74,0.2)",
            border: "2px solid rgba(134,239,172,0.5)",
            boxShadow: "0 0 30px rgba(22,163,74,0.35)",
            animation: "scaleIn 0.4s cubic-bezier(0.34,1.56,0.64,1)",
          }}
        >
          <svg viewBox="0 0 24 24" fill="none" className="w-7 h-7">
            <polyline
              points="20 6 9 17 4 12"
              stroke="#22C55E"
              strokeWidth="2.5"
              strokeLinecap="round"
              strokeLinejoin="round"
            />
          </svg>
        </div>
        <p className="text-white font-black text-sm text-center">
          Transaction Cryptographically Signed!
        </p>
        <p className="text-white/50 text-[8px] text-center mt-0.5">
          Anchored to eGovChain · Immutable record created
        </p>
      </div>

      <div className="flex-1 overflow-y-auto px-3 py-3 space-y-2.5">
        {/* Blockchain receipt */}
        <div
          className="rounded-2xl p-3.5"
          style={{
            background: "#080D1B",
            border: "1px solid rgba(99,102,241,0.4)",
            boxShadow: "0 0 30px rgba(99,102,241,0.12)",
          }}
        >
          <div className="flex items-center gap-1.5 mb-2.5">
            <div
              className="w-2 h-2 rounded-full bg-green-500"
              style={{ animation: "pulseRing 2s ease-in-out infinite" }}
            />
            <span className="text-[9px] font-bold text-indigo-300 uppercase tracking-widest">
              eGovChain Receipt
            </span>
          </div>
          {[
            { k: "Status", v: "✓ Anchored to eGovChain", color: "#86EFAC" },
            { k: "Tx Hash", v: TX.hash, mono: true, color: "#A5B4FC" },
            { k: "Block Number", v: `#${TX.block}`, mono: true, color: "#A5B4FC" },
            { k: "Auth Method", v: "Face Liveness + eVerify", color: "#FDE68A" },
            { k: "Timestamp", v: TX.ts, color: "#6B7280" },
          ].map((r) => (
            <div key={r.k} className="flex justify-between py-1.5 border-b border-white/5 last:border-0">
              <span className="text-[8px] text-gray-500">{r.k}</span>
              <span
                className={`text-[8px] text-right max-w-[55%] ${r.mono ? "font-mono" : "font-medium"}`}
                style={{ color: r.color }}
              >
                {r.v}
              </span>
            </div>
          ))}
        </div>

        {/* eGov services grid */}
        <div className="rounded-xl p-3 bg-gray-50 border border-gray-100">
          <p className="text-[8px] font-semibold text-gray-400 uppercase tracking-widest mb-2">
            eGov Services Invoked
          </p>
          <div className="grid grid-cols-2 gap-1.5">
            {[
              { name: "eGovPH SSO", icon: "🔑" },
              { name: "eVerify", icon: "🛡️" },
              { name: "Face Liveness", icon: "👁️" },
              { name: "eMessage", icon: "📩" },
              { name: "eGovChain", icon: "⛓️" },
              { name: "eGovAI", icon: "🤖" },
            ].map((s) => (
              <div
                key={s.name}
                className="flex items-center gap-1.5 px-2 py-1.5 rounded-lg bg-white border border-gray-100"
              >
                <span className="text-[10px]">{s.icon}</span>
                <span className="text-[7px] font-medium text-gray-600 truncate">{s.name}</span>
                <span className="ml-auto text-green-500 text-[9px] shrink-0">✓</span>
              </div>
            ))}
          </div>
        </div>

        <button
          onClick={onNext}
          className="w-full py-3 rounded-2xl text-white font-bold text-[11px]"
          style={{
            background: "linear-gradient(135deg, #003087 0%, #1B5FC1 100%)",
            boxShadow: "0 4px 20px rgba(0,48,135,0.35)",
          }}
        >
          ← Return to Dashboard
        </button>
      </div>
    </div>
  )
}

// ─── Connection Bridge ────────────────────────────────────────────────────────
type BridgeInfo = {
  dir: "right" | "left" | "both"
  service: string
  sub: string
  color: string
} | null

function ConnectionBridge({ step }: { step: Step }) {
  const infoMap: Record<Step, BridgeInfo> = {
    idle: null,
    "bank-transfer": null,
    deeplink: { dir: "right", service: "eGovPH SSO", sub: "tapatan:// → egovph://", color: "#3B9EFF" },
    "egov-notify": { dir: "left", service: "eMessage", sub: "Push notification", color: "#A78BFA" },
    "egov-review": { dir: "both", service: "eVerify + eGovAI", sub: "Transaction review", color: "#60A5FA" },
    "egov-liveness": { dir: "both", service: "Face Liveness API", sub: "Biometric check", color: "#34D399" },
    "egov-verifying": { dir: "both", service: "eVerify + PhilSys", sub: "Identity verification", color: "#FBBF24" },
    "egov-success": { dir: "left", service: "eGovChain", sub: "Signing + anchoring", color: "#22C55E" },
    "bank-done": { dir: "left", service: "Auth Token", sub: "tapatan://auth-result", color: "#22C55E" },
  }
  const info = infoMap[step]

  const Chevrons = ({
    dir,
    color,
  }: {
    dir: "right" | "left"
    color: string
  }) => (
    <div
      className={`flex items-center gap-0 ${dir === "left" ? "flex-row-reverse" : ""}`}
    >
      {[0, 1, 2, 3].map((i) => (
        <svg
          key={i}
          viewBox="0 0 8 14"
          className="w-2 h-3.5"
          style={{
            animation: `arrowFlow 0.8s ease-in-out ${i * 0.15}s infinite`,
          }}
        >
          <polyline
            points="1 1 7 7 1 13"
            fill="none"
            stroke={color}
            strokeWidth="1.8"
            strokeLinecap="round"
            strokeLinejoin="round"
          />
        </svg>
      ))}
    </div>
  )

  return (
    <div
      style={{ width: 116 }}
      className="flex flex-col items-center justify-center gap-3 shrink-0"
    >
      {info ? (
        <>
          <div className="flex items-center justify-center w-full gap-1">
            {info.dir === "left" ? (
              <Chevrons dir="left" color={info.color} />
            ) : info.dir === "right" ? (
              <Chevrons dir="right" color={info.color} />
            ) : (
              <>
                <Chevrons dir="left" color={info.color} />
                <div className="w-1" />
                <Chevrons dir="right" color={info.color} />
              </>
            )}
          </div>
          <div
            className="px-2.5 py-2 rounded-xl text-center w-full"
            style={{
              background: `${info.color}12`,
              border: `1px solid ${info.color}28`,
            }}
          >
            <p className="text-[8px] font-bold" style={{ color: info.color }}>
              {info.service}
            </p>
            <p className="text-[7px] text-gray-500 mt-0.5 leading-snug">{info.sub}</p>
          </div>
        </>
      ) : (
        <div className="flex flex-col items-center gap-2">
          <div className="w-16 h-px bg-gray-700" />
          <p className="text-[7px] text-gray-600 text-center">Deep Link Channel</p>
          <div className="w-16 h-px bg-gray-700" />
        </div>
      )}
    </div>
  )
}

// ─── Step Indicator ───────────────────────────────────────────────────────────
const STEP_LABELS: Record<Step, string> = {
  idle: "Start",
  "bank-transfer": "Transfer",
  deeplink: "SSO",
  "egov-notify": "Notify",
  "egov-review": "Review",
  "egov-liveness": "Liveness",
  "egov-verifying": "Verify",
  "egov-success": "Chain",
  "bank-done": "Done",
}

function StepIndicator({ step, onReset }: { step: Step; onReset: () => void }) {
  const curIdx = SEQ.indexOf(step)
  return (
    <div className="px-4 pb-8">
      <div className="flex items-start justify-center gap-0 overflow-x-auto">
        {SEQ.map((s, i) => {
          const done = i < curIdx
          const active = i === curIdx
          return (
            <div key={s} className="flex items-center shrink-0">
              <div className="flex flex-col items-center gap-1">
                <div
                  className="w-6 h-6 rounded-full flex items-center justify-center text-[8px] font-bold transition-all duration-300"
                  style={{
                    background: done ? "#16A34A" : active ? "#3B82F6" : "rgba(255,255,255,0.08)",
                    color: done || active ? "white" : "#4B5563",
                    boxShadow: active ? "0 0 12px rgba(59,130,246,0.5)" : "none",
                  }}
                >
                  {done ? "✓" : i + 1}
                </div>
                <span
                  className="text-[7px] whitespace-nowrap"
                  style={{ color: active ? "#93C5FD" : done ? "#6EE7B7" : "#374151", fontWeight: active ? 700 : 400 }}
                >
                  {STEP_LABELS[s]}
                </span>
              </div>
              {i < SEQ.length - 1 && (
                <div
                  className="w-5 h-px mb-4 mx-0.5 transition-all duration-500"
                  style={{ background: i < curIdx ? "#16A34A" : "rgba(255,255,255,0.1)" }}
                />
              )}
            </div>
          )
        })}
      </div>
      {step === "bank-done" && (
        <div className="flex justify-center mt-4" style={{ animation: "fadeInUp 0.4s ease-out" }}>
          <button
            onClick={onReset}
            className="px-5 py-2 rounded-xl text-[11px] font-semibold transition-opacity hover:opacity-80"
            style={{
              background: "rgba(255,255,255,0.07)",
              border: "1px solid rgba(255,255,255,0.13)",
              color: "#D1D5DB",
            }}
          >
            ↺ Reset Simulation
          </button>
        </div>
      )}
    </div>
  )
}

// ─── Service Legend ───────────────────────────────────────────────────────────
function ServiceLegend() {
  const services = [
    { icon: "🔐", name: "eGovPH SSO", desc: "Single sign-on gateway" },
    { icon: "🛡️", name: "eVerify", desc: "PhilSys identity backbone" },
    { icon: "👁️", name: "Face Liveness", desc: "Anti-spoofing biometrics" },
    { icon: "📩", name: "eMessage", desc: "Push notification delivery" },
    { icon: "⛓️", name: "eGovChain", desc: "Tamper-evident audit log" },
    { icon: "🤖", name: "eGovAI", desc: "Fraud anomaly detection" },
  ]
  return (
    <div className="px-6 pb-8 max-w-3xl mx-auto w-full">
      <p className="text-[9px] font-bold text-gray-600 uppercase tracking-widest text-center mb-3">
        eGovPH Security Layer — API Surface
      </p>
      <div className="grid grid-cols-3 gap-2">
        {services.map((s) => (
          <div
            key={s.name}
            className="px-3 py-2.5 rounded-xl flex items-start gap-2"
            style={{ background: "rgba(255,255,255,0.04)", border: "1px solid rgba(255,255,255,0.07)" }}
          >
            <span className="text-sm shrink-0">{s.icon}</span>
            <div>
              <p className="text-[9px] font-bold text-gray-300">{s.name}</p>
              <p className="text-[7px] text-gray-600 mt-0.5">{s.desc}</p>
            </div>
          </div>
        ))}
      </div>
    </div>
  )
}

// ─── App ──────────────────────────────────────────────────────────────────────
export default function App() {
  const [step, setStep] = useState<Step>("idle")

  const advance = useCallback(() => {
    setStep((prev) => {
      const idx = SEQ.indexOf(prev)
      return idx >= SEQ.length - 1 ? "idle" : SEQ[idx + 1]
    })
  }, [])

  // Auto-advances
  useEffect(() => {
    if (step === "deeplink") {
      const t = setTimeout(advance, 2200)
      return () => clearTimeout(t)
    }
    if (step === "egov-liveness") {
      const t = setTimeout(advance, 3800)
      return () => clearTimeout(t)
    }
    if (step === "egov-verifying") {
      const t = setTimeout(advance, 2000)
      return () => clearTimeout(t)
    }
  }, [step, advance])

  return (
    <div style={{ background: "#060D1B", minHeight: "100vh", fontFamily: "'Inter', sans-serif" }}>
      {/* Header */}
      <header className="text-center pt-7 pb-5 px-4">
        <div
          className="inline-flex items-center gap-2 px-3 py-1 rounded-full mb-3"
          style={{
            background: "rgba(255,255,255,0.05)",
            border: "1px solid rgba(255,255,255,0.1)",
          }}
        >
          <div
            className="w-1.5 h-1.5 rounded-full bg-green-400"
            style={{ animation: "glowPulse 2s ease-in-out infinite" }}
          />
          <span className="text-[9px] font-bold text-green-400 uppercase tracking-widest">
            Live Integration Simulator
          </span>
        </div>
        <h1 className="text-white font-black text-2xl tracking-tight">
          TAPAT <span style={{ color: "#FFD700" }}>×</span> eGovPH
        </h1>
        <p className="text-gray-500 text-xs mt-1">
          PhilSys Identity Backbone · Deep-link SSO · Face Liveness · eGovChain
        </p>
      </header>

      {/* Phones */}
      <div className="flex items-center justify-center gap-3 px-4 pb-5 overflow-x-auto">
        {/* Bank side */}
        <div className="flex flex-col items-center gap-2 shrink-0">
          <div className="flex items-center gap-1.5">
            <div
              className="w-1.5 h-1.5 rounded-full bg-blue-400"
              style={{ animation: "glowPulse 2s ease-in-out infinite" }}
            />
            <span className="text-[10px] font-bold text-gray-400">Tapat Bank App</span>
          </div>
          <PhoneFrame glowColor="#0082CC">
            <BankApp step={step} onNext={advance} />
          </PhoneFrame>
        </div>

        {/* Bridge */}
        <ConnectionBridge step={step} />

        {/* eGov side */}
        <div className="flex flex-col items-center gap-2 shrink-0">
          <div className="flex items-center gap-1.5">
            <div
              className="w-1.5 h-1.5 rounded-full bg-yellow-400"
              style={{ animation: "glowPulse 2s 0.5s ease-in-out infinite" }}
            />
            <span className="text-[10px] font-bold text-gray-400">eGovPH App</span>
          </div>
          <PhoneFrame glowColor="#1B5FC1">
            <EGovApp step={step} onNext={advance} />
          </PhoneFrame>
        </div>
      </div>

      {/* Step tracker */}
      <StepIndicator step={step} onReset={() => setStep("idle")} />

      {/* Service legend */}
      <ServiceLegend />
    </div>
  )
}
