'use client';

import React, { useState } from 'react';
import { motion, AnimatePresence } from 'motion/react';
import {
  X,
  CheckCircle,
  Wifi,
  ShieldAlert,
  CreditCard,
  Zap,
  Bell,
  Trash2,
} from 'lucide-react';

interface Notification {
  id: number;
  title: string;
  description: string;
  time: string;
  type: 'success' | 'payment' | 'security' | 'card' | 'promo';
}

interface NotificationPanelProps {
  isOpen: boolean;
  onClose: () => void;
}

const initialNotifications: Notification[] = [
  {
    id: 1,
    title: 'Transaction Successful',
    description: '₱2,500 sent to Maria Santos',
    time: '2 hrs ago',
    type: 'success',
  },
  {
    id: 2,
    title: 'NFC Payment',
    description: '₱185 at 7-Eleven',
    time: '5 hrs ago',
    type: 'payment',
  },
  {
    id: 3,
    title: 'Security Alert',
    description: 'New device login detected',
    time: 'Yesterday',
    type: 'security',
  },
  {
    id: 4,
    title: 'Java Card',
    description: 'Card armed successfully',
    time: 'Yesterday',
    type: 'card',
  },
  {
    id: 5,
    title: 'Promo',
    description: 'Upgrade to Premium for 0% fees',
    time: '2 days ago',
    type: 'promo',
  },
];

const typeConfig: Record<
  Notification['type'],
  { icon: React.ElementType; color: string; bg: string }
> = {
  success: {
    icon: CheckCircle,
    color: '#4ade80',
    bg: 'rgba(74, 222, 128, 0.15)',
  },
  payment: {
    icon: Wifi,
    color: '#22d3ee',
    bg: 'rgba(34, 211, 238, 0.15)',
  },
  security: {
    icon: ShieldAlert,
    color: '#fbbf24',
    bg: 'rgba(251, 191, 36, 0.15)',
  },
  card: {
    icon: CreditCard,
    color: '#a78bfa',
    bg: 'rgba(167, 139, 250, 0.15)',
  },
  promo: {
    icon: Zap,
    color: '#fbbf24',
    bg: 'rgba(251, 191, 36, 0.15)',
  },
};

