import { useState } from "react";
import { motion, AnimatePresence } from "motion/react";
import {
  Plus,
  Upload,
  Trash2,
  ChevronRight,
  Shield,
  CheckCircle,
  X,
  CreditCard,
  Eye,
  EyeOff,
  Star,
} from "lucide-react";
import { Card3D } from "./Card3D";
import type { CardData } from "./Card3D";

interface VirtualCardScreenProps {
  cards: CardData[];
  activeCardId: string;
  onSetActive: (id: string) => void;
  onAddCard: (card: CardData) => void;
  onDeleteCard: (id: string) => void;
}

const PROVIDERS = ["GCash", "Maya", "Custom"] as const;
const NETWORKS = ["visa", "mastercard"] as const;

const PRESET_COLORS: Record<string, [string, string, string]> = {
  GCash: ["#0046d5", "#0073e6", "#00b4d8"],
  Maya: ["#4a0e8f", "#7c3aed", "#0e7490"],
  Custom: ["#7f1d1d", "#b91c1c", "#c2410c"],
};

export function VirtualCardScreen({
  cards,
  activeCardId,
  onSetActive,
  onAddCard,
  onDeleteCard,
}: VirtualCardScreenProps) {
  const [activeIdx, setActiveIdx] = useState(
    Math.max(0, cards.findIndex((c) => c.id === activeCardId))
  );
  const [showAddModal, setShowAddModal] = useState(false);
  const [showCVV, setShowCVV] = useState(false);

  const [form, setForm] = useState({
    provider: "GCash" as typeof PROVIDERS[number],
    cardNumber: "",
    holderName: "",
    expiry: "",
    cvv: "",
    type: "visa" as "visa" | "mastercard",
  });

  const displayCard = cards[activeIdx] ?? null;

  function handleAddCard() {
    if (!form.cardNumber || !form.holderName || !form.expiry || !form.cvv)
      return;

    const masked =
      form.cardNumber.replace(/\s/g, "").slice(0, 4) +
      " •••• •••• " +
      form.cardNumber.replace(/\s/g, "").slice(-4);

    const newCard: CardData = {
      id: `card-${Date.now()}`,
      provider: form.provider,
      cardNumber: masked,
      holderName: form.holderName.toUpperCase(),
      expiry: form.expiry,
      cvv: form.cvv,
      type: form.type,
      colors: PRESET_COLORS[form.provider],
      balance: 0,
    };
    onAddCard(newCard);
    setShowAddModal(false);
    setForm({
      provider: "GCash",
      cardNumber: "",
      holderName: "",
      expiry: "",
      cvv: "",
      type: "visa",
    });
  }

  function formatCardInput(val: string) {
    const digits = val.replace(/\D/g, "").slice(0, 16);
    return digits.replace(/(.{4})/g, "$1 ").trim();
  }

  function formatExpiry(val: string) {
    const digits = val.replace(/\D/g, "").slice(0, 4);
    if (digits.length > 2) return digits.slice(0, 2) + "/" + digits.slice(2);
    return digits;
  }

  return (
    <div className="pt-14 pb-6 relative">
      {/* Header */}
      <div className="flex items-center justify-between px-5 mb-6">
        <div>
          <h2
            className="text-white"
            style={{ fontSize: 22, fontWeight: 800 }}
          >
            Virtual Cards
          </h2>
          <p className="text-white/40" style={{ fontSize: 12 }}>
            {cards.length} card{cards.length !== 1 ? "s" : ""} linked
          </p>
        </div>
        <motion.button
          whileTap={{ scale: 0.92 }}
          onClick={() => setShowAddModal(true)}
          className="flex items-center gap-1.5 px-3 py-2 rounded-2xl"
          style={{
            background:
              "linear-gradient(135deg, rgba(109,40,217,0.5), rgba(37,99,235,0.4))",
            border: "1px solid rgba(139,92,246,0.35)",
            backdropFilter: "blur(12px)",
          }}
        >
          <Plus size={15} className="text-violet-400" />
          <span className="text-violet-300" style={{ fontSize: 13, fontWeight: 700 }}>
            Add Card
          </span>
        </motion.button>
      </div>

      {/* 3D Card Carousel */}
      <div className="flex justify-center mb-6">
        {cards.length > 0 && displayCard ? (
          <div className="relative">
            <Card3D
              card={displayCard}
              isActive={displayCard.id === activeCardId}
              onSelect={() => {
                if (displayCard.id !== activeCardId) {
                  onSetActive(displayCard.id);
                }
              }}
            />
            {/* Reflection */}
            <div
              className="absolute left-0 right-0 bottom-0 h-16 pointer-events-none"
              style={{
                background:
                  "linear-gradient(to bottom, rgba(0,0,0,0) 0%, rgba(5,0,18,0.8) 100%)",
                filter: "blur(8px)",
                transform: "scaleY(-0.3) translateY(60px)",
                opacity: 0.4,
              }}
            />
          </div>
        ) : (
          <motion.button
            whileTap={{ scale: 0.96 }}
            onClick={() => setShowAddModal(true)}
            className="w-[320px] h-[190px] rounded-[28px] flex flex-col items-center justify-center gap-3 border-2 border-dashed"
            style={{
              borderColor: "rgba(139,92,246,0.3)",
              background: "rgba(139,92,246,0.05)",
            }}
          >
            <div
              className="w-14 h-14 rounded-2xl flex items-center justify-center"
              style={{ background: "rgba(139,92,246,0.15)" }}
            >
              <CreditCard size={24} className="text-violet-400" />
            </div>
            <p className="text-white/50" style={{ fontSize: 13 }}>
              Upload your first virtual card
            </p>
          </motion.button>
        )}
      </div>

      {/* Card dot navigation */}
      {cards.length > 1 && (
        <div className="flex justify-center gap-2 mb-5">
          {cards.map((c, i) => (
            <button
              key={c.id}
              onClick={() => setActiveIdx(i)}
              className="rounded-full transition-all duration-300"
              style={{
                width: i === activeIdx ? 24 : 8,
                height: 8,
                background:
                  i === activeIdx
                    ? "rgba(139,92,246,0.9)"
                    : "rgba(255,255,255,0.2)",
              }}
            />
          ))}
        </div>
      )}

      {/* Card details panel */}
      {displayCard && (
        <motion.div
          key={displayCard.id}
          initial={{ opacity: 0, y: 12 }}
          animate={{ opacity: 1, y: 0 }}
          className="mx-5 mb-4 p-4 rounded-3xl space-y-3"
          style={{
            background: "rgba(255,255,255,0.05)",
            backdropFilter: "blur(20px)",
            border: "1px solid rgba(255,255,255,0.10)",
          }}
        >
          <div className="flex items-center justify-between">
            <p className="text-white/60" style={{ fontSize: 12 }}>
              Card Details
            </p>
            <div className="flex items-center gap-2">
              <Shield size={13} className="text-emerald-400" />
              <span className="text-emerald-400" style={{ fontSize: 11 }}>
                Encrypted
              </span>
            </div>
          </div>

          <div className="grid grid-cols-2 gap-3">
            <div
              className="p-3 rounded-2xl"
              style={{ background: "rgba(255,255,255,0.04)" }}
            >
              <p className="text-white/40 uppercase" style={{ fontSize: 9, letterSpacing: "0.1em" }}>
                Card Number
              </p>
              <p className="text-white mt-1" style={{ fontSize: 12, fontFamily: "monospace" }}>
                {displayCard.cardNumber}
              </p>
            </div>
            <div
              className="p-3 rounded-2xl"
              style={{ background: "rgba(255,255,255,0.04)" }}
            >
              <p className="text-white/40 uppercase" style={{ fontSize: 9, letterSpacing: "0.1em" }}>
                CVV
              </p>
              <div className="flex items-center gap-2 mt-1">
                <p className="text-white" style={{ fontSize: 12, fontFamily: "monospace" }}>
                  {showCVV ? displayCard.cvv : "•••"}
                </p>
                <button onClick={() => setShowCVV(!showCVV)}>
                  {showCVV ? (
                    <EyeOff size={12} className="text-white/40" />
                  ) : (
                    <Eye size={12} className="text-white/40" />
                  )}
                </button>
              </div>
            </div>
            <div
              className="p-3 rounded-2xl"
              style={{ background: "rgba(255,255,255,0.04)" }}
            >
              <p className="text-white/40 uppercase" style={{ fontSize: 9, letterSpacing: "0.1em" }}>
                Expires
              </p>
              <p className="text-white mt-1" style={{ fontSize: 12 }}>
                {displayCard.expiry}
              </p>
            </div>
            <div
              className="p-3 rounded-2xl"
              style={{ background: "rgba(255,255,255,0.04)" }}
            >
              <p className="text-white/40 uppercase" style={{ fontSize: 9, letterSpacing: "0.1em" }}>
                Network
              </p>
              <p className="text-white mt-1 capitalize" style={{ fontSize: 12 }}>
                {displayCard.type}
              </p>
            </div>
          </div>
        </motion.div>
      )}

      {/* Card list */}
      <div className="px-5 space-y-2.5">
        <p className="text-white/50" style={{ fontSize: 12, fontWeight: 600 }}>
          ALL LINKED CARDS
        </p>
        {cards.map((card, i) => (
          <motion.div
            key={card.id}
            initial={{ opacity: 0, x: -16 }}
            animate={{ opacity: 1, x: 0 }}
            transition={{ delay: i * 0.07 }}
            className="flex items-center gap-3 p-3 rounded-2xl"
            style={{
              background:
                card.id === activeCardId
                  ? "rgba(109,40,217,0.18)"
                  : "rgba(255,255,255,0.04)",
              border:
                card.id === activeCardId
                  ? "1px solid rgba(139,92,246,0.3)"
                  : "1px solid rgba(255,255,255,0.07)",
              backdropFilter: "blur(12px)",
            }}
          >
            {/* Color swatch */}
            <div
              className="w-10 h-10 rounded-xl flex-shrink-0"
              style={{
                background: `linear-gradient(135deg, ${card.colors[0]}, ${card.colors[1]})`,
              }}
            />
            <div className="flex-1 min-w-0">
              <div className="flex items-center gap-2">
                <p
                  className="text-white"
                  style={{ fontSize: 13, fontWeight: 600 }}
                >
                  {card.provider}
                </p>
                {card.id === activeCardId && (
                  <span
                    className="px-1.5 py-0.5 rounded-full text-emerald-400"
                    style={{
                      fontSize: 9,
                      fontWeight: 700,
                      background: "rgba(16,185,129,0.15)",
                    }}
                  >
                    ACTIVE
                  </span>
                )}
              </div>
              <p className="text-white/40" style={{ fontSize: 11, fontFamily: "monospace" }}>
                {card.cardNumber}
              </p>
            </div>

            <div className="flex items-center gap-2">
              {card.id !== activeCardId ? (
                <button
                  onClick={() => {
                    onSetActive(card.id);
                    setActiveIdx(i);
                  }}
                  className="px-2.5 py-1.5 rounded-xl"
                  style={{
                    background: "rgba(139,92,246,0.15)",
                    border: "1px solid rgba(139,92,246,0.25)",
                    fontSize: 11,
                    fontWeight: 600,
                    color: "#a78bfa",
                  }}
                >
                  Set Active
                </button>
              ) : (
                <Star size={15} className="text-violet-400 fill-violet-400" />
              )}
              {cards.length > 1 && (
                <button
                  onClick={() => {
                    if (cards.length > 1) {
                      onDeleteCard(card.id);
                      setActiveIdx(Math.min(i, cards.length - 2));
                    }
                  }}
                  className="w-7 h-7 rounded-xl flex items-center justify-center"
                  style={{ background: "rgba(239,68,68,0.12)" }}
                >
                  <Trash2 size={13} className="text-red-400" />
                </button>
              )}
            </div>
          </motion.div>
        ))}

        {/* Add card prompt */}
        <button
          onClick={() => setShowAddModal(true)}
          className="w-full flex items-center gap-3 p-3 rounded-2xl"
          style={{
            background: "rgba(255,255,255,0.03)",
            border: "1px dashed rgba(255,255,255,0.12)",
          }}
        >
          <div
            className="w-10 h-10 rounded-xl flex items-center justify-center"
            style={{ background: "rgba(139,92,246,0.10)" }}
          >
            <Upload size={16} className="text-violet-400" />
          </div>
          <span className="text-white/50" style={{ fontSize: 13 }}>
            Upload another virtual card
          </span>
          <ChevronRight size={14} className="text-white/25 ml-auto" />
        </button>
      </div>

      {/* Add Card Modal */}
      <AnimatePresence>
        {showAddModal && (
          <>
            <motion.div
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
              className="absolute inset-0 z-40"
              style={{ background: "rgba(0,0,0,0.6)", backdropFilter: "blur(8px)" }}
              onClick={() => setShowAddModal(false)}
            />
            <motion.div
              initial={{ opacity: 0, y: 40, scale: 0.96 }}
              animate={{ opacity: 1, y: 0, scale: 1 }}
              exit={{ opacity: 0, y: 40, scale: 0.96 }}
              transition={{ type: "spring", stiffness: 280, damping: 28 }}
              className="absolute bottom-0 left-0 right-0 z-50 rounded-t-[32px] p-6"
              style={{
                background:
                  "linear-gradient(180deg, rgba(18,8,50,0.98) 0%, rgba(10,0,32,0.99) 100%)",
                backdropFilter: "blur(30px)",
                border: "1px solid rgba(255,255,255,0.12)",
                borderBottom: "none",
              }}
            >
              <div className="flex items-center justify-between mb-5">
                <h3 className="text-white" style={{ fontSize: 18, fontWeight: 800 }}>
                  Upload Virtual Card
                </h3>
                <button
                  onClick={() => setShowAddModal(false)}
                  className="w-8 h-8 rounded-full flex items-center justify-center"
                  style={{ background: "rgba(255,255,255,0.08)" }}
                >
                  <X size={16} className="text-white/60" />
                </button>
              </div>

              {/* Provider selection */}
              <div className="mb-4">
                <label className="text-white/50 mb-2 block" style={{ fontSize: 12 }}>
                  Provider
                </label>
                <div className="grid grid-cols-3 gap-2">
                  {PROVIDERS.map((p) => (
                    <button
                      key={p}
                      onClick={() =>
                        setForm((f) => ({
                          ...f,
                          provider: p,
                          type: p === "Maya" ? "mastercard" : "visa",
                        }))
                      }
                      className="py-2 rounded-2xl transition-all"
                      style={{
                        background:
                          form.provider === p
                            ? `linear-gradient(135deg, ${PRESET_COLORS[p][0]}88, ${PRESET_COLORS[p][1]}66)`
                            : "rgba(255,255,255,0.05)",
                        border:
                          form.provider === p
                            ? `1px solid ${PRESET_COLORS[p][0]}66`
                            : "1px solid rgba(255,255,255,0.08)",
                        color: form.provider === p ? "white" : "rgba(255,255,255,0.5)",
                        fontSize: 13,
                        fontWeight: form.provider === p ? 700 : 500,
                      }}
                    >
                      {p}
                    </button>
                  ))}
                </div>
              </div>

              {/* Card number */}
              <div className="mb-3">
                <label className="text-white/50 mb-1.5 block" style={{ fontSize: 12 }}>
                  Card Number
                </label>
                <input
                  value={form.cardNumber}
                  onChange={(e) =>
                    setForm((f) => ({
                      ...f,
                      cardNumber: formatCardInput(e.target.value),
                    }))
                  }
                  placeholder="1234 5678 9012 3456"
                  className="w-full px-4 py-3 rounded-2xl text-white placeholder-white/25 outline-none"
                  style={{
                    background: "rgba(255,255,255,0.07)",
                    border: "1px solid rgba(255,255,255,0.12)",
                    fontSize: 14,
                    fontFamily: "monospace",
                    letterSpacing: "0.1em",
                  }}
                  inputMode="numeric"
                />
              </div>

              {/* Holder name */}
              <div className="mb-3">
                <label className="text-white/50 mb-1.5 block" style={{ fontSize: 12 }}>
                  Card Holder Name
                </label>
                <input
                  value={form.holderName}
                  onChange={(e) =>
                    setForm((f) => ({ ...f, holderName: e.target.value }))
                  }
                  placeholder="JUAN DELA CRUZ"
                  className="w-full px-4 py-3 rounded-2xl text-white placeholder-white/25 outline-none uppercase"
                  style={{
                    background: "rgba(255,255,255,0.07)",
                    border: "1px solid rgba(255,255,255,0.12)",
                    fontSize: 14,
                  }}
                />
              </div>

              <div className="grid grid-cols-2 gap-3 mb-5">
                {/* Expiry */}
                <div>
                  <label className="text-white/50 mb-1.5 block" style={{ fontSize: 12 }}>
                    Expiry
                  </label>
                  <input
                    value={form.expiry}
                    onChange={(e) =>
                      setForm((f) => ({
                        ...f,
                        expiry: formatExpiry(e.target.value),
                      }))
                    }
                    placeholder="MM/YY"
                    className="w-full px-4 py-3 rounded-2xl text-white placeholder-white/25 outline-none"
                    style={{
                      background: "rgba(255,255,255,0.07)",
                      border: "1px solid rgba(255,255,255,0.12)",
                      fontSize: 14,
                      fontFamily: "monospace",
                    }}
                    inputMode="numeric"
                  />
                </div>
                {/* CVV */}
                <div>
                  <label className="text-white/50 mb-1.5 block" style={{ fontSize: 12 }}>
                    CVV
                  </label>
                  <input
                    value={form.cvv}
                    onChange={(e) =>
                      setForm((f) => ({
                        ...f,
                        cvv: e.target.value.replace(/\D/g, "").slice(0, 4),
                      }))
                    }
                    placeholder="•••"
                    type="password"
                    className="w-full px-4 py-3 rounded-2xl text-white placeholder-white/25 outline-none"
                    style={{
                      background: "rgba(255,255,255,0.07)",
                      border: "1px solid rgba(255,255,255,0.12)",
                      fontSize: 14,
                    }}
                    inputMode="numeric"
                  />
                </div>
              </div>

              {/* Network type */}
              <div className="mb-5">
                <label className="text-white/50 mb-2 block" style={{ fontSize: 12 }}>
                  Network
                </label>
                <div className="grid grid-cols-2 gap-2">
                  {NETWORKS.map((n) => (
                    <button
                      key={n}
                      onClick={() => setForm((f) => ({ ...f, type: n }))}
                      className="py-2 rounded-2xl capitalize"
                      style={{
                        background:
                          form.type === n
                            ? "rgba(139,92,246,0.25)"
                            : "rgba(255,255,255,0.05)",
                        border:
                          form.type === n
                            ? "1px solid rgba(139,92,246,0.45)"
                            : "1px solid rgba(255,255,255,0.08)",
                        color: form.type === n ? "#a78bfa" : "rgba(255,255,255,0.5)",
                        fontSize: 13,
                        fontWeight: form.type === n ? 700 : 500,
                      }}
                    >
                      {n}
                    </button>
                  ))}
                </div>
              </div>

              {/* Submit */}
              <motion.button
                whileTap={{ scale: 0.97 }}
                onClick={handleAddCard}
                className="w-full py-4 rounded-2xl flex items-center justify-center gap-2"
                style={{
                  background:
                    "linear-gradient(135deg, #7c3aed, #2563eb)",
                  boxShadow: "0 8px 30px rgba(124,58,237,0.4)",
                }}
              >
                <CheckCircle size={18} className="text-white" />
                <span className="text-white" style={{ fontSize: 15, fontWeight: 800 }}>
                  Upload Card
                </span>
              </motion.button>

              <p className="text-center text-white/30 mt-3" style={{ fontSize: 11 }}>
                🔒 Card details are encrypted end-to-end
              </p>
            </motion.div>
          </>
        )}
      </AnimatePresence>
    </div>
  );
}
