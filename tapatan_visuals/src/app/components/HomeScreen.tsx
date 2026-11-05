import { useState } from "react";
import { motion, AnimatePresence } from "motion/react";
import {
  Eye,
  EyeOff,
  Bell,
  ArrowUpRight,
  ArrowDownLeft,
  Zap,
  Plus,
  ChevronRight,
  TrendingUp,
  ShoppingBag,
  Coffee,
  Wifi,
  Shield,
} from "lucide-react";
import {
  AreaChart,
  Area,
  ResponsiveContainer,
  XAxis,
  Tooltip,
} from "recharts";
import type { CardData } from "./Card3D";
import NotificationPanel from "./NotificationPanel";
import ReceiveModal from "./ReceiveModal";
import TopUpModal from "./TopUpModal";
import TransactionHistoryModal from "./TransactionHistoryModal";

const spendingData = [
  { day: "Mon", amount: 320 },
  { day: "Tue", amount: 180 },
  { day: "Wed", amount: 520 },
  { day: "Thu", amount: 280 },
  { day: "Fri", amount: 640 },
  { day: "Sat", amount: 420 },
  { day: "Sun", amount: 230 },
];

const transactions = [
  {
    id: 1,
    name: "Shopee",
    amount: -245.0,
    icon: ShoppingBag,
    iconColor: "#f97316",
    time: "2 hrs ago",
  },
  {
    id: 2,
    name: "GCash Transfer",
    amount: +5000.0,
    icon: ArrowDownLeft,
    iconColor: "#10b981",
    time: "Yesterday",
  },
  {
    id: 3,
    name: "Starbucks",
    amount: -185.0,
    icon: Coffee,
    iconColor: "#a78bfa",
    time: "2 days ago",
  },
];

interface HomeScreenProps {
  activeCard: CardData | null;
  onTabChange: (tab: string) => void;
  cardActive?: boolean;
  sessionTxnDone?: boolean;
  onArmCard?: () => void;
  onOpenOverlay?: (type: "nfc" | "send") => void;
}

