/**
 * nfcService.ts
 * Wraps the Web NFC API (NDEFReader) for NDEF tag reading and writing.
 * Works on Android Chrome 89+ and Capacitor WebView with NFC permission.
 */

// ── Types ─────────────────────────────────────────────────────────────────────

export interface NFCWriteResult {
  success: boolean;
  error?: string;
}

export interface NFCReadResult {
  success: boolean;
  text?: string;
  serialNumber?: string;
  error?: string;
}

export interface TokenPayload {
  token: string;
  issuedAt: number;       // Unix ms
  expiresAt: number;      // Unix ms
  cardId: string;
  amount?: number;        // Optional: amount this token is valid for
  sessionId: string;
}

const TOKEN_LIFETIME_MS = 5 * 60 * 1000; // 5 minutes

// ── Helpers ───────────────────────────────────────────────────────────────────

/** Generates a cryptographically-inspired one-time token string */
export function generateRawToken(): string {
  const chars = "ABCDEF0123456789";
  const segments = Array.from({ length: 6 }, () =>
    Array.from({ length: 4 }, () => chars[Math.floor(Math.random() * 16)]).join("")
  );
  return segments.join("-");
}

/** Generates a sessionId */
function generateSessionId(): string {
  return `sess_${Date.now().toString(36)}_${Math.random().toString(36).slice(2, 8)}`;
}

/** Builds a timestamp-bound token payload */
export function buildTokenPayload(cardId: string, amount?: number): TokenPayload {
  const now = Date.now();
  return {
    token: generateRawToken(),
    issuedAt: now,
    expiresAt: now + TOKEN_LIFETIME_MS,
    cardId,
    amount,
    sessionId: generateSessionId(),
  };
}

/** Serializes token payload to a string for NFC writing */
export function serializePayload(payload: TokenPayload): string {
  return JSON.stringify(payload);
}

/** Deserializes a token payload string */
export function deserializePayload(raw: string): TokenPayload | null {
  try {
    const p = JSON.parse(raw) as TokenPayload;
    if (!p.token || !p.issuedAt || !p.expiresAt || !p.cardId) return null;
    return p;
  } catch {
    return null;
  }
}

/** Returns true if the token payload has not expired */
export function isTokenValid(payload: TokenPayload): boolean {
  return Date.now() < payload.expiresAt;
}

// ── NFC Support ───────────────────────────────────────────────────────────────

/** Returns true if the Web NFC API is available on this device/browser */
export function isNFCSupported(): boolean {
  return typeof window !== "undefined" && "NDEFReader" in window;
}

// ── Haptic Feedback ───────────────────────────────────────────────────────────

/** Short success vibration */
export function hapticSuccess(): void {
  try {
    if (navigator.vibrate) navigator.vibrate([50, 30, 80]);
  } catch {
    // Silently ignore if not supported
  }
}

/** Double-tap error vibration */
export function hapticError(): void {
  try {
    if (navigator.vibrate) navigator.vibrate([100, 50, 100, 50, 200]);
  } catch {
    // Silently ignore
  }
}

/** Subtle haptic on scan start */
export function hapticStart(): void {
  try {
    if (navigator.vibrate) navigator.vibrate(30);
  } catch {
    // Silently ignore
  }
}

// ── Audio Feedback ────────────────────────────────────────────────────────────

let _audioCtx: AudioContext | null = null;

function getAudioContext(): AudioContext | null {
  try {
    if (!_audioCtx) {
      _audioCtx = new (window.AudioContext || (window as any).webkitAudioContext)();
    }
    return _audioCtx;
  } catch {
    return null;
  }
}

/** Plays a short success beep (high pitch) */
export function audioSuccess(): void {
  const ctx = getAudioContext();
  if (!ctx) return;
  try {
    const osc = ctx.createOscillator();
    const gain = ctx.createGain();
    osc.connect(gain);
    gain.connect(ctx.destination);
    osc.type = "sine";
    osc.frequency.setValueAtTime(880, ctx.currentTime);
    osc.frequency.exponentialRampToValueAtTime(1320, ctx.currentTime + 0.1);
    gain.gain.setValueAtTime(0.18, ctx.currentTime);
    gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + 0.25);
    osc.start(ctx.currentTime);
    osc.stop(ctx.currentTime + 0.25);
  } catch {
    // Silently ignore
  }
}

