const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');

const CONFIG_PATH = path.join(__dirname, 'config', 'account_rules.json');
const DATA_DIR = path.join(__dirname, 'data');
const DB_PATH = path.join(DATA_DIR, 'accounts_db.json');

const DEFAULT_CONFIG = {
  port: 4000,
  initialWalletBalance: 5000.0,
  currency: 'PHP',
  pinMinLength: 4,
  pinMaxLength: 6,
  maxPinRetries: 5,
  requirePinOnEmailLogin: true,
  autoCreateAccountOnUnknownEmailLogin: false,
  strictCardToAccountBinding: true,
  allowCardRebindOnSignup: true,
  syncCardHolderNameWithAccount: true,
  blockedPlaceholderNames: ['richard', 'cardholder'],
  blockedPlaceholderEmails: ['richard@tapat.ph'],
};

function ensureDirectories() {
  if (!fs.existsSync(path.dirname(CONFIG_PATH))) {
    fs.mkdirSync(path.dirname(CONFIG_PATH), { recursive: true });
  }
  if (!fs.existsSync(DATA_DIR)) {
    fs.mkdirSync(DATA_DIR, { recursive: true });
  }
  if (!fs.existsSync(CONFIG_PATH)) {
    fs.writeFileSync(CONFIG_PATH, JSON.stringify(DEFAULT_CONFIG, null, 2));
  }
  if (!fs.existsSync(DB_PATH)) {
    fs.writeFileSync(
      DB_PATH,
      JSON.stringify({ version: 2, accounts: {} }, null, 2),
    );
  }
}

function loadConfig() {
  ensureDirectories();
  try {
    const raw = JSON.parse(fs.readFileSync(CONFIG_PATH, 'utf8'));
    return { ...DEFAULT_CONFIG, ...raw };
  } catch (_) {
    return { ...DEFAULT_CONFIG };
  }
}

function saveConfig(nextConfig) {
  ensureDirectories();
  const merged = { ...loadConfig(), ...nextConfig };
  fs.writeFileSync(CONFIG_PATH, JSON.stringify(merged, null, 2));
  return merged;
}

function loadDb() {
  ensureDirectories();
  try {
    const raw = JSON.parse(fs.readFileSync(DB_PATH, 'utf8'));
    if (!raw || typeof raw.accounts !== 'object') {
      return { version: 2, accounts: {} };
    }
    return raw;
  } catch (_) {
    return { version: 2, accounts: {} };
  }
}

function saveDb(db) {
  ensureDirectories();
  const tmpPath = `${DB_PATH}.tmp`;
  fs.writeFileSync(tmpPath, JSON.stringify(db, null, 2));
  fs.renameSync(tmpPath, DB_PATH);
}

function normalizeEmail(email) {
  return String(email || '').trim().toLowerCase();
}

function hashPin(pin, salt) {
  const effectiveSalt = salt || crypto.randomBytes(16).toString('hex');
  const hash = crypto
    .createHash('sha256')
    .update(`${effectiveSalt}:${String(pin).trim()}`)
    .digest('hex');
  return { salt: effectiveSalt, pinHash: hash };
}

function verifyPin(pin, account) {
  if (!account || !account.pinHash || !account.pinSalt) return false;
  const computed = hashPin(pin, account.pinSalt).pinHash;
  return crypto.timingSafeEqual(
    Buffer.from(computed, 'hex'),
    Buffer.from(account.pinHash, 'hex'),
  );
}

function buildDefaultCard(name, cardId, balance) {
  const cleanId = String(cardId || '');
  const suffix = cleanId.length >= 4 ? cleanId.slice(-4) : '8821';
  return {
    id: 'card-tapat-primary',
    provider: 'Tapat JCOP4',
    cardNumber: `4532 •••• •••• ${suffix}`,
    holderName: String(name || 'MEMBER').trim().toUpperCase(),
    expiry: '12/28',
    cvv: '882',
    type: 'visa',
    colors: [0xff0369a1, 0xff0891b2],
    balance: Number(balance || 0),
  };
}

