import { useState, useEffect } from "react";
import { motion, AnimatePresence } from "motion/react";
import { Home, CreditCard, User, BarChart2 } from "lucide-react";
import { HomeScreen } from "./components/HomeScreen";
import { VirtualCardScreen } from "./components/VirtualCardScreen";
import { NFCFlowScreen } from "./components/NFCFlowScreen";
import { SendScreen } from "./components/SendScreen";
import { ProfileScreen } from "./components/ProfileScreen";
import { AuthScreen } from "./components/AuthScreen";
import { NFCUnlockScreen } from "./components/NFCUnlockScreen";
import { AnalyticsScreen } from "./components/AnalyticsScreen";
import type { CardData } from "./components/Card3D";

type Tab = "home" | "cards" | "analytics" | "profile";
type AppPhase = "auth" | "nfc_unlock" | "main";
type Overlay = "nfc" | "send" | null;

const INITIAL_CARDS: CardData[] = [
  {
    id: "gcash-1",
    provider: "GCash",
    cardNumber: "4532 •••• •••• 8821",
    holderName: "HARRY DIMAANO",
    expiry: "12/27",
    cvv: "123",
    type: "visa",
    colors: ["#0046d5", "#006be6", "#00aaff"],
    balance: 312500,
  },
  {
    id: "maya-1",
    provider: "Maya",
    cardNumber: "5412 •••• •••• 3344",
    holderName: "HARRY DIMAANO",
    expiry: "08/26",
    cvv: "456",
    type: "mastercard",
    colors: ["#4a0e8f", "#6d28d9", "#0e7490"],
    balance: 128750.5,
  },
];

const TABS = [
  { id: "home" as Tab, label: "Home", icon: Home },
  { id: "cards" as Tab, label: "Cards", icon: CreditCard },
  { id: "analytics" as Tab, label: "Analytics", icon: BarChart2 },
  { id: "profile" as Tab, label: "Profile", icon: User },
];

