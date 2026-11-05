'use client';

import React, { useState, useCallback } from 'react';
import { motion, AnimatePresence } from 'motion/react';
import { X, Copy, Check, Share2, QrCode, User, Phone, Hash } from 'lucide-react';

interface ReceiveModalProps {
  isOpen: boolean;
  onClose: () => void;
}

const QRCodeSVG: React.FC = () => {
  const size = 180;
  const moduleSize = 6;
  const modules = Math.floor(size / moduleSize);

  // Generate a deterministic QR-like pattern
  const getModule = (row: number, col: number): boolean => {
    // Position detection patterns (corners)
    const isFinderPattern = (r: number, c: number, startR: number, startC: number) => {
      const dr = r - startR;
      const dc = c - startC;
      if (dr < 0 || dr > 6 || dc < 0 || dc > 6) return false;
      if (dr === 0 || dr === 6 || dc === 0 || dc === 6) return true;
      if (dr >= 2 && dr <= 4 && dc >= 2 && dc <= 4) return true;
      return false;
    };

    if (isFinderPattern(row, col, 0, 0)) return true;
    if (isFinderPattern(row, col, 0, modules - 7)) return true;
    if (isFinderPattern(row, col, modules - 7, 0)) return true;

    // Timing patterns
    if (row === 6 && col > 7 && col < modules - 8) return col % 2 === 0;
    if (col === 6 && row > 7 && row < modules - 8) return row % 2 === 0;

    // Separator zones (white)
    if ((row <= 7 && col <= 7) || (row <= 7 && col >= modules - 8) || (row >= modules - 8 && col <= 7))
      return false;

    // Data area - pseudo-random pattern
    const seed = (row * 31 + col * 17 + 42) % 100;
    return seed < 48;
  };

  const rects: React.ReactElement[] = [];
  for (let r = 0; r < modules; r++) {
    for (let c = 0; c < modules; c++) {
      if (getModule(r, c)) {
        rects.push(
          <rect
            key={`${r}-${c}`}
            x={c * moduleSize}
            y={r * moduleSize}
            width={moduleSize - 0.5}
            height={moduleSize - 0.5}
            rx={1}
            fill="url(#qrGradient)"
          />
        );
      }
    }
  }

  return (
    <svg
      width={size}
      height={size}
      viewBox={`0 0 ${size} ${size}`}
      style={{ borderRadius: '4px' }}
    >
      <defs>
        <linearGradient id="qrGradient" x1="0%" y1="0%" x2="100%" y2="100%">
          <stop offset="0%" stopColor="#a78bfa" />
          <stop offset="50%" stopColor="#818cf8" />
          <stop offset="100%" stopColor="#22d3ee" />
        </linearGradient>
      </defs>
      {rects}
    </svg>
  );
};

