'use client';

import React, { useState, useMemo } from 'react';
import { motion, AnimatePresence } from 'motion/react';
import {
  X,
  Search,
  ArrowUpRight,
  ArrowDownLeft,
  Wifi,
  CreditCard,
  Send,
  Download,
  Filter,
} from 'lucide-react';

type TransactionType = 'send' | 'nfc' | 'receive' | 'topup';
type FilterType = 'all' | TransactionType;

interface Transaction {
  id: number;
  type: TransactionType;
  name: string;
  description: string;
  amount: number;
  date: string;
  status: 'completed' | 'pending' | 'failed';
}

interface TransactionHistoryModalProps {
  isOpen: boolean;
  onClose: () => void;
}

const mockTransactions: Transaction[] = [
  { id: 1, type: 'send', name: 'Maria Santos', description: 'Monthly rent', amount: -12500, date: 'Today, 2:30 PM', status: 'completed' },
  { id: 2, type: 'nfc', name: '7-Eleven Makati', description: 'NFC Payment', amount: -185, date: 'Today, 11:15 AM', status: 'completed' },
  { id: 3, type: 'receive', name: 'Jose Rizal', description: 'Salary payment', amount: 35000, date: 'Today, 9:00 AM', status: 'completed' },
  { id: 4, type: 'topup', name: 'GCash Top Up', description: 'Wallet reload', amount: 5000, date: 'Yesterday, 8:45 PM', status: 'completed' },
  { id: 5, type: 'send', name: 'Ana Garcia', description: 'Dinner split', amount: -450, date: 'Yesterday, 7:20 PM', status: 'completed' },
  { id: 6, type: 'nfc', name: 'Starbucks BGC', description: 'NFC Payment', amount: -275, date: 'Yesterday, 3:10 PM', status: 'completed' },
  { id: 7, type: 'receive', name: 'Carlos Reyes', description: 'Freelance work', amount: 8500, date: 'May 27, 5:00 PM', status: 'completed' },
  { id: 8, type: 'send', name: 'Globe Telecom', description: 'Phone bill', amount: -1299, date: 'May 27, 2:15 PM', status: 'completed' },
  { id: 9, type: 'nfc', name: 'SM Supermarket', description: 'NFC Payment', amount: -2340, date: 'May 27, 12:30 PM', status: 'completed' },
  { id: 10, type: 'topup', name: 'Maya Top Up', description: 'Wallet reload', amount: 2000, date: 'May 26, 10:00 AM', status: 'completed' },
  { id: 11, type: 'send', name: 'Pedro Cruz', description: 'Birthday gift', amount: -1000, date: 'May 26, 8:30 AM', status: 'completed' },
  { id: 12, type: 'nfc', name: 'Grab Ride', description: 'NFC Payment', amount: -156, date: 'May 25, 9:45 PM', status: 'completed' },
  { id: 13, type: 'receive', name: 'Sofia Lim', description: 'Refund', amount: 750, date: 'May 25, 4:20 PM', status: 'completed' },
  { id: 14, type: 'send', name: 'Meralco', description: 'Electric bill', amount: -3200, date: 'May 25, 2:00 PM', status: 'failed' },
  { id: 15, type: 'topup', name: 'Bank Transfer', description: 'Wallet reload', amount: 10000, date: 'May 24, 11:00 AM', status: 'completed' },
  { id: 16, type: 'nfc', name: 'Mercury Drug', description: 'NFC Payment', amount: -890, date: 'May 24, 9:15 AM', status: 'pending' },
];

const typeConfig: Record<
  TransactionType,
  { icon: React.ElementType; color: string; bg: string; label: string }
> = {
  send: {
    icon: Send,
    color: '#f87171',
    bg: 'rgba(248, 113, 113, 0.12)',
    label: 'Send',
  },
  nfc: {
    icon: Wifi,
    color: '#22d3ee',
    bg: 'rgba(34, 211, 238, 0.12)',
    label: 'NFC Pay',
  },
  receive: {
    icon: Download,
    color: '#4ade80',
    bg: 'rgba(74, 222, 128, 0.12)',
    label: 'Receive',
  },
  topup: {
    icon: CreditCard,
    color: '#a78bfa',
    bg: 'rgba(167, 139, 250, 0.12)',
    label: 'Top Up',
  },
};

