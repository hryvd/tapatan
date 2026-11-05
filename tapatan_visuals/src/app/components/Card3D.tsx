import { useRef, useCallback, useEffect } from "react";
import {
  motion,
  useMotionValue,
  useSpring,
  useTransform,
  animate,
} from "motion/react";

export interface CardData {
  id: string;
  provider: "GCash" | "Maya" | "Custom";
  cardNumber: string;
  holderName: string;
  expiry: string;
  cvv: string;
  type: "visa" | "mastercard";
  colors: [string, string, string];
  balance: number;
}

interface Card3DProps {
  card: CardData;
  isActive: boolean;
  onSelect: () => void;
  compact?: boolean;
}

export function Card3D({ card, isActive, onSelect, compact = false }: Card3DProps) {
  const cardRef = useRef<HTMLDivElement>(null);
  const isHovered = useRef(false);

  const mouseX = useMotionValue(0);
  const mouseY = useMotionValue(0);

  const rotateX = useSpring(useTransform(mouseY, [-0.5, 0.5], [10, -10]), {
    stiffness: 180,
    damping: 26,
  });
  const rotateY = useSpring(useTransform(mouseX, [-0.5, 0.5], [-15, 15]), {
    stiffness: 180,
    damping: 26,
  });

  const shineX = useTransform(mouseX, [-0.5, 0.5], ["15%", "85%"]);
  const shineY = useTransform(mouseY, [-0.5, 0.5], ["15%", "85%"]);

  // Idle float animation
  useEffect(() => {
    let t = 0;
    let rafId: number;
    function tick() {
      if (!isHovered.current) {
        t += 0.006;
        mouseX.set(Math.sin(t) * 0.15);
        mouseY.set(Math.sin(t * 0.7) * 0.12);
      }
      rafId = requestAnimationFrame(tick);
    }
    rafId = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(rafId);
  }, [mouseX, mouseY]);

  const handleMouseMove = useCallback(
    (e: React.MouseEvent<HTMLDivElement>) => {
      const rect = cardRef.current?.getBoundingClientRect();
      if (!rect) return;
      mouseX.set((e.clientX - rect.left) / rect.width - 0.5);
      mouseY.set((e.clientY - rect.top) / rect.height - 0.5);
    },
    [mouseX, mouseY]
  );

  const handleMouseEnter = useCallback(() => {
    isHovered.current = true;
  }, []);

  const handleMouseLeave = useCallback(() => {
    isHovered.current = false;
    animate(mouseX, 0, { duration: 0.7, ease: "easeOut" });
    animate(mouseY, 0, { duration: 0.7, ease: "easeOut" });
  }, [mouseX, mouseY]);

  const handleTouchMove = useCallback(
    (e: React.TouchEvent<HTMLDivElement>) => {
      const rect = cardRef.current?.getBoundingClientRect();
      if (!rect || !e.touches[0]) return;
      isHovered.current = true;
      mouseX.set((e.touches[0].clientX - rect.left) / rect.width - 0.5);
      mouseY.set((e.touches[0].clientY - rect.top) / rect.height - 0.5);
    },
    [mouseX, mouseY]
  );

  const handleTouchEnd = useCallback(() => {
    isHovered.current = false;
    animate(mouseX, 0, { duration: 0.7, ease: "easeOut" });
    animate(mouseY, 0, { duration: 0.7, ease: "easeOut" });
  }, [mouseX, mouseY]);

  const w = compact ? 260 : 320;
  const h = compact ? 158 : 190;
  const pad = compact ? "14px 18px" : "20px 24px";

  return (
    <div
      ref={cardRef}
      style={{ perspective: "1100px", width: w, height: h }}
      onMouseMove={handleMouseMove}
      onMouseEnter={handleMouseEnter}
      onMouseLeave={handleMouseLeave}
      onTouchMove={handleTouchMove}
      onTouchEnd={handleTouchEnd}
      onClick={onSelect}
      className="cursor-pointer select-none"
    >
      <motion.div
        style={{ rotateX, rotateY, transformStyle: "preserve-3d", width: w, height: h }}
        animate={{ scale: isActive ? 1 : 0.9, y: isActive ? 0 : 8 }}
        whileHover={{ scale: isActive ? 1.03 : 0.93 }}
        whileTap={{ scale: isActive ? 0.97 : 0.88 }}
        transition={{ type: "spring", stiffness: 200, damping: 26 }}
        className="relative rounded-[28px]"
      >
        {/* Base gradient */}
        <div
          className="absolute inset-0 rounded-[28px]"
          style={{
            background: `linear-gradient(135deg, ${card.colors[0]} 0%, ${card.colors[1]} 55%, ${card.colors[2]} 100%)`,
            boxShadow: isActive
              ? `0 28px 56px ${card.colors[0]}66, 0 0 80px ${card.colors[1]}33`
              : "0 10px 32px rgba(0,0,0,0.55)",
          }}
        />

        {/* Shimmer sweep */}
        <div className="absolute inset-0 rounded-[28px] overflow-hidden pointer-events-none">
          <motion.div
            className="absolute"
            style={{
              width: "55%",
              height: "200%",
              top: "-50%",
              background: "linear-gradient(105deg, transparent 20%, rgba(255,255,255,0.18) 50%, transparent 80%)",
              transform: "skewX(-15deg)",
            }}
            animate={{ left: ["-70%", "160%"] }}
            transition={{ repeat: Infinity, repeatDelay: 4, duration: 1.5, ease: "easeInOut" }}
          />
        </div>

        {/* Subtle texture */}
        <div
          className="absolute inset-0 rounded-[28px]"
          style={{
            background: "repeating-linear-gradient(45deg, rgba(255,255,255,0.025) 0px, rgba(255,255,255,0.025) 1px, transparent 1px, transparent 20px)",
          }}
        />

        {/* Glass sheen */}
        <div
          className="absolute inset-0 rounded-[28px]"
          style={{
            background: "linear-gradient(135deg, rgba(255,255,255,0.18) 0%, rgba(255,255,255,0.03) 40%, transparent 60%, rgba(255,255,255,0.06) 100%)",
          }}
        />

        {/* Dynamic shine */}
        <motion.div
          className="absolute inset-0 rounded-[28px] pointer-events-none"
          style={{
            background: `radial-gradient(circle at ${shineX} ${shineY}, rgba(255,255,255,0.25) 0%, rgba(255,255,255,0.05) 30%, transparent 65%)`,
          }}
        />

        {/* Border */}
        <div
          className="absolute inset-0 rounded-[28px] pointer-events-none"
          style={{ border: "1px solid rgba(255,255,255,0.26)" }}
        />

        {/* Card content */}
        <div
          className="absolute inset-0 flex flex-col justify-between"
          style={{ padding: pad, transform: "translateZ(18px)" }}
        >
          {/* Top row */}
          <div className="flex items-start justify-between">
            <div>
              <p className="text-white/55" style={{ fontSize: compact ? 10 : 11 }}>
                {card.provider} · Bantay
              </p>
              <p className="text-white" style={{ fontSize: compact ? 13 : 15, fontWeight: 700, marginTop: 2 }}>
                {card.holderName}
              </p>
            </div>
            <div className="flex flex-col items-end gap-1.5">
              {/* NFC icon */}
              <svg viewBox="0 0 24 24" width={compact ? 18 : 22} height={compact ? 18 : 22} fill="none" stroke="rgba(255,255,255,0.65)" strokeWidth="1.8">
                <path d="M12 12a2 2 0 100-4 2 2 0 000 4z" />
                <path d="M9.5 9.5a4 4 0 015 5" strokeLinecap="round" />
                <path d="M7 7a7 7 0 0110 10" strokeLinecap="round" />
              </svg>
              {isActive && (
                <div className="flex items-center gap-1">
                  <span className="w-1.5 h-1.5 rounded-full bg-emerald-400 animate-pulse" style={{ boxShadow: "0 0 5px #34d399" }} />
                  <span className="text-emerald-400" style={{ fontSize: 9, fontWeight: 600 }}>ACTIVE</span>
                </div>
              )}
            </div>
          </div>

          {/* Chip */}
          <div>
            <div
              style={{
                width: compact ? 32 : 40,
                height: compact ? 24 : 30,
                borderRadius: 6,
                background: "linear-gradient(135deg, rgba(255,215,0,0.9), rgba(200,160,0,0.7) 50%, rgba(255,215,0,0.85))",
                border: "1px solid rgba(255,215,0,0.45)",
                boxShadow: "inset 0 1px 0 rgba(255,255,255,0.35), 0 2px 5px rgba(0,0,0,0.3)",
                overflow: "hidden",
              }}
            >
              <div style={{ width: "100%", height: "100%", background: "repeating-linear-gradient(90deg, transparent, transparent 4px, rgba(0,0,0,0.1) 4px, rgba(0,0,0,0.1) 5px)" }} />
            </div>
          </div>

          {/* Card number */}
          <p
            className="text-white/88 tracking-widest"
            style={{ fontFamily: "'Courier New', monospace", fontSize: compact ? 11 : 14, letterSpacing: "0.16em" }}
          >
            {card.cardNumber}
          </p>

          {/* Bottom row */}
          <div className="flex items-end justify-between">
            <div>
              <p className="text-white/40 uppercase" style={{ fontSize: 8, letterSpacing: "0.12em" }}>Expires</p>
              <p className="text-white" style={{ fontSize: compact ? 11 : 13, fontWeight: 600 }}>{card.expiry}</p>
            </div>

            {card.type === "visa" ? (
              <p className="text-white italic" style={{ fontSize: compact ? 16 : 20, fontWeight: 900, letterSpacing: "-0.03em" }}>
                VISA
              </p>
            ) : (
              <div className="flex items-center">
                <div className="w-5 h-5 rounded-full" style={{ background: "#eb001b", opacity: 0.88 }} />
                <div className="w-5 h-5 rounded-full -ml-2.5" style={{ background: "#f79e1b", opacity: 0.88 }} />
              </div>
            )}
          </div>
        </div>
      </motion.div>
    </div>
  );
}