const ReceiveModal: React.FC<ReceiveModalProps> = ({ isOpen, onClose }) => {
  const [copied, setCopied] = useState(false);

  const accountId = 'SNFC-2024-8821';

  const handleCopy = useCallback(() => {
    navigator.clipboard?.writeText(accountId).catch(() => {});
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  }, []);

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
            {/* Glow accent */}
            <div
              className="absolute top-0 left-1/2 -translate-x-1/2 w-48 h-48 rounded-full"
              style={{
                background:
                  'radial-gradient(circle, rgba(139, 92, 246, 0.15) 0%, transparent 70%)',
                filter: 'blur(40px)',
                pointerEvents: 'none',
              }}
            />

            {/* Header */}
            <div className="relative flex items-center justify-between p-5 pb-2">
              <div className="flex items-center gap-3">
                <div
                  className="flex items-center justify-center w-9 h-9 rounded-xl"
                  style={{
                    background:
                      'linear-gradient(135deg, rgba(34, 211, 238, 0.2), rgba(139, 92, 246, 0.2))',
                    border: '1px solid rgba(34, 211, 238, 0.15)',
                  }}
                >
                  <QrCode size={18} style={{ color: '#22d3ee' }} />
                </div>
                <h2
                  style={{
                    fontSize: '18px',
                    fontWeight: 700,
                    color: '#ffffff',
                    letterSpacing: '-0.02em',
                  }}
                >
                  Receive Payment
                </h2>
              </div>
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
            </div>

            {/* QR Code */}
            <div className="relative flex flex-col items-center px-5 pt-4 pb-2">
              <div
                className="p-5 rounded-2xl"
                style={{
                  background: 'rgba(255, 255, 255, 0.95)',
                  boxShadow: '0 8px 32px rgba(139, 92, 246, 0.15)',
                }}
              >
                <QRCodeSVG />
              </div>
              <p
                style={{
                  fontSize: '11px',
                  color: 'rgba(148, 163, 184, 0.6)',
                  marginTop: '12px',
                }}
              >
                Scan to pay via SecureNFC
              </p>
            </div>

            {/* Account Details */}
            <div className="px-5 pt-3 pb-2 space-y-2">
              <div
                className="flex items-center gap-3 p-3 rounded-xl"
                style={{
                  background: 'rgba(255, 255, 255, 0.03)',
                  border: '1px solid rgba(255, 255, 255, 0.05)',
                }}
              >
                <div
                  className="flex items-center justify-center w-8 h-8 rounded-lg"
                  style={{ background: 'rgba(139, 92, 246, 0.12)' }}
                >
                  <User size={14} style={{ color: '#a78bfa' }} />
                </div>
                <div>
                  <p style={{ fontSize: '10px', color: '#64748b', fontWeight: 500 }}>
                    Name
                  </p>
                  <p style={{ fontSize: '13px', color: '#e2e8f0', fontWeight: 600 }}>
                    Juan dela Cruz
                  </p>
                </div>
              </div>

              <div
                className="flex items-center gap-3 p-3 rounded-xl"
                style={{
                  background: 'rgba(255, 255, 255, 0.03)',
                  border: '1px solid rgba(255, 255, 255, 0.05)',
                }}
              >
                <div
                  className="flex items-center justify-center w-8 h-8 rounded-lg"
                  style={{ background: 'rgba(34, 211, 238, 0.12)' }}
                >
                  <Phone size={14} style={{ color: '#22d3ee' }} />
                </div>
                <div>
                  <p style={{ fontSize: '10px', color: '#64748b', fontWeight: 500 }}>
                    Phone
                  </p>
                  <p style={{ fontSize: '13px', color: '#e2e8f0', fontWeight: 600 }}>
                    +63 917 123 4567
                  </p>
                </div>
              </div>

              <div
                className="flex items-center gap-3 p-3 rounded-xl"
                style={{
                  background: 'rgba(255, 255, 255, 0.03)',
                  border: '1px solid rgba(255, 255, 255, 0.05)',
                }}
              >
                <div
                  className="flex items-center justify-center w-8 h-8 rounded-lg"
                  style={{ background: 'rgba(99, 102, 241, 0.12)' }}
                >
                  <Hash size={14} style={{ color: '#818cf8' }} />
                </div>
                <div>
                  <p style={{ fontSize: '10px', color: '#64748b', fontWeight: 500 }}>
                    Account ID
                  </p>
                  <p
                    style={{
                      fontSize: '13px',
                      color: '#e2e8f0',
                      fontWeight: 600,
                      fontFamily: 'monospace',
                    }}
                  >
                    {accountId}
                  </p>
                </div>
              </div>
            </div>

            {/* Action Buttons */}
            <div className="flex gap-3 p-5 pt-4">
              <motion.button
                whileTap={{ scale: 0.97 }}
                onClick={handleCopy}
                className="flex-1 flex items-center justify-center gap-2 py-3 rounded-xl transition-all"
                style={{
                  background: copied
                    ? 'rgba(74, 222, 128, 0.15)'
                    : 'linear-gradient(135deg, rgba(139, 92, 246, 0.2), rgba(99, 102, 241, 0.2))',
                  border: copied
                    ? '1px solid rgba(74, 222, 128, 0.25)'
                    : '1px solid rgba(139, 92, 246, 0.2)',
                  fontSize: '13px',
                  fontWeight: 600,
                  color: copied ? '#4ade80' : '#c4b5fd',
                }}
              >
                {copied ? (
                  <>
                    <Check size={15} />
                    Copied!
                  </>
                ) : (
                  <>
                    <Copy size={15} />
                    Copy Account ID
                  </>
                )}
              </motion.button>

              <motion.button
                whileTap={{ scale: 0.97 }}
                className="flex items-center justify-center gap-2 px-5 py-3 rounded-xl"
                style={{
                  background:
                    'linear-gradient(135deg, rgba(34, 211, 238, 0.15), rgba(59, 130, 246, 0.15))',
                  border: '1px solid rgba(34, 211, 238, 0.15)',
                  fontSize: '13px',
                  fontWeight: 600,
                  color: '#67e8f9',
                }}
              >
                <Share2 size={15} />
                Share
              </motion.button>
            </div>
          </motion.div>
        </motion.div>
      )}
    </AnimatePresence>
  );
};

export default ReceiveModal;
