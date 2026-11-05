'use client';

import React, { useState, useEffect, useCallback } from 'react';
import { motion, AnimatePresence } from 'motion/react';
import {
  X,
  ArrowLeft,
  CheckCircle,
  Loader2,
  Wallet,
  Landmark,
  Smartphone,
  Banknote,
  Sparkles,
} from 'lucide-react';

interface TopUpModalProps {
  isOpen: boolean;
  onClose: () => void;
  onTopUp?: (amount: number) => void;
}

type Step = 1 | 2 | 3 | 4;

interface PaymentSource {
  id: string;
  name: string;
  icon: React.ElementType;
  color: string;
  bg: string;
  borderColor: string;
}

const presetAmounts = [500, 1000, 2000, 5000];

const paymentSources: PaymentSource[] = [
  {
    id: 'gcash',
    name: 'GCash',
    icon: Smartphone,
    color: '#3b82f6',
    bg: 'rgba(59, 130, 246, 0.12)',
    borderColor: 'rgba(59, 130, 246, 0.2)',
  },
  {
    id: 'maya',
    name: 'Maya',
    icon: Wallet,
    color: '#a855f7',
    bg: 'rgba(168, 85, 247, 0.12)',
    borderColor: 'rgba(168, 85, 247, 0.2)',
  },
  {
    id: 'bank',
    name: 'Bank Transfer',
    icon: Landmark,
    color: '#22c55e',
    bg: 'rgba(34, 197, 94, 0.12)',
    borderColor: 'rgba(34, 197, 94, 0.2)',
  },
];