/** Plays a low error beep */
export function audioError(): void {
  const ctx = getAudioContext();
  if (!ctx) return;
  try {
    const osc = ctx.createOscillator();
    const gain = ctx.createGain();
    osc.connect(gain);
    gain.connect(ctx.destination);
    osc.type = "sawtooth";
    osc.frequency.setValueAtTime(220, ctx.currentTime);
    osc.frequency.exponentialRampToValueAtTime(110, ctx.currentTime + 0.3);
    gain.gain.setValueAtTime(0.15, ctx.currentTime);
    gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + 0.3);
    osc.start(ctx.currentTime);
    osc.stop(ctx.currentTime + 0.3);
  } catch {
    // Silently ignore
  }
}

// ── NFC Write ─────────────────────────────────────────────────────────────────

/**
 * Writes a token payload to an NFC tag as an NDEF text record.
 * Returns a Promise that resolves when the write is complete or rejects on error.
 * The abortController can be used to cancel the scan.
 */
export async function writeTokenToNFC(
  payload: TokenPayload,
  abortSignal?: AbortSignal
): Promise<NFCWriteResult> {
  if (!isNFCSupported()) {
    return { success: false, error: "NFC not supported on this device or browser." };
  }

  try {
    hapticStart();
    const ndef = new (window as any).NDEFReader();
    const serialized = serializePayload(payload);

    await ndef.write(
      {
        records: [
          {
            recordType: "text",
            data: serialized,
            lang: "en",
          },
        ],
      },
      { signal: abortSignal }
    );

    hapticSuccess();
    audioSuccess();
    return { success: true };
  } catch (err: any) {
    hapticError();
    audioError();
    if (err?.name === "AbortError") {
      return { success: false, error: "NFC write cancelled." };
    }
    if (err?.name === "NotAllowedError") {
      return { success: false, error: "NFC permission denied. Please allow NFC access." };
    }
    if (err?.name === "NotSupportedError") {
      return { success: false, error: "NFC is not enabled. Please turn on NFC in settings." };
    }
    return { success: false, error: err?.message ?? "Unknown NFC error." };
  }
}

// ── NFC Read ──────────────────────────────────────────────────────────────────

/**
 * Starts passive NFC reading. Resolves on the first successful tag read.
 * Pass an AbortSignal to cancel scanning.
 */
export async function readTagFromNFC(
  abortSignal?: AbortSignal
): Promise<NFCReadResult> {
  if (!isNFCSupported()) {
    return { success: false, error: "NFC not supported on this device or browser." };
  }

  return new Promise<NFCReadResult>((resolve) => {
    try {
      hapticStart();
      const ndef = new (window as any).NDEFReader();

      ndef.scan({ signal: abortSignal }).catch((err: any) => {
        if (err?.name === "AbortError") {
          resolve({ success: false, error: "NFC scan cancelled." });
        } else if (err?.name === "NotAllowedError") {
          resolve({ success: false, error: "NFC permission denied." });
        } else {
          resolve({ success: false, error: err?.message ?? "NFC scan failed." });
        }
      });

      ndef.onreading = (event: any) => {
        const serialNumber: string = event.serialNumber ?? "";
        let text: string | undefined;

        for (const record of event.message.records) {
          if (record.recordType === "text") {
            const decoder = new TextDecoder(record.encoding ?? "utf-8");
            text = decoder.decode(record.data);
            break;
          }
        }

        hapticSuccess();
        audioSuccess();
        resolve({ success: true, text, serialNumber });
      };

      ndef.onreadingerror = () => {
        hapticError();
        audioError();
        resolve({ success: false, error: "Could not read NFC tag. Try again." });
      };

      // Handle abort externally
      abortSignal?.addEventListener("abort", () => {
        resolve({ success: false, error: "NFC scan cancelled." });
      });
    } catch (err: any) {
      hapticError();
      if (err?.name === "NotAllowedError") {
        resolve({ success: false, error: "NFC permission denied." });
      } else {
        resolve({ success: false, error: err?.message ?? "NFC not available." });
      }
    }
  });
}