function syncCardsForAccount(account, config) {
  const holderUpper = String(account.name || '').trim().toUpperCase();
  const blockedNames = (config.blockedPlaceholderNames || []).map((n) =>
    String(n).toLowerCase(),
  );
  let cards = Array.isArray(account.virtualCards) ? account.virtualCards : [];
  if (cards.length === 0 && holderUpper.length > 0) {
    cards = [buildDefaultCard(account.name, account.cardId, account.balance)];
  }
  const activeId = account.activeCardId || (cards[0] && cards[0].id) || '';
  return cards.map((card, idx) => {
    const rawHolder = String(card.holderName || '').trim();
    const isBlocked =
      rawHolder.length === 0 ||
      blockedNames.includes(rawHolder.toLowerCase());
    const shouldSyncHolder =
      config.syncCardHolderNameWithAccount ||
      isBlocked ||
      card.id === 'card-tapat-primary';
    const isPrimaryOrActive =
      card.id === activeId || (cards.length === 1 && idx === 0);
    return {
      ...card,
      holderName:
        shouldSyncHolder && holderUpper.length > 0 ? holderUpper : rawHolder,
      balance: isPrimaryOrActive
          ? Number(account.balance || 0)
          : Number(card.balance ?? account.balance ?? 0),
    };
  });
}

function sanitizeAccount(account, config) {
  const syncedCards = syncCardsForAccount(account, config);
  const { pinHash, pinSalt, ...publicFields } = account;
  return {
    ...publicFields,
    virtualCards: syncedCards,
    activeCardId:
      account.activeCardId ||
      (syncedCards.length > 0 ? syncedCards[0].id : ''),
    transactions: Array.isArray(account.transactions)
      ? account.transactions
      : [],
  };
}

function sendJson(res, statusCode, payload) {
  res.writeHead(statusCode, {
    'Content-Type': 'application/json; charset=utf-8',
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization',
  });
  res.end(JSON.stringify(payload));
}

function readJsonBody(req) {
  return new Promise((resolve, reject) => {
    let data = '';
    req.on('data', (chunk) => {
      data += chunk;
      if (data.length > 2 * 1024 * 1024) {
        reject(new Error('Payload too large'));
      }
    });
    req.on('end', () => {
      if (!data.trim()) return resolve({});
      try {
        resolve(JSON.parse(data));
      } catch (err) {
        reject(new Error('Invalid JSON payload'));
      }
    });
    req.on('error', reject);
  });
}

