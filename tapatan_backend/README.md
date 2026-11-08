# Bantay / tap@tan — Configurable Account Management Backend

Dedicated Node.js backend service (`tapatan_backend`) that centralizes account registration, authentication, JCOP4 NFC smart-card binding, virtual card holder synchronization, and persistent transaction ledger storage across sign-outs and re-logins.

## Quick Start

```powershell
cd tapatan_backend
node server.js
```

By default, the backend listens on `http://0.0.0.0:4000`.

- **Configuration File**: `config/account_rules.json` (can be edited directly or updated live via `PUT /api/config` or from the Bantay app's **Account Backend & Rules** settings modal).
- **Persistent Database**: `data/accounts_db.json` (atomic file-backed ledger; signing out in the mobile app never deletes account records or transaction history).

## Configurable Rules (`config/account_rules.json`)

| Rule | Default | Description |
| :--- | :--- | :--- |
| `port` | `4000` | HTTP port for the backend server |
| `initialWalletBalance` | `5000.0` | Starting balance granted to newly registered accounts |
| `pinMinLength` / `pinMaxLength` | `4` / `6` | Allowed card/account PIN length |
| `maxPinRetries` | `5` | Maximum consecutive failed PIN attempts before lock |
| `requirePinOnEmailLogin` | `true` | Enforce PIN verification when signing in by email |
| `autoCreateAccountOnUnknownEmailLogin` | `false` | Reject unknown emails on Sign In instead of fabricating placeholder accounts |
| `strictCardToAccountBinding` | `true` | Require NFC card taps to match a registered account's `cardId` or `jcopCardUid` |
| `allowCardRebindOnSignup` | `true` | Allow re-provisioning a physical JCOP4 card to a newly created account |
| `syncCardHolderNameWithAccount` | `true` | Always synchronize card holder display names with the authenticated account's real name |

## REST API Endpoints

- `GET /api/health` — Server status, account count, and active rules
- `GET /api/config` / `PUT /api/config` — Read or update account management rules
- `GET /api/accounts` — List registered account summaries (PIN hashes omitted)
- `POST /api/accounts/register` — Register a new account with salted SHA-256 PIN hash
- `POST /api/accounts/login` — Authenticate with `email` + `pin` and restore full balance, cards, and transaction history
- `POST /api/accounts/login-card` — Authenticate via bound `cardId` / `jcopCardUid`
- `GET /api/accounts/:email` — Retrieve account state
- `PUT /api/accounts/:email/sync` — Persist balance, virtual cards, and transaction history updates
- `POST /api/accounts/:email/change-pin` — Verify current PIN and update PIN hash
- `POST /api/accounts/:email/bind-card` — Bind a JCOP4 `cardId` / `jcopCardUid` to an account