const filters: { key: FilterType; label: string }[] = [
  { key: 'all', label: 'All' },
  { key: 'send', label: 'Send' },
  { key: 'nfc', label: 'NFC Pay' },
  { key: 'receive', label: 'Receive' },
  { key: 'topup', label: 'Top Up' },
];

const TransactionHistoryModal: React.FC<TransactionHistoryModalProps> = ({
  isOpen,
  onClose,
}) => {
  const [searchQuery, setSearchQuery] = useState('');
  const [activeFilter, setActiveFilter] = useState<FilterType>('all');

  const filteredTransactions = useMemo(() => {
    return mockTransactions.filter((t) => {
      const matchesFilter =
        activeFilter === 'all' || t.type === activeFilter;
      const matchesSearch =
        !searchQuery ||
        t.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
        t.description.toLowerCase().includes(searchQuery.toLowerCase());
      return matchesFilter && matchesSearch;
    });
  }, [searchQuery, activeFilter]);

  const formatAmount = (amount: number) => {
    const abs = Math.abs(amount);
    const formatted = `₱${abs.toLocaleString()}`;
    return amount >= 0 ? `+${formatted}` : `-${formatted}`;
  };

  return (
    <AnimatePresence>
      {isOpen && (
        <motion.div
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          exit={{ opacity: 0 }}
          transition={{ duration: 0.2 }}
          className="fixed inset-0 z-50 flex flex-col"
          style={{
            background:
              'linear-gradient(180deg, rgba(8, 6, 28, 0.99) 0%, rgba(5, 5, 20, 1) 100%)',
          }}
        >
          {/* Header */}
          <motion.div
            initial={{ y: -20, opacity: 0 }}
            animate={{ y: 0, opacity: 1 }}
            transition={{ delay: 0.1 }}
            className="shrink-0 p-5 pb-0"
          >
            <div className="flex items-center justify-between mb-4">
              <div className="flex items-center gap-3">
                <div
                  className="flex items-center justify-center w-9 h-9 rounded-xl"
                  style={{
                    background:
                      'linear-gradient(135deg, rgba(139, 92, 246, 0.25), rgba(59, 130, 246, 0.25))',
                    border: '1px solid rgba(139, 92, 246, 0.2)',
                  }}
                >
                  <Filter size={16} style={{ color: '#a78bfa' }} />
                </div>
                <h2
                  style={{
                    fontSize: '20px',
                    fontWeight: 700,
                    color: '#ffffff',
                    letterSpacing: '-0.02em',
                  }}
                >
                  Transactions
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

            {/* Search */}
            <div
              className="relative mb-4 rounded-xl overflow-hidden"
              style={{
                background: 'rgba(255, 255, 255, 0.04)',
                border: '1px solid rgba(255, 255, 255, 0.06)',
              }}
            >
              <Search
                size={16}
                className="absolute left-3.5 top-1/2 -translate-y-1/2"
                style={{ color: '#64748b' }}
              />
              <input
                type="text"
                placeholder="Search transactions..."
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                className="w-full py-3 pl-10 pr-4 bg-transparent outline-none"
                style={{
                  fontSize: '13px',
                  color: '#e2e8f0',
                }}
              />
            </div>

            {/* Filter pills */}
            <div
              className="flex gap-2 pb-4 overflow-x-auto"
              style={{ scrollbarWidth: 'none' }}
            >
              {filters.map((filter) => (
                <button
                  key={filter.key}
                  onClick={() => setActiveFilter(filter.key)}
                  className="shrink-0 px-4 py-2 rounded-full transition-all"
                  style={{
                    background:
                      activeFilter === filter.key
                        ? 'linear-gradient(135deg, rgba(139, 92, 246, 0.3), rgba(99, 102, 241, 0.3))'
                        : 'rgba(255, 255, 255, 0.04)',
                    border:
                      activeFilter === filter.key
                        ? '1px solid rgba(139, 92, 246, 0.3)'
                        : '1px solid rgba(255, 255, 255, 0.06)',
                    fontSize: '12px',
                    fontWeight: 600,
                    color:
                      activeFilter === filter.key ? '#c4b5fd' : '#94a3b8',
                  }}
                >
                  {filter.label}
                </button>
              ))}
            </div>
          </motion.div>

          {/* Divider */}
          <div
            className="shrink-0 mx-5"
            style={{
              height: '1px',
              background:
                'linear-gradient(90deg, transparent, rgba(255,255,255,0.06), transparent)',
            }}
          />

          {/* Transaction List */}
          <div
            className="flex-1 overflow-y-auto px-5 pt-3 pb-8"
            style={{ scrollbarWidth: 'thin' }}
          >
            <AnimatePresence mode="popLayout">
              {filteredTransactions.length === 0 && (
                <motion.div
                  initial={{ opacity: 0 }}
                  animate={{ opacity: 1 }}
                  className="flex flex-col items-center justify-center py-20"
                >
                  <Search
                    size={40}
                    style={{ color: 'rgba(148, 163, 184, 0.2)' }}
                  />
                  <p
                    style={{
                      fontSize: '14px',
                      color: 'rgba(148, 163, 184, 0.4)',
                      marginTop: '12px',
                    }}
                  >
                    No transactions found
                  </p>
                </motion.div>
              )}

              {filteredTransactions.map((transaction, index) => {
                const config = typeConfig[transaction.type];
                const IconComponent = config.icon;
                const isIncoming = transaction.amount >= 0;

                return (
                  <motion.div
                    key={transaction.id}
                    layout
                    initial={{ opacity: 0, y: 15 }}
                    animate={{ opacity: 1, y: 0 }}
                    exit={{ opacity: 0, y: -10 }}
                    transition={{
                      type: 'spring',
                      damping: 25,
                      stiffness: 300,
                      delay: index * 0.03,
                    }}
                    className="flex items-center gap-3 py-3.5"
                    style={{
                      borderBottom: '1px solid rgba(255, 255, 255, 0.03)',
                    }}
                  >
                    {/* Icon */}
                    <div
                      className="flex items-center justify-center w-11 h-11 rounded-xl shrink-0"
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

                    {/* Details */}
                    <div className="flex-1 min-w-0">
                      <div className="flex items-center gap-2">
                        <p
                          className="truncate"
                          style={{
                            fontSize: '13px',
                            fontWeight: 600,
                            color: '#e2e8f0',
                          }}
                        >
                          {transaction.name}
                        </p>
                        {transaction.status === 'failed' && (
                          <span
                            className="shrink-0 px-1.5 py-0.5 rounded"
                            style={{
                              fontSize: '9px',
                              fontWeight: 700,
                              color: '#f87171',
                              background: 'rgba(248, 113, 113, 0.12)',
                              textTransform: 'uppercase',
                              letterSpacing: '0.05em',
                            }}
                          >
                            Failed
                          </span>
                        )}
                        {transaction.status === 'pending' && (
                          <span
                            className="shrink-0 px-1.5 py-0.5 rounded"
                            style={{
                              fontSize: '9px',
                              fontWeight: 700,
                              color: '#fbbf24',
                              background: 'rgba(251, 191, 36, 0.12)',
                              textTransform: 'uppercase',
                              letterSpacing: '0.05em',
                            }}
                          >
                            Pending
                          </span>
                        )}
                      </div>
                      <p
                        style={{
                          fontSize: '11px',
                          color: '#64748b',
                          marginTop: '2px',
                        }}
                      >
                        {transaction.date}
                      </p>
                    </div>

                    {/* Amount */}
                    <div className="flex items-center gap-1.5 shrink-0">
                      {isIncoming ? (
                        <ArrowDownLeft
                          size={14}
                          style={{ color: '#4ade80' }}
                        />
                      ) : (
                        <ArrowUpRight
                          size={14}
                          style={{ color: '#f87171' }}
                        />
                      )}
                      <p
                        style={{
                          fontSize: '14px',
                          fontWeight: 700,
                          color: isIncoming ? '#4ade80' : '#f87171',
                          fontVariantNumeric: 'tabular-nums',
                        }}
                      >
                        {formatAmount(transaction.amount)}
                      </p>
                    </div>
                  </motion.div>
                );
              })}
            </AnimatePresence>
          </div>
        </motion.div>
      )}
    </AnimatePresence>
  );
};

export default TransactionHistoryModal;