const NotificationPanel: React.FC<NotificationPanelProps> = ({
  isOpen,
  onClose,
}) => {
  const [notifications, setNotifications] =
    useState<Notification[]>(initialNotifications);

  const dismissNotification = (id: number) => {
    setNotifications((prev) => prev.filter((n) => n.id !== id));
  };

  const clearAll = () => {
    setNotifications([]);
  };

  return (
    <AnimatePresence>
      {isOpen && (
        <>
          {/* Backdrop */}
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            transition={{ duration: 0.2 }}
            className="fixed inset-0 z-50"
            style={{ backgroundColor: 'rgba(0, 0, 0, 0.5)' }}
            onClick={onClose}
          />

          {/* Panel */}
          <motion.div
            initial={{ y: '-100%', opacity: 0 }}
            animate={{ y: 0, opacity: 1 }}
            exit={{ y: '-100%', opacity: 0 }}
            transition={{ type: 'spring', damping: 28, stiffness: 300 }}
            className="fixed top-0 left-0 right-0 z-50 max-h-[85vh] overflow-hidden flex flex-col"
            style={{
              background:
                'linear-gradient(135deg, rgba(15, 10, 40, 0.97) 0%, rgba(10, 10, 35, 0.98) 100%)',
              backdropFilter: 'blur(24px)',
              WebkitBackdropFilter: 'blur(24px)',
              borderBottom: '1px solid rgba(255, 255, 255, 0.08)',
              boxShadow: '0 8px 32px rgba(0, 0, 0, 0.4)',
            }}
          >
            {/* Header */}
            <div className="flex items-center justify-between p-5 pb-3">
              <div className="flex items-center gap-3">
                <div
                  className="flex items-center justify-center w-9 h-9 rounded-xl"
                  style={{
                    background:
                      'linear-gradient(135deg, rgba(139, 92, 246, 0.3), rgba(59, 130, 246, 0.3))',
                    border: '1px solid rgba(139, 92, 246, 0.2)',
                  }}
                >
                  <Bell size={18} style={{ color: '#a78bfa' }} />
                </div>
                <h2
                  style={{
                    fontSize: '18px',
                    fontWeight: 700,
                    color: '#ffffff',
                    letterSpacing: '-0.02em',
                  }}
                >
                  Notifications
                </h2>
                {notifications.length > 0 && (
                  <span
                    className="flex items-center justify-center rounded-full"
                    style={{
                      minWidth: '22px',
                      height: '22px',
                      fontSize: '11px',
                      fontWeight: 700,
                      color: '#ffffff',
                      background:
                        'linear-gradient(135deg, #8b5cf6, #6366f1)',
                      padding: '0 6px',
                    }}
                  >
                    {notifications.length}
                  </span>
                )}
              </div>
              <button
                onClick={onClose}
                className="flex items-center justify-center w-9 h-9 rounded-xl transition-colors"
                style={{
                  background: 'rgba(255, 255, 255, 0.06)',
                  border: '1px solid rgba(255, 255, 255, 0.08)',
                }}
              >
                <X size={18} style={{ color: '#94a3b8' }} />
              </button>
            </div>

            {/* Notification List */}
            <div
              className="flex-1 overflow-y-auto px-4 pb-2"
              style={{ scrollbarWidth: 'thin' }}
            >
              <AnimatePresence mode="popLayout">
                {notifications.length === 0 && (
                  <motion.div
                    initial={{ opacity: 0, scale: 0.9 }}
                    animate={{ opacity: 1, scale: 1 }}
                    className="flex flex-col items-center justify-center py-12"
                  >
                    <Bell
                      size={40}
                      style={{ color: 'rgba(148, 163, 184, 0.3)' }}
                    />
                    <p
                      style={{
                        fontSize: '14px',
                        color: 'rgba(148, 163, 184, 0.5)',
                        marginTop: '12px',
                      }}
                    >
                      No notifications
                    </p>
                  </motion.div>
                )}

                {notifications.map((notification, index) => {
                  const config = typeConfig[notification.type];
                  const IconComponent = config.icon;

                  return (
                    <motion.div
                      key={notification.id}
                      layout
                      initial={{ opacity: 0, y: -20, scale: 0.95 }}
                      animate={{ opacity: 1, y: 0, scale: 1 }}
                      exit={{
                        opacity: 0,
                        x: 80,
                        scale: 0.9,
                        transition: { duration: 0.2 },
                      }}
                      transition={{
                        type: 'spring',
                        damping: 25,
                        stiffness: 300,
                        delay: index * 0.04,
                      }}
                      className="flex items-start gap-3 p-3 rounded-xl mb-2 group"
                      style={{
                        background: 'rgba(255, 255, 255, 0.03)',
                        border: '1px solid rgba(255, 255, 255, 0.05)',
                      }}
                    >
                      {/* Icon */}
                      <div
                        className="flex items-center justify-center w-10 h-10 rounded-xl shrink-0 mt-0.5"
                        style={{
                          background: config.bg,
                          border: `1px solid ${config.color}22`,
                        }}
                      >
                        <IconComponent
                          size={18}
                          style={{ color: config.color }}
                        />
                      </div>

                      {/* Content */}
                      <div className="flex-1 min-w-0">
                        <p
                          style={{
                            fontSize: '13px',
                            fontWeight: 600,
                            color: '#e2e8f0',
                            marginBottom: '2px',
                          }}
                        >
                          {notification.title}
                        </p>
                        <p
                          style={{
                            fontSize: '12px',
                            color: '#94a3b8',
                            lineHeight: '1.4',
                          }}
                        >
                          {notification.description}
                        </p>
                        <p
                          style={{
                            fontSize: '11px',
                            color: 'rgba(148, 163, 184, 0.5)',
                            marginTop: '4px',
                          }}
                        >
                          {notification.time}
                        </p>
                      </div>

                      {/* Dismiss button */}
                      <button
                        onClick={() => dismissNotification(notification.id)}
                        className="flex items-center justify-center w-7 h-7 rounded-lg opacity-0 group-hover:opacity-100 transition-opacity shrink-0"
                        style={{
                          background: 'rgba(255, 255, 255, 0.06)',
                        }}
                      >
                        <X size={14} style={{ color: '#64748b' }} />
                      </button>
                    </motion.div>
                  );
                })}
              </AnimatePresence>
            </div>

            {/* Clear All */}
            {notifications.length > 0 && (
              <div className="p-4 pt-2">
                <button
                  onClick={clearAll}
                  className="w-full flex items-center justify-center gap-2 py-3 rounded-xl transition-colors"
                  style={{
                    background: 'rgba(239, 68, 68, 0.08)',
                    border: '1px solid rgba(239, 68, 68, 0.15)',
                    fontSize: '13px',
                    fontWeight: 600,
                    color: '#f87171',
                  }}
                >
                  <Trash2 size={14} />
                  Clear All
                </button>
              </div>
            )}
          </motion.div>
        </>
      )}
    </AnimatePresence>
  );
};

export default NotificationPanel;