export default function App() {
  const [isRegisteredUser] = useState(() => {
    return localStorage.getItem("snfc_registered") === "true";
  });
  const [appPhase, setAppPhase] = useState<AppPhase>(
    isRegisteredUser ? "auth" : "auth"
  );
  const [activeTab, setActiveTab] = useState<Tab>("home");
  const [cards, setCards] = useState<CardData[]>(INITIAL_CARDS);
  const [activeCardId, setActiveCardId] = useState(INITIAL_CARDS[0].id);
  const [cardActive, setCardActive] = useState(false);
  const [sessionTxnDone, setSessionTxnDone] = useState(false);
  const [activeOverlay, setActiveOverlay] = useState<Overlay>(null);
  const [userName, setUserName] = useState("Harry");

  // NFC-tap-to-unlock: simulate card tap bypassing PIN for returning users
  function handleNFCTapUnlock() {
    setCardActive(true);
    setSessionTxnDone(false);
    setAppPhase("main");
  }

  const activeCard = cards.find((c) => c.id === activeCardId) ?? null;

  function handleAddCard(card: CardData) {
    setCards((prev) => [...prev, card]);
  }

  function handleDeleteCard(id: string) {
    setCards((prev) => {
      const next = prev.filter((c) => c.id !== id);
      if (activeCardId === id && next.length > 0) {
        setActiveCardId(next[0].id);
      }
      return next;
    });
  }

  function handleAuthSuccess(data?: { name?: string; isNewUser?: boolean }) {
    if (data?.name) setUserName(data.name.split(" ")[0] || "Harry");
    if (data?.isNewUser) {
      // New user — go through NFC card registration then main
      localStorage.setItem("snfc_registered", "true");
      setCardActive(true);
      setSessionTxnDone(false);
      setAppPhase("main");
    } else {
      // Returning user — go straight to main (card NOT armed)
      localStorage.setItem("snfc_registered", "true");
      setCardActive(false);
      setSessionTxnDone(false);
      setAppPhase("main");
    }
  }

  function handleCardUnlocked() {
    setCardActive(true);
    setSessionTxnDone(false);
    setAppPhase("main");
  }

  function handleArmCard() {
    // Open the NFC unlock flow as an overlay-like phase
    setAppPhase("nfc_unlock");
  }

  function handleTransactionComplete() {
    setCardActive(false);
    setSessionTxnDone(true);
    setActiveOverlay(null);
  }

  function handleSignOut() {
    setAppPhase("auth");
    setActiveTab("home");
    setCardActive(false);
    setSessionTxnDone(false);
    setActiveOverlay(null);
  }

  function handleNavigateTab(tab: string) {
    if (tab === "nfc") {
      setActiveOverlay("nfc");
    } else if (tab === "send") {
      setActiveOverlay("send");
    } else {
      setActiveTab(tab as Tab);
    }
  }

  return (
    <div
      className="relative overflow-hidden w-full h-full min-h-screen"
      style={{
        background:
          "linear-gradient(160deg, #0d0230 0%, #070020 35%, #050018 65%, #040015 100%)",
      }}
    >
        {/* Internal ambient glows */}
        <div
          className="absolute pointer-events-none"
          style={{
            top: -80,
            left: -80,
            width: 320,
            height: 320,
            borderRadius: "50%",
            background: "rgba(109,40,217,0.18)",
            filter: "blur(80px)",
          }}
        />
        <div
          className="absolute pointer-events-none"
          style={{
            top: 280,
            right: -60,
            width: 220,
            height: 220,
            borderRadius: "50%",
            background: "rgba(6,182,212,0.10)",
            filter: "blur(70px)",
          }}
        />
        <div
          className="absolute pointer-events-none"
          style={{
            bottom: 100,
            left: 20,
            width: 200,
            height: 200,
            borderRadius: "50%",
            background: "rgba(37,99,235,0.08)",
            filter: "blur(60px)",
          }}
        />



        {/* ── Phase: AUTH ── */}
        <AnimatePresence mode="wait">
          {appPhase === "auth" && (
            <motion.div
              key="auth"
              className="absolute inset-0"
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0, scale: 0.96 }}
              transition={{ duration: 0.3 }}
            >
              <AuthScreen
                onAuthSuccess={handleAuthSuccess}
                isReturningUser={isRegisteredUser}
                onNFCTapUnlock={handleNFCTapUnlock}
                onEnableTransaction={() => {
                  setAppPhase("main");
                  setCardActive(false);
                  setActiveOverlay("nfc");
                }}
              />
            </motion.div>
          )}

          {/* ── Phase: NFC UNLOCK (arm card) ── */}
          {appPhase === "nfc_unlock" && (
            <motion.div
              key="nfc_unlock"
              className="absolute inset-0"
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0, y: -20 }}
              transition={{ duration: 0.3 }}
            >
              <NFCUnlockScreen
                userName={userName}
                onUnlocked={handleCardUnlocked}
              />
            </motion.div>
          )}

          {/* ── Phase: MAIN APP ── */}
          {appPhase === "main" && (
            <motion.div
              key="main"
              className="absolute inset-0"
              initial={{ opacity: 0, y: 16 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0 }}
              transition={{ duration: 0.3 }}
            >
              {/* Scrollable content */}
              <div
                className="absolute inset-0 overflow-y-auto"
                style={{ top: 0, bottom: 90, scrollbarWidth: "none" }}
              >
                <AnimatePresence mode="wait">
                  {activeTab === "home" && (
                    <motion.div
                      key="home"
                      initial={{ opacity: 0, y: 12 }}
                      animate={{ opacity: 1, y: 0 }}
                      exit={{ opacity: 0, y: -8 }}
                      transition={{ duration: 0.22 }}
                    >
                      <HomeScreen
                        activeCard={activeCard}
                        onTabChange={handleNavigateTab}
                        cardActive={cardActive}
                        sessionTxnDone={sessionTxnDone}
                        onArmCard={handleArmCard}
                        onOpenOverlay={(type) => setActiveOverlay(type)}
                      />
                    </motion.div>
                  )}
                  {activeTab === "cards" && (
                    <motion.div
                      key="cards"
                      initial={{ opacity: 0, y: 12 }}
                      animate={{ opacity: 1, y: 0 }}
                      exit={{ opacity: 0, y: -8 }}
                      transition={{ duration: 0.22 }}
                    >
                      <VirtualCardScreen
                        cards={cards}
                        activeCardId={activeCardId}
                        onSetActive={setActiveCardId}
                        onAddCard={handleAddCard}
                        onDeleteCard={handleDeleteCard}
                      />
                    </motion.div>
                  )}
                  {activeTab === "analytics" && (
                    <motion.div
                      key="analytics"
                      initial={{ opacity: 0, y: 12 }}
                      animate={{ opacity: 1, y: 0 }}
                      exit={{ opacity: 0, y: -8 }}
                      transition={{ duration: 0.22 }}
                    >
                      <AnalyticsScreen />
                    </motion.div>
                  )}
                  {activeTab === "profile" && (
                    <motion.div
                      key="profile"
                      initial={{ opacity: 0, y: 12 }}
                      animate={{ opacity: 1, y: 0 }}
                      exit={{ opacity: 0, y: -8 }}
                      transition={{ duration: 0.22 }}
                    >
                      <ProfileScreen
                        onSignOut={handleSignOut}
                        onNavigate={handleNavigateTab}
                      />
                    </motion.div>
                  )}
                </AnimatePresence>
              </div>

              {/* Bottom navigation — floating with blur */}
              <div
                className="absolute bottom-4 left-4 right-4 z-20"
                style={{
                  height: 66,
                  background: "rgba(8,2,28,0.72)",
                  backdropFilter: "blur(32px) saturate(180%)",
                  WebkitBackdropFilter: "blur(32px) saturate(180%)",
                  borderRadius: 28,
                  border: "1px solid rgba(255,255,255,0.10)",
                  boxShadow:
                    "0 8px 32px rgba(0,0,0,0.55), 0 0 0 1px rgba(139,92,246,0.08), inset 0 1px 0 rgba(255,255,255,0.06)",
                }}
              >
                <div className="flex items-center justify-around h-full px-2">
                  {TABS.map((tab) => {
                    const Icon = tab.icon;
                    const isActive = activeTab === tab.id;
                    return (
                      <button
                        key={tab.id}
                        onClick={() => setActiveTab(tab.id)}
                        className="relative flex flex-col items-center gap-0.5 py-1.5 rounded-2xl transition-all duration-300"
                        style={{
                          minWidth: 64,
                          paddingLeft: 10,
                          paddingRight: 10,
                        }}
                      >
                        {isActive && (
                          <motion.div
                            layoutId="nav-pill"
                            className="absolute inset-0 rounded-2xl"
                            style={{
                              background:
                                "linear-gradient(135deg, rgba(109,40,217,0.38), rgba(37,99,235,0.25))",
                              border: "1px solid rgba(139,92,246,0.28)",
                              boxShadow: "0 0 12px rgba(109,40,217,0.2)",
                            }}
                            transition={{
                              type: "spring",
                              stiffness: 380,
                              damping: 32,
                            }}
                          />
                        )}
                        {tab.id === "analytics" && isActive && (
                          <div
                            className="absolute inset-0 rounded-2xl pointer-events-none"
                            style={{
                              background:
                                "radial-gradient(circle at 50% 40%, rgba(16,185,129,0.15) 0%, transparent 70%)",
                            }}
                          />
                        )}
                        <Icon
                          size={20}
                          className="relative z-10 transition-all duration-300"
                          style={{
                            color: isActive
                              ? "#a78bfa"
                              : "rgba(255,255,255,0.3)",
                            filter: isActive
                              ? "drop-shadow(0 0 6px rgba(167,139,250,0.6))"
                              : "none",
                          }}
                        />
                        <span
                          className="relative z-10 transition-all duration-300"
                          style={{
                            fontSize: 10,
                            fontWeight: isActive ? 700 : 500,
                            color: isActive
                              ? "#a78bfa"
                              : "rgba(255,255,255,0.28)",
                            letterSpacing: "0.02em",
                          }}
                        >
                          {tab.label}
                        </span>
                        {isActive && (
                          <motion.div
                            initial={{ scale: 0 }}
                            animate={{ scale: 1 }}
                            className="absolute -top-0.5 w-1 h-1 rounded-full"
                            style={{
                              background: "#a78bfa",
                              boxShadow: "0 0 6px #a78bfa",
                              left: "50%",
                              transform: "translateX(-50%)",
                            }}
                          />
                        )}
                      </button>
                    );
                  })}
                </div>
              </div>



              {/* ── Overlays: NFC Pay & Send ── */}
              <AnimatePresence>
                {activeOverlay === "nfc" && (
                  <motion.div
                    key="overlay-nfc"
                    className="absolute inset-0 z-40"
                    initial={{ opacity: 0, y: 30 }}
                    animate={{ opacity: 1, y: 0 }}
                    exit={{ opacity: 0, y: 30 }}
                    transition={{ duration: 0.3, ease: "easeOut" }}
                    style={{
                      background:
                        "linear-gradient(160deg, #0d0230 0%, #070020 35%, #050018 65%, #040015 100%)",
                    }}
                  >
                    <div
                      className="absolute inset-0 overflow-y-auto"
                      style={{ scrollbarWidth: "none" }}
                    >
                      <NFCFlowScreen
                        activeCard={activeCard}
                        onClose={() => setActiveOverlay(null)}
                        onTransactionComplete={handleTransactionComplete}
                      />
                    </div>
                  </motion.div>
                )}
                {activeOverlay === "send" && (
                  <motion.div
                    key="overlay-send"
                    className="absolute inset-0 z-40"
                    initial={{ opacity: 0, y: 30 }}
                    animate={{ opacity: 1, y: 0 }}
                    exit={{ opacity: 0, y: 30 }}
                    transition={{ duration: 0.3, ease: "easeOut" }}
                    style={{
                      background:
                        "linear-gradient(160deg, #0d0230 0%, #070020 35%, #050018 65%, #040015 100%)",
                    }}
                  >
                    <div
                      className="absolute inset-0 overflow-y-auto"
                      style={{ scrollbarWidth: "none" }}
                    >
                      <SendScreen
                        cardActive={cardActive}
                        onTransactionComplete={handleTransactionComplete}
                        onClose={() => setActiveOverlay(null)}
                      />
                    </div>
                  </motion.div>
                )}
              </AnimatePresence>
            </motion.div>
          )}
        </AnimatePresence>
    </div>
  );
}
