import { useState, useEffect, useRef, useCallback } from "react";
import { motion, AnimatePresence } from "motion/react";
import { Wifi, Shield, CheckCircle, AlertCircle, Zap, KeyRound, AlertTriangle } from "lucide-react";
import {
  isNFCSupported,
  readTagFromNFC,
  deserializePayload,
  isTokenValid,
} from "../services/nfcService";
import { isRevoked, verifyCardPin, hasCardPin } from "../services/cardRevocationService";

type UnlockStep = "idle" | "scanning" | "success" | "error" | "pin_fallback" | "pin_entry";

interface NFCUnlockScreenProps {
  userName?: string;
  onUnlocked: () => void;
}

const MAX_NFC_FAILURES = 3;

export function NFCUnlockScreen({ userName = "Juan", onUnlocked }: NFCUnlockScreenProps) {
  const [step, setStep] = useState<UnlockStep>("idle");
  const [failureCount, setFailureCount] = useState(0);
  const [errorMsg, setErrorMsg] = useState("");
  const [pinStr, setPinStr] = useState("");
  const [pinError, setPinError] = useState("");
  const abortRef = useRef<AbortController | null>(null);
  const nfcSupported = isNFCSupported();

  // ── Start passive NFC reading automatically on mount ─────────────────────

  const startNFCScan = useCallback(async () => {
    if (step === "scanning") return;
    setStep("scanning");
    setErrorMsg("");

    abortRef.current = new AbortController();

    if (nfcSupported) {
      const result = await readTagFromNFC(abortRef.current.signal);

      if (result.success && result.text) {
        // Validate payload
        const payload = deserializePayload(result.text);
        if (!payload) {
          handleScanFailure("Tag format unrecognised. This doesn't look like a valid card.");
          return;
        }
        if (isRevoked(payload.cardId)) {
          handleScanFailure("This card has been remotely revoked. Contact support.");
          return;
        }
        if (!isTokenValid(payload)) {
          handleScanFailure("Token has expired. Please re-arm your card in the app.");
          return;
        }
        // All checks passed
        setStep("success");
        setTimeout(onUnlocked, 1100);
        return;
      }

      if (result.error === "NFC scan cancelled.") {
        // Intentionally aborted — don't count as failure
        return;
      }
      handleScanFailure(result.error ?? "Could not read card.");
    } else {
      // Simulation fallback: 90% pass, 10% fail
      await delay(2000);
      if (Math.random() > 0.1) {
        setStep("success");
        setTimeout(onUnlocked, 1100);
      } else {
        handleScanFailure("Card not recognised (simulated failure).");
      }
    }
  }, [nfcSupported, onUnlocked, step]);

  // Auto-start scan on mount
  useEffect(() => {
    // Small delay so the screen renders first
    const t = setTimeout(() => startNFCScan(), 600);
    return () => {
      clearTimeout(t);
      abortRef.current?.abort();
    };
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  function handleScanFailure(msg: string) {
    const newCount = failureCount + 1;
    setFailureCount(newCount);
    if (newCount >= MAX_NFC_FAILURES) {
      setStep("pin_fallback");
      setErrorMsg(msg);
    } else {
      setErrorMsg(msg);
      setStep("error");
    }
  }

  function handleRetry() {
    abortRef.current?.abort();
    setStep("idle");
    setErrorMsg("");
    setTimeout(() => startNFCScan(), 300);
  }

  function handleUsePIN() {
    setStep("pin_entry");
    setPinStr("");
    setPinError("");
  }

  function handlePINSubmit() {
    if (!hasCardPin()) {
      // No PIN ever set — auto-allow for demo
      setStep("success");
      setTimeout(onUnlocked, 1100);
      return;
    }
    if (verifyCardPin(pinStr)) {
      setStep("success");
      setTimeout(onUnlocked, 1100);
    } else {
      setPinError("Incorrect PIN. Try again.");
      setPinStr("");
    }
  }

  return (
    <div
      className="absolute inset-0 flex flex-col items-center justify-between px-6"
      style={{ paddingTop: 70, paddingBottom: 60 }}
    >
      {/* Background center glow */}
      <div
        className="absolute pointer-events-none"
        style={{
          top: "30%",
          left: "50%",
          transform: "translate(-50%, -50%)",
          width: 320,
          height: 320,
          borderRadius: "50%",
          background:
            step === "success"
              ? "rgba(16,185,129,0.12)"
              : step === "error" || step === "pin_fallback"
              ? "rgba(239,68,68,0.10)"
              : step === "scanning"
              ? "rgba(6,182,212,0.12)"
              : "rgba(109,40,217,0.14)",
          filter: "blur(80px)",
          transition: "background 0.6s ease",
        }}
      />

      {/* Top greeting */}
      <div className="text-center z-10">
        <p className="text-white/40" style={{ fontSize: 14 }}>Welcome back,</p>
        <h1 className="text-white" style={{ fontSize: 28, fontWeight: 900, marginTop: 2 }}>
          {userName}
        </h1>
      </div>

      {/* ── PIN Entry ── */}
      {(step === "pin_entry") && (
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          className="w-full z-10 space-y-4"
        >
          <div className="text-center mb-2">
            <KeyRound size={36} className="mx-auto mb-3" style={{ color: "#a78bfa" }} />
            <h2 className="text-white" style={{ fontSize: 20, fontWeight: 900 }}>Enter Card PIN</h2>
            <p className="text-white/40" style={{ fontSize: 12, marginTop: 4 }}>
              NFC failed {MAX_NFC_FAILURES} times — use your backup PIN
            </p>
          </div>
          <div
            className="rounded-2xl p-4"
            style={{ background: "rgba(255,255,255,0.05)", border: "1px solid rgba(255,255,255,0.12)" }}
          >
            <input
              type="password"
              inputMode="numeric"
              value={pinStr}
              onChange={(e) => { setPinStr(e.target.value.replace(/\D/g, "").slice(0, 6)); setPinError(""); }}
              placeholder="● ● ● ●"
              autoFocus
              className="w-full bg-transparent text-white outline-none text-center tracking-widest"
              style={{ fontSize: 28, fontWeight: 800 }}
            />
          </div>
          {pinError && (
            <p className="text-red-400 text-center" style={{ fontSize: 12 }}>{pinError}</p>
          )}
          {!hasCardPin() && (
            <p className="text-amber-400/60 text-center" style={{ fontSize: 11 }}>
              ⚠ No card PIN set. Any entry will be accepted (demo mode).
            </p>
          )}
          <motion.button
            whileTap={{ scale: 0.97 }}
            onClick={handlePINSubmit}
            className="w-full py-4 rounded-2xl"
            style={{
              background: "linear-gradient(135deg, #7c3aed, #2563eb)",
              color: "white", fontSize: 16, fontWeight: 800,
            }}
          >
            Unlock with PIN
          </motion.button>
        </motion.div>
      )}

      {/* ── NFC Animation (non-PIN steps) ── */}
      {step !== "pin_entry" && (
        <div className="relative flex flex-col items-center gap-8 z-10">
          {/* Phone + card illustration */}
          <div className="relative" style={{ width: 160, height: 200 }}>
            {/* Phone body */}
            <motion.div
              className="absolute rounded-3xl"
              style={{
                width: 100, height: 180,
                left: "50%", top: "50%",
                transform: "translate(-50%, -50%)",
                background: "linear-gradient(160deg, #1a0840 0%, #080022 100%)",
                border: "2px solid rgba(255,255,255,0.12)",
                boxShadow: "0 20px 60px rgba(0,0,0,0.5)",
              }}
            >
              <div
                className="absolute rounded-2xl"
                style={{
                  top: 10, left: 6, right: 6, bottom: 10,
                  background: "linear-gradient(160deg, #0d0230, #070018)",
                  display: "flex", alignItems: "center", justifyContent: "center",
                }}
              >
                <Shield
                  size={28}
                  style={{
                    color: step === "success" ? "#34d399" : step === "error" || step === "pin_fallback" ? "#f87171" : "#a78bfa",
                  }}
                />
              </div>
            </motion.div>

            {/* NFC card floating */}
            <motion.div
              animate={
                step === "scanning"
                  ? { x: -50, y: 20, rotate: -15, opacity: 1 }
                  : step === "success"
                  ? { x: -20, y: 70, rotate: -5, opacity: 0.7 }
                  : step === "error" || step === "pin_fallback"
                  ? { x: -60, y: 10, rotate: -20, opacity: 0.6 }
                  : { x: -70, y: -10, rotate: -20, opacity: 0.9 }
              }
              transition={{ type: "spring", stiffness: 200, damping: 20 }}
              className="absolute rounded-xl"
              style={{
                width: 72, height: 46,
                background: "linear-gradient(135deg, #7c3aed, #2563eb)",
                boxShadow: "0 8px 24px rgba(124,58,237,0.5)",
                border: "1px solid rgba(255,255,255,0.2)",
                display: "flex", alignItems: "center", justifyContent: "center",
              }}
            >
              <div className="rounded-sm" style={{ width: 28, height: 20, background: "rgba(255,215,0,0.6)" }} />
            </motion.div>

            {/* NFC pulse rings */}
            <AnimatePresence>
              {step === "scanning" &&
                [0, 1, 2].map((i) => (
                  <motion.div
                    key={i}
                    initial={{ scale: 0.8, opacity: 0.6 }}
                    animate={{ scale: 1.8, opacity: 0 }}
                    transition={{ repeat: Infinity, duration: 1.5, delay: i * 0.45, ease: "easeOut" }}
                    className="absolute rounded-full pointer-events-none"
                    style={{
                      width: 40, height: 40,
                      left: "50%", top: "50%",
                      transform: "translate(-50%, -50%)",
                      border: "2px solid rgba(6,182,212,0.5)",
                    }}
                  />
                ))}
            </AnimatePresence>
          </div>

          {/* Status label */}
          <AnimatePresence mode="wait">
            <motion.div
              key={step}
              initial={{ opacity: 0, y: 6 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0, y: -6 }}
              transition={{ duration: 0.2 }}
              className="text-center"
            >
              {step === "idle" && (
                <>
                  <h2 className="text-white" style={{ fontSize: 22, fontWeight: 900 }}>
                    {nfcSupported ? "Hold NFC Card to Phone" : "Tap to authenticate"}
                  </h2>
                  <p className="text-white/40" style={{ fontSize: 13, marginTop: 4 }}>
                    {nfcSupported
                      ? "Bring your NFC card to the back of your phone"
                      : "Simulated NFC — for testing only"}
                  </p>
                </>
              )}
              {step === "scanning" && (
                <>
                  <h2 className="text-cyan-300" style={{ fontSize: 22, fontWeight: 900 }}>
                    {nfcSupported ? "Hold card steady…" : "Scanning…"}
                  </h2>
                  <p className="text-white/40" style={{ fontSize: 13, marginTop: 4 }}>
                    Authenticating secure element
                  </p>
                </>
              )}
              {step === "success" && (
                <>
                  <h2 className="text-emerald-400" style={{ fontSize: 22, fontWeight: 900 }}>Card Authenticated</h2>
                  <p className="text-white/40" style={{ fontSize: 13, marginTop: 4 }}>
                    Session unlocked — entering app…
                  </p>
                </>
              )}
              {(step === "error" || step === "pin_fallback") && (
                <>
                  <h2 className="text-red-400" style={{ fontSize: 20, fontWeight: 900 }}>
                    {step === "pin_fallback" ? `${MAX_NFC_FAILURES} Failures — Use PIN` : "Authentication Failed"}
                  </h2>
                  <p className="text-white/40" style={{ fontSize: 12, marginTop: 4, maxWidth: 240 }}>
                    {errorMsg || "Card not recognised."}
                  </p>
                  {step === "error" && (
                    <p className="text-white/25" style={{ fontSize: 11, marginTop: 4 }}>
                      Attempt {failureCount} of {MAX_NFC_FAILURES}
                    </p>
                  )}
                </>
              )}
            </motion.div>
          </AnimatePresence>

          {/* Session info card */}
          <motion.div
            animate={
              step === "success"
                ? { borderColor: "rgba(16,185,129,0.4)", background: "rgba(16,185,129,0.08)" }
                : step === "error" || step === "pin_fallback"
                ? { borderColor: "rgba(239,68,68,0.4)", background: "rgba(239,68,68,0.06)" }
                : step === "scanning"
                ? { borderColor: "rgba(6,182,212,0.3)", background: "rgba(6,182,212,0.06)" }
                : {}
            }
            transition={{ duration: 0.4 }}
            className="w-full p-4 rounded-2xl"
            style={{ background: "rgba(255,255,255,0.05)", border: "1px solid rgba(255,255,255,0.10)" }}
          >
            <div className="flex items-center justify-between mb-3">
              <span className="text-white/60" style={{ fontSize: 12, fontWeight: 600, letterSpacing: "0.08em" }}>
                SESSION STATUS
              </span>
              {step === "success" ? (
                <CheckCircle size={14} style={{ color: "#34d399" }} />
              ) : step === "error" || step === "pin_fallback" ? (
                <AlertCircle size={14} style={{ color: "#f87171" }} />
              ) : (
                <div className="w-2 h-2 rounded-full" style={{ background: step === "scanning" ? "#06b6d4" : "rgba(255,255,255,0.2)" }} />
              )}
            </div>
            <div className="flex flex-col gap-2">
              {[
                {
                  label: "Card Status",
                  value:
                    step === "success" ? "Authenticated ✓"
                    : step === "error" || step === "pin_fallback" ? `Failed (${failureCount}/${MAX_NFC_FAILURES})`
                    : step === "scanning" ? "Reading…"
                    : "Pending",
                  color:
                    step === "success" ? "#34d399"
                    : step === "error" || step === "pin_fallback" ? "#f87171"
                    : step === "scanning" ? "#06b6d4"
                    : "rgba(255,255,255,0.4)",
                },
                {
                  label: "Mode",
                  value: nfcSupported ? "Real NFC" : "Simulation",
                  color: nfcSupported ? "#a78bfa" : "#f59e0b",
                },
                {
                  label: "Fallback",
                  value: step === "pin_fallback" || step === "pin_entry" ? "PIN Active" : `${MAX_NFC_FAILURES - failureCount} tries left`,
                  color: step === "pin_fallback" ? "#f87171" : "rgba(255,255,255,0.3)",
                },
              ].map(({ label, value, color }) => (
                <div key={label} className="flex items-center justify-between">
                  <span className="text-white/40" style={{ fontSize: 12 }}>{label}</span>
                  <span style={{ fontSize: 12, fontWeight: 700, color }}>{value}</span>
                </div>
              ))}
            </div>
          </motion.div>
        </div>
      )}

      {/* Bottom action buttons */}
      <div className="w-full z-10 space-y-2">
        {step === "idle" && (
          <motion.button
            whileTap={{ scale: 0.96 }}
            onClick={() => startNFCScan()}
            className="w-full py-4 rounded-2xl flex items-center justify-center gap-2"
            style={{
              background: "linear-gradient(135deg, #7c3aed, #2563eb)",
              boxShadow: "0 8px 30px rgba(124,58,237,0.4)",
            }}
          >
            <Wifi size={18} className="text-white" />
            <span className="text-white" style={{ fontSize: 16, fontWeight: 800 }}>
              {nfcSupported ? "Start NFC Scan" : "Simulate Tap"}
            </span>
          </motion.button>
        )}

        {step === "scanning" && (
          <div
            className="w-full py-4 rounded-2xl flex items-center justify-center gap-2"
            style={{ background: "rgba(6,182,212,0.12)", border: "1px solid rgba(6,182,212,0.25)" }}
          >
            <motion.div
              animate={{ rotate: 360 }}
              transition={{ repeat: Infinity, duration: 0.9, ease: "linear" }}
              className="w-5 h-5 border-2 border-cyan-300/30 border-t-cyan-300 rounded-full"
            />
            <span className="text-cyan-300" style={{ fontSize: 15, fontWeight: 700 }}>
              {nfcSupported ? "Waiting for NFC card…" : "Scanning…"}
            </span>
          </div>
        )}

        {step === "error" && (
          <div className="flex gap-2">
            <motion.button
              whileTap={{ scale: 0.96 }}
              onClick={handleRetry}
              className="flex-1 py-4 rounded-2xl flex items-center justify-center gap-2"
              style={{
                background: "linear-gradient(135deg, #7c3aed, #2563eb)",
                boxShadow: "0 8px 30px rgba(124,58,237,0.3)",
              }}
            >
              <Wifi size={18} className="text-white" />
              <span className="text-white" style={{ fontSize: 15, fontWeight: 800 }}>Retry</span>
            </motion.button>
            <button
              onClick={handleUsePIN}
              className="px-4 py-4 rounded-2xl flex items-center gap-1.5"
              style={{ background: "rgba(255,255,255,0.06)", border: "1px solid rgba(255,255,255,0.10)" }}
            >
              <KeyRound size={16} className="text-white/50" />
              <span className="text-white/50" style={{ fontSize: 12, fontWeight: 600 }}>PIN</span>
            </button>
          </div>
        )}

        {step === "pin_fallback" && (
          <motion.button
            whileTap={{ scale: 0.96 }}
            onClick={handleUsePIN}
            className="w-full py-4 rounded-2xl flex items-center justify-center gap-2"
            style={{
              background: "linear-gradient(135deg, #ef4444, #dc2626)",
              boxShadow: "0 8px 30px rgba(239,68,68,0.3)",
            }}
          >
            <KeyRound size={18} className="text-white" />
            <span className="text-white" style={{ fontSize: 16, fontWeight: 800 }}>
              Use Card PIN
            </span>
          </motion.button>
        )}

        {step === "success" && (
          <motion.div
            initial={{ opacity: 0, y: 6 }}
            animate={{ opacity: 1, y: 0 }}
            className="w-full py-4 rounded-2xl flex items-center justify-center gap-2"
            style={{ background: "rgba(16,185,129,0.12)", border: "1px solid rgba(16,185,129,0.3)" }}
          >
            <Zap size={18} style={{ color: "#34d399" }} />
            <span style={{ color: "#34d399", fontSize: 15, fontWeight: 700 }}>Entering app…</span>
          </motion.div>
        )}

        {/* NFC not supported warning */}
        {!nfcSupported && step !== "pin_entry" && (
          <p className="text-center text-amber-400/50" style={{ fontSize: 10 }}>
            Web NFC not available · Running simulation
          </p>
        )}
      </div>
    </div>
  );
}

function delay(ms: number) {
  return new Promise((r) => setTimeout(r, ms));
}
