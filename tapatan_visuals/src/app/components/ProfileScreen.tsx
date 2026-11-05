import { useState } from "react";
import { motion, AnimatePresence } from "motion/react";
import {
  User,
  Shield,
  Bell,
  CreditCard,
  HelpCircle,
  ChevronRight,
  Lock,
  Fingerprint,
  Wifi,
  LogOut,
  Star,
  CheckCircle,
  Info,
} from "lucide-react";
import {
  PersonalInfoPanel,
  ChangePINModal,
  PrivacySettingsPanel,
  NFCSettingsPanel,
  HelpCenterPanel,
  PremiumUpgradeModal,
} from "./ProfileModals";
import { SecurityInfoScreen } from "./SecurityInfoScreen";

interface ProfileScreenProps {
  onSignOut?: () => void;
  onNavigate?: (tab: string) => void;
}

export function ProfileScreen({ onSignOut, onNavigate }: ProfileScreenProps) {
  const [toggles, setToggles] = useState<Record<string, boolean>>({
    "Biometric Auth": true,
    Notifications: true,
  });

  const [showPersonalInfo, setShowPersonalInfo] = useState(false);
  const [showChangePIN, setShowChangePIN] = useState(false);
  const [showPrivacy, setShowPrivacy] = useState(false);
  const [showNFC, setShowNFC] = useState(false);
  const [showHelp, setShowHelp] = useState(false);
  const [showPremium, setShowPremium] = useState(false);
  const [showSecurityInfo, setShowSecurityInfo] = useState(false);

  function toggleItem(label: string) {
    setToggles((t) => ({ ...t, [label]: !t[label] }));
  }

  const MENU_SECTIONS = [
    {
      title: "Account",
      items: [
        { icon: User, label: "Personal Information", color: "#7c3aed", action: () => setShowPersonalInfo(true) },
        { icon: CreditCard, label: "Linked Banks & Cards", color: "#2563eb", badge: "3", action: () => onNavigate?.("cards") },
        { icon: Star, label: "Upgrade to Premium", color: "#f59e0b", highlight: true, action: () => setShowPremium(true) },
      ],
    },
    {
      title: "Security",
      items: [
        { icon: Lock, label: "Change PIN", color: "#06b6d4", action: () => setShowChangePIN(true) },
        { icon: Fingerprint, label: "Biometric Auth", color: "#10b981", toggle: true, defaultOn: true },
        { icon: Shield, label: "Privacy Settings", color: "#7c3aed", action: () => setShowPrivacy(true) },
        { icon: Info, label: "Security Info & Card Lock", color: "#ef4444", action: () => setShowSecurityInfo(true) },
      ],
    },
    {
      title: "Preferences",
      items: [
        { icon: Bell, label: "Notifications", color: "#f59e0b", toggle: true, defaultOn: true },
        { icon: Wifi, label: "NFC & Java Card Settings", color: "#06b6d4", action: () => setShowNFC(true) },
      ],
    },
    {
      title: "Support",
      items: [
        { icon: HelpCircle, label: "Help Center", color: "#64748b", action: () => setShowHelp(true) },
        { icon: LogOut, label: "Sign Out", color: "#ef4444", danger: true, action: () => onSignOut?.() },
      ],
    },
  ];

  return (
    <div className="pt-14 pb-6 relative min-h-full">
      {/* Profile hero */}
      <div className="px-5 mb-6">
        <motion.div
          initial={{ opacity: 0, y: 16 }}
          animate={{ opacity: 1, y: 0 }}
          className="p-5 rounded-3xl relative overflow-hidden"
          style={{
            background:
              "linear-gradient(135deg, rgba(109,40,217,0.35) 0%, rgba(37,99,235,0.28) 100%)",
            backdropFilter: "blur(24px)",
            border: "1px solid rgba(255,255,255,0.14)",
          }}
        >
          {/* Orb */}
          <div
            className="absolute -top-10 -right-10 w-40 h-40 rounded-full pointer-events-none"
            style={{ background: "rgba(139,92,246,0.25)", filter: "blur(40px)" }}
          />

          <div className="flex items-center gap-4 relative">
            {/* Avatar */}
            <div
              className="w-16 h-16 rounded-2xl flex items-center justify-center flex-shrink-0"
              style={{
                background:
                  "linear-gradient(135deg, rgba(124,58,237,0.6), rgba(37,99,235,0.5))",
                border: "2px solid rgba(255,255,255,0.2)",
                boxShadow: "0 8px 25px rgba(124,58,237,0.35)",
              }}
            >
              <span
                className="text-white"
                style={{ fontSize: 22, fontWeight: 900 }}
              >
                JC
              </span>
            </div>

            <div className="flex-1">
              <div className="flex items-center gap-2">
                <p
                  className="text-white"
                  style={{ fontSize: 17, fontWeight: 800 }}
                >
                  Juan dela Cruz
                </p>
                <div
                  className="flex items-center gap-1 px-1.5 py-0.5 rounded-full cursor-pointer"
                  onClick={() => setShowPremium(true)}
                  style={{
                    background: "rgba(245,158,11,0.18)",
                    border: "1px solid rgba(245,158,11,0.3)",
                  }}
                >
                  <Star
                    size={9}
                    className="text-amber-400 fill-amber-400"
                  />
                  <span
                    className="text-amber-400"
                    style={{ fontSize: 9, fontWeight: 700 }}
                  >
                    PRO
                  </span>
                </div>
              </div>
              <p className="text-white/50" style={{ fontSize: 12, marginTop: 2 }}>
                juan.delacruz@gcash.com
              </p>
              <p className="text-white/35" style={{ fontSize: 11, marginTop: 1 }}>
                +63 917 123 4567
              </p>
            </div>
          </div>

          {/* Stats */}
          <div
            className="flex items-center gap-0 mt-4 rounded-2xl overflow-hidden"
            style={{ background: "rgba(0,0,0,0.2)" }}
          >
            {[
              { label: "Cards", value: "2" },
              { label: "Transactions", value: "142" },
              { label: "NFC Pays", value: "38" },
            ].map((s, i) => (
              <div
                key={s.label}
                className="flex-1 py-3 text-center"
                style={{
                  borderRight:
                    i < 2 ? "1px solid rgba(255,255,255,0.08)" : "none",
                }}
              >
                <p
                  className="text-white"
                  style={{ fontSize: 18, fontWeight: 800 }}
                >
                  {s.value}
                </p>
                <p className="text-white/40" style={{ fontSize: 10 }}>
                  {s.label}
                </p>
              </div>
            ))}
          </div>
        </motion.div>
      </div>

      {/* Menu sections */}
      <div className="px-5 space-y-5">
        {MENU_SECTIONS.map((section, si) => (
          <motion.div
            key={section.title}
            initial={{ opacity: 0, y: 16 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: si * 0.07 }}
          >
            <p
              className="text-white/40 mb-2.5 px-1"
              style={{ fontSize: 11, fontWeight: 700, letterSpacing: "0.1em" }}
            >
              {section.title.toUpperCase()}
            </p>
            <div
              className="rounded-3xl overflow-hidden"
              style={{
                background: "rgba(255,255,255,0.04)",
                border: "1px solid rgba(255,255,255,0.08)",
                backdropFilter: "blur(16px)",
              }}
            >
              {section.items.map((item, ii) => {
                const Icon = item.icon;
                const hasToggle = "toggle" in item && item.toggle;
                const isOn = toggles[item.label] ?? false;

                return (
                  <button
                    key={item.label}
                    onClick={() => {
                      if (hasToggle) toggleItem(item.label);
                      else if ("action" in item && item.action) item.action();
                    }}
                    className="w-full flex items-center gap-3 px-4 py-3.5 text-left"
                    style={{
                      borderTop:
                        ii > 0 ? "1px solid rgba(255,255,255,0.05)" : "none",
                      background:
                        "highlight" in item && item.highlight
                          ? "rgba(245,158,11,0.06)"
                          : "transparent",
                    }}
                  >
                    <div
                      className="w-8 h-8 rounded-xl flex items-center justify-center flex-shrink-0"
                      style={{ background: `${item.color}22` }}
                    >
                      <Icon size={15} style={{ color: item.color }} />
                    </div>
                    <span
                      className="flex-1"
                      style={{
                        fontSize: 14,
                        fontWeight: 500,
                        color:
                          "danger" in item && item.danger
                            ? "#ef4444"
                            : "highlight" in item && item.highlight
                            ? "#f59e0b"
                            : "rgba(255,255,255,0.85)",
                      }}
                    >
                      {item.label}
                    </span>

                    {"badge" in item && item.badge && (
                      <span
                        className="px-2 py-0.5 rounded-full"
                        style={{
                          background: "rgba(139,92,246,0.2)",
                          color: "#a78bfa",
                          fontSize: 11,
                          fontWeight: 700,
                        }}
                      >
                        {item.badge}
                      </span>
                    )}

                    {hasToggle ? (
                      <div
                        className="relative flex-shrink-0"
                        style={{
                          width: 40,
                          height: 24,
                          borderRadius: 12,
                          background: isOn
                            ? "rgba(124,58,237,0.6)"
                            : "rgba(255,255,255,0.12)",
                          border: isOn
                            ? "1px solid rgba(139,92,246,0.5)"
                            : "1px solid rgba(255,255,255,0.12)",
                          transition: "background 0.2s",
                        }}
                      >
                        <div
                          style={{
                            position: "absolute",
                            top: 3,
                            left: isOn ? 18 : 3,
                            width: 16,
                            height: 16,
                            borderRadius: "50%",
                            background: "white",
                            transition: "left 0.2s",
                            boxShadow: "0 1px 4px rgba(0,0,0,0.3)",
                          }}
                        />
                      </div>
                    ) : (
                      !("danger" in item && item.danger) && (
                        <ChevronRight size={15} className="text-white/20 flex-shrink-0" />
                      )
                    )}
                  </button>
                );
              })}
            </div>
          </motion.div>
        ))}

        {/* App info */}
        <motion.div
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ delay: 0.4 }}
          className="text-center pt-2 pb-4"
        >
          <div className="flex items-center justify-center gap-1.5 mb-1">
            <CheckCircle size={12} className="text-emerald-400" />
            <span className="text-white/30" style={{ fontSize: 11 }}>
              Secured by end-to-end encryption
            </span>
          </div>
          <p className="text-white/20" style={{ fontSize: 11 }}>
            JavaPay v2.4.0 · Build 2024.12
          </p>
        </motion.div>
      </div>

      {/* ── Modals ── */}
      <PersonalInfoPanel isOpen={showPersonalInfo} onClose={() => setShowPersonalInfo(false)} />
      <ChangePINModal isOpen={showChangePIN} onClose={() => setShowChangePIN(false)} />
      <PrivacySettingsPanel isOpen={showPrivacy} onClose={() => setShowPrivacy(false)} />
      <NFCSettingsPanel isOpen={showNFC} onClose={() => setShowNFC(false)} />
      <HelpCenterPanel isOpen={showHelp} onClose={() => setShowHelp(false)} />
      <PremiumUpgradeModal isOpen={showPremium} onClose={() => setShowPremium(false)} />

      {/* Security Info overlay */}
      <AnimatePresence>
        {showSecurityInfo && (
          <motion.div
            key="security-info"
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: 20 }}
            transition={{ duration: 0.25 }}
            className="fixed inset-0 z-50 overflow-y-auto"
            style={{
              background: "linear-gradient(160deg, #0d0230 0%, #070020 35%, #050018 65%, #040015 100%)",
              scrollbarWidth: "none",
            }}
          >
            <SecurityInfoScreen onBack={() => setShowSecurityInfo(false)} />
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}
