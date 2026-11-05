import { useState } from "react";
import { motion, AnimatePresence } from "motion/react";
import { Shield, AlertTriangle, Lock, CheckCircle, XCircle, Eye, Info, ChevronDown, ChevronUp, ArrowLeft } from "lucide-react";
import { getRevokedCards, revokeCard, unRevokeCard } from "../services/cardRevocationService";

interface SecurityInfoScreenProps {
  onBack?: () => void;
}

const PROTECTED_ATTACKS = [
  {
    attack: "MITM (Man-in-the-Middle)",
    protection: "Tokens are single-use and timestamp-bound. Intercepted tokens expire in 30 seconds and cannot be replayed.",
    protected: true,
  },
  {
    attack: "SIM Swap",
    protection: "Authentication requires physical possession of the NFC card — no SMS OTP dependency.",
    protected: true,
  },
  {
    attack: "Phishing",
    protection: "No credentials are entered. The NFC card holds the token — phishing pages can't steal what doesn't exist in a form.",
    protected: true,
  },
  {
    attack: "Token Replay",
    protection: "Tokens are single-use and cryptographically bound to a session ID and timestamp.",
    protected: true,
  },
  {
    attack: "Remote Card Cloning",
    protection: "Partial — card UID is validated, but without attestation certificates a sophisticated clone is theoretically possible.",
    protected: false,
  },
  {
    attack: "Physical Theft of Card Only",
    protection: "Protected — the card is only useful when paired with the app's token. Without the app, a stolen card cannot transact.",
    protected: true,
  },
  {
    attack: "Physical Theft of Phone + Card Simultaneously",
    protection: "NOT protected — if both are stolen together and the app is already unlocked, the attacker can transact. Use app lock immediately.",
    protected: false,
  },
];

const SECURITY_PROPERTIES = [
  { label: "Authentication Factor", value: "Something you have (NFC card)", icon: Shield, color: "#34d399" },
  { label: "Token Lifetime", value: "5 minutes (idle) or single-use", icon: Lock, color: "#a78bfa" },
  { label: "Token Binding", value: "Session ID + Timestamp + Card ID", icon: CheckCircle, color: "#06b6d4" },
  { label: "Card Revocation", value: "Remote lock via this screen", icon: XCircle, color: "#f59e0b" },
  { label: "Fallback Auth", value: "Card PIN after 3 NFC failures", icon: Lock, color: "#a78bfa" },
  { label: "Progressive Auth", value: "Amount-scaled auth levels", icon: Shield, color: "#34d399" },
];

