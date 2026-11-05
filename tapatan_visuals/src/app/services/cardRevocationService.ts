/**
 * cardRevocationService.ts
 * Manages a local revocation list for NFC card UIDs.
 * In production this would sync to a backend. For now, localStorage is used.
 */

const REVOCATION_KEY = "snfc_revoked_cards";
const USE_COUNT_KEY = "snfc_card_use_count";
const LAST_TAP_KEY = "snfc_card_last_tap";

// ── Revocation ────────────────────────────────────────────────────────────────

export function getRevokedCards(): string[] {
  try {
    const raw = localStorage.getItem(REVOCATION_KEY);
    return raw ? (JSON.parse(raw) as string[]) : [];
  } catch {
    return [];
  }
}

export function isRevoked(cardUid: string): boolean {
  return getRevokedCards().includes(cardUid);
}

export function revokeCard(cardUid: string): void {
  const list = getRevokedCards();
  if (!list.includes(cardUid)) {
    list.push(cardUid);
    localStorage.setItem(REVOCATION_KEY, JSON.stringify(list));
  }
}

export function unRevokeCard(cardUid: string): void {
  const list = getRevokedCards().filter((uid) => uid !== cardUid);
  localStorage.setItem(REVOCATION_KEY, JSON.stringify(list));
}

// ── Card Health ───────────────────────────────────────────────────────────────

export function incrementUseCount(cardId: string): void {
  const counts = getUseCounts();
  counts[cardId] = (counts[cardId] ?? 0) + 1;
  localStorage.setItem(USE_COUNT_KEY, JSON.stringify(counts));
}

export function getUseCount(cardId: string): number {
  return getUseCounts()[cardId] ?? 0;
}

function getUseCounts(): Record<string, number> {
  try {
    const raw = localStorage.getItem(USE_COUNT_KEY);
    return raw ? (JSON.parse(raw) as Record<string, number>) : {};
  } catch {
    return {};
  }
}

export function recordLastTap(cardId: string): void {
  const taps = getLastTaps();
  taps[cardId] = Date.now();
  localStorage.setItem(LAST_TAP_KEY, JSON.stringify(taps));
}

export function getLastTap(cardId: string): number | null {
  return getLastTaps()[cardId] ?? null;
}

function getLastTaps(): Record<string, number> {
  try {
    const raw = localStorage.getItem(LAST_TAP_KEY);
    return raw ? (JSON.parse(raw) as Record<string, number>) : {};
  } catch {
    return {};
  }
}

// ── Card PIN Fallback ─────────────────────────────────────────────────────────
// Stores a hashed PIN (simple for demo — in production use PBKDF2 or bcrypt)

const CARD_PIN_KEY = "snfc_card_pin";

function simpleHash(pin: string): string {
  // Simple XOR-based pseudo-hash for demo purposes
  let hash = 0;
  for (let i = 0; i < pin.length; i++) {
    hash = ((hash << 5) - hash + pin.charCodeAt(i)) | 0;
  }
  return hash.toString(16);
}

export function setCardPin(pin: string): void {
  localStorage.setItem(CARD_PIN_KEY, simpleHash(pin));
}

export function verifyCardPin(pin: string): boolean {
  const stored = localStorage.getItem(CARD_PIN_KEY);
  if (!stored) return false; // No PIN set
  return stored === simpleHash(pin);
}

export function hasCardPin(): boolean {
  return !!localStorage.getItem(CARD_PIN_KEY);
}
