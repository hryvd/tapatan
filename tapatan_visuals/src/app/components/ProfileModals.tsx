'use client';

import React, { useState, useEffect, useRef, useCallback } from 'react';
import { motion, AnimatePresence } from 'motion/react';
import {
  X,
  User,
  Mail,
  Phone,
  Calendar,
  Save,
  CheckCircle2,
  Lock,
  ArrowLeft,
  Shield,
  Eye,
  Bell,
  MailCheck,
  Nfc,
  CreditCard,
  Vibrate,
  Volume2,
  Unlink,
  HelpCircle,
  ChevronDown,
  MessageCircle,
  Crown,
  Zap,
  BarChart3,
  Layers,
  Headphones,
  Sparkles,
  Check,
} from 'lucide-react';

/* ──────────────────────────────────────────────
   Shared styles & helpers
   ────────────────────────────────────────────── */

const overlayStyle: React.CSSProperties = {
  position: 'fixed',
  inset: 0,
  zIndex: 100,
  background: 'rgba(0,0,0,0.65)',
  backdropFilter: 'blur(12px)',
  WebkitBackdropFilter: 'blur(12px)',
};

const panelGlass: React.CSSProperties = {
  background: 'rgba(15,10,40,0.92)',
  borderBottom: '1px solid rgba(255,255,255,0.08)',
};

const cardGlass: React.CSSProperties = {
  background: 'rgba(255,255,255,0.05)',
  border: '1px solid rgba(255,255,255,0.08)',
  borderRadius: 16,
  backdropFilter: 'blur(12px)',
};

const inputStyle: React.CSSProperties = {
  background: 'rgba(255,255,255,0.06)',
  border: '1px solid rgba(255,255,255,0.1)',
  borderRadius: 12,
  color: '#fff',
  fontSize: 15,
  padding: '12px 14px',
  outline: 'none',
  width: '100%',
  transition: 'border-color 0.2s',
};

const primaryBtnStyle: React.CSSProperties = {
  background: 'linear-gradient(135deg, #7c3aed, #3b82f6, #06b6d4)',
  color: '#fff',
  fontWeight: 600,
  fontSize: 15,
  border: 'none',
  borderRadius: 14,
  padding: '14px 0',
  cursor: 'pointer',
  width: '100%',
};

const closeButtonStyle: React.CSSProperties = {
  background: 'rgba(255,255,255,0.08)',
  border: '1px solid rgba(255,255,255,0.1)',
  borderRadius: 10,
  color: '#94a3b8',
  cursor: 'pointer',
  display: 'flex',
  alignItems: 'center',
  justifyContent: 'center',
  width: 36,
  height: 36,
};

const slideUp = {
  initial: { y: '100%', opacity: 0 },
  animate: { y: 0, opacity: 1, transition: { type: 'spring', damping: 30, stiffness: 300 } },
  exit: { y: '100%', opacity: 0, transition: { duration: 0.25 } },
};

const fadeScale = {
  initial: { scale: 0.92, opacity: 0 },
  animate: { scale: 1, opacity: 1, transition: { type: 'spring', damping: 26, stiffness: 300 } },
  exit: { scale: 0.92, opacity: 0, transition: { duration: 0.2 } },
};

const overlayMotion = {
  initial: { opacity: 0 },
  animate: { opacity: 1, transition: { duration: 0.2 } },
  exit: { opacity: 0, transition: { duration: 0.2 } },
};

/* ──────────────────────────────────────────────
   Toggle Component
   ────────────────────────────────────────────── */

interface ToggleRowProps {
  icon: React.ReactNode;
  label: string;
  description: string;
  value: boolean;
  onChange: (v: boolean) => void;
}

function ToggleRow({ icon, label, description, value, onChange }: ToggleRowProps) {
  return (
    <div className="flex items-start gap-3 py-4" style={{ borderBottom: '1px solid rgba(255,255,255,0.06)' }}>
      <div
        className="flex items-center justify-center shrink-0"
        style={{
          width: 40,
          height: 40,
          borderRadius: 12,
          background: 'rgba(124,58,237,0.15)',
          color: '#a78bfa',
          marginTop: 2,
        }}
      >
        {icon}
      </div>
      <div className="flex-1 min-w-0">
        <p style={{ color: '#fff', fontSize: 14, fontWeight: 500, margin: 0 }}>{label}</p>
        <p style={{ color: '#64748b', fontSize: 12, margin: '4px 0 0' }}>{description}</p>
      </div>
      <button
        onClick={() => onChange(!value)}
        className="shrink-0"
        style={{
          width: 48,
          height: 28,
          borderRadius: 14,
          border: 'none',
          cursor: 'pointer',
          background: value
            ? 'linear-gradient(135deg, #7c3aed, #3b82f6)'
            : 'rgba(255,255,255,0.1)',
          position: 'relative',
          transition: 'background 0.3s',
          marginTop: 4,
        }}
      >
        <motion.div
          animate={{ x: value ? 20 : 2 }}
          transition={{ type: 'spring', stiffness: 500, damping: 30 }}
          style={{
            width: 22,
            height: 22,
            borderRadius: '50%',
            background: '#fff',
            position: 'absolute',
            top: 3,
            left: 0,
            boxShadow: '0 2px 6px rgba(0,0,0,0.25)',
          }}
        />
      </button>
    </div>
  );
}

