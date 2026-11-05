import { useState, useRef } from "react";
import { motion, AnimatePresence } from "motion/react";
import {
  Shield,
  Mail,
  Lock,
  User,
  ArrowLeft,
  Eye,
  EyeOff,
  CheckCircle,
  Wifi,
  Zap,
  ChevronRight,
} from "lucide-react";

type AuthView = "welcome" | "login" | "signup" | "register_card";

interface AuthScreenProps {
  onAuthSuccess: (data?: { name?: string; isNewUser?: boolean }) => void;
  isReturningUser?: boolean;
  onNFCTapUnlock?: () => void;
  onEnableTransaction?: () => void;
}

function delay(ms: number) {
  return new Promise((r) => setTimeout(r, ms));
}

// ── 4-Digit PIN Input ──────────────────────────────────────────────────────
function PinInput({
  value,
  onChange,
}: {
  value: string;
  onChange: (v: string) => void;
}) {
  const inputRef = useRef<HTMLInputElement>(null);

  function handleChange(e: React.ChangeEvent<HTMLInputElement>) {
    const raw = e.target.value.replace(/\D/g, "").slice(0, 4);
    onChange(raw);
  }

  return (
    <div className="flex flex-col gap-2">
      <label className="text-white/40" style={{ fontSize: 12, fontWeight: 600, letterSpacing: "0.08em" }}>
        4-DIGIT PIN
      </label>
      <div
        className="flex items-center gap-3 px-4 py-4 rounded-2xl cursor-text"
        style={{
          background: "rgba(255,255,255,0.06)",
          border: "1px solid rgba(255,255,255,0.10)",
        }}
        onClick={() => inputRef.current?.focus()}
      >
        <Lock size={18} style={{ color: "rgba(255,255,255,0.4)", flexShrink: 0 }} />
        {/* Hidden real input */}
        <input
          ref={inputRef}
          type="password"
          inputMode="numeric"
          pattern="[0-9]*"
          maxLength={4}
          value={value}
          onChange={handleChange}
          className="sr-only"
          autoComplete="current-password"
        />
        {/* Visual dots */}
        <div className="flex items-center gap-3 flex-1">
          {[0, 1, 2, 3].map((i) => (
            <motion.div
              key={i}
              animate={{
                scale: value.length > i ? 1.2 : 1,
                background: value.length > i ? "#a78bfa" : "rgba(255,255,255,0.18)",
              }}
              transition={{ type: "spring", stiffness: 500, damping: 30 }}
              className="w-3 h-3 rounded-full"
              style={{ background: "rgba(255,255,255,0.18)" }}
            />
          ))}
        </div>
        <span className="text-white/25" style={{ fontSize: 12 }}>
          {value.length}/4
        </span>
      </div>
    </div>
  );
}

// ── Email Field with validation ────────────────────────────────────────────
function EmailInput({
  value,
  onChange,
}: {
  value: string;
  onChange: (v: string) => void;
}) {
  const [touched, setTouched] = useState(false);
  const isValid = /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value);
  const showError = touched && value.length > 0 && !isValid;

  function handleChange(e: React.ChangeEvent<HTMLInputElement>) {
    // Strip spaces and disallow invalid chars mid-type
    const v = e.target.value.replace(/\s/g, "");
    onChange(v);
  }

  return (
    <div className="flex flex-col gap-1.5">
      <div
        className="flex items-center gap-3 px-4 py-4 rounded-2xl transition-all duration-200"
        style={{
          background: showError ? "rgba(239,68,68,0.07)" : "rgba(255,255,255,0.06)",
          border: showError
            ? "1px solid rgba(239,68,68,0.4)"
            : isValid && touched
            ? "1px solid rgba(16,185,129,0.4)"
            : "1px solid rgba(255,255,255,0.10)",
        }}
      >
        <Mail
          size={18}
          style={{
            color: showError
              ? "#f87171"
              : isValid && touched
              ? "#34d399"
              : "rgba(255,255,255,0.4)",
            flexShrink: 0,
          }}
        />
        <input
          type="email"
          placeholder="harry@example.com"
          value={value}
          onChange={handleChange}
          onBlur={() => setTouched(true)}
          className="flex-1 bg-transparent outline-none text-white placeholder-white/25"
          style={{ fontSize: 15 }}
          autoComplete="email"
          inputMode="email"
        />
        {isValid && touched && (
          <CheckCircle size={15} style={{ color: "#34d399", flexShrink: 0 }} />
        )}
      </div>
      {showError && (
        <motion.p
          initial={{ opacity: 0, y: -4 }}
          animate={{ opacity: 1, y: 0 }}
          className="text-red-400"
          style={{ fontSize: 11, paddingLeft: 4 }}
        >
          Enter a valid email (e.g. name@domain.com)
        </motion.p>
      )}
    </div>
  );
}