const TopUpModal: React.FC<TopUpModalProps> = ({ isOpen, onClose, onTopUp }) => {
  const [step, setStep] = useState<Step>(1);
  const [selectedAmount, setSelectedAmount] = useState<number>(0);
  const [customAmount, setCustomAmount] = useState<string>('');
  const [selectedSource, setSelectedSource] = useState<string>('');

  // Reset state when modal opens/closes
  useEffect(() => {
    if (!isOpen) {
      setTimeout(() => {
        setStep(1);
        setSelectedAmount(0);
        setCustomAmount('');
        setSelectedSource('');
      }, 300);
    }
  }, [isOpen]);

  // Handle processing step
  useEffect(() => {
    if (step === 3) {
      const timer = setTimeout(() => {
        setStep(4);
        onTopUp?.(selectedAmount);
      }, 1500);
      return () => clearTimeout(timer);
    }
  }, [step, selectedAmount, onTopUp]);

  const handleAmountSelect = (amount: number) => {
    setSelectedAmount(amount);
    setCustomAmount('');
  };

  const handleCustomAmountChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const value = e.target.value.replace(/[^0-9]/g, '');
    setCustomAmount(value);
    setSelectedAmount(value ? parseInt(value, 10) : 0);
  };

  const handleNext = useCallback(() => {
    if (step === 1 && selectedAmount > 0) setStep(2);
    else if (step === 2 && selectedSource) setStep(3);
  }, [step, selectedAmount, selectedSource]);

  const handleBack = () => {
    if (step === 2) setStep(1);
  };

  const formatAmount = (amount: number) =>
    `₱${amount.toLocaleString()}`;

  const stepTitle = () => {
    switch (step) {
      case 1:
        return 'Enter Amount';
      case 2:
        return 'Select Source';
      case 3:
        return 'Processing';
      case 4:
        return 'Success!';
    }
  };

  return (
    <AnimatePresence>
      {isOpen && (
        <motion.div
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          exit={{ opacity: 0 }}
          transition={{ duration: 0.2 }}
          className="fixed inset-0 z-50 flex items-center justify-center p-4"
          style={{
            backgroundColor: 'rgba(0, 0, 0, 0.6)',
            backdropFilter: 'blur(8px)',
            WebkitBackdropFilter: 'blur(8px)',
          }}
          onClick={onClose}
        >
          <motion.div
            initial={{ scale: 0.85, opacity: 0, y: 30 }}
            animate={{ scale: 1, opacity: 1, y: 0 }}
            exit={{ scale: 0.85, opacity: 0, y: 30 }}
            transition={{ type: 'spring', damping: 25, stiffness: 300 }}
            className="relative w-full max-w-sm overflow-hidden rounded-3xl"
            style={{
              background:
                'linear-gradient(160deg, rgba(15, 10, 45, 0.97) 0%, rgba(10, 10, 35, 0.98) 100%)',
              border: '1px solid rgba(255, 255, 255, 0.08)',
              boxShadow:
                '0 24px 64px rgba(0, 0, 0, 0.5), inset 0 1px 0 rgba(255, 255, 255, 0.05)',
            }}
            onClick={(e) => e.stopPropagation()}
          >
            {/* Glow */}
            <div
              className="absolute top-0 left-1/2 -translate-x-1/2 w-48 h-48 rounded-full"
              style={{
                background:
                  'radial-gradient(circle, rgba(139, 92, 246, 0.12) 0%, transparent 70%)',
                filter: 'blur(40px)',
                pointerEvents: 'none',
              }}
            />

            {/* Header */}
            <div className="relative flex items-center justify-between p-5 pb-3">
              <div className="flex items-center gap-3">
                {step === 2 && (
                  <motion.button
                    initial={{ opacity: 0, x: -10 }}
                    animate={{ opacity: 1, x: 0 }}
                    onClick={handleBack}
                    className="flex items-center justify-center w-9 h-9 rounded-xl"
                    style={{
                      background: 'rgba(255, 255, 255, 0.06)',
                      border: '1px solid rgba(255, 255, 255, 0.08)',
                    }}
                  >
                    <ArrowLeft size={18} style={{ color: '#94a3b8' }} />
                  </motion.button>
                )}
                <div
                  className="flex items-center justify-center w-9 h-9 rounded-xl"
                  style={{
                    background:
                      'linear-gradient(135deg, rgba(34, 211, 238, 0.2), rgba(139, 92, 246, 0.2))',
                    border: '1px solid rgba(34, 211, 238, 0.15)',
                  }}
                >
                  <Banknote size={18} style={{ color: '#22d3ee' }} />
                </div>
                <h2
                  style={{
                    fontSize: '18px',
                    fontWeight: 700,
                    color: '#ffffff',
                    letterSpacing: '-0.02em',
                  }}
                >
                  {stepTitle()}
                </h2>
              </div>
              {step !== 3 && (
                <button
                  onClick={onClose}
                  className="flex items-center justify-center w-9 h-9 rounded-xl"
                  style={{
                    background: 'rgba(255, 255, 255, 0.06)',
                    border: '1px solid rgba(255, 255, 255, 0.08)',
                  }}
                >
                  <X size={18} style={{ color: '#94a3b8' }} />
                </button>
              )}
            </div>

            {/* Step indicator */}
            <div className="flex gap-2 px-5 pb-4">
              {[1, 2, 3, 4].map((s) => (
                <div
                  key={s}
                  className="flex-1 h-1 rounded-full overflow-hidden"
                  style={{ background: 'rgba(255,255,255,0.06)' }}
                >
                  <motion.div
                    className="h-full rounded-full"
                    initial={{ width: '0%' }}
                    animate={{ width: step >= s ? '100%' : '0%' }}
                    transition={{ duration: 0.4, ease: 'easeOut' }}
                    style={{
                      background:
                        'linear-gradient(90deg, #8b5cf6, #22d3ee)',
                    }}
                  />
                </div>
              ))}
            </div>

            {/* Content Area */}
            <div className="px-5 pb-5" style={{ minHeight: '280px' }}>
              <AnimatePresence mode="wait">
                {/* Step 1: Amount */}
                {step === 1 && (
                  <motion.div
                    key="step1"
                    initial={{ opacity: 0, x: 40 }}
                    animate={{ opacity: 1, x: 0 }}
                    exit={{ opacity: 0, x: -40 }}
                    transition={{ duration: 0.25 }}
                  >
                    {/* Preset amounts */}
                    <div className="grid grid-cols-2 gap-3 mb-4">
                      {presetAmounts.map((amount) => (
                        <motion.button
                          key={amount}
                          whileTap={{ scale: 0.96 }}
                          onClick={() => handleAmountSelect(amount)}
                          className="py-4 rounded-xl text-center transition-all"
                          style={{
                            background:
                              selectedAmount === amount && !customAmount
                                ? 'linear-gradient(135deg, rgba(139, 92, 246, 0.25), rgba(99, 102, 241, 0.25))'
                                : 'rgba(255, 255, 255, 0.03)',
                            border:
                              selectedAmount === amount && !customAmount
                                ? '1px solid rgba(139, 92, 246, 0.4)'
                                : '1px solid rgba(255, 255, 255, 0.06)',
                            fontSize: '16px',
                            fontWeight: 700,
                            color:
                              selectedAmount === amount && !customAmount
                                ? '#c4b5fd'
                                : '#e2e8f0',
                          }}
                        >
                          ₱{amount.toLocaleString()}
                        </motion.button>
                      ))}
                    </div>

                    {/* Custom amount */}
                    <div
                      className="relative rounded-xl overflow-hidden mb-4"
                      style={{
                        background: 'rgba(255, 255, 255, 0.03)',
                        border: customAmount
                          ? '1px solid rgba(139, 92, 246, 0.3)'
                          : '1px solid rgba(255, 255, 255, 0.06)',
                      }}
                    >
                      <span
                        className="absolute left-4 top-1/2 -translate-y-1/2"
                        style={{
                          fontSize: '16px',
                          fontWeight: 700,
                          color: '#94a3b8',
                        }}
                      >
                        ₱
                      </span>
                      <input
                        type="text"
                        placeholder="Custom amount"
                        value={customAmount}
                        onChange={handleCustomAmountChange}
                        className="w-full py-4 pl-10 pr-4 bg-transparent outline-none"
                        style={{
                          fontSize: '16px',
                          fontWeight: 600,
                          color: '#e2e8f0',
                        }}
                      />
                    </div>

                    {/* Next button */}
                    <motion.button
                      whileTap={{ scale: 0.97 }}
                      onClick={handleNext}
                      disabled={selectedAmount <= 0}
                      className="w-full py-3.5 rounded-xl flex items-center justify-center gap-2 transition-all"
                      style={{
                        background:
                          selectedAmount > 0
                            ? 'linear-gradient(135deg, #8b5cf6, #6366f1)'
                            : 'rgba(255, 255, 255, 0.05)',
                        fontSize: '14px',
                        fontWeight: 700,
                        color:
                          selectedAmount > 0
                            ? '#ffffff'
                            : 'rgba(148, 163, 184, 0.4)',
                        cursor:
                          selectedAmount > 0 ? 'pointer' : 'not-allowed',
                        boxShadow:
                          selectedAmount > 0
                            ? '0 4px 20px rgba(139, 92, 246, 0.3)'
                            : 'none',
                      }}
                    >
                      Continue with {selectedAmount > 0 ? formatAmount(selectedAmount) : '₱0'}
                    </motion.button>
                  </motion.div>
                )}

                {/* Step 2: Source */}
                {step === 2 && (
                  <motion.div
                    key="step2"
                    initial={{ opacity: 0, x: 40 }}
                    animate={{ opacity: 1, x: 0 }}
                    exit={{ opacity: 0, x: -40 }}
                    transition={{ duration: 0.25 }}
                  >
                    {/* Amount display */}
                    <div
                      className="text-center py-3 mb-4 rounded-xl"
                      style={{
                        background: 'rgba(139, 92, 246, 0.08)',
                        border: '1px solid rgba(139, 92, 246, 0.12)',
                      }}
                    >
                      <p style={{ fontSize: '11px', color: '#94a3b8', marginBottom: '2px' }}>
                        Top Up Amount
                      </p>
                      <p
                        style={{
                          fontSize: '24px',
                          fontWeight: 800,
                          color: '#c4b5fd',
                          letterSpacing: '-0.02em',
                        }}
                      >
                        {formatAmount(selectedAmount)}
                      </p>
                    </div>

                    {/* Source options */}
                    <div className="space-y-3 mb-4">
                      {paymentSources.map((source) => {
                        const IconComp = source.icon;
                        const isSelected = selectedSource === source.id;
                        return (
                          <motion.button
                            key={source.id}
                            whileTap={{ scale: 0.97 }}
                            onClick={() => setSelectedSource(source.id)}
                            className="w-full flex items-center gap-3 p-4 rounded-xl transition-all"
                            style={{
                              background: isSelected
                                ? source.bg
                                : 'rgba(255, 255, 255, 0.03)',
                              border: isSelected
                                ? `1px solid ${source.borderColor}`
                                : '1px solid rgba(255, 255, 255, 0.06)',
                            }}
                          >
                            <div
                              className="flex items-center justify-center w-10 h-10 rounded-xl"
                              style={{
                                background: source.bg,
                                border: `1px solid ${source.borderColor}`,
                              }}
                            >
                              <IconComp size={18} style={{ color: source.color }} />
                            </div>
                            <span
                              style={{
                                fontSize: '14px',
                                fontWeight: 600,
                                color: isSelected ? source.color : '#e2e8f0',
                              }}
                            >
                              {source.name}
                            </span>
                            {isSelected && (
                              <motion.div
                                initial={{ scale: 0 }}
                                animate={{ scale: 1 }}
                                className="ml-auto"
                              >
                                <CheckCircle
                                  size={18}
                                  style={{ color: source.color }}
                                />
                              </motion.div>
                            )}
                          </motion.button>
                        );
                      })}
                    </div>

                    {/* Confirm button */}
                    <motion.button
                      whileTap={{ scale: 0.97 }}
                      onClick={handleNext}
                      disabled={!selectedSource}
                      className="w-full py-3.5 rounded-xl flex items-center justify-center gap-2 transition-all"
                      style={{
                        background: selectedSource
                          ? 'linear-gradient(135deg, #8b5cf6, #6366f1)'
                          : 'rgba(255, 255, 255, 0.05)',
                        fontSize: '14px',
                        fontWeight: 700,
                        color: selectedSource
                          ? '#ffffff'
                          : 'rgba(148, 163, 184, 0.4)',
                        cursor: selectedSource ? 'pointer' : 'not-allowed',
                        boxShadow: selectedSource
                          ? '0 4px 20px rgba(139, 92, 246, 0.3)'
                          : 'none',
                      }}
                    >
                      Confirm Top Up
                    </motion.button>
                  </motion.div>
                )}

                {/* Step 3: Processing */}
                {step === 3 && (
                  <motion.div
                    key="step3"
                    initial={{ opacity: 0, scale: 0.9 }}
                    animate={{ opacity: 1, scale: 1 }}
                    exit={{ opacity: 0, scale: 0.9 }}
                    transition={{ duration: 0.3 }}
                    className="flex flex-col items-center justify-center py-16"
                  >
                    <motion.div
                      animate={{ rotate: 360 }}
                      transition={{
                        repeat: Infinity,
                        duration: 1,
                        ease: 'linear',
                      }}
                    >
                      <Loader2
                        size={48}
                        style={{ color: '#8b5cf6' }}
                      />
                    </motion.div>
                    <p
                      style={{
                        fontSize: '16px',
                        fontWeight: 600,
                        color: '#e2e8f0',
                        marginTop: '20px',
                      }}
                    >
                      Processing...
                    </p>
                    <p
                      style={{
                        fontSize: '13px',
                        color: '#64748b',
                        marginTop: '6px',
                      }}
                    >
                      Please wait a moment
                    </p>
                  </motion.div>
                )}

                {/* Step 4: Success */}
                {step === 4 && (
                  <motion.div
                    key="step4"
                    initial={{ opacity: 0, scale: 0.9 }}
                    animate={{ opacity: 1, scale: 1 }}
                    exit={{ opacity: 0, scale: 0.9 }}
                    transition={{ duration: 0.3 }}
                    className="flex flex-col items-center justify-center py-8"
                  >
                    <motion.div
                      initial={{ scale: 0 }}
                      animate={{ scale: 1 }}
                      transition={{
                        type: 'spring',
                        damping: 12,
                        stiffness: 200,
                        delay: 0.1,
                      }}
                      className="flex items-center justify-center w-20 h-20 rounded-full mb-5"
                      style={{
                        background:
                          'linear-gradient(135deg, rgba(74, 222, 128, 0.15), rgba(34, 197, 94, 0.15))',
                        border: '2px solid rgba(74, 222, 128, 0.3)',
                        boxShadow: '0 0 40px rgba(74, 222, 128, 0.15)',
                      }}
                    >
                      <CheckCircle size={36} style={{ color: '#4ade80' }} />
                    </motion.div>

                    <motion.div
                      initial={{ opacity: 0, y: 10 }}
                      animate={{ opacity: 1, y: 0 }}
                      transition={{ delay: 0.25 }}
                      className="text-center"
                    >
                      <p
                        style={{
                          fontSize: '14px',
                          color: '#94a3b8',
                          marginBottom: '4px',
                        }}
                      >
                        Successfully topped up
                      </p>
                      <p
                        style={{
                          fontSize: '32px',
                          fontWeight: 800,
                          color: '#4ade80',
                          letterSpacing: '-0.02em',
                        }}
                      >
                        {formatAmount(selectedAmount)}
                      </p>
                      <div className="flex items-center justify-center gap-1 mt-2">
                        <Sparkles size={14} style={{ color: '#fbbf24' }} />
                        <p style={{ fontSize: '12px', color: '#94a3b8' }}>
                          Added to your SecureNFC wallet
                        </p>
                      </div>
                    </motion.div>

                    <motion.button
                      initial={{ opacity: 0, y: 10 }}
                      animate={{ opacity: 1, y: 0 }}
                      transition={{ delay: 0.4 }}
                      whileTap={{ scale: 0.97 }}
                      onClick={onClose}
                      className="w-full py-3.5 rounded-xl mt-8"
                      style={{
                        background:
                          'linear-gradient(135deg, #8b5cf6, #6366f1)',
                        fontSize: '14px',
                        fontWeight: 700,
                        color: '#ffffff',
                        boxShadow: '0 4px 20px rgba(139, 92, 246, 0.3)',
                      }}
                    >
                      Done
                    </motion.button>
                  </motion.div>
                )}
              </AnimatePresence>
            </div>
          </motion.div>
        </motion.div>
      )}
    </AnimatePresence>
  );
};

export default TopUpModal;