/* ──────────────────────────────────────────────
   1. PersonalInfoPanel
   ────────────────────────────────────────────── */

interface ModalProps {
  isOpen: boolean;
  onClose: () => void;
}

export function PersonalInfoPanel({ isOpen, onClose }: ModalProps) {
  const [fullName, setFullName] = useState('Juan dela Cruz');
  const [email, setEmail] = useState('juan.delacruz@gcash.com');
  const [phone, setPhone] = useState('+63 917 123 4567');
  const [dob, setDob] = useState('1995-06-15');
  const [saved, setSaved] = useState(false);

  const handleSave = useCallback(() => {
    setSaved(true);
    setTimeout(() => {
      setSaved(false);
      onClose();
    }, 2000);
  }, [onClose]);

  return (
    <AnimatePresence>
      {isOpen && (
        <motion.div {...overlayMotion} style={overlayStyle} className="flex flex-col">
          <motion.div
            {...slideUp}
            className="flex flex-col flex-1 overflow-y-auto"
            style={{ background: 'rgba(8,5,28,0.98)' }}
          >
            {/* Header */}
            <div className="flex items-center justify-between px-5 py-4" style={panelGlass}>
              <div className="flex items-center gap-3">
                <div
                  className="flex items-center justify-center"
                  style={{
                    width: 36,
                    height: 36,
                    borderRadius: 10,
                    background: 'linear-gradient(135deg, #7c3aed, #3b82f6)',
                  }}
                >
                  <User size={18} color="#fff" />
                </div>
                <span style={{ color: '#fff', fontSize: 17, fontWeight: 600 }}>Personal Information</span>
              </div>
              <button onClick={onClose} style={closeButtonStyle}>
                <X size={18} />
              </button>
            </div>

            {/* Form */}
            <div className="flex flex-col gap-5 p-5">
              {/* Full Name */}
              <div className="flex flex-col gap-2">
                <label className="flex items-center gap-2" style={{ color: '#94a3b8', fontSize: 13, fontWeight: 500 }}>
                  <User size={14} /> Full Name
                </label>
                <input
                  type="text"
                  value={fullName}
                  onChange={(e) => setFullName(e.target.value)}
                  style={inputStyle}
                  onFocus={(e) => (e.currentTarget.style.borderColor = 'rgba(124,58,237,0.5)')}
                  onBlur={(e) => (e.currentTarget.style.borderColor = 'rgba(255,255,255,0.1)')}
                />
              </div>

              {/* Email */}
              <div className="flex flex-col gap-2">
                <label className="flex items-center gap-2" style={{ color: '#94a3b8', fontSize: 13, fontWeight: 500 }}>
                  <Mail size={14} /> Email Address
                </label>
                <input
                  type="email"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  style={inputStyle}
                  onFocus={(e) => (e.currentTarget.style.borderColor = 'rgba(124,58,237,0.5)')}
                  onBlur={(e) => (e.currentTarget.style.borderColor = 'rgba(255,255,255,0.1)')}
                />
              </div>

              {/* Phone */}
              <div className="flex flex-col gap-2">
                <label className="flex items-center gap-2" style={{ color: '#94a3b8', fontSize: 13, fontWeight: 500 }}>
                  <Phone size={14} /> Phone Number
                </label>
                <input
                  type="tel"
                  value={phone}
                  onChange={(e) => setPhone(e.target.value)}
                  style={inputStyle}
                  onFocus={(e) => (e.currentTarget.style.borderColor = 'rgba(124,58,237,0.5)')}
                  onBlur={(e) => (e.currentTarget.style.borderColor = 'rgba(255,255,255,0.1)')}
                />
              </div>

              {/* Date of Birth */}
              <div className="flex flex-col gap-2">
                <label className="flex items-center gap-2" style={{ color: '#94a3b8', fontSize: 13, fontWeight: 500 }}>
                  <Calendar size={14} /> Date of Birth
                </label>
                <input
                  type="date"
                  value={dob}
                  onChange={(e) => setDob(e.target.value)}
                  style={{ ...inputStyle, colorScheme: 'dark' }}
                  onFocus={(e) => (e.currentTarget.style.borderColor = 'rgba(124,58,237,0.5)')}
                  onBlur={(e) => (e.currentTarget.style.borderColor = 'rgba(255,255,255,0.1)')}
                />
              </div>

              {/* Save */}
              <motion.button
                whileHover={{ scale: 1.02 }}
                whileTap={{ scale: 0.97 }}
                onClick={handleSave}
                className="flex items-center justify-center gap-2 mt-3"
                style={primaryBtnStyle}
              >
                <Save size={18} /> Save Changes
              </motion.button>
            </div>

            {/* Success toast */}
            <AnimatePresence>
              {saved && (
                <motion.div
                  initial={{ y: 60, opacity: 0 }}
                  animate={{ y: 0, opacity: 1 }}
                  exit={{ y: 60, opacity: 0 }}
                  className="fixed bottom-8 left-1/2 flex items-center gap-2 px-5 py-3"
                  style={{
                    transform: 'translateX(-50%)',
                    background: 'rgba(16,185,129,0.18)',
                    border: '1px solid rgba(16,185,129,0.3)',
                    borderRadius: 14,
                    color: '#34d399',
                    fontSize: 14,
                    fontWeight: 500,
                    zIndex: 110,
                    backdropFilter: 'blur(16px)',
                  }}
                >
                  <CheckCircle2 size={18} /> Changes saved successfully
                </motion.div>
              )}
            </AnimatePresence>
          </motion.div>
        </motion.div>
      )}
    </AnimatePresence>
  );
}