export function SecurityInfoScreen({ onBack }: SecurityInfoScreenProps) {
  const [expandedIdx, setExpandedIdx] = useState<number | null>(null);
  const [revokedCards, setRevokedCards] = useState<string[]>(getRevokedCards());
  const [newRevokeId, setNewRevokeId] = useState("");
  const [showRevokeInput, setShowRevokeInput] = useState(false);
  const [revokeAction, setRevokeAction] = useState<"revoked" | "unrevoked" | null>(null);

  function handleRevoke(id: string) {
    revokeCard(id);
    setRevokedCards(getRevokedCards());
    setNewRevokeId("");
    setShowRevokeInput(false);
    setRevokeAction("revoked");
    setTimeout(() => setRevokeAction(null), 2500);
  }

  function handleUnrevoke(id: string) {
    unRevokeCard(id);
    setRevokedCards(getRevokedCards());
    setRevokeAction("unrevoked");
    setTimeout(() => setRevokeAction(null), 2500);
  }

  return (
    <div className="pt-14 pb-6 px-5 space-y-5">
      {/* Header */}
      <div className="flex items-center gap-3">
        {onBack && (
          <button
            onClick={onBack}
            className="w-9 h-9 rounded-xl flex items-center justify-center flex-shrink-0"
            style={{ background: "rgba(255,255,255,0.08)" }}
          >
            <ArrowLeft size={18} className="text-white" />
          </button>
        )}
        <div>
          <h2 className="text-white" style={{ fontSize: 22, fontWeight: 800 }}>Security Info</h2>
          <p className="text-white/40" style={{ fontSize: 12, marginTop: 2 }}>
            Threat model & card management
          </p>
        </div>
      </div>

      {/* Revoke action toast */}
      <AnimatePresence>
        {revokeAction && (
          <motion.div
            initial={{ opacity: 0, y: -8 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -8 }}
            className="p-3 rounded-2xl flex items-center gap-2"
            style={{
              background: revokeAction === "revoked" ? "rgba(239,68,68,0.12)" : "rgba(16,185,129,0.12)",
              border: `1px solid ${revokeAction === "revoked" ? "rgba(239,68,68,0.3)" : "rgba(16,185,129,0.3)"}`,
            }}
          >
            {revokeAction === "revoked" ? (
              <XCircle size={14} className="text-red-400" />
            ) : (
              <CheckCircle size={14} className="text-emerald-400" />
            )}
            <span
              style={{
                fontSize: 12, fontWeight: 700,
                color: revokeAction === "revoked" ? "#f87171" : "#34d399",
              }}
            >
              {revokeAction === "revoked" ? "Card revoked successfully." : "Card re-activated."}
            </span>
          </motion.div>
        )}
      </AnimatePresence>

      {/* Card Revocation Panel */}
      <motion.div
        initial={{ opacity: 0, y: 10 }}
        animate={{ opacity: 1, y: 0 }}
        className="p-4 rounded-3xl space-y-3"
        style={{
          background: "linear-gradient(135deg, rgba(239,68,68,0.08), rgba(220,38,38,0.05))",
          border: "1px solid rgba(239,68,68,0.2)",
        }}
      >
        <div className="flex items-center gap-2">
          <XCircle size={16} style={{ color: "#f87171" }} />
          <p className="text-red-400" style={{ fontSize: 14, fontWeight: 800 }}>Card Revocation</p>
        </div>
        <p className="text-white/40" style={{ fontSize: 12 }}>
          Lost your NFC card? Revoke it instantly. Any card with this ID will be rejected everywhere — even if it has a valid token.
        </p>

        {revokedCards.length > 0 && (
          <div className="space-y-2">
            <p className="text-white/50" style={{ fontSize: 11, fontWeight: 600 }}>REVOKED CARDS</p>
            {revokedCards.map((uid) => (
              <div
                key={uid}
                className="flex items-center justify-between p-2.5 rounded-xl"
                style={{ background: "rgba(239,68,68,0.10)", border: "1px solid rgba(239,68,68,0.2)" }}
              >
                <span className="text-red-300 font-mono" style={{ fontSize: 11 }}>{uid}</span>
                <button
                  onClick={() => handleUnrevoke(uid)}
                  className="text-white/40 px-2 py-1 rounded-lg"
                  style={{ background: "rgba(255,255,255,0.06)", fontSize: 10, fontWeight: 700 }}
                >
                  Restore
                </button>
              </div>
            ))}
          </div>
        )}

        <AnimatePresence>
          {showRevokeInput ? (
            <motion.div
              initial={{ opacity: 0, height: 0 }}
              animate={{ opacity: 1, height: "auto" }}
              exit={{ opacity: 0, height: 0 }}
              className="space-y-2"
            >
              <input
                type="text"
                value={newRevokeId}
                onChange={(e) => setNewRevokeId(e.target.value)}
                placeholder="Enter Card ID to revoke"
                className="w-full px-3 py-2 rounded-xl text-white outline-none"
                style={{
                  background: "rgba(255,255,255,0.07)",
                  border: "1px solid rgba(255,255,255,0.12)",
                  fontSize: 13,
                }}
                autoFocus
              />
              <div className="flex gap-2">
                <button
                  onClick={() => { setShowRevokeInput(false); setNewRevokeId(""); }}
                  className="flex-1 py-2 rounded-xl text-white/40"
                  style={{ background: "rgba(255,255,255,0.05)", fontSize: 13 }}
                >
                  Cancel
                </button>
                <button
                  onClick={() => newRevokeId.trim() && handleRevoke(newRevokeId.trim())}
                  disabled={!newRevokeId.trim()}
                  className="flex-1 py-2 rounded-xl font-bold"
                  style={{
                    background: newRevokeId.trim() ? "rgba(239,68,68,0.7)" : "rgba(255,255,255,0.05)",
                    color: newRevokeId.trim() ? "white" : "rgba(255,255,255,0.3)",
                    fontSize: 13,
                  }}
                >
                  🔒 Revoke Card
                </button>
              </div>
            </motion.div>
          ) : (
            <button
              onClick={() => setShowRevokeInput(true)}
              className="w-full py-2.5 rounded-xl flex items-center justify-center gap-1.5"
              style={{
                background: "rgba(239,68,68,0.15)",
                border: "1px solid rgba(239,68,68,0.3)",
                color: "#f87171",
                fontSize: 13,
                fontWeight: 700,
              }}
            >
              <Lock size={13} />
              Lock / Revoke a Card
            </button>
          )}
        </AnimatePresence>
      </motion.div>

      {/* Security Properties */}
      <motion.div
        initial={{ opacity: 0, y: 10 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ delay: 0.1 }}
        className="p-4 rounded-3xl space-y-3"
        style={{
          background: "rgba(255,255,255,0.04)",
          border: "1px solid rgba(255,255,255,0.08)",
        }}
      >
        <div className="flex items-center gap-2 mb-1">
          <Eye size={14} className="text-violet-400" />
          <p className="text-white/70" style={{ fontSize: 13, fontWeight: 800 }}>System Properties</p>
        </div>
        {SECURITY_PROPERTIES.map(({ label, value, icon: Icon, color }) => (
          <div key={label} className="flex items-start gap-3">
            <div
              className="w-7 h-7 rounded-lg flex items-center justify-center flex-shrink-0"
              style={{ background: `${color}22` }}
            >
              <Icon size={13} style={{ color }} />
            </div>
            <div className="flex-1">
              <p className="text-white/50" style={{ fontSize: 11 }}>{label}</p>
              <p className="text-white" style={{ fontSize: 12, fontWeight: 600 }}>{value}</p>
            </div>
          </div>
        ))}
      </motion.div>

      {/* Threat Model */}
      <motion.div
        initial={{ opacity: 0, y: 10 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ delay: 0.15 }}
        className="space-y-2"
      >
        <div className="flex items-center gap-2 mb-1">
          <Info size={14} className="text-violet-400" />
          <p className="text-white/70" style={{ fontSize: 13, fontWeight: 800 }}>Threat Model</p>
          <span className="text-white/25" style={{ fontSize: 11 }}>— tap to expand</span>
        </div>

        {PROTECTED_ATTACKS.map((item, i) => (
          <motion.div
            key={item.attack}
            initial={{ opacity: 0, y: 6 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.15 + i * 0.04 }}
          >
            <button
              onClick={() => setExpandedIdx(expandedIdx === i ? null : i)}
              className="w-full text-left"
            >
              <div
                className="p-3 rounded-2xl"
                style={{
                  background: item.protected ? "rgba(16,185,129,0.06)" : "rgba(239,68,68,0.06)",
                  border: `1px solid ${item.protected ? "rgba(16,185,129,0.2)" : "rgba(239,68,68,0.2)"}`,
                }}
              >
                <div className="flex items-center gap-2">
                  {item.protected ? (
                    <CheckCircle size={14} style={{ color: "#34d399", flexShrink: 0 }} />
                  ) : (
                    <AlertTriangle size={14} style={{ color: "#f87171", flexShrink: 0 }} />
                  )}
                  <p className="text-white flex-1" style={{ fontSize: 12, fontWeight: 700 }}>
                    {item.attack}
                  </p>
                  {expandedIdx === i ? (
                    <ChevronUp size={12} style={{ color: "rgba(255,255,255,0.3)", flexShrink: 0 }} />
                  ) : (
                    <ChevronDown size={12} style={{ color: "rgba(255,255,255,0.3)", flexShrink: 0 }} />
                  )}
                </div>
                <AnimatePresence>
                  {expandedIdx === i && (
                    <motion.p
                      initial={{ opacity: 0, height: 0 }}
                      animate={{ opacity: 1, height: "auto" }}
                      exit={{ opacity: 0, height: 0 }}
                      className="text-white/50 mt-2"
                      style={{ fontSize: 11, lineHeight: 1.5 }}
                    >
                      {item.protection}
                    </motion.p>
                  )}
                </AnimatePresence>
              </div>
            </button>
          </motion.div>
        ))}
      </motion.div>

      {/* Academic Note */}
      <motion.div
        initial={{ opacity: 0, y: 10 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ delay: 0.4 }}
        className="p-4 rounded-3xl"
        style={{
          background: "linear-gradient(135deg, rgba(109,40,217,0.10), rgba(37,99,235,0.08))",
          border: "1px solid rgba(139,92,246,0.2)",
        }}
      >
        <div className="flex items-center gap-2 mb-2">
          <Info size={13} className="text-violet-400" />
          <p className="text-violet-400" style={{ fontSize: 12, fontWeight: 700 }}>
            Research Transparency Note
          </p>
        </div>
        <p className="text-white/40" style={{ fontSize: 11, lineHeight: 1.6 }}>
          This system is a research prototype. It does not implement SCP03 Secure Channel Protocol or 
          formal card attestation certificates. The NFC communication channel is not encrypted at the 
          transport layer. These limitations are acknowledged in the study and represent future work directions.
        </p>
      </motion.div>
    </div>
  );
}
