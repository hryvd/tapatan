import React, { useState, useEffect, useRef, useCallback } from "react";
import { motion, AnimatePresence } from "motion/react";
import {
  Smartphone,
  CreditCard,
  Monitor,
  CheckCircle,
  Shield,
  RefreshCw,
  ChevronRight,
  Wifi,
  Lock,
  ArrowLeft,
  Timer,
  AlertTriangle,
  Nfc,
  KeyRound,
  BadgeCheck,
  Mail,
  DollarSign,
} from "lucide-react";
import type { CardData } from "./Card3D";
import {
  isNFCSupported,
  buildTokenPayload,
  serializePayload,
  writeTokenToNFC,
  type TokenPayload,
} from "../services/nfcService";
import {
  incrementUseCount,
  recordLastTap,
  isRevoked,
} from "../services/cardRevocationService";

// ── Constants ─────────────────────────────────────────────────────────────────

const CARD_TIMEOUT_SECONDS = 5 * 60; // 5 minutes
const MICRO_THRESHOLD = 100;   // < ₱100: tap-and-go (no extra auth)
const MEDIUM_THRESHOLD = 500;  // ₱100–500: card tap only
const HIGH_THRESHOLD = 5000;   // ₱500–5000: card tap + PIN
// > ₱5000: card tap + PIN + email OTP

// ── Types ─────────────────────────────────────────────────────────────────────

type FlowStep =
  | "idle"
  | "amount"
  | "pin"
  | "otp"
  | "authenticating"
  | "writing"
  | "ready"
  | "success"
  | "error";

interface NFCFlowScreenProps {
  activeCard: CardData | null;
  onClose?: () => void;
  onTransactionComplete?: () => void;
}

const STEP_LABELS: Record<FlowStep, string> = {
  idle: "Ready to begin",
  amount: "Enter transaction amount",
  pin: "Enter your PIN",
  otp: "Email OTP verification",
  authenticating: "Authenticating...",
  writing: "Writing token to NFC tag...",
  ready: "NFC tag armed — tap to pay",
  success: "Payment complete!",
  error: "Write failed",
};

// ── Component ─────────────────────────────────────────────────────────────────