/* ──────────────────────────────────────────────
   2. ChangePINModal
   ────────────────────────────────────────────── */

export function ChangePINModal({ isOpen, onClose }: ModalProps) {
  const [step, setStep] = useState(1);
  const [currentPin, setCurrentPin] = useState('');
  const [newPin, setNewPin] = useState('');
  const [confirmPin, setConfirmPin] = useState('');
  const hiddenInputRef = useRef<HTMLInputElement>(null);

  // Reset on close
  useEffect(() => {
    if (!isOpen) {
      setTimeout(() => {
        setStep(1);
        setCurrentPin('');
        setNewPin('');
        setConfirmPin('');
      }, 300);
    }
  }, [isOpen]);

  const activePin = step === 1 ? currentPin : step === 2 ? newPin : confirmPin;
  const setActivePin = step === 1 ? setCurrentPin : step === 2 ? setNewPin : setConfirmPin;

  const handleInput = useCallback(
    (value: string) => {
      const clean = value.replace(/\D/g, '').slice(0, 4);
      setActivePin(clean);
      if (clean.length === 4) {
        setTimeout(() => {
          if (step < 3) {
            setStep(step + 1);
          } else {
            setStep(4);
          }
        }, 400);
      }
    },
    [step, setActivePin],
  );

  const stepLabels = ['Enter Current PIN', 'Enter New PIN', 'Confirm New PIN', 'PIN Changed!'];
  const stepDescriptions = [
    'Enter your current 4-digit PIN to continue',
    'Choose a strong 4-digit PIN',
    'Re-enter your new PIN to confirm',
    'Your PIN has been updated successfully',
  ];

  return (
    <AnimatePresence>
      {isOpen && (
        <motion.div
          {...overlayMotion}
          style={overlayStyle}
          className="flex items-center justify-center p-5"
          onClick={onClose}
        >
          <motion.div
            {...fadeScale}
            onClick={(e) => e.stopPropagation()}
            className="w-full flex flex-col"
            style={{
              ...cardGlass,
              maxWidth: 380,
              background: 'rgba(15,10,40,0.95)',
              padding: 0,
              overflow: 'hidden',
            }}
          >
            {/* Header */}
            <div className="flex items-center justify-between px-5 pt-5 pb-3">
              <div className="flex items-center gap-3">
                {step > 1 && step < 4 && (
                  <motion.button
                    initial={{ opacity: 0, x: -8 }}
                    animate={{ opacity: 1, x: 0 }}
                    whileTap={{ scale: 0.9 }}
                    onClick={() => {
                      if (step === 2) { setNewPin(''); setStep(1); }
                      else if (step === 3) { setConfirmPin(''); setStep(2); }
                    }}
                    style={{ ...closeButtonStyle, width: 32, height: 32 }}
                  >
                    <ArrowLeft size={16} />
                  </motion.button>
                )}
                <div
                  className="flex items-center justify-center"
                  style={{
                    width: 36,
                    height: 36,
                    borderRadius: 10,
                    background: step === 4 ? 'rgba(16,185,129,0.2)' : 'linear-gradient(135deg, #7c3aed, #3b82f6)',
                  }}
                >
                  {step === 4 ? <CheckCircle2 size={18} color="#34d399" /> : <Lock size={18} color="#fff" />}
                </div>
                <span style={{ color: '#fff', fontSize: 16, fontWeight: 600 }}>Change PIN</span>
              </div>
              <button onClick={onClose} style={closeButtonStyle}>
                <X size={18} />
              </button>
            </div>

            {/* Step indicators */}
            <div className="flex gap-2 px-5 pb-2">
              {[1, 2, 3, 4].map((s) => (
                <div
                  key={s}
                  className="flex-1"
                  style={{
                    height: 3,
                    borderRadius: 2,
                    background: s <= step ? 'linear-gradient(90deg, #7c3aed, #3b82f6)' : 'rgba(255,255,255,0.08)',
                    transition: 'background 0.3s',
                  }}
                />
              ))}
            </div>

            {/* Content */}
            <div className="flex flex-col items-center px-6 py-8 gap-3">
              <AnimatePresence mode="wait">
                <motion.div
                  key={step}
                  initial={{ opacity: 0, y: 12 }}
                  animate={{ opacity: 1, y: 0 }}
                  exit={{ opacity: 0, y: -12 }}
                  transition={{ duration: 0.2 }}
                  className="flex flex-col items-center gap-2 w-full"
                >
                  <p style={{ color: '#fff', fontSize: 17, fontWeight: 600, margin: 0 }}>{stepLabels[step - 1]}</p>
                  <p style={{ color: '#64748b', fontSize: 13, margin: 0, textAlign: 'center' }}>
                    {stepDescriptions[step - 1]}
                  </p>

                  {step < 4 ? (
                    <div className="flex flex-col items-center gap-6 mt-6 w-full">
                      {/* PIN circles */}
                      <div className="flex gap-4 justify-center">
                        {[0, 1, 2, 3].map((i) => (
                          <motion.div
                            key={i}
                            animate={{
                              scale: activePin.length === i ? [1, 1.15, 1] : 1,
                              background:
                                i < activePin.length
                                  ? 'linear-gradient(135deg, #7c3aed, #3b82f6)'
                                  : 'rgba(255,255,255,0.08)',
                            }}
                            transition={{ duration: 0.2 }}
                            style={{
                              width: 48,
                              height: 48,
                              borderRadius: 14,
                              border: `2px solid ${i < activePin.length ? 'rgba(124,58,237,0.5)' : 'rgba(255,255,255,0.1)'}`,
                              display: 'flex',
                              alignItems: 'center',
                              justifyContent: 'center',
                            }}
                          >
                            {i < activePin.length && (
                              <motion.div
                                initial={{ scale: 0 }}
                                animate={{ scale: 1 }}
                                style={{
                                  width: 14,
                                  height: 14,
                                  borderRadius: '50%',
                                  background: '#fff',
                                }}
                              />
                            )}
                          </motion.div>
                        ))}
                      </div>

                      {/* Hidden input */}
                      <input
                        ref={hiddenInputRef}
                        type="tel"
                        inputMode="numeric"
                        autoFocus
                        maxLength={4}
                        value={activePin}
                        onChange={(e) => handleInput(e.target.value)}
                        style={{
                          position: 'absolute',
                          opacity: 0,
                          pointerEvents: 'none',
                        }}
                      />
                      <button
                        onClick={() => hiddenInputRef.current?.focus()}
                        style={{
                          background: 'rgba(255,255,255,0.05)',
                          border: '1px solid rgba(255,255,255,0.08)',
                          borderRadius: 10,
                          color: '#94a3b8',
                          fontSize: 13,
                          padding: '8px 18px',
                          cursor: 'pointer',
                        }}
                      >
                        Tap to enter PIN
                      </button>
                    </div>
                  ) : (
                    /* Success */
                    <motion.div
                      initial={{ scale: 0 }}
                      animate={{ scale: 1 }}
                      transition={{ type: 'spring', stiffness: 200, damping: 15 }}
                      className="flex items-center justify-center mt-6"
                      style={{
                        width: 80,
                        height: 80,
                        borderRadius: '50%',
                        background: 'rgba(16,185,129,0.15)',
                        border: '2px solid rgba(16,185,129,0.3)',
                      }}
                    >
                      <motion.div
                        initial={{ pathLength: 0 }}
                        animate={{ pathLength: 1 }}
                      >
                        <CheckCircle2 size={40} color="#34d399" />
                      </motion.div>
                    </motion.div>
                  )}
                </motion.div>
              </AnimatePresence>
            </div>

            {/* Done button on success */}
            {step === 4 && (
              <div className="px-6 pb-6">
                <motion.button
                  initial={{ opacity: 0, y: 10 }}
                  animate={{ opacity: 1, y: 0 }}
                  transition={{ delay: 0.3 }}
                  whileTap={{ scale: 0.97 }}
                  onClick={onClose}
                  style={primaryBtnStyle}
                >
                  Done
                </motion.button>
              </div>
            )}
          </motion.div>
        </motion.div>
      )}
    </AnimatePresence>
  );
}