function createServer() {
  ensureDirectories();

  return http.createServer(async (req, res) => {
    if (req.method === 'OPTIONS') {
      return sendJson(res, 200, { ok: true });
    }

    const parsedUrl = new URL(req.url, 'http://localhost');
    const pathname = parsedUrl.pathname;
    const config = loadConfig();

    try {
      // 1. Health check
      if (req.method === 'GET' && pathname === '/api/health') {
        const db = loadDb();
        return sendJson(res, 200, {
          success: true,
          service: 'tapatan-account-backend',
          accountCount: Object.keys(db.accounts).length,
          config,
        });
      }

      // 2. Get or Update Account Management Rules
      if (pathname === '/api/config') {
        if (req.method === 'GET') {
          return sendJson(res, 200, { success: true, config });
        }
        if (req.method === 'PUT') {
          const body = await readJsonBody(req);
          const updated = saveConfig(body);
          return sendJson(res, 200, { success: true, config: updated });
        }
      }

      // 3. List Registered Accounts (Summary only, no secrets)
      if (req.method === 'GET' && pathname === '/api/accounts') {
        const db = loadDb();
        const summaries = Object.values(db.accounts).map((acc) => ({
          id: acc.id,
          name: acc.name,
          email: acc.email,
          phone: acc.phone || '',
          cardId: acc.cardId || '',
          jcopCardUid: acc.jcopCardUid || '',
          balance: acc.balance,
          transactionCount: Array.isArray(acc.transactions)
            ? acc.transactions.length
            : 0,
          createdAt: acc.createdAt,
          lastLoginAt: acc.lastLoginAt,
        }));
        return sendJson(res, 200, { success: true, accounts: summaries });
      }

      // 4. Register New Account
      if (req.method === 'POST' && pathname === '/api/accounts/register') {
        const body = await readJsonBody(req);
        const name = String(body.name || '').trim();
        const email = normalizeEmail(body.email);
        const phone = String(body.phone || '').trim();
        const pin = String(body.pin || '').trim();
        const cardId = String(body.cardId || '').trim();
        const jcopCardUid = String(body.jcopCardUid || '').trim().toUpperCase();

        if (name.length < 2) {
          return sendJson(res, 400, {
            success: false,
            error: 'Full name must be at least 2 characters.',
          });
        }
        if (
          (config.blockedPlaceholderNames || [])
            .map((s) => s.toLowerCase())
            .includes(name.toLowerCase())
        ) {
          return sendJson(res, 400, {
            success: false,
            error: 'Please enter the real account holder name.',
          });
        }
        if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
          return sendJson(res, 400, {
            success: false,
            error: 'Please provide a valid email address.',
          });
        }
        if (
          pin.length < config.pinMinLength ||
          pin.length > config.pinMaxLength
        ) {
          return sendJson(res, 400, {
            success: false,
            error: `PIN must be ${config.pinMinLength} to ${config.pinMaxLength} digits.`,
          });
        }

        const db = loadDb();
        if (db.accounts[email]) {
          return sendJson(res, 409, {
            success: false,
            error: `An account with ${email} already exists. Please Sign In instead.`,
          });
        }

        // Handle physical card exclusivity / rebinding policy
        if (cardId || jcopCardUid) {
          for (const existing of Object.values(db.accounts)) {
            const sameCardId =
              cardId &&
              cardId !== 'TAPAT_JCOP4_8821' &&
              existing.cardId === cardId;
            const sameUid =
              jcopCardUid &&
              jcopCardUid !== '04:7A:93:E2:10:88:01' &&
              String(existing.jcopCardUid || '').toUpperCase() === jcopCardUid;

            if (sameCardId || sameUid) {
              if (!config.allowCardRebindOnSignup) {
                return sendJson(res, 409, {
                  success: false,
                  error: `This Tapat card is already bound to ${existing.email}.`,
                });
              }
              if (sameCardId) existing.cardId = '';
              if (sameUid) existing.jcopCardUid = '';
            }
          }
        }

        const startBalance =
          typeof body.initialBalance === 'number'
            ? body.initialBalance
            : Number(config.initialWalletBalance || 0);
        const { salt, pinHash } = hashPin(pin);
        const nowIso = new Date().toISOString();
        const primaryCard = buildDefaultCard(name, cardId, startBalance);
        const initialTransactions =
          startBalance > 0
            ? [
                {
                  id: `tx-${Date.now()}`,
                  name: 'Initial Wallet Balance',
                  amount: startBalance,
                  time: 'Account Created',
                  type: 'receive',
                },
              ]
            : [];

        const accountRecord = {
          id: `acc_${crypto.randomBytes(6).toString('hex')}`,
          name,
          email,
          phone,
          pinSalt: salt,
          pinHash,
          balance: startBalance,
          cardId,
          jcopCardUid,
          activeCardId: primaryCard.id,
          virtualCards: [primaryCard],
          transactions: initialTransactions,
          pinRetriesLeft: config.maxPinRetries,
          cardLifecycleState: cardId ? 'ENROLLED' : 'unknown',
          createdAt: nowIso,
          lastLoginAt: nowIso,
          updatedAt: nowIso,
        };

        db.accounts[email] = accountRecord;
        saveDb(db);

        return sendJson(res, 201, {
          success: true,
          account: sanitizeAccount(accountRecord, config),
        });
      }

      // 5. Login with Email + PIN
      if (req.method === 'POST' && pathname === '/api/accounts/login') {
        const body = await readJsonBody(req);
        const email = normalizeEmail(body.email);
        const pin = String(body.pin || '').trim();

        if (!email) {
          return sendJson(res, 400, {
            success: false,
            error: 'Please enter your registered email address.',
          });
        }

        const db = loadDb();
        const account = db.accounts[email];
        if (!account) {
          return sendJson(res, 404, {
            success: false,
            error: `No account found for "${email}". Please check your email or Create Account.`,
          });
        }

        if (config.requirePinOnEmailLogin) {
          if (!pin) {
            return sendJson(res, 400, {
              success: false,
              error: 'Please enter your account PIN.',
            });
          }
          if (account.pinRetriesLeft === 0) {
            return sendJson(res, 423, {
              success: false,
              error: 'Account PIN is locked due to too many failed attempts.',
            });
          }
          if (!verifyPin(pin, account)) {
            const left = Math.max(
              0,
              Number(account.pinRetriesLeft ?? config.maxPinRetries) - 1,
            );
            account.pinRetriesLeft = left;
            account.updatedAt = new Date().toISOString();
            saveDb(db);
            return sendJson(res, 401, {
              success: false,
              error: `Incorrect PIN for ${account.email} (${left} attempt(s) remaining).`,
              pinRetriesLeft: left,
            });
          }
        }

        account.pinRetriesLeft = config.maxPinRetries;
        account.lastLoginAt = new Date().toISOString();
        account.updatedAt = account.lastLoginAt;
        account.virtualCards = syncCardsForAccount(account, config);
        saveDb(db);

        return sendJson(res, 200, {
          success: true,
          account: sanitizeAccount(account, config),
        });
      }

      // 6. Login via Bound Tapat JCOP4 Card (Authoritative DB lookup, never falls back to Richard)
      if (req.method === 'POST' && pathname === '/api/accounts/login-card') {
        const body = await readJsonBody(req);
        const cardId = String(body.cardId || '').trim();
        const jcopCardUid = String(body.uid || body.jcopCardUid || '')
          .trim()
          .toUpperCase();
        const rawOwnerEmail = normalizeEmail(body.owner || body.email || '');
        const blockedEmails = (config.blockedPlaceholderEmails || []).map((e) =>
          String(e).toLowerCase(),
        );
        const ownerEmail = blockedEmails.includes(rawOwnerEmail)
          ? ''
          : rawOwnerEmail;

        const db = loadDb();
        const allAccounts = Object.values(db.accounts);

        // Priority 1: Exact unique cardId match
        let matched = null;
        if (cardId && cardId !== 'TAPAT_JCOP4_8821') {
          matched = allAccounts.find((a) => a.cardId === cardId) || null;
        }
        // Priority 2: Physical JCOP4 hardware UID match
        if (!matched && jcopCardUid && jcopCardUid !== '04:7A:93:E2:10:88:01') {
          matched =
            allAccounts.find(
              (a) => String(a.jcopCardUid || '').toUpperCase() === jcopCardUid,
            ) || null;
        }
        // Priority 3: Provisioned owner email on card (if registered and not a blocked placeholder)
        if (!matched && ownerEmail && db.accounts[ownerEmail]) {
          matched = db.accounts[ownerEmail];
        }
        // Priority 4: Demo / default card ID bound to a real registered account
        if (!matched && cardId === 'TAPAT_JCOP4_8821') {
          matched =
            allAccounts.find((a) => a.cardId === 'TAPAT_JCOP4_8821') || null;
        }

        if (!matched) {
          return sendJson(res, 404, {
            success: false,
            error:
              'This Tapat card is not bound to any registered account yet. Sign in with your Email & PIN or Create Account first.',
          });
        }

        if (jcopCardUid) matched.jcopCardUid = jcopCardUid;
        if (cardId && (!matched.cardId || cardId !== 'TAPAT_JCOP4_8821')) {
          matched.cardId = cardId;
        }
        matched.lastLoginAt = new Date().toISOString();
        matched.updatedAt = matched.lastLoginAt;
        matched.virtualCards = syncCardsForAccount(matched, config);
        saveDb(db);

        return sendJson(res, 200, {
          success: true,
          account: sanitizeAccount(matched, config),
        });
      }

      // 7. Account-specific routes: /api/accounts/:email[...]
      const accountRouteMatch = pathname.match(
        /^\/api\/accounts\/([^/]+)(\/[a-z-]+)?$/i,
      );
      if (accountRouteMatch) {
        const email = normalizeEmail(decodeURIComponent(accountRouteMatch[1]));
        const subAction = accountRouteMatch[2] || '';
        const db = loadDb();
        const account = db.accounts[email];

        if (!account) {
          return sendJson(res, 404, {
            success: false,
            error: `Account not found for ${email}.`,
          });
        }

        // GET /api/accounts/:email
        if (req.method === 'GET' && !subAction) {
          return sendJson(res, 200, {
            success: true,
            account: sanitizeAccount(account, config),
          });
        }

        // PUT /api/accounts/:email/sync
        if (req.method === 'PUT' && subAction === '/sync') {
          const body = await readJsonBody(req);
          if (typeof body.name === 'string' && body.name.trim().length >= 2) {
            account.name = body.name.trim();
          }
          if (typeof body.phone === 'string') {
            account.phone = body.phone.trim();
          }
          if (typeof body.balance === 'number') {
            account.balance = body.balance;
          }
          if (typeof body.cardId === 'string' && body.cardId.trim()) {
            account.cardId = body.cardId.trim();
          }
          if (typeof body.jcopCardUid === 'string' && body.jcopCardUid.trim()) {
            account.jcopCardUid = body.jcopCardUid.trim().toUpperCase();
          }
          if (typeof body.activeCardId === 'string') {
            account.activeCardId = body.activeCardId;
          }
          if (Array.isArray(body.transactions)) {
            account.transactions = body.transactions;
          }
          if (Array.isArray(body.virtualCards)) {
            account.virtualCards = body.virtualCards;
          }
          if (typeof body.cardLifecycleState === 'string') {
            account.cardLifecycleState = body.cardLifecycleState;
          }
          if (typeof body.pinRetriesLeft === 'number') {
            account.pinRetriesLeft = body.pinRetriesLeft;
          }
          account.virtualCards = syncCardsForAccount(account, config);
          account.updatedAt = new Date().toISOString();
          saveDb(db);

          return sendJson(res, 200, {
            success: true,
            account: sanitizeAccount(account, config),
          });
        }

        // POST /api/accounts/:email/change-pin
        if (req.method === 'POST' && subAction === '/change-pin') {
          const body = await readJsonBody(req);
          const currentPin = String(body.currentPin || '').trim();
          const newPin = String(body.newPin || '').trim();

          if (!verifyPin(currentPin, account)) {
            return sendJson(res, 401, {
              success: false,
              error: 'Current PIN is incorrect.',
            });
          }
          if (
            newPin.length < config.pinMinLength ||
            newPin.length > config.pinMaxLength
          ) {
            return sendJson(res, 400, {
              success: false,
              error: `New PIN must be ${config.pinMinLength} to ${config.pinMaxLength} digits.`,
            });
          }
          const { salt, pinHash } = hashPin(newPin);
          account.pinSalt = salt;
          account.pinHash = pinHash;
          account.pinRetriesLeft = config.maxPinRetries;
          account.updatedAt = new Date().toISOString();
          saveDb(db);

          return sendJson(res, 200, {
            success: true,
            message: 'PIN updated successfully.',
          });
        }

        // POST /api/accounts/:email/bind-card
        if (req.method === 'POST' && subAction === '/bind-card') {
          const body = await readJsonBody(req);
          const cardId = String(body.cardId || '').trim();
          const jcopCardUid = String(body.jcopCardUid || '')
              .trim()
              .toUpperCase();

          for (const other of Object.values(db.accounts)) {
            if (other.email === account.email) continue;
            if (cardId && other.cardId === cardId) other.cardId = '';
            if (
              jcopCardUid &&
              String(other.jcopCardUid || '').toUpperCase() === jcopCardUid
            ) {
              other.jcopCardUid = '';
            }
          }

          if (cardId) account.cardId = cardId;
          if (jcopCardUid) account.jcopCardUid = jcopCardUid;
          account.cardLifecycleState = 'ENROLLED';
          account.virtualCards = syncCardsForAccount(account, config);
          account.updatedAt = new Date().toISOString();
          saveDb(db);

          return sendJson(res, 200, {
            success: true,
            account: sanitizeAccount(account, config),
          });
        }

        // DELETE /api/accounts/:email
        if (req.method === 'DELETE' && !subAction) {
          delete db.accounts[email];
          saveDb(db);
          return sendJson(res, 200, { success: true });
        }
      }

      return sendJson(res, 404, {
        success: false,
        error: `Endpoint not found: ${req.method} ${pathname}`,
      });
    } catch (err) {
      return sendJson(res, 500, {
        success: false,
        error: err.message || 'Internal server error',
      });
    }
  });
}

if (require.main === module) {
  const cfg = loadConfig();
  const port = Number(process.env.PORT || cfg.port || 4000);
  const server = createServer();
  server.listen(port, '0.0.0.0', () => {
    console.log(
      `[tapatan-account-backend] Listening on http://0.0.0.0:${port} (DB: ${DB_PATH})`,
    );
  });
}

module.exports = { createServer, loadConfig, saveConfig, loadDb };