export function NFCFlowScreen({
  activeCard,
  onClose,
  onTransactionComplete,
}: NFCFlowScreenProps) {
  const [step, setStep] = useState<FlowStep>("idle");
  const [payload, setPayload] = useState<TokenPayload | null>(null);
  const [errorMsg, setErrorMsg] = useState<string>("");
  const [amountStr, setAmountStr] = useState<string>("");
  const [pinStr, setPinStr] = useState<string>("");
  const [otpStr, setOtpStr] = useState<string>("");
  const [generatedOtp] = useState<string>(() =>
    Math.floor(100000 + Math.random() * 900000).toString()
  );
  const [timeoutSecsLeft, setTimeoutSecsLeft] = useState<number>(CARD_TIMEOUT_SECONDS);
  const abortRef = useRef<AbortController | null>(null);
  const timerRef = useRef<ReturnType<typeof setInterval> | null>(null);
  const nfcSupported = isNFCSupported();

  const amount = parseFloat(amountStr) || 0;

  const authLevel = (): "micro" | "low" | "medium" | "high" => {
    if (amount < MICRO_THRESHOLD) return "micro";
    if (amount < MEDIUM_THRESHOLD) return "low";
    if (amount < HIGH_THRESHOLD) return "medium";
    return "high";
  };

  // ── Countdown timer when card is ready ──────────────────────────────────────

  useEffect(() => {
    if (step === "ready") {
      setTimeoutSecsLeft(CARD_TIMEOUT_SECONDS);
      timerRef.current = setInterval(() => {
        setTimeoutSecsLeft((prev) => {
          if (prev <= 1) {
            clearInterval(timerRef.current!);
            setStep("idle");
            setPayload(null);
            return 0;
          }
          return prev - 1;
        });
      }, 1000);
    } else {
      if (timerRef.current) {
        clearInterval(timerRef.current);
        timerRef.current = null;
      }
    }
    return () => {
      if (timerRef.current) clearInterval(timerRef.current);
    };
  }, [step]);

  const cleanup = useCallback(() => {
    abortRef.current?.abort();
    abortRef.current = null;
    if (timerRef.current) clearInterval(timerRef.current);
  }, []);

  useEffect(() => () => cleanup(), [cleanup]);

  // ── Flow steps ──────────────────────────────────────────────────────────────

  function handleStart() {
    if (!activeCard) return;
    if (isRevoked(activeCard.id)) {
      setErrorMsg("This card has been revoked. Please contact support.");
      setStep("error");
      return;
    }
    setAmountStr("");
    setPinStr("");
    setOtpStr("");
    setStep("amount");
  }

  function handleAmountNext() {
    if (amount <= 0) return;
    const level = authLevel();
    if (level === "micro" || level === "low") {
      // No extra auth needed
      startWriteFlow();
    } else if (level === "medium") {
      setStep("pin");
    } else {
      setStep("pin");
    }
  }

  function handlePinNext() {
    if (pinStr.length < 4) return;
    const level = authLevel();
    if (level === "high") {
      setStep("otp");
    } else {
      startWriteFlow();
    }
  }

  function handleOtpNext() {
    if (otpStr !== generatedOtp) {
      setErrorMsg("Incorrect OTP. Check your email.");
      return;
    }
    startWriteFlow();
  }

  async function startWriteFlow() {
    if (!activeCard) return;
    setStep("authenticating");
    await delay(900);

    const newPayload = buildTokenPayload(activeCard.id, amount > 0 ? amount : undefined);
    setPayload(newPayload);
    setStep("writing");

    abortRef.current = new AbortController();

    if (nfcSupported) {
      const result = await writeTokenToNFC(newPayload, abortRef.current.signal);
      if (result.success) {
        incrementUseCount(activeCard.id);
        recordLastTap(activeCard.id);
        setStep("ready");
      } else {
        setErrorMsg(result.error ?? "NFC write failed.");
        setStep("error");
      }
    } else {
      // Fallback simulation for non-NFC devices (dev preview)
      await delay(1800);
      setStep("ready");
    }
  }

  function handleSimulatePOSTap() {
    // This represents the physical card tap at POS — we just mark success
    setStep("success");
    onTransactionComplete?.();
  }

  function reset() {
    cleanup();
    setStep("idle");
    setPayload(null);
    setAmountStr("");
    setPinStr("");
    setOtpStr("");
    setErrorMsg("");
  }

  const flowStepIndex: Record<FlowStep, number> = {
    idle: 0,
    amount: 0,
    pin: 0,
    otp: 0,
    authenticating: 1,
    writing: 1,
    ready: 2,
    success: 3,
    error: 1,
  };
  const currentIdx = flowStepIndex[step];

  const mins = Math.floor(timeoutSecsLeft / 60);
  const secs = timeoutSecsLeft % 60;
  const timeoutStr = `${mins}:${secs.toString().padStart(2, "0")}`;
  const timeoutPct = (timeoutSecsLeft / CARD_TIMEOUT_SECONDS) * 100;

  return (
    <div className="pt-14 pb-6 px-5 space-y-5">
      {/* Header */}
      <div className="flex items-center gap-3">
        {onClose && (
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
            NFC Pay Flow
          </h2>
          <p className="text-white/40" style={{ fontSize: 12, marginTop: 2 }}>
            {nfcSupported
              ? "Real NFC · Privacy-preserving payment"
              : "⚠ NFC not detected — simulation mode"}
          </p>
        </div>
      </div>

      {/* NFC not supported warning */}
      {!nfcSupported && (
        <motion.div
          initial={{ opacity: 0, y: 6 }}
          animate={{ opacity: 1, y: 0 }}
          className="p-3 rounded-2xl flex items-start gap-2"
          style={{
            background: "rgba(245,158,11,0.10)",
            border: "1px solid rgba(245,158,11,0.25)",
          }}
        >
          <AlertTriangle size={14} className="text-amber-400 mt-0.5 flex-shrink-0" />
          <p className="text-amber-300" style={{ fontSize: 12 }}>
            Web NFC API not available. This device or browser doesn't support NFC
            writing. Install the app on Android Chrome with NFC enabled for real operation.
            Running in <strong>simulation mode</strong>.
          </p>
        </motion.div>
      )}

      {/* Active card indicator */}
      {activeCard ? (
        <motion.div
          initial={{ opacity: 0, y: 10 }}
          animate={{ opacity: 1, y: 0 }}
          className="flex items-center gap-3 p-3 rounded-2xl"
          style={{
            background: `linear-gradient(135deg, ${activeCard.colors[0]}33, ${activeCard.colors[1]}22)`,
            border: `1px solid ${activeCard.colors[0]}44`,
            backdropFilter: "blur(16px)",
          }}
        >
          <div
            className="w-10 h-10 rounded-xl flex-shrink-0"
            style={{
              background: `linear-gradient(135deg, ${activeCard.colors[0]}, ${activeCard.colors[1]})`,
            }}
          />
          <div className="flex-1">
            <p className="text-white" style={{ fontSize: 13, fontWeight: 700 }}>
              {activeCard.provider} — {activeCard.type.toUpperCase()}
            </p>
            <p className="text-white/50" style={{ fontSize: 11, fontFamily: "monospace" }}>
              {activeCard.cardNumber}
            </p>
          </div>
          <div className="flex items-center gap-1">
            {isRevoked(activeCard.id) ? (
              <span className="text-red-400" style={{ fontSize: 10, fontWeight: 700 }}>
                REVOKED
              </span>
            ) : (
              <>
                <span
                  className="w-2 h-2 rounded-full bg-emerald-400"
                  style={{ boxShadow: "0 0 8px #34d399" }}
                />
                <span className="text-emerald-400" style={{ fontSize: 10, fontWeight: 700 }}>
                  ACTIVE
                </span>
              </>
            )}
          </div>
        </motion.div>
      ) : (
        <div
          className="p-4 rounded-2xl text-center"
          style={{
            background: "rgba(255,255,255,0.04)",
            border: "1px solid rgba(255,255,255,0.08)",
          }}
        >
          <p className="text-white/40" style={{ fontSize: 13 }}>
            No active card — go to Virtual Cards to set one
          </p>
        </div>
      )}

      {/* ── Progressive Auth level badge ── */}
      {step === "amount" && amount > 0 && (
        <motion.div
          initial={{ opacity: 0, scale: 0.95 }}
          animate={{ opacity: 1, scale: 1 }}
          className="flex items-center gap-2 px-3 py-2 rounded-xl"
          style={{
            background:
              authLevel() === "high"
                ? "rgba(239,68,68,0.10)"
                : authLevel() === "medium"
                ? "rgba(245,158,11,0.10)"
                : "rgba(16,185,129,0.10)",
            border:
              authLevel() === "high"
                ? "1px solid rgba(239,68,68,0.25)"
                : authLevel() === "medium"
                ? "1px solid rgba(245,158,11,0.25)"
                : "1px solid rgba(16,185,129,0.25)",
          }}
        >
          <Shield
            size={13}
            style={{
              color:
                authLevel() === "high"
                  ? "#f87171"
                  : authLevel() === "medium"
                  ? "#fbbf24"
                  : "#34d399",
            }}
          />
          <span
            style={{
              fontSize: 11,
              fontWeight: 700,
              color:
                authLevel() === "high"
                  ? "#f87171"
                  : authLevel() === "medium"
                  ? "#fbbf24"
                  : "#34d399",
            }}
          >
            {authLevel() === "micro"
              ? "Tap-and-Go · No additional auth required"
              : authLevel() === "low"
              ? "Standard · Card tap only"
              : authLevel() === "medium"
              ? "Elevated · Card tap + PIN required"
              : "High-value · Card tap + PIN + Email OTP required"}
          </span>
        </motion.div>
      )}

      {/* ── Flow diagram ── */}
      <motion.div
        initial={{ opacity: 0, y: 16 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ delay: 0.1 }}
        className="p-5 rounded-3xl relative overflow-hidden"
        style={{
          background: "rgba(255,255,255,0.04)",
          backdropFilter: "blur(20px)",
          border: "1px solid rgba(255,255,255,0.08)",
        }}
      >
        <div
          className="absolute inset-0 pointer-events-none"
          style={{
            background:
              "radial-gradient(ellipse at 50% 50%, rgba(109,40,217,0.08) 0%, transparent 70%)",
          }}
        />
        <p className="text-white/50 mb-4 text-center" style={{ fontSize: 11, letterSpacing: "0.1em" }}>
          THREE-DEVICE PAYMENT CHAIN
        </p>
        <div className="flex items-center justify-between relative">
          <FlowNode
            icon={Smartphone}
            label="Your Phone"
            sublabel="App"
            active={currentIdx >= 1}
            complete={currentIdx >= 2}
            color="#7c3aed"
          />
          <FlowArrow active={step === "writing" || step === "authenticating"} complete={currentIdx >= 2} label="NFC Write" />
          <FlowNode
            icon={Nfc}
            label="NFC Tag"
            sublabel="Token Carrier"
            active={currentIdx >= 2}
            complete={currentIdx >= 3}
            color="#06b6d4"
          />
          <FlowArrow active={false} complete={step === "success"} label="Tap POS" />
          <FlowNode
            icon={Monitor}
            label="POS Terminal"
            sublabel="Merchant"
            active={currentIdx >= 3}
            complete={step === "success"}
            color="#10b981"
          />
        </div>
        <motion.div key={step} initial={{ opacity: 0, y: 4 }} animate={{ opacity: 1, y: 0 }} className="mt-5 text-center">
          <p
            className={step === "success" ? "text-emerald-400" : step === "error" ? "text-red-400" : "text-white/60"}
            style={{ fontSize: 12, fontWeight: 600 }}
          >
            {STEP_LABELS[step]}
          </p>
        </motion.div>
      </motion.div>

      {/* ── Token display (when written) ── */}
      <AnimatePresence>
        {payload && (step === "ready" || step === "success") && (
          <motion.div
            initial={{ opacity: 0, height: 0 }}
            animate={{ opacity: 1, height: "auto" }}
            exit={{ opacity: 0, height: 0 }}
            className="rounded-3xl overflow-hidden"
            style={{
              background: "rgba(6,182,212,0.08)",
              border: "1px solid rgba(6,182,212,0.25)",
              backdropFilter: "blur(16px)",
            }}
          >
            <div className="p-4">
              <div className="flex items-center gap-2 mb-2">
                <Lock size={13} className="text-cyan-400" />
                <p className="text-cyan-400" style={{ fontSize: 11, fontWeight: 700 }}>
                  TOKEN WRITTEN TO NFC TAG
                </p>
              </div>
              <p className="text-cyan-300/80 break-all" style={{ fontSize: 11, fontFamily: "monospace", letterSpacing: "0.08em" }}>
                {payload.token}
              </p>
              <div className="flex items-center justify-between mt-2">
                <p className="text-white/30" style={{ fontSize: 10 }}>
                  Expires: {new Date(payload.expiresAt).toLocaleTimeString()} · Single-use
                </p>
                {payload.amount && (
                  <p className="text-cyan-400/70" style={{ fontSize: 10, fontWeight: 700 }}>
                    ₱{payload.amount.toFixed(2)}
                  </p>
                )}
              </div>
            </div>
          </motion.div>
        )}
      </AnimatePresence>

      {/* ── Countdown timer ── */}
      <AnimatePresence>
        {step === "ready" && (
          <motion.div
            initial={{ opacity: 0, y: 8 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0 }}
            className="space-y-2"
          >
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-1.5">
                <Timer size={13} className="text-amber-400" />
                <span className="text-amber-400" style={{ fontSize: 12, fontWeight: 700 }}>
                  Card expires in {timeoutStr}
                </span>
              </div>
              <span className="text-white/30" style={{ fontSize: 10 }}>
                Tap POS before timeout
              </span>
            </div>
            <div
              className="w-full rounded-full overflow-hidden"
              style={{ height: 4, background: "rgba(255,255,255,0.08)" }}
            >
              <motion.div
                className="h-full rounded-full"
                style={{
                  width: `${timeoutPct}%`,
                  background:
                    timeoutPct > 50
                      ? "#34d399"
                      : timeoutPct > 20
                      ? "#fbbf24"
                      : "#f87171",
                  transition: "width 1s linear, background 0.5s ease",
                }}
              />
            </div>
          </motion.div>
        )}
      </AnimatePresence>

      {/* ── Action buttons ── */}
      <div className="space-y-3">
        {/* Idle: start button */}
        {step === "idle" && activeCard && !isRevoked(activeCard.id) && (
          <motion.button
            initial={{ opacity: 0, y: 10 }}
            animate={{ opacity: 1, y: 0 }}
            whileTap={{ scale: 0.97 }}
            onClick={handleStart}
            className="w-full py-4 rounded-2xl flex items-center justify-center gap-2"
            style={{
              background: "linear-gradient(135deg, #7c3aed, #2563eb)",
              boxShadow: "0 8px 30px rgba(124,58,237,0.45)",
            }}
          >
            <Wifi size={18} className="text-white" />
            <span className="text-white" style={{ fontSize: 15, fontWeight: 800 }}>
              {nfcSupported ? "Write Token to NFC Tag" : "Start Payment Flow"}
            </span>
          </motion.button>
        )}

        {/* Revoked card notice */}
        {step === "idle" && activeCard && isRevoked(activeCard.id) && (
          <div
            className="w-full py-4 rounded-2xl flex items-center justify-center gap-2"
            style={{ background: "rgba(239,68,68,0.12)", border: "1px solid rgba(239,68,68,0.3)" }}
          >
            <AlertTriangle size={16} className="text-red-400" />
            <span className="text-red-400" style={{ fontSize: 14, fontWeight: 700 }}>
              Card is revoked — payment blocked
            </span>
          </div>
        )}

        {/* Amount input */}
        {step === "amount" && (
          <motion.div
            initial={{ opacity: 0, y: 10 }}
            animate={{ opacity: 1, y: 0 }}
            className="space-y-3"
          >
            <div
              className="rounded-2xl p-4"
              style={{ background: "rgba(255,255,255,0.05)", border: "1px solid rgba(255,255,255,0.12)" }}
            >
              <div className="flex items-center gap-2 mb-2">
                <DollarSign size={14} className="text-violet-400" />
                <span className="text-white/60" style={{ fontSize: 12, fontWeight: 600 }}>
                  TRANSACTION AMOUNT (₱)
                </span>
              </div>
              <input
                type="number"
                value={amountStr}
                onChange={(e) => setAmountStr(e.target.value)}
                placeholder="0.00"
                min="0"
                step="0.01"
                autoFocus
                className="w-full bg-transparent text-white outline-none"
                style={{ fontSize: 28, fontWeight: 800, letterSpacing: "-0.02em" }}
              />
            </div>
            <div className="flex gap-2">
              <button
                onClick={reset}
                className="flex-1 py-3 rounded-2xl"
                style={{ background: "rgba(255,255,255,0.05)", border: "1px solid rgba(255,255,255,0.10)", color: "rgba(255,255,255,0.5)", fontSize: 14 }}
              >
                Cancel
              </button>
              <motion.button
                whileTap={{ scale: 0.97 }}
                onClick={handleAmountNext}
                disabled={amount <= 0}
                className="flex-1 py-3 rounded-2xl flex items-center justify-center gap-1"
                style={{
                  background: amount > 0 ? "linear-gradient(135deg, #7c3aed, #2563eb)" : "rgba(255,255,255,0.05)",
                  color: amount > 0 ? "white" : "rgba(255,255,255,0.3)",
                  fontSize: 14,
                  fontWeight: 700,
                }}
              >
                Continue <ChevronRight size={14} />
              </motion.button>
            </div>
          </motion.div>
        )}

        {/* PIN input */}
        {step === "pin" && (
          <motion.div
            initial={{ opacity: 0, y: 10 }}
            animate={{ opacity: 1, y: 0 }}
            className="space-y-3"
          >
            <div
              className="rounded-2xl p-4"
              style={{ background: "rgba(255,255,255,0.05)", border: "1px solid rgba(255,255,255,0.12)" }}
            >
              <div className="flex items-center gap-2 mb-2">
                <KeyRound size={14} className="text-violet-400" />
                <span className="text-white/60" style={{ fontSize: 12, fontWeight: 600 }}>
                  ENTER PIN
                  {amount >= HIGH_THRESHOLD && " (Step 1 of 2)"}
                </span>
              </div>
              <input
                type="password"
                inputMode="numeric"
                value={pinStr}
                onChange={(e) => setPinStr(e.target.value.replace(/\D/g, "").slice(0, 6))}
                placeholder="••••"
                autoFocus
                className="w-full bg-transparent text-white outline-none tracking-widest"
                style={{ fontSize: 28, fontWeight: 800 }}
              />
            </div>
            <div className="flex gap-2">
              <button onClick={reset} className="flex-1 py-3 rounded-2xl" style={{ background: "rgba(255,255,255,0.05)", border: "1px solid rgba(255,255,255,0.10)", color: "rgba(255,255,255,0.5)", fontSize: 14 }}>
                Cancel
              </button>
              <motion.button
                whileTap={{ scale: 0.97 }}
                onClick={handlePinNext}
                disabled={pinStr.length < 4}
                className="flex-1 py-3 rounded-2xl flex items-center justify-center gap-1"
                style={{
                  background: pinStr.length >= 4 ? "linear-gradient(135deg, #7c3aed, #2563eb)" : "rgba(255,255,255,0.05)",
                  color: pinStr.length >= 4 ? "white" : "rgba(255,255,255,0.3)",
                  fontSize: 14, fontWeight: 700,
                }}
              >
                Confirm <ChevronRight size={14} />
              </motion.button>
            </div>
          </motion.div>
        )}

        {/* OTP input */}
        {step === "otp" && (
          <motion.div
            initial={{ opacity: 0, y: 10 }}
            animate={{ opacity: 1, y: 0 }}
            className="space-y-3"
          >
            <div
              className="rounded-2xl p-4"
              style={{ background: "rgba(255,255,255,0.05)", border: "1px solid rgba(255,255,255,0.12)" }}
            >
              <div className="flex items-center gap-2 mb-1">
                <Mail size={14} className="text-violet-400" />
                <span className="text-white/60" style={{ fontSize: 12, fontWeight: 600 }}>EMAIL OTP (Step 2 of 2)</span>
              </div>
              <p className="text-white/30 mb-3" style={{ fontSize: 11 }}>
                A 6-digit OTP was sent to your registered email. (Demo: <span className="text-violet-400 font-mono">{generatedOtp}</span>)
              </p>
              <input
                type="text"
                inputMode="numeric"
                value={otpStr}
                onChange={(e) => { setOtpStr(e.target.value.replace(/\D/g, "").slice(0, 6)); setErrorMsg(""); }}
                placeholder="000000"
                autoFocus
                className="w-full bg-transparent text-white outline-none tracking-widest"
                style={{ fontSize: 28, fontWeight: 800 }}
              />
              {errorMsg && (
                <p className="text-red-400 mt-2" style={{ fontSize: 11 }}>{errorMsg}</p>
              )}
            </div>
            <div className="flex gap-2">
              <button onClick={reset} className="flex-1 py-3 rounded-2xl" style={{ background: "rgba(255,255,255,0.05)", border: "1px solid rgba(255,255,255,0.10)", color: "rgba(255,255,255,0.5)", fontSize: 14 }}>
                Cancel
              </button>
              <motion.button
                whileTap={{ scale: 0.97 }}
                onClick={handleOtpNext}
                disabled={otpStr.length < 6}
                className="flex-1 py-3 rounded-2xl flex items-center justify-center gap-1"
                style={{
                  background: otpStr.length === 6 ? "linear-gradient(135deg, #7c3aed, #2563eb)" : "rgba(255,255,255,0.05)",
                  color: otpStr.length === 6 ? "white" : "rgba(255,255,255,0.3)",
                  fontSize: 14, fontWeight: 700,
                }}
              >
                Verify <ChevronRight size={14} />
              </motion.button>
            </div>
          </motion.div>
        )}

        {/* Authenticating / Writing spinner */}
        {(step === "authenticating" || step === "writing") && (
          <div
            className="w-full py-4 rounded-2xl flex items-center justify-center gap-3"
            style={{ background: "rgba(255,255,255,0.05)", border: "1px solid rgba(255,255,255,0.10)" }}
          >
            <motion.div animate={{ rotate: 360 }} transition={{ repeat: Infinity, duration: 1, ease: "linear" }}>
              <RefreshCw size={17} className="text-violet-400" />
            </motion.div>
            <span className="text-violet-400" style={{ fontSize: 14, fontWeight: 600 }}>
              {step === "authenticating" ? "Authenticating..." : nfcSupported ? "Hold phone to NFC tag..." : "Writing token..."}
            </span>
          </div>
        )}

        {/* Ready: NFC tag armed */}
        {step === "ready" && (
          <motion.div
            initial={{ opacity: 0, scale: 0.95 }}
            animate={{ opacity: 1, scale: 1 }}
            className="space-y-3"
          >
            <div
              className="w-full py-4 rounded-2xl flex items-center justify-center gap-2 relative overflow-hidden"
              style={{
                background: "linear-gradient(135deg, rgba(16,185,129,0.2), rgba(6,182,212,0.15))",
                border: "1px solid rgba(16,185,129,0.35)",
              }}
            >
              <BadgeCheck size={20} className="text-emerald-400" />
              <span className="text-emerald-400" style={{ fontSize: 15, fontWeight: 800 }}>
                NFC Tag Armed — Tap at POS
              </span>
            </div>
            {/* Dev-mode simulate button */}
            {!nfcSupported && (
              <button
                onClick={handleSimulatePOSTap}
                className="w-full py-3 rounded-2xl text-white/50"
                style={{ background: "rgba(255,255,255,0.04)", border: "1px solid rgba(255,255,255,0.08)", fontSize: 13 }}
              >
                [Dev] Simulate POS tap →
              </button>
            )}
          </motion.div>
        )}

        {/* Success */}
        {step === "success" && (
          <>
            <motion.div
              initial={{ opacity: 0, scale: 0.9 }}
              animate={{ opacity: 1, scale: 1 }}
              className="w-full py-5 rounded-2xl flex flex-col items-center justify-center gap-2"
              style={{
                background: "linear-gradient(135deg, rgba(16,185,129,0.25), rgba(5,150,105,0.20))",
                border: "1px solid rgba(16,185,129,0.35)",
              }}
            >
              <CheckCircle size={36} className="text-emerald-400" style={{ filter: "drop-shadow(0 0 12px #34d399)" }} />
              <p className="text-emerald-400" style={{ fontSize: 18, fontWeight: 800 }}>
                Payment Successful!
              </p>
              <p className="text-white/40" style={{ fontSize: 12 }}>
                Token expired · Your card details were never exposed
              </p>
            </motion.div>
            <button
              onClick={reset}
              className="w-full py-3 rounded-2xl"
              style={{
                background: "rgba(255,255,255,0.05)",
                border: "1px solid rgba(255,255,255,0.10)",
                color: "rgba(255,255,255,0.6)",
                fontSize: 14,
                fontWeight: 600,
              }}
            >
              New Transaction
            </button>
          </>
        )}

        {/* Error */}
        {step === "error" && (
          <>
            <div
              className="w-full py-4 rounded-2xl flex items-center justify-center gap-2"
              style={{ background: "rgba(239,68,68,0.12)", border: "1px solid rgba(239,68,68,0.3)" }}
            >
              <AlertTriangle size={16} className="text-red-400" />
              <span className="text-red-400" style={{ fontSize: 14, fontWeight: 700 }}>
                {errorMsg || "NFC write failed"}
              </span>
            </div>
            <button
              onClick={reset}
              className="w-full py-3 rounded-2xl"
              style={{
                background: "linear-gradient(135deg, #7c3aed, #2563eb)",
                color: "white", fontSize: 14, fontWeight: 700,
              }}
            >
              Try Again
            </button>
          </>
        )}
      </div>

      {/* How it works */}
      <motion.div
        initial={{ opacity: 0, y: 16 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ delay: 0.2 }}
        className="p-4 rounded-3xl space-y-3"
        style={{
          background: "rgba(255,255,255,0.04)",
          border: "1px solid rgba(255,255,255,0.08)",
          backdropFilter: "blur(16px)",
        }}
      >
        <div className="flex items-center gap-2 mb-1">
          <Shield size={14} className="text-violet-400" />
          <p className="text-white/70" style={{ fontSize: 12, fontWeight: 700 }}>
            Progressive Authentication
          </p>
        </div>
        {[
          { range: "< ₱100", label: "Tap-and-Go", desc: "Card tap only — instant checkout", color: "#10b981" },
          { range: "₱100–500", label: "Standard", desc: "Card write via NFC", color: "#06b6d4" },
          { range: "₱500–5k", label: "Elevated", desc: "Card write + PIN confirmation", color: "#f59e0b" },
          { range: "> ₱5k", label: "High-value", desc: "Card write + PIN + Email OTP", color: "#ef4444" },
        ].map((item) => (
          <div key={item.range} className="flex items-start gap-3">
            <div
              className="px-2 py-0.5 rounded-full flex-shrink-0 mt-0.5"
              style={{ background: `${item.color}22`, border: `1px solid ${item.color}44` }}
            >
              <span style={{ fontSize: 9, color: item.color, fontWeight: 800 }}>{item.range}</span>
            </div>
            <div>
              <p className="text-white" style={{ fontSize: 12, fontWeight: 600 }}>{item.label}</p>
              <p className="text-white/40" style={{ fontSize: 11 }}>{item.desc}</p>
            </div>
          </div>
        ))}
      </motion.div>
    </div>
  );
}

// ── Helpers ───────────────────────────────────────────────────────────────────

function delay(ms: number) {
  return new Promise((res) => setTimeout(res, ms));
}

function FlowNode({
  icon: Icon,
  label,
  sublabel,
  active,
  complete,
  color,
}: {
  icon: React.ElementType;
  label: string;
  sublabel: string;
  active: boolean;
  complete: boolean;
  color: string;
}) {
  return (
    <div className="flex flex-col items-center gap-2 flex-shrink-0" style={{ width: 72 }}>
      <motion.div
        animate={{
          boxShadow: complete
            ? `0 0 20px ${color}66`
            : active
            ? `0 0 14px ${color}44`
            : "none",
          scale: active || complete ? 1.05 : 1,
        }}
        className="w-14 h-14 rounded-2xl flex items-center justify-center"
        style={{
          background: active || complete ? `${color}33` : "rgba(255,255,255,0.05)",
          border: `1px solid ${active || complete ? color + "55" : "rgba(255,255,255,0.10)"}`,
          transition: "all 0.4s ease",
        }}
      >
        {complete ? (
          <CheckCircle size={22} style={{ color }} />
        ) : (
          <Icon size={22} style={{ color: active ? color : "rgba(255,255,255,0.25)" }} />
        )}
      </motion.div>
      <div className="text-center">
        <p className="text-white" style={{ fontSize: 10, fontWeight: 700, color: active || complete ? "white" : "rgba(255,255,255,0.4)" }}>
          {label}
        </p>
        <p className="text-white/30" style={{ fontSize: 9 }}>{sublabel}</p>
      </div>
    </div>
  );
}

function FlowArrow({
  active,
  complete,
  label,
}: {
  active: boolean;
  complete: boolean;
  label: string;
}) {
  return (
    <div className="flex flex-col items-center gap-1 flex-1 min-w-0 mx-1">
      <div className="relative w-full h-6 flex items-center">
        <div className="absolute inset-y-0 left-0 right-0 flex items-center">
          <div
            className="h-0.5 w-full"
            style={{
              background: complete
                ? "rgba(16,185,129,0.6)"
                : active
                ? "rgba(6,182,212,0.6)"
                : "rgba(255,255,255,0.10)",
            }}
          />
        </div>
        {active && (
          <>
            <motion.div
              className="absolute h-2 w-2 rounded-full"
              style={{ background: "#06b6d4", top: "50%", marginTop: -4 }}
              animate={{ left: ["0%", "100%"] }}
              transition={{ repeat: Infinity, duration: 0.9, ease: "linear" }}
            />
            <motion.div
              className="absolute h-2 w-2 rounded-full"
              style={{ background: "#06b6d4", top: "50%", marginTop: -4 }}
              animate={{ left: ["0%", "100%"] }}
              transition={{ repeat: Infinity, duration: 0.9, ease: "linear", delay: 0.45 }}
            />
          </>
        )}
        <div
          className="absolute right-0"
          style={{
            width: 0, height: 0,
            borderTop: "4px solid transparent",
            borderBottom: "4px solid transparent",
            borderLeft: `6px solid ${complete ? "rgba(16,185,129,0.7)" : active ? "rgba(6,182,212,0.7)" : "rgba(255,255,255,0.12)"}`,
          }}
        />
      </div>
      <p
        className="text-center"
        style={{
          fontSize: 8,
          color: active || complete ? "rgba(255,255,255,0.6)" : "rgba(255,255,255,0.2)",
          letterSpacing: "0.04em",
          fontWeight: 600,
          whiteSpace: "nowrap",
        }}
      >
        {label}
      </p>
    </div>
  );
}