/* ──────────────────────────────────────────────
   3. PrivacySettingsPanel
   ────────────────────────────────────────────── */

export function PrivacySettingsPanel({ isOpen, onClose }: ModalProps) {
  const [shareData, setShareData] = useState(false);
  const [marketing, setMarketing] = useState(false);
  const [showBalance, setShowBalance] = useState(true);
  const [readReceipts, setReadReceipts] = useState(true);
  const [saved, setSaved] = useState(false);

  const handleSave = useCallback(() => {
    setSaved(true);
    setTimeout(() => {
      setSaved(false);
      onClose();
    }, 2000);
  }, [onClose]);

  return (
    <AnimatePresence>
      {isOpen && (
        <motion.div {...overlayMotion} style={overlayStyle} className="flex flex-col">
          <motion.div
            {...slideUp}
            className="flex flex-col flex-1 overflow-y-auto"
            style={{ background: 'rgba(8,5,28,0.98)' }}
          >
            {/* Header */}
            <div className="flex items-center justify-between px-5 py-4" style={panelGlass}>
              <div className="flex items-center gap-3">
                <div
                  className="flex items-center justify-center"
                  style={{
                    width: 36,
                    height: 36,
                    borderRadius: 10,
                    background: 'linear-gradient(135deg, #7c3aed, #3b82f6)',
                  }}
                >
                  <Shield size={18} color="#fff" />
                </div>
                <span style={{ color: '#fff', fontSize: 17, fontWeight: 600 }}>Privacy Settings</span>
              </div>
              <button onClick={onClose} style={closeButtonStyle}>
                <X size={18} />
              </button>
            </div>

            {/* Toggles */}
            <div className="flex flex-col px-5 py-2">
              <ToggleRow
                icon={<BarChart3 size={18} />}
                label="Share transaction data"
                description="Allow anonymized transaction data to improve services and provide personalized offers."
                value={shareData}
                onChange={setShareData}
              />
              <ToggleRow
                icon={<MailCheck size={18} />}
                label="Allow marketing emails"
                description="Receive promotional emails about new features, offers, and partner deals."
                value={marketing}
                onChange={setMarketing}
              />
              <ToggleRow
                icon={<Eye size={18} />}
                label="Show balance on home"
                description="Display your wallet balance on the home screen. Disable to hide until tapped."
                value={showBalance}
                onChange={setShowBalance}
              />
              <ToggleRow
                icon={<Bell size={18} />}
                label="Enable read receipts"
                description="Let senders know when you have viewed their payment requests and messages."
                value={readReceipts}
                onChange={setReadReceipts}
              />
            </div>

            {/* Save */}
            <div className="px-5 mt-auto pb-8 pt-6">
              <motion.button
                whileHover={{ scale: 1.02 }}
                whileTap={{ scale: 0.97 }}
                onClick={handleSave}
                className="flex items-center justify-center gap-2"
                style={primaryBtnStyle}
              >
                <Save size={18} /> Save Settings
              </motion.button>
            </div>

            {/* Success toast */}
            <AnimatePresence>
              {saved && (
                <motion.div
                  initial={{ y: 60, opacity: 0 }}
                  animate={{ y: 0, opacity: 1 }}
                  exit={{ y: 60, opacity: 0 }}
                  className="fixed bottom-8 left-1/2 flex items-center gap-2 px-5 py-3"
                  style={{
                    transform: 'translateX(-50%)',
                    background: 'rgba(16,185,129,0.18)',
                    border: '1px solid rgba(16,185,129,0.3)',
                    borderRadius: 14,
                    color: '#34d399',
                    fontSize: 14,
                    fontWeight: 500,
                    zIndex: 110,
                    backdropFilter: 'blur(16px)',
                  }}
                >
                  <CheckCircle2 size={18} /> Settings saved successfully
                </motion.div>
              )}
            </AnimatePresence>
          </motion.div>
        </motion.div>
      )}
    </AnimatePresence>
  );
}

