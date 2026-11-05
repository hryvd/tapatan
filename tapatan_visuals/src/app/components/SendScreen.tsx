import { useState } from "react";
import { motion, AnimatePresence } from "motion/react";
import { Search, ArrowRight, CheckCircle, ChevronLeft, Wifi, Shield, AlertCircle, ArrowLeft } from "lucide-react";

const CONTACTS = [
  { id: 1, name: "Maria Santos", initials: "MS", color: "#7c3aed", recent: 2500 },
  { id: 2, name: "Jose Reyes", initials: "JR", color: "#0891b2", recent: 800 },
  { id: 3, name: "Ana Gonzalez", initials: "AG", color: "#059669", recent: 1200 },
  { id: 4, name: "Pedro Flores", initials: "PF", color: "#dc2626", recent: 350 },
  { id: 5, name: "Sofia Torres", initials: "ST", color: "#d97706", recent: 5000 },
  { id: 6, name: "Luis Mendoza", initials: "LM", color: "#7c3aed", recent: 150 },
];

type SendStep = "select" | "amount" | "confirm" | "nfc_tap" | "success";
type NfcTapState = "idle" | "scanning" | "success" | "error";

interface SendScreenProps {
  cardActive?: boolean;
  onTransactionComplete?: () => void;
  onClose?: () => void;
}

function delay(ms: number) {
  return new Promise((r) => setTimeout(r, ms));
}

