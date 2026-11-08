const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');
const { createServer } = require('./server');

const DB_PATH = path.join(__dirname, 'data', 'accounts_db.json');

async function request(baseUrl, method, route, body) {
  const res = await fetch(`${baseUrl}${route}`, {
    method,
    headers: { 'Content-Type': 'application/json' },
    body: body ? JSON.stringify(body) : undefined,
  });
  const json = await res.json();
  return { status: res.status, json };
}

async function run() {
  if (fs.existsSync(DB_PATH)) fs.unlinkSync(DB_PATH);

  const server = createServer();
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  const port = server.address().port;
  const baseUrl = `http://127.0.0.1:${port}`;

  try {
    // 1. Register Harry
    const reg = await request(baseUrl, 'POST', '/api/accounts/register', {
      name: 'Harry Valdoz',
      email: 'harry@tapat.ph',
      phone: '+639171234567',
      pin: '654321',
      cardId: 'CARD_TEST_001',
      jcopCardUid: '04:AA:BB:CC:DD:EE:FF',
    });
    assert.strictEqual(reg.status, 201);
    assert.strictEqual(reg.json.account.name, 'Harry Valdoz');
    assert.strictEqual(
      reg.json.account.virtualCards[0].holderName,
      'HARRY VALDOZ',
    );

    // 2. Sync a new transaction (e.g., paid 250 PHP at Sar-E Store)
    const sync = await request(
      baseUrl,
      'PUT',
      '/api/accounts/harry%40tapat.ph/sync',
      {
        balance: 4750.0,
        transactions: [
          {
            id: 'tx-2',
            name: 'Sar-E Store',
            amount: -250.0,
            time: 'Just now',
            type: 'nfc',
          },
          ...reg.json.account.transactions,
        ],
      },
    );
    assert.strictEqual(sync.status, 200);
    assert.strictEqual(sync.json.account.balance, 4750.0);
    assert.strictEqual(sync.json.account.transactions.length, 2);

    // 3. Re-login after sign-out with Email + PIN -> must restore 4750.0 & 2 transactions & HARRY VALDOZ card
    const relogin = await request(baseUrl, 'POST', '/api/accounts/login', {
      email: 'harry@tapat.ph',
      pin: '654321',
    });
    assert.strictEqual(relogin.status, 200);
    assert.strictEqual(relogin.json.account.balance, 4750.0);
    assert.strictEqual(relogin.json.account.transactions.length, 2);
    assert.strictEqual(
      relogin.json.account.virtualCards[0].holderName,
      'HARRY VALDOZ',
    );

    // 4. Card login even if legacy card applet sent owner="richard@tapat.ph" -> UID resolves to Harry Valdoz!
    const cardLogin = await request(
      baseUrl,
      'POST',
      '/api/accounts/login-card',
      {
        cardId: 'TAPAT_JCOP4_8821',
        uid: '04:AA:BB:CC:DD:EE:FF',
        owner: 'richard@tapat.ph',
        name: 'Richard',
      },
    );
    assert.strictEqual(cardLogin.status, 200);
    assert.strictEqual(cardLogin.json.account.name, 'Harry Valdoz');
    assert.strictEqual(
      cardLogin.json.account.virtualCards[0].holderName,
      'HARRY VALDOZ',
    );

    // 5. Unknown email must NOT auto-create or fall back to Richard
    const unknown = await request(baseUrl, 'POST', '/api/accounts/login', {
      email: 'unknown@tapat.ph',
      pin: '123456',
    });
    assert.strictEqual(unknown.status, 404);

    // Clean test account so production DB starts clean
    await request(baseUrl, 'DELETE', '/api/accounts/harry%40tapat.ph');
    console.log('ALL BACKEND SMOKE TESTS PASSED!');
  } finally {
    server.close();
  }
}

run().catch((err) => {
  console.error(err);
  process.exit(1);
});