/* ──────────────────────────────────────────────
   4. NFCSettingsPanel
   ────────────────────────────────────────────── */

export function NFCSettingsPanel({ isOpen, onClose }: ModalProps) {
  const [autoDeactivate, setAutoDeactivate] = useState(true);
  const [vibrate, setVibrate] = useState(true);
  const [sound, setSound] = useState(false);
  const [showUnlink, setShowUnlink] = useState(false);

  return (
    <AnimatePresence>
      {isOpen && (
        <motion.div {...overlayMotion} style={overlayStyle} className="flex flex-col">
          <motion.div
            {...slideUp}
            className="flex flex-col flex-1 overflow-y-auto"
            style={{ background: 'rgba(8,5,28,0.98)' }}
          >
            {/* Header */}
            <div className="flex items-center justify-between px-5 py-4" style={panelGlass}>
              <div className="flex items-center gap-3">
                <div
                  className="flex items-center justify-center"
                  style={{
                    width: 36,
                    height: 36,
                    borderRadius: 10,
                    background: 'linear-gradient(135deg, #06b6d4, #3b82f6)',
                  }}
                >
                  <Nfc size={18} color="#fff" />
                </div>
                <span style={{ color: '#fff', fontSize: 17, fontWeight: 600 }}>NFC & Java Card</span>
              </div>
              <button onClick={onClose} style={closeButtonStyle}>
                <X size={18} />
              </button>
            </div>

            {/* Linked card info */}
            <div className="px-5 pt-5">
              <div style={cardGlass} className="p-4">
                <div className="flex items-center gap-3 mb-4">
                  <div
                    className="flex items-center justify-center"
                    style={{
                      width: 44,
                      height: 44,
                      borderRadius: 12,
                      background: 'linear-gradient(135deg, rgba(6,182,212,0.2), rgba(59,130,246,0.2))',
                      border: '1px solid rgba(6,182,212,0.2)',
                    }}
                  >
                    <CreditCard size={20} color="#22d3ee" />
                  </div>
                  <div>
                    <p style={{ color: '#fff', fontSize: 15, fontWeight: 600, margin: 0 }}>Linked Java Card</p>
                    <p style={{ color: '#34d399', fontSize: 12, margin: '2px 0 0', fontWeight: 500 }}>● Active</p>
                  </div>
                </div>
                <div className="flex flex-col gap-2">
                  {[
                    { label: 'Card ID', value: 'JC-2024-XXXX' },
                    { label: 'Status', value: 'Active' },
                    { label: 'Last Used', value: 'Today' },
                  ].map((row) => (
                    <div key={row.label} className="flex justify-between">
                      <span style={{ color: '#64748b', fontSize: 13 }}>{row.label}</span>
                      <span style={{ color: '#cbd5e1', fontSize: 13, fontWeight: 500 }}>{row.value}</span>
                    </div>
                  ))}
                </div>
              </div>
            </div>

            {/* Toggles */}
            <div className="flex flex-col px-5 py-2">
              <ToggleRow
                icon={<Shield size={18} />}
                label="Auto-deactivate after transaction"
                description="Automatically deactivate NFC after each transaction for extra security."
                value={autoDeactivate}
                onChange={setAutoDeactivate}
              />
              <ToggleRow
                icon={<Vibrate size={18} />}
                label="Vibrate on NFC tap"
                description="Haptic feedback when your device detects an NFC tap."
                value={vibrate}
                onChange={setVibrate}
              />
              <ToggleRow
                icon={<Volume2 size={18} />}
                label="Sound on NFC tap"
                description="Play a confirmation sound when NFC tap is detected."
                value={sound}
                onChange={setSound}
              />
            </div>

            {/* Unlink button */}
            <div className="px-5 mt-auto pb-8 pt-6">
              {!showUnlink ? (
                <motion.button
                  whileHover={{ scale: 1.02 }}
                  whileTap={{ scale: 0.97 }}
                  onClick={() => setShowUnlink(true)}
                  className="flex items-center justify-center gap-2 w-full"
                  style={{
                    background: 'rgba(239,68,68,0.1)',
                    border: '1px solid rgba(239,68,68,0.25)',
                    borderRadius: 14,
                    padding: '14px 0',
                    color: '#f87171',
                    fontWeight: 600,
                    fontSize: 15,
                    cursor: 'pointer',
                  }}
                >
                  <Unlink size={18} /> Unlink Java Card
                </motion.button>
              ) : (
                <motion.div
                  initial={{ opacity: 0, y: 8 }}
                  animate={{ opacity: 1, y: 0 }}
                  className="flex flex-col gap-3"
                  style={cardGlass}
                >
                  <div className="p-4 flex flex-col gap-3">
                    <p style={{ color: '#f87171', fontSize: 14, fontWeight: 600, margin: 0 }}>
                      Are you sure you want to unlink?
                    </p>
                    <p style={{ color: '#64748b', fontSize: 13, margin: 0 }}>
                      You will need to re-register your Java Card to use NFC features again.
                    </p>
                    <div className="flex gap-3">
                      <button
                        onClick={() => setShowUnlink(false)}
                        className="flex-1"
                        style={{
                          background: 'rgba(255,255,255,0.06)',
                          border: '1px solid rgba(255,255,255,0.1)',
                          borderRadius: 10,
                          padding: '10px',
                          color: '#94a3b8',
                          fontSize: 14,
                          fontWeight: 500,
                          cursor: 'pointer',
                        }}
                      >
                        Cancel
                      </button>
                      <button
                        onClick={onClose}
                        className="flex-1"
                        style={{
                          background: 'rgba(239,68,68,0.2)',
                          border: '1px solid rgba(239,68,68,0.3)',
                          borderRadius: 10,
                          padding: '10px',
                          color: '#f87171',
                          fontSize: 14,
                          fontWeight: 600,
                          cursor: 'pointer',
                        }}
                      >
                        Unlink
                      </button>
                    </div>
                  </div>
                </motion.div>
              )}
            </div>
          </motion.div>
        </motion.div>
      )}
    </AnimatePresence>
  );
}