export function SendScreen({ cardActive = true, onTransactionComplete, onClose }: SendScreenProps) {
  const [query, setQuery] = useState("");
  const [selected, setSelected] = useState<(typeof CONTACTS)[0] | null>(null);
  const [amount, setAmount] = useState("");
  const [step, setStep] = useState<SendStep>("select");
  const [note, setNote] = useState("");
  const [nfcState, setNfcState] = useState<NfcTapState>("idle");

  const filtered = CONTACTS.filter((c) =>
    c.name.toLowerCase().includes(query.toLowerCase())
  );

  function handleSelectContact(c: (typeof CONTACTS)[0]) {
    setSelected(c);
    setStep("amount");
  }

  async function handleSend() {
    setStep("confirm");
  }

  async function handleConfirm() {
    setStep("nfc_tap");
    setNfcState("idle");
  }

  async function handleNfcTap() {
    if (nfcState !== "idle" && nfcState !== "error") return;
    setNfcState("scanning");
    await delay(1800);
    setNfcState("success");
    await delay(900);
    onTransactionComplete?.();
    setStep("success");
  }

  function reset() {
    setSelected(null);
    setAmount("");
    setNote("");
    setQuery("");
    setStep("select");
    setNfcState("idle");
  }

  return (
    <div className="pt-14 pb-6 px-5 min-h-full">
      {/* Header */}
      <div className="flex items-center gap-3 mb-6">
        {step !== "select" && step !== "success" && step !== "nfc_tap" && (
          <button
            onClick={() => setStep(step === "amount" ? "select" : "amount")}
            className="w-9 h-9 rounded-xl flex items-center justify-center"
            style={{ background: "rgba(255,255,255,0.08)" }}
          >
            <ChevronLeft size={18} className="text-white" />
          </button>
        )}
        {step === "select" && onClose && (
          <button
            onClick={onClose}
            className="w-9 h-9 rounded-xl flex items-center justify-center flex-shrink-0"
            style={{ background: "rgba(255,255,255,0.08)" }}
          >
            <ArrowLeft size={18} className="text-white" />
          </button>
        )}
        <div>
          <h2 className="text-white" style={{ fontSize: 22, fontWeight: 800 }}>
            {step === "select"
              ? "Send Money"
              : step === "amount"
              ? "Enter Amount"
              : step === "confirm"
              ? "Confirm Transfer"
              : step === "nfc_tap"
              ? "Authorize with Card"
              : "Transfer Sent!"}
          </h2>
          {step === "select" && (
            <p className="text-white/40" style={{ fontSize: 12, marginTop: 2 }}>
              Choose a recipient
            </p>
          )}
          {step === "nfc_tap" && (
            <p className="text-white/40" style={{ fontSize: 12, marginTop: 2 }}>
              Java Card required to confirm
            </p>
          )}
        </div>
      </div>

      <AnimatePresence mode="wait">
        {/* Step 1 — Select contact */}
        {step === "select" && (
          <motion.div
            key="select"
            initial={{ opacity: 0, x: -20 }}
            animate={{ opacity: 1, x: 0 }}
            exit={{ opacity: 0, x: 20 }}
            className="space-y-4"
          >
            {/* Search */}
            <div
              className="flex items-center gap-3 px-4 py-3 rounded-2xl"
              style={{
                background: "rgba(255,255,255,0.06)",
                border: "1px solid rgba(255,255,255,0.10)",
              }}
            >
              <Search size={16} style={{ color: "rgba(255,255,255,0.35)" }} />
              <input
                value={query}
                onChange={(e) => setQuery(e.target.value)}
                placeholder="Search contacts..."
                className="flex-1 bg-transparent outline-none text-white placeholder-white/25"
                style={{ fontSize: 14 }}
              />
            </div>

            {/* Contact list */}
            <div className="space-y-2">
              {filtered.map((c) => (
                <motion.button
                  key={c.id}
                  whileTap={{ scale: 0.98 }}
                  onClick={() => handleSelectContact(c)}
                  className="w-full flex items-center gap-3 p-4 rounded-2xl"
                  style={{
                    background: "rgba(255,255,255,0.05)",
                    border: "1px solid rgba(255,255,255,0.08)",
                  }}
                >
                  <div
                    className="w-11 h-11 rounded-2xl flex items-center justify-center flex-shrink-0"
                    style={{ background: `${c.color}33` }}
                  >
                    <span className="text-white" style={{ fontSize: 14, fontWeight: 800 }}>
                      {c.initials}
                    </span>
                  </div>
                  <div className="flex-1 text-left">
                    <p className="text-white" style={{ fontSize: 14, fontWeight: 700 }}>
                      {c.name}
                    </p>
                    <p className="text-white/40" style={{ fontSize: 12 }}>
                      Recent: ₱{c.recent.toLocaleString()}
                    </p>
                  </div>
                  <ArrowRight size={16} style={{ color: "rgba(255,255,255,0.25)" }} />
                </motion.button>
              ))}
            </div>
          </motion.div>
        )}

        {/* Step 2 — Amount */}
        {step === "amount" && selected && (
          <motion.div
            key="amount"
            initial={{ opacity: 0, x: 20 }}
            animate={{ opacity: 1, x: 0 }}
            exit={{ opacity: 0, x: -20 }}
            className="space-y-5"
          >
            {/* Recipient */}
            <div
              className="flex items-center gap-3 p-4 rounded-2xl"
              style={{
                background: `${selected.color}18`,
                border: `1px solid ${selected.color}33`,
              }}
            >
              <div
                className="w-10 h-10 rounded-xl flex items-center justify-center"
                style={{ background: `${selected.color}33` }}
              >
                <span className="text-white" style={{ fontSize: 13, fontWeight: 800 }}>
                  {selected.initials}
                </span>
              </div>
              <div>
                <p className="text-white" style={{ fontSize: 14, fontWeight: 700 }}>
                  {selected.name}
                </p>
                <p className="text-white/40" style={{ fontSize: 12 }}>
                  Recipient
                </p>
              </div>
            </div>

            {/* Amount input */}
            <div className="text-center py-4">
              <p className="text-white/40 mb-2" style={{ fontSize: 13 }}>
                Amount (PHP)
              </p>
              <div className="flex items-center justify-center gap-2">
                <span className="text-white/40" style={{ fontSize: 32, fontWeight: 700 }}>
                  ₱
                </span>
                <input
                  type="number"
                  value={amount}
                  onChange={(e) => setAmount(e.target.value)}
                  placeholder="0.00"
                  className="bg-transparent outline-none text-white text-center"
                  style={{ fontSize: 40, fontWeight: 900, width: 160 }}
                />
              </div>
            </div>

            {/* Quick amounts */}
            <div className="grid grid-cols-4 gap-2">
              {["500", "1000", "2500", "5000"].map((q) => (
                <button
                  key={q}
                  onClick={() => setAmount(q)}
                  className="py-2 rounded-xl"
                  style={{
                    background:
                      amount === q ? "rgba(124,58,237,0.3)" : "rgba(255,255,255,0.06)",
                    border:
                      amount === q
                        ? "1px solid rgba(124,58,237,0.5)"
                        : "1px solid rgba(255,255,255,0.08)",
                    color: "rgba(255,255,255,0.7)",
                    fontSize: 12,
                    fontWeight: 600,
                  }}
                >
                  ₱{q}
                </button>
              ))}
            </div>

            {/* Note */}
            <input
              value={note}
              onChange={(e) => setNote(e.target.value)}
              placeholder="Add a note (optional)"
              className="w-full px-4 py-3 rounded-2xl text-white placeholder-white/25 outline-none"
              style={{
                background: "rgba(255,255,255,0.06)",
                border: "1px solid rgba(255,255,255,0.10)",
                fontSize: 14,
              }}
            />

            <motion.button
              whileTap={{ scale: 0.97 }}
              onClick={handleSend}
              disabled={!amount || parseFloat(amount) <= 0}
              className="w-full py-4 rounded-2xl flex items-center justify-center gap-2"
              style={{
                background:
                  amount && parseFloat(amount) > 0
                    ? "linear-gradient(135deg, #7c3aed, #2563eb)"
                    : "rgba(255,255,255,0.06)",
                boxShadow:
                  amount && parseFloat(amount) > 0
                    ? "0 8px 30px rgba(124,58,237,0.4)"
                    : "none",
                opacity: amount && parseFloat(amount) > 0 ? 1 : 0.5,
              }}
            >
              <span className="text-white" style={{ fontSize: 15, fontWeight: 800 }}>
                Continue
              </span>
              <ArrowRight size={18} className="text-white" />
            </motion.button>
          </motion.div>
        )}

        {/* Step 3 — Confirm */}
        {step === "confirm" && selected && (
          <motion.div
            key="confirm"
            initial={{ opacity: 0, x: 20 }}
            animate={{ opacity: 1, x: 0 }}
            exit={{ opacity: 0, x: -20 }}
            className="space-y-4"
          >
            <div
              className="p-5 rounded-3xl space-y-4"
              style={{
                background: "rgba(255,255,255,0.05)",
                border: "1px solid rgba(255,255,255,0.10)",
                backdropFilter: "blur(20px)",
              }}
            >
              <div className="text-center">
                <div
                  className="w-16 h-16 rounded-3xl flex items-center justify-center mx-auto mb-3"
                  style={{ background: `${selected.color}33` }}
                >
                  <span className="text-white" style={{ fontSize: 22, fontWeight: 900 }}>
                    {selected.initials}
                  </span>
                </div>
                <p className="text-white/50" style={{ fontSize: 13 }}>
                  Sending to
                </p>
                <p className="text-white" style={{ fontSize: 18, fontWeight: 800 }}>
                  {selected.name}
                </p>
              </div>

              <div className="h-px" style={{ background: "rgba(255,255,255,0.08)" }} />

              <div className="flex items-center justify-between">
                <span className="text-white/50" style={{ fontSize: 13 }}>Amount</span>
                <span className="text-white" style={{ fontSize: 18, fontWeight: 800 }}>
                  ₱{parseFloat(amount || "0").toFixed(2)}
                </span>
              </div>
              <div className="flex items-center justify-between">
                <span className="text-white/50" style={{ fontSize: 13 }}>Fee</span>
                <span className="text-emerald-400" style={{ fontSize: 13, fontWeight: 600 }}>Free</span>
              </div>
              {note && (
                <div className="flex items-start justify-between gap-3">
                  <span className="text-white/50" style={{ fontSize: 13 }}>Note</span>
                  <span className="text-white/80 text-right" style={{ fontSize: 13 }}>{note}</span>
                </div>
              )}
            </div>

            {/* NFC required notice */}
            <div
              className="flex items-center gap-3 p-3 rounded-2xl"
              style={{
                background: "rgba(167,139,250,0.08)",
                border: "1px solid rgba(167,139,250,0.2)",
              }}
            >
              <Wifi size={16} style={{ color: "#a78bfa", flexShrink: 0 }} />
              <p className="text-violet-300/70" style={{ fontSize: 12 }}>
                Java Card tap required to authorize this transaction
              </p>
            </div>

            <motion.button
              whileTap={{ scale: 0.97 }}
              onClick={handleConfirm}
              className="w-full py-4 rounded-2xl flex items-center justify-center gap-2"
              style={{
                background: "linear-gradient(135deg, #7c3aed, #2563eb)",
                boxShadow: "0 8px 30px rgba(124,58,237,0.35)",
              }}
            >
              <Shield size={18} className="text-white" />
              <span className="text-white" style={{ fontSize: 15, fontWeight: 800 }}>
                Proceed to Card Auth
              </span>
            </motion.button>
          </motion.div>
        )}

        {/* Step 4 — NFC Card Tap Confirmation */}
        {step === "nfc_tap" && selected && (
          <motion.div
            key="nfc_tap"
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -16 }}
            className="flex flex-col items-center gap-5"
          >
            {/* Transaction summary */}
            <div
              className="w-full p-4 rounded-2xl flex items-center justify-between"
              style={{
                background: "rgba(255,255,255,0.05)",
                border: "1px solid rgba(255,255,255,0.09)",
              }}
            >
              <div>
                <p className="text-white/40" style={{ fontSize: 12 }}>Authorizing</p>
                <p className="text-white" style={{ fontSize: 16, fontWeight: 800 }}>
                  ₱{parseFloat(amount || "0").toFixed(2)} → {selected.name}
                </p>
              </div>
              <div
                className="w-10 h-10 rounded-xl flex items-center justify-center"
                style={{ background: `${selected.color}33` }}
              >
                <span className="text-white" style={{ fontSize: 12, fontWeight: 800 }}>
                  {selected.initials}
                </span>
              </div>
            </div>

            {/* NFC animation */}
            <div className="relative flex items-center justify-center" style={{ width: 180, height: 180 }}>
              {nfcState === "idle" &&
                [0, 1, 2].map((i) => (
                  <motion.div
                    key={i}
                    className="absolute rounded-full"
                    style={{
                      width: 60 + i * 36,
                      height: 60 + i * 36,
                      border: "1px solid rgba(167,139,250,0.25)",
                    }}
                    animate={{ scale: [1, 1.12, 1], opacity: [0.5, 0.1, 0.5] }}
                    transition={{ repeat: Infinity, duration: 2, delay: i * 0.35, ease: "easeInOut" }}
                  />
                ))}

              {nfcState === "scanning" &&
                [0, 1].map((i) => (
                  <motion.div
                    key={i}
                    className="absolute rounded-full"
                    style={{
                      width: 80 + i * 40,
                      height: 80 + i * 40,
                      border: "2px solid rgba(6,182,212,0.6)",
                    }}
                    animate={{ scale: [1, 1.4], opacity: [0.7, 0] }}
                    transition={{ repeat: Infinity, duration: 1, delay: i * 0.5, ease: "easeOut" }}
                  />
                ))}

              <motion.div
                animate={
                  nfcState === "scanning"
                    ? { boxShadow: ["0 0 20px rgba(6,182,212,0.3)", "0 0 50px rgba(6,182,212,0.6)", "0 0 20px rgba(6,182,212,0.3)"] }
                    : nfcState === "success"
                    ? { boxShadow: "0 0 40px rgba(16,185,129,0.5)" }
                    : nfcState === "error"
                    ? { boxShadow: "0 0 30px rgba(239,68,68,0.4)" }
                    : {}
                }
                transition={{ repeat: nfcState === "scanning" ? Infinity : 0, duration: 1 }}
                className="w-20 h-20 rounded-3xl flex items-center justify-center z-10"
                style={{
                  background:
                    nfcState === "success"
                      ? "linear-gradient(135deg, #05966933, #0891b233)"
                      : nfcState === "error"
                      ? "linear-gradient(135deg, #ef444433, #dc262633)"
                      : nfcState === "scanning"
                      ? "linear-gradient(135deg, #06b6d433, #2563eb33)"
                      : "linear-gradient(135deg, #7c3aed33, #2563eb33)",
                  border:
                    nfcState === "success"
                      ? "1px solid rgba(16,185,129,0.5)"
                      : nfcState === "error"
                      ? "1px solid rgba(239,68,68,0.4)"
                      : nfcState === "scanning"
                      ? "1px solid rgba(6,182,212,0.5)"
                      : "1px solid rgba(139,92,246,0.4)",
                }}
              >
                {nfcState === "success" ? (
                  <motion.div initial={{ scale: 0 }} animate={{ scale: 1 }} transition={{ type: "spring", stiffness: 400 }}>
                    <CheckCircle size={36} style={{ color: "#34d399" }} />
                  </motion.div>
                ) : nfcState === "error" ? (
                  <AlertCircle size={36} style={{ color: "#f87171" }} />
                ) : (
                  <Wifi
                    size={36}
                    style={{
                      color: nfcState === "scanning" ? "#06b6d4" : "#a78bfa",
                      filter: `drop-shadow(0 0 8px ${nfcState === "scanning" ? "#06b6d4" : "#a78bfa"})`,
                    }}
                  />
                )}
              </motion.div>
            </div>

            {/* Status text */}
            <AnimatePresence mode="wait">
              <motion.div
                key={nfcState}
                initial={{ opacity: 0, y: 6 }}
                animate={{ opacity: 1, y: 0 }}
                exit={{ opacity: 0, y: -6 }}
                className="text-center"
              >
                {nfcState === "idle" && (
                  <>
                    <p className="text-white" style={{ fontSize: 18, fontWeight: 800 }}>Tap Java Card to Authorize</p>
                    <p className="text-white/40 mt-1" style={{ fontSize: 13 }}>Hold card against back of phone</p>
                  </>
                )}
                {nfcState === "scanning" && (
                  <>
                    <p className="text-cyan-300" style={{ fontSize: 18, fontWeight: 800 }}>Reading secure element…</p>
                    <p className="text-white/40 mt-1" style={{ fontSize: 13 }}>Verifying transaction token</p>
                  </>
                )}
                {nfcState === "success" && (
                  <>
                    <p className="text-emerald-400" style={{ fontSize: 18, fontWeight: 800 }}>Card Authorized!</p>
                    <p className="text-white/40 mt-1" style={{ fontSize: 13 }}>Processing transfer…</p>
                  </>
                )}
                {nfcState === "error" && (
                  <>
                    <p className="text-red-400" style={{ fontSize: 18, fontWeight: 800 }}>Auth Failed</p>
                    <p className="text-white/40 mt-1" style={{ fontSize: 13 }}>Card not recognised. Try again.</p>
                  </>
                )}
              </motion.div>
            </AnimatePresence>

            {/* Tap button */}
            {(nfcState === "idle" || nfcState === "error") && (
              <motion.button
                whileTap={{ scale: 0.96 }}
                onClick={handleNfcTap}
                className="w-full py-4 rounded-2xl flex items-center justify-center gap-2"
                style={{
                  background: nfcState === "error"
                    ? "linear-gradient(135deg, #ef4444, #dc2626)"
                    : "linear-gradient(135deg, #7c3aed, #06b6d4)",
                  boxShadow: nfcState === "error"
                    ? "0 8px 30px rgba(239,68,68,0.3)"
                    : "0 8px 30px rgba(124,58,237,0.4)",
                }}
              >
                <Wifi size={18} className="text-white" />
                <span className="text-white" style={{ fontSize: 16, fontWeight: 800 }}>
                  {nfcState === "error" ? "Retry Tap" : "Tap Java Card"}
                </span>
              </motion.button>
            )}

            {nfcState === "scanning" && (
              <div
                className="w-full py-4 rounded-2xl flex items-center justify-center gap-2"
                style={{ background: "rgba(6,182,212,0.10)", border: "1px solid rgba(6,182,212,0.2)" }}
              >
                <motion.div
                  animate={{ rotate: 360 }}
                  transition={{ repeat: Infinity, duration: 0.9, ease: "linear" }}
                  className="w-5 h-5 border-2 border-cyan-300/30 border-t-cyan-300 rounded-full"
                />
                <span className="text-cyan-300" style={{ fontSize: 15, fontWeight: 700 }}>Scanning…</span>
              </div>
            )}
          </motion.div>
        )}

        {/* Step 5 — Success */}
        {step === "success" && selected && (
          <motion.div
            key="success"
            initial={{ opacity: 0, scale: 0.9 }}
            animate={{ opacity: 1, scale: 1 }}
            className="flex flex-col items-center pt-8 space-y-6"
          >
            <motion.div animate={{ scale: [1, 1.08, 1] }} transition={{ repeat: 2, duration: 0.4 }}>
              <CheckCircle size={72} className="text-emerald-400" style={{ filter: "drop-shadow(0 0 20px #34d399)" }} />
            </motion.div>
            <div className="text-center">
              <p className="text-white" style={{ fontSize: 24, fontWeight: 900 }}>
                ₱{parseFloat(amount || "0").toFixed(2)} Sent!
              </p>
              <p className="text-white/50 mt-1" style={{ fontSize: 14 }}>to {selected.name}</p>
            </div>

            <motion.div
              initial={{ opacity: 0, y: 10 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: 0.3 }}
              className="w-full p-4 rounded-2xl space-y-2"
              style={{
                background: "rgba(255,255,255,0.05)",
                border: "1px solid rgba(255,255,255,0.08)",
              }}
            >
              <p className="text-white/40 text-center" style={{ fontSize: 12 }}>Transaction ID</p>
              <p className="text-white/70 text-center" style={{ fontSize: 11, fontFamily: "monospace" }}>
                TXN-{Date.now().toString().slice(-8)}
              </p>
              <div className="flex items-center justify-center gap-2 mt-2">
                <div className="w-1.5 h-1.5 rounded-full bg-emerald-400" />
                <p className="text-emerald-400" style={{ fontSize: 12, fontWeight: 700 }}>
                  Java Card authorized · Token consumed
                </p>
              </div>
            </motion.div>

            <button
              onClick={reset}
              className="w-full py-4 rounded-2xl"
              style={{
                background: "rgba(255,255,255,0.06)",
                border: "1px solid rgba(255,255,255,0.10)",
                color: "rgba(255,255,255,0.7)",
                fontSize: 15,
                fontWeight: 700,
              }}
            >
              Send Another
            </button>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}
