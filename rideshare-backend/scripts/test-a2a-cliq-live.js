/**
 * اختبار مباشر لـ A2A CliQ كما في Postman: GetToken ثم Purchase.
 * التشغيل من مجلد rideshare-backend:
 *   node -r dotenv/config scripts/test-a2a-cliq-live.js
 */
const axios = require('axios');
const { randomUUID } = require('crypto');

function headersFor(bearer) {
  return {
    Authorization: `Bearer ${bearer}`,
    CorrelationID: process.env.A2A_CLIQ_CORRELATION_ID,
    MerchantID: process.env.A2A_CLIQ_MERCHANT_ID,
    UserID: process.env.A2A_CLIQ_USER_ID,
    Password: process.env.A2A_CLIQ_PASSWORD,
    'Content-Type': 'application/json',
  };
}

function purchaseHeaders(bearer) {
  return {
    Authorization: `Bearer ${bearer}`,
    CorrelationID: process.env.A2A_CLIQ_CORRELATION_ID,
    MerchantID: process.env.A2A_CLIQ_MERCHANT_ID,
    'Content-Type': 'application/json',
  };
}

async function main() {
  const base = (process.env.A2A_CLIQ_BASE_URL || '').replace(/\/$/, '');
  if (!base) {
    console.error('Missing A2A_CLIQ_BASE_URL');
    process.exit(1);
  }

  const getTokenBearer =
    process.env.A2A_CLIQ_BEARER_TOKEN_GETTOKEN ||
    process.env.A2A_CLIQ_BEARER_TOKEN;
  const purchaseStatic = process.env.A2A_CLIQ_BEARER_TOKEN;

  console.log('--- 1) GetToken (كما في Postman) ---');
  let sessionJwt = null;
  let getTokenStatus = null;
  try {
    const r1 = await axios.post(
      `${base}/GetToken`,
      { SecurityKey: process.env.A2A_CLIQ_SECURITY_KEY },
      { headers: headersFor(getTokenBearer), validateStatus: () => true },
    );
    getTokenStatus = r1.status;
    console.log('HTTP', r1.status);
    console.log(JSON.stringify(r1.data, null, 2));
    if (r1.data?.TokenInfo?.Token) {
      sessionJwt = r1.data.TokenInfo.Token;
    }
  } catch (e) {
    console.error('GetToken request failed:', e.message);
  }

  if (getTokenStatus === 401 && purchaseStatic && getTokenBearer !== purchaseStatic) {
    console.log('\n--- إعادة GetToken بتوكن Purchase (نفس منطق الباكند) ---');
    try {
      const r1b = await axios.post(
        `${base}/GetToken`,
        { SecurityKey: process.env.A2A_CLIQ_SECURITY_KEY },
        { headers: headersFor(purchaseStatic), validateStatus: () => true },
      );
      console.log('HTTP', r1b.status);
      console.log(JSON.stringify(r1b.data, null, 2));
      if (r1b.data?.TokenInfo?.Token) sessionJwt = r1b.data.TokenInfo.Token;
    } catch (e) {
      console.error(e.message);
    }
  }

  const bearerForPurchase = sessionJwt || purchaseStatic;
  if (!bearerForPurchase) {
    console.error('لا يوجد توكن للـ Purchase');
    process.exit(1);
  }

  const messageTrxId = `WST${Date.now()}${randomUUID().replace(/-/g, '').slice(0, 8)}`;
  const body = {
    MessageTrxID: messageTrxId,
    MerchantID: process.env.A2A_CLIQ_MERCHANT_ID,
    RAliasType: 'MOBL',
    RAliasValue: '962789001167',
    Amount: 0.15,
    CallBackURL:
      process.env.A2A_CLIQ_CALLBACK_URL || 'https://example.com/cliq-callback',
  };

  console.log('\n--- 2) Purchase (نفس نموذج Postman: MOBL + رقم من المجموعة) ---');
  console.log('MessageTrxID:', messageTrxId);
  try {
    const r2 = await axios.post(`${base}/Purchase`, body, {
      headers: purchaseHeaders(bearerForPurchase),
      validateStatus: () => true,
    });
    console.log('HTTP', r2.status);
    console.log(JSON.stringify(r2.data, null, 2));
  } catch (e) {
    console.error('Purchase failed:', e.message);
  }

  if (sessionJwt) {
    console.log('\n--- 3) PaymentInquiry (اختياري) ---');
    try {
      const r3 = await axios.post(
        `${base}/PaymentInquiry`,
        { MessageTrxID: messageTrxId },
        { headers: purchaseHeaders(sessionJwt || purchaseStatic), validateStatus: () => true },
      );
      console.log('HTTP', r3.status);
      console.log(JSON.stringify(r3.data, null, 2));
    } catch (e) {
      console.error(e.message);
    }
  }
}

main();