/* ──────────────────────────────────────────────
   5. HelpCenterPanel
   ────────────────────────────────────────────── */

const faqData = [
  {
    q: 'How does Java Card authentication work?',
    a: 'Your Java Card uses NFC (Near Field Communication) to communicate securely with your device. Simply tap your registered Java Card on the back of your phone to authenticate transactions. The card generates a one-time cryptographic token that verifies your identity without transmitting sensitive data.',
  },
  {
    q: 'Is my card information safe?',
    a: 'Absolutely. All card data is encrypted using AES-256 end-to-end encryption. Your actual card numbers are never stored on our servers — instead, we use tokenized representations. The Java Card itself has a secure element that prevents cloning or data extraction.',
  },
  {
    q: 'What happens if I lose my Java Card?',
    a: 'If your Java Card is lost or stolen, immediately go to NFC & Java Card settings and tap "Unlink Java Card." This instantly deactivates the card, preventing any unauthorized use. You can then order a replacement card and link it to your account.',
  },
  {
    q: 'How do I add a new virtual card?',
    a: 'Navigate to the Cards tab from the bottom navigation. Tap the "Add Card" button and follow the on-screen instructions. You can add virtual debit or credit cards from supported banks and e-wallets. Each card will be tokenized for secure NFC transactions.',
  },
  {
    q: 'What are single-use tokens?',
    a: 'Single-use tokens are unique, one-time cryptographic codes generated for each transaction. After a token is used, it becomes invalid, so even if intercepted, it cannot be reused. This tokenization layer adds an extra level of security to every NFC payment you make.',
  },
];