export function HomeScreen({
  activeCard,
  onTabChange,
  cardActive = false,
  sessionTxnDone = false,
  onArmCard,
  onOpenOverlay,
}: HomeScreenProps) {
  const [showBalance, setShowBalance] = useState(true);
  const [showNotifications, setShowNotifications] = useState(false);
  const [showReceive, setShowReceive] = useState(false);
  const [showTopUp, setShowTopUp] = useState(false);
  const [showHistory, setShowHistory] = useState(false);

  return (
    <div className="px-5 pt-14 pb-6 space-y-4">
      {/* ── Java Card Status Banner ── */}
      <div
        className="flex items-center gap-2 px-3 py-2 rounded-2xl"
        style={{
          background: sessionTxnDone
            ? "rgba(245,158,11,0.08)"
            : cardActive
            ? "rgba(16,185,129,0.08)"
            : "rgba(255,255,255,0.04)",
          border: sessionTxnDone
            ? "1px solid rgba(245,158,11,0.2)"
            : cardActive
            ? "1px solid rgba(16,185,129,0.25)"
            : "1px solid rgba(255,255,255,0.08)",
        }}
      >
        <div
          className="w-1.5 h-1.5 rounded-full flex-shrink-0"
          style={{
            background: sessionTxnDone
              ? "#f59e0b"
              : cardActive
              ? "#34d399"
              : "rgba(255,255,255,0.2)",
            boxShadow: sessionTxnDone
              ? "0 0 6px #f59e0b"
              : cardActive
              ? "0 0 6px #34d399"
              : "none",
          }}
        />
        <span
          style={{
            fontSize: 11,
            fontWeight: 700,
            color: sessionTxnDone
              ? "#f59e0b"
              : cardActive
              ? "#34d399"
              : "rgba(255,255,255,0.3)",
          }}
        >
          {sessionTxnDone
            ? "Java Card · Transaction used — re-tap to rearm"
            : cardActive
            ? "Java Card · Armed — 1 transaction ready"
            : "Java Card · Not activated"}
        </span>
        <Wifi
          size={11}
          className="ml-auto flex-shrink-0"
          style={{
            color: sessionTxnDone
              ? "#f59e0b"
              : cardActive
              ? "#34d399"
              : "rgba(255,255,255,0.2)",
          }}
        />
      </div>

      {/* Header */}
      <div className="flex items-center justify-between">
        <motion.div
          initial={{ opacity: 0, x: -20 }}
          animate={{ opacity: 1, x: 0 }}
        >
          <p className="text-white/50" style={{ fontSize: 13 }}>
            Good morning ☀️
          </p>
          <h2
            className="text-white"
            style={{ fontSize: 20, fontWeight: 700, marginTop: 2 }}
          >
            Harry Dimaano
          </h2>
        </motion.div>
        <motion.button
          initial={{ opacity: 0, scale: 0.8 }}
          animate={{ opacity: 1, scale: 1 }}
          onClick={() => setShowNotifications(true)}
          className="relative w-10 h-10 rounded-full flex items-center justify-center"
          style={{
            background: "rgba(255,255,255,0.08)",
            backdropFilter: "blur(12px)",
            border: "1px solid rgba(255,255,255,0.14)",
          }}
        >
          <Bell size={17} className="text-white/80" />
          <span
            className="absolute top-0.5 right-0.5 w-2.5 h-2.5 rounded-full bg-violet-500"
            style={{ border: "2px solid #050012" }}
          />
        </motion.button>
      </div>

      {/* ── Enable Transaction Button (when card NOT armed) ── */}
      {!cardActive && (
        <motion.button
          initial={{ opacity: 0, y: 12 }}
          animate={{ opacity: 1, y: 0 }}
          whileTap={{ scale: 0.97 }}
          onClick={onArmCard}
          className="w-full py-4 rounded-3xl flex items-center justify-center gap-3 relative overflow-hidden"
          style={{
            background:
              "linear-gradient(135deg, rgba(109,40,217,0.5) 0%, rgba(6,182,212,0.4) 50%, rgba(37,99,235,0.45) 100%)",
            border: "1px solid rgba(139,92,246,0.35)",
            boxShadow:
              "0 8px 32px rgba(109,40,217,0.3), 0 0 60px rgba(6,182,212,0.1)",
          }}
        >
          {/* Animated background pulse */}
          <motion.div
            className="absolute inset-0 pointer-events-none"
            animate={{ opacity: [0.3, 0.6, 0.3] }}
            transition={{ repeat: Infinity, duration: 2.5, ease: "easeInOut" }}
            style={{
              background:
                "radial-gradient(circle at 50% 50%, rgba(167,139,250,0.25) 0%, transparent 70%)",
            }}
          />
          <div
            className="w-10 h-10 rounded-2xl flex items-center justify-center relative z-10"
            style={{
              background: "rgba(255,255,255,0.12)",
              backdropFilter: "blur(8px)",
            }}
          >
            <Shield size={20} className="text-white" />
          </div>
          <div className="relative z-10 text-left">
            <p
              className="text-white"
              style={{ fontSize: 15, fontWeight: 800 }}
            >
              Enable Transaction
            </p>
            <p className="text-white/50" style={{ fontSize: 11 }}>
              Tap Java Card to arm for payment
            </p>
          </div>
          <motion.div
            animate={{ x: [0, 4, 0] }}
            transition={{ repeat: Infinity, duration: 1.5 }}
            className="relative z-10"
          >
            <ChevronRight size={20} className="text-white/60" />
          </motion.div>
        </motion.button>
      )}

      {/* Balance Card */}
      <motion.div
        initial={{ opacity: 0, y: 24 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ delay: 0.05 }}
        className="rounded-3xl p-5 relative overflow-hidden"
        style={{
          background:
            "linear-gradient(135deg, rgba(109,40,217,0.45) 0%, rgba(37,99,235,0.35) 60%, rgba(6,182,212,0.25) 100%)",
          backdropFilter: "blur(24px)",
          border: "1px solid rgba(255,255,255,0.16)",
          boxShadow:
            "0 8px 40px rgba(109,40,217,0.25), inset 0 1px 0 rgba(255,255,255,0.12)",
        }}
      >
        {/* Ambient glow blobs */}
        <div
          className="absolute -top-12 -right-12 w-48 h-48 rounded-full pointer-events-none"
          style={{
            background: "rgba(139,92,246,0.25)",
            filter: "blur(50px)",
          }}
        />
        <div
          className="absolute -bottom-12 -left-8 w-36 h-36 rounded-full pointer-events-none"
          style={{
            background: "rgba(6,182,212,0.18)",
            filter: "blur(40px)",
          }}
        />

        <div className="flex items-center justify-between mb-1">
          <span className="text-white/60" style={{ fontSize: 12 }}>
            Total Balance
          </span>
          <button
            onClick={() => setShowBalance(!showBalance)}
            className="p-1 rounded-lg"
            style={{ background: "rgba(255,255,255,0.06)" }}
          >
            {showBalance ? (
              <Eye size={14} className="text-white/40" />
            ) : (
              <EyeOff size={14} className="text-white/40" />
            )}
          </button>
        </div>

        <motion.div
          key={showBalance ? "shown" : "hidden"}
          initial={{ opacity: 0, y: 6 }}
          animate={{ opacity: 1, y: 0 }}
          className="text-white mb-4"
          style={{
            fontSize: 34,
            fontWeight: 800,
            letterSpacing: "-0.03em",
          }}
        >
          {showBalance ? "₱ 441,250.50" : "₱ ••••••••"}
        </motion.div>

        <div className="flex items-center gap-5">
          <div className="flex items-center gap-2">
            <div
              className="w-7 h-7 rounded-full flex items-center justify-center"
              style={{ background: "rgba(16,185,129,0.18)" }}
            >
              <TrendingUp size={13} className="text-emerald-400" />
            </div>
            <div>
              <p className="text-white/45" style={{ fontSize: 10 }}>
                Income
              </p>
              <p
                className="text-emerald-400"
                style={{ fontSize: 13, fontWeight: 700 }}
              >
                +₱128,400
              </p>
            </div>
          </div>
          <div
            className="w-px h-8"
            style={{ background: "rgba(255,255,255,0.12)" }}
          />
          <div className="flex items-center gap-2">
            <div
              className="w-7 h-7 rounded-full flex items-center justify-center"
              style={{ background: "rgba(248,113,113,0.18)" }}
            >
              <ArrowUpRight size={13} className="text-red-400" />
            </div>
            <div>
              <p className="text-white/45" style={{ fontSize: 10 }}>
                Expenses
              </p>
              <p
                className="text-red-400"
                style={{ fontSize: 13, fontWeight: 700 }}
              >
                -₱35,320
              </p>
            </div>
          </div>
        </div>
      </motion.div>

      {/* Active card preview */}
      {activeCard && (
        <motion.button
          initial={{ opacity: 0, y: 16 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.1 }}
          onClick={() => onTabChange("cards")}
          className="w-full flex items-center gap-3 p-3 rounded-2xl text-left"
          style={{
            background: "rgba(255,255,255,0.05)",
            backdropFilter: "blur(16px)",
            border: "1px solid rgba(255,255,255,0.10)",
          }}
        >
          <div
            className="w-10 h-10 rounded-xl flex items-center justify-center"
            style={{
              background: `linear-gradient(135deg, ${activeCard.colors[0]}, ${activeCard.colors[1]})`,
            }}
          >
            <Wifi size={16} className="text-white" />
          </div>
          <div className="flex-1">
            <p
              className="text-white"
              style={{ fontSize: 13, fontWeight: 600 }}
            >
              {activeCard.provider} Active
            </p>
            <p className="text-white/45" style={{ fontSize: 11 }}>
              {activeCard.cardNumber} · Ready for NFC
            </p>
          </div>
          <div className="flex items-center gap-1.5">
            <span
              className="w-2 h-2 rounded-full bg-emerald-400 animate-pulse"
              style={{ boxShadow: "0 0 6px #34d399" }}
            />
            <ChevronRight size={14} className="text-white/30" />
          </div>
        </motion.button>
      )}

      {/* Quick actions */}
      <motion.div
        initial={{ opacity: 0, y: 16 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ delay: 0.12 }}
        className="grid grid-cols-4 gap-2.5"
      >
        {[
          {
            label: "Send",
            icon: ArrowUpRight,
            from: "rgba(124,58,237,0.35)",
            to: "rgba(109,40,217,0.25)",
            action: () => onOpenOverlay?.("send"),
          },
          {
            label: "Receive",
            icon: ArrowDownLeft,
            from: "rgba(59,130,246,0.35)",
            to: "rgba(37,99,235,0.25)",
            action: () => setShowReceive(true),
          },
          {
            label: "NFC Pay",
            icon: Wifi,
            from: "rgba(6,182,212,0.35)",
            to: "rgba(8,145,178,0.25)",
            action: () => onOpenOverlay?.("nfc"),
          },
          {
            label: "Top Up",
            icon: Plus,
            from: "rgba(16,185,129,0.35)",
            to: "rgba(5,150,105,0.25)",
            action: () => setShowTopUp(true),
          },
        ].map((act) => {
          const Icon = act.icon;
          return (
            <button
              key={act.label}
              onClick={act.action}
              className="flex flex-col items-center gap-2 py-3 px-1 rounded-2xl"
              style={{
                background: `linear-gradient(160deg, ${act.from}, ${act.to})`,
                backdropFilter: "blur(12px)",
                border: "1px solid rgba(255,255,255,0.10)",
              }}
            >
              <div
                className="w-9 h-9 rounded-xl flex items-center justify-center"
                style={{ background: "rgba(255,255,255,0.10)" }}
              >
                <Icon size={17} className="text-white" />
              </div>
              <span
                className="text-white/70"
                style={{ fontSize: 10, fontWeight: 500 }}
              >
                {act.label}
              </span>
            </button>
          );
        })}
      </motion.div>

      {/* Spending chart */}
      <motion.div
        initial={{ opacity: 0, y: 16 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ delay: 0.15 }}
        className="rounded-3xl p-4"
        style={{
          background: "rgba(255,255,255,0.04)",
          backdropFilter: "blur(20px)",
          border: "1px solid rgba(255,255,255,0.08)",
        }}
      >
        <div className="flex items-center justify-between mb-3">
          <h3
            className="text-white"
            style={{ fontSize: 14, fontWeight: 700 }}
          >
            Weekly Spending
          </h3>
          <span
            className="px-2 py-0.5 rounded-full text-violet-400"
            style={{
              fontSize: 10,
              fontWeight: 600,
              background: "rgba(139,92,246,0.15)",
              border: "1px solid rgba(139,92,246,0.25)",
            }}
          >
            This week
          </span>
        </div>
        <ResponsiveContainer width="100%" height={75}>
          <AreaChart
            data={spendingData}
            margin={{ top: 2, right: 2, left: 2, bottom: 0 }}
          >
            <defs>
              <linearGradient id="spendGrad" x1="0" y1="0" x2="0" y2="1">
                <stop offset="5%" stopColor="#7c3aed" stopOpacity={0.5} />
                <stop offset="95%" stopColor="#7c3aed" stopOpacity={0.0} />
              </linearGradient>
            </defs>
            <XAxis
              dataKey="day"
              axisLine={false}
              tickLine={false}
              tick={{ fill: "rgba(255,255,255,0.35)", fontSize: 9 }}
            />
            <Tooltip
              contentStyle={{
                background: "rgba(10,0,32,0.92)",
                border: "1px solid rgba(139,92,246,0.3)",
                borderRadius: 12,
                color: "white",
                fontSize: 12,
                backdropFilter: "blur(16px)",
              }}
              itemStyle={{ color: "#a78bfa" }}
              formatter={(v: number) => [`₱${v}`, "Spent"]}
              cursor={{ stroke: "rgba(139,92,246,0.3)", strokeWidth: 1 }}
            />
            <Area
              type="monotone"
              dataKey="amount"
              stroke="#7c3aed"
              strokeWidth={2}
              fill="url(#spendGrad)"
              dot={false}
            />
          </AreaChart>
        </ResponsiveContainer>
      </motion.div>

      {/* Recent transactions */}
      <motion.div
        initial={{ opacity: 0, y: 16 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ delay: 0.18 }}
      >
        <div className="flex items-center justify-between mb-3">
          <h3
            className="text-white"
            style={{ fontSize: 14, fontWeight: 700 }}
          >
            Recent Activity
          </h3>
          <button
            onClick={() => setShowHistory(true)}
            className="flex items-center gap-0.5 text-violet-400"
            style={{ fontSize: 12 }}
          >
            See all <ChevronRight size={13} />
          </button>
        </div>

        <div className="space-y-2.5">
          {transactions.map((tx, i) => {
            const Icon = tx.icon;
            return (
              <motion.div
                key={tx.id}
                initial={{ opacity: 0, x: -16 }}
                animate={{ opacity: 1, x: 0 }}
                transition={{ delay: 0.2 + i * 0.07 }}
                className="flex items-center gap-3 p-3 rounded-2xl"
                style={{
                  background: "rgba(255,255,255,0.04)",
                  border: "1px solid rgba(255,255,255,0.07)",
                  backdropFilter: "blur(12px)",
                }}
              >
                <div
                  className="w-10 h-10 rounded-xl flex items-center justify-center flex-shrink-0"
                  style={{ background: `${tx.iconColor}22` }}
                >
                  <Icon size={17} style={{ color: tx.iconColor }} />
                </div>
                <div className="flex-1 min-w-0">
                  <p
                    className="text-white"
                    style={{ fontSize: 13, fontWeight: 600 }}
                  >
                    {tx.name}
                  </p>
                  <p className="text-white/40" style={{ fontSize: 11 }}>
                    {tx.time}
                  </p>
                </div>
                <p
                  style={{
                    fontSize: 14,
                    fontWeight: 700,
                    color: tx.amount > 0 ? "#34d399" : "#f87171",
                  }}
                >
                  {tx.amount > 0 ? "+" : ""}₱
                  {Math.abs(tx.amount).toFixed(2)}
                </p>
              </motion.div>
            );
          })}
        </div>
      </motion.div>

      {/* Zap promotion */}
      <motion.div
        initial={{ opacity: 0, y: 16 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ delay: 0.22 }}
        className="rounded-3xl p-4 flex items-center gap-3 relative overflow-hidden"
        style={{
          background:
            "linear-gradient(135deg, rgba(245,158,11,0.22) 0%, rgba(239,68,68,0.15) 100%)",
          border: "1px solid rgba(245,158,11,0.25)",
          backdropFilter: "blur(16px)",
        }}
      >
        <div
          className="w-10 h-10 rounded-2xl flex items-center justify-center flex-shrink-0"
          style={{ background: "rgba(245,158,11,0.25)" }}
        >
          <Zap size={18} className="text-amber-400" />
        </div>
        <div className="flex-1">
          <p
            className="text-white"
            style={{ fontSize: 13, fontWeight: 700 }}
          >
            Java Card Ready
          </p>
          <p className="text-white/50" style={{ fontSize: 11 }}>
            Tap phone to write token to your Java Card
          </p>
        </div>
        <button
          onClick={() => onOpenOverlay?.("nfc")}
          className="px-3 py-1.5 rounded-xl text-amber-400"
          style={{
            background: "rgba(245,158,11,0.18)",
            border: "1px solid rgba(245,158,11,0.3)",
            fontSize: 11,
            fontWeight: 700,
          }}
        >
          Go
        </button>
      </motion.div>

      {/* ── Modals ── */}
      <NotificationPanel
        isOpen={showNotifications}
        onClose={() => setShowNotifications(false)}
      />
      <ReceiveModal
        isOpen={showReceive}
        onClose={() => setShowReceive(false)}
      />
      <TopUpModal isOpen={showTopUp} onClose={() => setShowTopUp(false)} />
      <TransactionHistoryModal
        isOpen={showHistory}
        onClose={() => setShowHistory(false)}
      />
    </div>
  );
}