export function AuthScreen({
  onAuthSuccess,
  isReturningUser = false,
  onNFCTapUnlock,
  onEnableTransaction,
}: AuthScreenProps) {
  const [view, setView] = useState<AuthView>(isReturningUser ? "login" : "welcome");
  const [showPass, setShowPass] = useState(false);
  const [cardStep, setCardStep] = useState<"idle" | "scanning" | "success">("idle");
  const [loading, setLoading] = useState(false);
  const [nfcTapping, setNfcTapping] = useState(false);

  const [name, setName] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [pin, setPin] = useState("");

  async function handleLogin() {
    if (pin.length < 4) return;
    setLoading(true);
    await delay(900);
    setLoading(false);
    onAuthSuccess({ name: "Harry Dimaano", isNewUser: false });
  }

  async function handleSignupContinue() {
    setView("register_card");
  }

  async function handleCardRegister() {
    setCardStep("scanning");
    await delay(2200);
    setCardStep("success");
    await delay(1100);
    onAuthSuccess({ name: name || "Harry Dimaano", isNewUser: true });
  }

  async function handleNFCTap() {
    if (nfcTapping) return;
    setNfcTapping(true);
    await delay(1800);
    onNFCTapUnlock?.();
  }

  return (
    <div className="absolute inset-0 flex flex-col overflow-hidden" style={{ paddingTop: 52 }}>
      {/* Background glow */}
      <div
        className="absolute pointer-events-none"
        style={{
          top: -60,
          left: "50%",
          transform: "translateX(-50%)",
          width: 340,
          height: 340,
          borderRadius: "50%",
          background: "rgba(109,40,217,0.18)",
          filter: "blur(90px)",
        }}
      />

      <AnimatePresence mode="wait">
        {/* ─── WELCOME ─── */}
        {view === "welcome" && (
          <motion.div
            key="welcome"
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -16 }}
            transition={{ duration: 0.28 }}
            className="flex flex-col items-center justify-center flex-1 px-6 gap-8"
          >
            {/* Logo */}
            <div className="flex flex-col items-center gap-4">
              <motion.div
                animate={{ scale: [1, 1.06, 1] }}
                transition={{ repeat: Infinity, duration: 3, ease: "easeInOut" }}
                className="w-24 h-24 rounded-3xl flex items-center justify-center relative"
                style={{
                  background: "linear-gradient(135deg, #7c3aed22, #2563eb22)",
                  border: "1px solid rgba(139,92,246,0.4)",
                  boxShadow: "0 0 40px rgba(109,40,217,0.3)",
                }}
              >
                <Shield size={44} style={{ color: "#a78bfa" }} />
                <div
                  className="absolute inset-0 rounded-3xl"
                  style={{
                    background: "radial-gradient(circle at 50% 30%, rgba(167,139,250,0.15) 0%, transparent 70%)",
                  }}
                />
              </motion.div>

              <div className="text-center">
                <h1
                  className="text-white"
                  style={{ fontSize: 28, fontWeight: 900, letterSpacing: "-0.02em" }}
                >
                  SecureNFC Pay
                </h1>
                <p className="text-white/40" style={{ fontSize: 13, marginTop: 4 }}>
                  Java Card · Privacy-first · Tokenized
                </p>
              </div>
            </div>

            {/* Feature pills */}
            <div className="flex flex-col gap-2 w-full">
              {[
                { icon: Shield, label: "Hardware-secured Java Card auth", color: "#7c3aed" },
                { icon: Wifi, label: "NFC tap-to-authenticate", color: "#06b6d4" },
                { icon: Zap, label: "Single-use tokenized payments", color: "#f59e0b" },
              ].map(({ icon: Icon, label, color }) => (
                <div
                  key={label}
                  className="flex items-center gap-3 px-4 py-3 rounded-2xl"
                  style={{
                    background: "rgba(255,255,255,0.04)",
                    border: "1px solid rgba(255,255,255,0.07)",
                  }}
                >
                  <div
                    className="w-8 h-8 rounded-xl flex items-center justify-center flex-shrink-0"
                    style={{ background: `${color}22` }}
                  >
                    <Icon size={16} style={{ color }} />
                  </div>
                  <span className="text-white/70" style={{ fontSize: 13, fontWeight: 600 }}>
                    {label}
                  </span>
                </div>
              ))}
            </div>

            {/* Buttons */}
            <div className="w-full flex flex-col gap-3">
              <motion.button
                whileTap={{ scale: 0.97 }}
                onClick={() => setView("login")}
                className="w-full py-4 rounded-2xl flex items-center justify-center"
                style={{
                  background: "linear-gradient(135deg, #7c3aed, #2563eb)",
                  boxShadow: "0 8px 30px rgba(124,58,237,0.4)",
                }}
              >
                <span className="text-white" style={{ fontSize: 16, fontWeight: 800 }}>
                  Sign In
                </span>
              </motion.button>

              <motion.button
                whileTap={{ scale: 0.97 }}
                onClick={() => setView("signup")}
                className="w-full py-4 rounded-2xl flex items-center justify-center"
                style={{
                  background: "rgba(255,255,255,0.06)",
                  border: "1px solid rgba(255,255,255,0.12)",
                }}
              >
                <span className="text-white/80" style={{ fontSize: 16, fontWeight: 700 }}>
                  Create Account
                </span>
              </motion.button>
            </div>
          </motion.div>
        )}

        {/* ─── LOGIN ─── */}
        {view === "login" && (
          <motion.div
            key="login"
            initial={{ opacity: 0, x: 30 }}
            animate={{ opacity: 1, x: 0 }}
            exit={{ opacity: 0, x: -20 }}
            transition={{ duration: 0.25 }}
            className="flex flex-col flex-1 px-6 pt-4 gap-5 overflow-y-auto"
            style={{ scrollbarWidth: "none" }}
          >
            {!isReturningUser && (
              <button
                onClick={() => setView("welcome")}
                className="w-9 h-9 rounded-xl flex items-center justify-center self-start"
                style={{ background: "rgba(255,255,255,0.08)" }}
              >
                <ArrowLeft size={18} className="text-white" />
              </button>
            )}

            <div>
              <h2 className="text-white" style={{ fontSize: 26, fontWeight: 900 }}>
                Welcome back
              </h2>
              <p className="text-white/40" style={{ fontSize: 13, marginTop: 3 }}>
                Harry Dimaano · Enter your PIN to continue
              </p>
            </div>

            <div className="flex flex-col gap-3">
              {/* Email */}
              <EmailInput value={email} onChange={setEmail} />

              {/* 4-digit PIN */}
              <PinInput value={pin} onChange={setPin} />
            </div>

            <div className="text-right">
              <button className="text-violet-400" style={{ fontSize: 13, fontWeight: 600 }}>
                Forgot PIN?
              </button>
            </div>

            <motion.button
              whileTap={{ scale: 0.97 }}
              onClick={handleLogin}
              disabled={loading || pin.length < 4}
              className="w-full py-4 rounded-2xl flex items-center justify-center gap-2"
              style={{
                background: "linear-gradient(135deg, #7c3aed, #2563eb)",
                boxShadow: "0 8px 30px rgba(124,58,237,0.4)",
                opacity: loading || pin.length < 4 ? 0.6 : 1,
              }}
            >
              {loading ? (
                <motion.div
                  animate={{ rotate: 360 }}
                  transition={{ repeat: Infinity, duration: 0.8, ease: "linear" }}
                  className="w-5 h-5 border-2 border-white/30 border-t-white rounded-full"
                />
              ) : (
                <span className="text-white" style={{ fontSize: 16, fontWeight: 800 }}>
                  Sign In
                </span>
              )}
            </motion.button>

            {/* ── NFC Tap to Unlock (returning users) ── */}
            {isReturningUser && (
              <div className="flex flex-col gap-2">
                <div className="flex items-center gap-3">
                  <div className="flex-1 h-px" style={{ background: "rgba(255,255,255,0.08)" }} />
                  <span className="text-white/30" style={{ fontSize: 11 }}>or</span>
                  <div className="flex-1 h-px" style={{ background: "rgba(255,255,255,0.08)" }} />
                </div>

                <motion.button
                  whileTap={{ scale: 0.96 }}
                  onClick={handleNFCTap}
                  disabled={nfcTapping}
                  className="w-full py-4 rounded-2xl flex items-center justify-center gap-3 relative overflow-hidden"
                  style={{
                    background: "linear-gradient(135deg, rgba(6,182,212,0.25), rgba(37,99,235,0.2))",
                    border: "1px solid rgba(6,182,212,0.35)",
                    boxShadow: "0 4px 20px rgba(6,182,212,0.15)",
                  }}
                >
                  {nfcTapping ? (
                    <>
                      <motion.div
                        animate={{ rotate: 360 }}
                        transition={{ repeat: Infinity, duration: 0.9, ease: "linear" }}
                        className="w-5 h-5 border-2 border-cyan-300/30 border-t-cyan-300 rounded-full"
                      />
                      <span className="text-cyan-300" style={{ fontSize: 15, fontWeight: 700 }}>
                        Reading Java Card…
                      </span>
                    </>
                  ) : (
                    <>
                      <motion.div
                        animate={{ scale: [1, 1.15, 1] }}
                        transition={{ repeat: Infinity, duration: 1.8 }}
                      >
                        <Wifi size={20} style={{ color: "#06b6d4" }} />
                      </motion.div>
                      <span className="text-cyan-300" style={{ fontSize: 15, fontWeight: 700 }}>
                        Tap NFC Card to Unlock
                      </span>
                    </>
                  )}
                </motion.button>
              </div>
            )}

            {/* ── Enable Transaction shortcut (returning users) ── */}
            {isReturningUser && onEnableTransaction && (
              <motion.button
                whileTap={{ scale: 0.97 }}
                onClick={onEnableTransaction}
                className="w-full py-3.5 rounded-2xl flex items-center justify-between px-5 relative overflow-hidden"
                style={{
                  background:
                    "linear-gradient(135deg, rgba(109,40,217,0.45) 0%, rgba(6,182,212,0.35) 100%)",
                  border: "1px solid rgba(139,92,246,0.35)",
                  boxShadow: "0 6px 24px rgba(109,40,217,0.25)",
                }}
              >
                <motion.div
                  className="absolute inset-0 pointer-events-none"
                  animate={{ opacity: [0.3, 0.6, 0.3] }}
                  transition={{ repeat: Infinity, duration: 2.5 }}
                  style={{
                    background:
                      "radial-gradient(circle at 30% 50%, rgba(167,139,250,0.2) 0%, transparent 65%)",
                  }}
                />
                <div className="flex items-center gap-3 relative z-10">
                  <div
                    className="w-8 h-8 rounded-xl flex items-center justify-center"
                    style={{ background: "rgba(255,255,255,0.12)" }}
                  >
                    <Shield size={16} className="text-white" />
                  </div>
                  <div className="text-left">
                    <p className="text-white" style={{ fontSize: 13, fontWeight: 800 }}>
                      Enable Transaction
                    </p>
                    <p className="text-white/50" style={{ fontSize: 10 }}>
                      Go directly to NFC payment
                    </p>
                  </div>
                </div>
                <motion.div
                  animate={{ x: [0, 4, 0] }}
                  transition={{ repeat: Infinity, duration: 1.5 }}
                  className="relative z-10"
                >
                  <ChevronRight size={18} className="text-white/60" />
                </motion.div>
              </motion.button>
            )}

            <div className="text-center mt-1">
              <span className="text-white/40" style={{ fontSize: 14 }}>
                No account?{" "}
              </span>
              <button
                onClick={() => setView("signup")}
                className="text-violet-400"
                style={{ fontSize: 14, fontWeight: 700 }}
              >
                Create one
              </button>
            </div>

            {/* Info note */}
            <div
              className="mt-auto p-3 rounded-2xl flex items-center gap-3"
              style={{
                background: "rgba(6,182,212,0.08)",
                border: "1px solid rgba(6,182,212,0.2)",
              }}
            >
              <Wifi size={16} style={{ color: "#06b6d4", flexShrink: 0 }} />
              <p className="text-cyan-300/70" style={{ fontSize: 12 }}>
                After signing in, tap "Enable Transaction" or use NFC tap on this screen.
              </p>
            </div>
          </motion.div>
        )}

        {/* ─── SIGN UP ─── */}
        {view === "signup" && (
          <motion.div
            key="signup"
            initial={{ opacity: 0, x: 30 }}
            animate={{ opacity: 1, x: 0 }}
            exit={{ opacity: 0, x: -20 }}
            transition={{ duration: 0.25 }}
            className="flex flex-col flex-1 px-6 pt-4 gap-4"
          >
            <button
              onClick={() => setView("welcome")}
              className="w-9 h-9 rounded-xl flex items-center justify-center self-start"
              style={{ background: "rgba(255,255,255,0.08)" }}
            >
              <ArrowLeft size={18} className="text-white" />
            </button>

            <div>
              <h2 className="text-white" style={{ fontSize: 26, fontWeight: 900 }}>
                Create account
              </h2>
              <p className="text-white/40" style={{ fontSize: 13, marginTop: 3 }}>
                You'll register your Java Card after
              </p>
            </div>

            <div className="flex flex-col gap-3">
              {/* Name */}
              <div
                className="flex items-center gap-3 px-4 py-4 rounded-2xl"
                style={{
                  background: "rgba(255,255,255,0.06)",
                  border: "1px solid rgba(255,255,255,0.10)",
                }}
              >
                <User size={18} style={{ color: "rgba(255,255,255,0.4)" }} />
                <input
                  type="text"
                  placeholder="Full name"
                  value={name}
                  onChange={(e) => setName(e.target.value)}
                  className="flex-1 bg-transparent outline-none text-white placeholder-white/30"
                  style={{ fontSize: 15 }}
                  autoComplete="name"
                />
              </div>

              {/* Email */}
              <EmailInput value={email} onChange={setEmail} />

              {/* PIN for signup */}
              <PinInput value={pin} onChange={setPin} />

              {/* Confirm PIN */}
              <div className="flex flex-col gap-1">
                <div
                  className="flex items-center gap-3 px-4 py-4 rounded-2xl"
                  style={{
                    background: "rgba(255,255,255,0.06)",
                    border: "1px solid rgba(255,255,255,0.10)",
                  }}
                >
                  <Lock size={18} style={{ color: "rgba(255,255,255,0.4)" }} />
                  <input
                    type={showPass ? "text" : "password"}
                    placeholder="Confirm PIN"
                    value={password}
                    onChange={(e) => setPassword(e.target.value.replace(/\D/g, "").slice(0, 4))}
                    inputMode="numeric"
                    maxLength={4}
                    className="flex-1 bg-transparent outline-none text-white placeholder-white/30"
                    style={{ fontSize: 15 }}
                  />
                  <button onClick={() => setShowPass(!showPass)}>
                    {showPass ? (
                      <EyeOff size={16} style={{ color: "rgba(255,255,255,0.3)" }} />
                    ) : (
                      <Eye size={16} style={{ color: "rgba(255,255,255,0.3)" }} />
                    )}
                  </button>
                </div>
                {password.length === 4 && password !== pin && (
                  <motion.p
                    initial={{ opacity: 0, y: -4 }}
                    animate={{ opacity: 1, y: 0 }}
                    className="text-red-400"
                    style={{ fontSize: 11, paddingLeft: 4 }}
                  >
                    PINs do not match
                  </motion.p>
                )}
              </div>
            </div>

            <motion.button
              whileTap={{ scale: 0.97 }}
              onClick={handleSignupContinue}
              disabled={pin.length < 4 || password !== pin}
              className="w-full py-4 rounded-2xl flex items-center justify-center gap-2"
              style={{
                background: "linear-gradient(135deg, #7c3aed, #2563eb)",
                boxShadow: "0 8px 30px rgba(124,58,237,0.4)",
                opacity: pin.length < 4 || password !== pin ? 0.6 : 1,
              }}
            >
              <span className="text-white" style={{ fontSize: 16, fontWeight: 800 }}>
                Continue
              </span>
            </motion.button>

            <div className="text-center">
              <span className="text-white/40" style={{ fontSize: 14 }}>
                Already have an account?{" "}
              </span>
              <button
                onClick={() => setView("login")}
                className="text-violet-400"
                style={{ fontSize: 14, fontWeight: 700 }}
              >
                Sign in
              </button>
            </div>
          </motion.div>
        )}

        {/* ─── REGISTER JAVA CARD ─── */}
        {view === "register_card" && (
          <motion.div
            key="register_card"
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -16 }}
            transition={{ duration: 0.28 }}
            className="flex flex-col items-center flex-1 px-6 pt-4 gap-6"
          >
            <div className="text-center">
              <h2 className="text-white" style={{ fontSize: 24, fontWeight: 900 }}>
                Register Java Card
              </h2>
              <p className="text-white/40" style={{ fontSize: 13, marginTop: 4 }}>
                Tap your card once to bind it to your account
              </p>
            </div>

            {/* NFC tap animation */}
            <div className="relative flex items-center justify-center" style={{ width: 200, height: 200 }}>
              {cardStep === "idle" &&
                [0, 1, 2].map((i) => (
                  <motion.div
                    key={i}
                    className="absolute rounded-full"
                    style={{
                      width: 80 + i * 40,
                      height: 80 + i * 40,
                      border: "1px solid rgba(167,139,250,0.3)",
                    }}
                    animate={{ scale: [1, 1.15, 1], opacity: [0.4, 0.1, 0.4] }}
                    transition={{
                      repeat: Infinity,
                      duration: 2.2,
                      delay: i * 0.4,
                      ease: "easeInOut",
                    }}
                  />
                ))}

              {cardStep === "scanning" &&
                [0, 1].map((i) => (
                  <motion.div
                    key={i}
                    className="absolute rounded-full"
                    style={{
                      width: 100 + i * 50,
                      height: 100 + i * 50,
                      border: "2px solid rgba(6,182,212,0.5)",
                    }}
                    animate={{ scale: [1, 1.3], opacity: [0.6, 0] }}
                    transition={{
                      repeat: Infinity,
                      duration: 1.0,
                      delay: i * 0.5,
                      ease: "easeOut",
                    }}
                  />
                ))}

              <motion.div
                className="w-20 h-20 rounded-3xl flex items-center justify-center relative z-10"
                animate={
                  cardStep === "scanning"
                    ? { boxShadow: ["0 0 20px rgba(6,182,212,0.3)", "0 0 50px rgba(6,182,212,0.6)", "0 0 20px rgba(6,182,212,0.3)"] }
                    : cardStep === "success"
                    ? { boxShadow: "0 0 40px rgba(16,185,129,0.5)" }
                    : {}
                }
                transition={{ repeat: cardStep === "scanning" ? Infinity : 0, duration: 1 }}
                style={{
                  background:
                    cardStep === "success"
                      ? "linear-gradient(135deg, #05966933, #0891b233)"
                      : cardStep === "scanning"
                      ? "linear-gradient(135deg, #06b6d433, #2563eb33)"
                      : "linear-gradient(135deg, #7c3aed33, #2563eb33)",
                  border:
                    cardStep === "success"
                      ? "1px solid rgba(16,185,129,0.5)"
                      : cardStep === "scanning"
                      ? "1px solid rgba(6,182,212,0.5)"
                      : "1px solid rgba(139,92,246,0.4)",
                }}
              >
                {cardStep === "success" ? (
                  <motion.div
                    initial={{ scale: 0 }}
                    animate={{ scale: 1 }}
                    transition={{ type: "spring", stiffness: 400, damping: 18 }}
                  >
                    <CheckCircle size={36} style={{ color: "#34d399" }} />
                  </motion.div>
                ) : (
                  <Wifi
                    size={36}
                    style={{
                      color: cardStep === "scanning" ? "#06b6d4" : "#a78bfa",
                      filter:
                        cardStep === "scanning"
                          ? "drop-shadow(0 0 8px #06b6d4)"
                          : "drop-shadow(0 0 8px #a78bfa)",
                    }}
                  />
                )}
              </motion.div>
            </div>

            {/* Card illustration */}
            <div
              className="w-full p-4 rounded-3xl flex items-center gap-4"
              style={{
                background: "rgba(255,255,255,0.04)",
                border: "1px solid rgba(255,255,255,0.08)",
              }}
            >
              <div
                className="w-12 h-9 rounded-lg flex-shrink-0 flex items-center justify-center"
                style={{
                  background: "linear-gradient(135deg, #7c3aed, #2563eb)",
                  boxShadow: "0 4px 12px rgba(124,58,237,0.3)",
                }}
              >
                <div
                  className="w-6 h-4 rounded-sm"
                  style={{ background: "rgba(255,215,0,0.7)" }}
                />
              </div>
              <div>
                <p className="text-white" style={{ fontSize: 14, fontWeight: 700 }}>
                  {cardStep === "success" ? "Java Card Registered ✓" : "Java Card"}
                </p>
                <p className="text-white/40" style={{ fontSize: 12, marginTop: 1 }}>
                  {cardStep === "idle"
                    ? "Not yet linked to account"
                    : cardStep === "scanning"
                    ? "Reading secure element..."
                    : "Bound to your account"}
                </p>
              </div>
              {cardStep === "success" && (
                <motion.div
                  initial={{ scale: 0 }}
                  animate={{ scale: 1 }}
                  className="ml-auto"
                >
                  <CheckCircle size={20} style={{ color: "#34d399" }} />
                </motion.div>
              )}
            </div>

            {/* Instructions */}
            {cardStep === "idle" && (
              <p className="text-white/50 text-center" style={{ fontSize: 14 }}>
                Hold your Java Card against the back of your phone to register it
              </p>
            )}
            {cardStep === "scanning" && (
              <p className="text-cyan-300/70 text-center" style={{ fontSize: 14 }}>
                Reading card secure element…
              </p>
            )}
            {cardStep === "success" && (
              <p className="text-emerald-400 text-center" style={{ fontSize: 14, fontWeight: 700 }}>
                Card registered successfully!
              </p>
            )}

            {/* Tap button (simulates NFC) */}
            {cardStep === "idle" && (
              <motion.button
                whileTap={{ scale: 0.96 }}
                onClick={handleCardRegister}
                className="w-full py-4 rounded-2xl flex items-center justify-center gap-2"
                style={{
                  background: "linear-gradient(135deg, #7c3aed, #06b6d4)",
                  boxShadow: "0 8px 30px rgba(124,58,237,0.4)",
                }}
              >
                <Wifi size={18} className="text-white" />
                <span className="text-white" style={{ fontSize: 16, fontWeight: 800 }}>
                  Tap Java Card
                </span>
              </motion.button>
            )}
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}