function FAQItem({ q, a }: { q: string; a: string }) {
  const [open, setOpen] = useState(false);

  return (
    <div style={{ borderBottom: '1px solid rgba(255,255,255,0.06)' }}>
      <button
        onClick={() => setOpen(!open)}
        className="flex items-center justify-between w-full py-4 text-left"
        style={{ background: 'none', border: 'none', cursor: 'pointer', padding: '16px 0' }}
      >
        <span style={{ color: '#fff', fontSize: 14, fontWeight: 500, paddingRight: 12 }}>{q}</span>
        <motion.div animate={{ rotate: open ? 180 : 0 }} transition={{ duration: 0.25 }}>
          <ChevronDown size={18} color="#94a3b8" />
        </motion.div>
      </button>
      <AnimatePresence>
        {open && (
          <motion.div
            initial={{ height: 0, opacity: 0 }}
            animate={{ height: 'auto', opacity: 1 }}
            exit={{ height: 0, opacity: 0 }}
            transition={{ duration: 0.25 }}
            style={{ overflow: 'hidden' }}
          >
            <p style={{ color: '#94a3b8', fontSize: 13, lineHeight: 1.7, margin: 0, paddingBottom: 16 }}>{a}</p>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}

export function HelpCenterPanel({ isOpen, onClose }: ModalProps) {
  return (
    <AnimatePresence>
      {isOpen && (
        <motion.div {...overlayMotion} style={overlayStyle} className="flex flex-col">
          <motion.div
            {...slideUp}
            className="flex flex-col flex-1 overflow-y-auto"
            style={{ background: 'rgba(8,5,28,0.98)' }}
          >
            {/* Header */}
            <div className="flex items-center justify-between px-5 py-4" style={panelGlass}>
              <div className="flex items-center gap-3">
                <div
                  className="flex items-center justify-center"
                  style={{
                    width: 36,
                    height: 36,
                    borderRadius: 10,
                    background: 'linear-gradient(135deg, #7c3aed, #06b6d4)',
                  }}
                >
                  <HelpCircle size={18} color="#fff" />
                </div>
                <span style={{ color: '#fff', fontSize: 17, fontWeight: 600 }}>Help Center</span>
              </div>
              <button onClick={onClose} style={closeButtonStyle}>
                <X size={18} />
              </button>
            </div>

            {/* FAQ section label */}
            <div className="px-5 pt-5 pb-1">
              <p style={{ color: '#64748b', fontSize: 12, fontWeight: 600, textTransform: 'uppercase', letterSpacing: 1, margin: 0 }}>
                Frequently Asked Questions
              </p>
            </div>

            {/* FAQ items */}
            <div className="flex flex-col px-5">
              {faqData.map((faq) => (
                <FAQItem key={faq.q} q={faq.q} a={faq.a} />
              ))}
            </div>

            {/* Contact support */}
            <div className="px-5 mt-auto pb-8 pt-6">
              <motion.button
                whileHover={{ scale: 1.02 }}
                whileTap={{ scale: 0.97 }}
                className="flex items-center justify-center gap-2 w-full"
                style={primaryBtnStyle}
              >
                <MessageCircle size={18} /> Contact Support
              </motion.button>
            </div>
          </motion.div>
        </motion.div>
      )}
    </AnimatePresence>
  );
}

/* ──────────────────────────────────────────────
   6. PremiumUpgradeModal
   ────────────────────────────────────────────── */

const premiumFeatures = [
  { icon: <Zap size={18} />, label: '0% transaction fees' },
  { icon: <Nfc size={18} />, label: 'Priority NFC processing' },
  { icon: <BarChart3 size={18} />, label: 'Advanced analytics' },
  { icon: <Layers size={18} />, label: 'Multi-card support (up to 10)' },
  { icon: <Headphones size={18} />, label: '24/7 priority support' },
];

export function PremiumUpgradeModal({ isOpen, onClose }: ModalProps) {
  return (
    <AnimatePresence>
      {isOpen && (
        <motion.div
          {...overlayMotion}
          style={overlayStyle}
          className="flex items-center justify-center p-5"
          onClick={onClose}
        >
          <motion.div
            {...fadeScale}
            onClick={(e) => e.stopPropagation()}
            className="w-full flex flex-col"
            style={{
              maxWidth: 400,
              background: 'rgba(20,12,42,0.96)',
              border: '1px solid rgba(251,191,36,0.15)',
              borderRadius: 20,
              overflow: 'hidden',
            }}
          >
            {/* Gold glow header */}
            <div
              className="relative flex flex-col items-center pt-8 pb-6 px-6"
              style={{
                background: 'linear-gradient(180deg, rgba(251,191,36,0.12) 0%, transparent 100%)',
              }}
            >
              {/* Close */}
              <button onClick={onClose} style={{ ...closeButtonStyle, position: 'absolute', top: 16, right: 16 }}>
                <X size={18} />
              </button>

              {/* Crown icon */}
              <motion.div
                animate={{ y: [0, -6, 0] }}
                transition={{ duration: 2, repeat: Infinity, ease: 'easeInOut' }}
                className="flex items-center justify-center"
                style={{
                  width: 64,
                  height: 64,
                  borderRadius: 20,
                  background: 'linear-gradient(135deg, #f59e0b, #fbbf24, #f59e0b)',
                  boxShadow: '0 8px 32px rgba(251,191,36,0.25)',
                  marginBottom: 16,
                }}
              >
                <Crown size={30} color="#451a03" />
              </motion.div>

              <h2 style={{ color: '#fbbf24', fontSize: 22, fontWeight: 700, margin: 0 }}>Go Premium</h2>
              <p style={{ color: '#94a3b8', fontSize: 13, margin: '6px 0 0', textAlign: 'center' }}>
                Unlock the full SecureNFC Pay experience
              </p>
            </div>

            {/* Features list */}
            <div className="flex flex-col gap-1 px-6 pb-4">
              {premiumFeatures.map((feat, i) => (
                <motion.div
                  key={feat.label}
                  initial={{ opacity: 0, x: -16 }}
                  animate={{ opacity: 1, x: 0 }}
                  transition={{ delay: 0.1 + i * 0.07 }}
                  className="flex items-center gap-3 py-3"
                  style={{ borderBottom: i < premiumFeatures.length - 1 ? '1px solid rgba(255,255,255,0.05)' : 'none' }}
                >
                  <div
                    className="flex items-center justify-center shrink-0"
                    style={{
                      width: 36,
                      height: 36,
                      borderRadius: 10,
                      background: 'rgba(251,191,36,0.1)',
                      color: '#fbbf24',
                    }}
                  >
                    {feat.icon}
                  </div>
                  <span style={{ color: '#e2e8f0', fontSize: 14, fontWeight: 500 }}>{feat.label}</span>
                  <Check size={16} color="#fbbf24" className="ml-auto" />
                </motion.div>
              ))}
            </div>

            {/* Price */}
            <div className="flex items-baseline justify-center gap-1 py-4">
              <span style={{ color: '#fbbf24', fontSize: 32, fontWeight: 700 }}>₱299</span>
              <span style={{ color: '#64748b', fontSize: 14 }}>/month</span>
            </div>

            {/* Buttons */}
            <div className="flex flex-col gap-3 px-6 pb-6">
              <motion.button
                whileHover={{ scale: 1.02 }}
                whileTap={{ scale: 0.97 }}
                className="flex items-center justify-center gap-2 w-full"
                style={{
                  background: 'linear-gradient(135deg, #f59e0b, #fbbf24, #f59e0b)',
                  color: '#451a03',
                  fontWeight: 700,
                  fontSize: 15,
                  border: 'none',
                  borderRadius: 14,
                  padding: '14px 0',
                  cursor: 'pointer',
                  boxShadow: '0 4px 20px rgba(251,191,36,0.25)',
                }}
              >
                <Sparkles size={18} /> Upgrade Now
              </motion.button>
              <button
                onClick={onClose}
                className="w-full"
                style={{
                  background: 'none',
                  border: 'none',
                  color: '#64748b',
                  fontSize: 14,
                  cursor: 'pointer',
                  padding: '10px 0',
                }}
              >
                Maybe Later
              </button>
            </div>
          </motion.div>
        </motion.div>
      )}
    </AnimatePresence>
  );
}
