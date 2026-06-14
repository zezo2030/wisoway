/**
 * تدفق من Postman "fees cal":
 *   1) GenerateToken (Global API)
 *   2) LoginCustomerMRZ
 *   3) GetCustomerAccount
 * ثم محاولة استخراج رقم جوال أو alias من الرد، وبعدها A2A GetToken + Purchase (كما في eCommerce ABJD).
 *
 * التشغيل: node -r dotenv/config scripts/uwallet-global-login-then-a2a-purchase.js
 */
const axios = require('axios');
const { randomUUID } = require('crypto');

const GLOBAL_URL =
  'https://testapi.uwallet.jo/Global.eWalletAPI.UAT.WithoutSession/api/base/A2AProcess';

function deepFindStrings(obj, out = []) {
  if (obj == null) return out;
  if (typeof obj === 'string') {
    if (obj.length > 3) out.push(obj);
    return out;
  }
  if (Array.isArray(obj)) {
    obj.forEach((x) => deepFindStrings(x, out));
    return out;
  }
  if (typeof obj === 'object') {
    Object.values(obj).forEach((v) => deepFindStrings(v, out));
  }
  return out;
}

/** يخمن رقم جوال أردني/إقليمي أو alias من نصوص الرد */
function guessAliasOrMobile(strings) {
  const candidates = { mobl: null, alias: null };
  for (const s of strings) {
    const t = s.trim();
    if (/^962\d{9,12}$/.test(t) || /^00962\d{8,12}$/.test(t)) {
      candidates.mobl = t.replace(/^00962/, '962');
      continue;
    }
    if (/^\d{10,15}$/.test(t) && t.startsWith('962')) {
      candidates.mobl = t;
      continue;
    }
    if (/^[A-Za-z0-9._@]{3,32}$/.test(t) && /[A-Za-z]/.test(t) && !t.includes(' ')) {
      if (!candidates.alias && t.length < 30) candidates.alias = t;
    }
  }
  return candidates;
}

async function postGlobal(bodyObj) {
  const r = await axios.post(GLOBAL_URL, bodyObj, {
    headers: { 'Content-Type': 'application/json' },
    validateStatus: () => true,
    timeout: 45000,
  });
  return r;
}

function extractTokenFromGenerateToken(data) {
  const tryPaths = [
    data?.A2AResponse?.Body?.Token,
    data?.a2AResponse?.Body?.Token,
    data?.A2AResponse?.body?.Token,
    data?.Token,
    data?.token,
  ];
  for (const t of tryPaths) {
    if (typeof t === 'string' && t.length > 20) return t;
  }
  const flat = deepFindStrings(data, []);
  const jwtLike = flat.find(
    (s) => s.startsWith('eyJ') && s.split('.').length === 3 && s.length > 80,
  );
  return jwtLike || null;
}

function extractTokenFromLogin(data) {
  return extractTokenFromGenerateToken(data);
}

async function main() {
  console.log('=== 1) GenerateToken (ITBEEB) ===\n');
  const genBody = {
    A2ARequest: {
      header: {
        channel: 'ITBEEB',
        srvID: 'GenerateToken',
        DeviceID: '4566',
        UserID: 'ITBEEB',
        Password: 'Cx/PQu8EPIW7sL180gff+w==',
      },
      body: {},
      footer: { signature: null },
    },
  };

  const g1 = await postGlobal(genBody);
  console.log('HTTP', g1.status);
  console.log(JSON.stringify(g1.data, null, 2).slice(0, 4000));
  const tokenAfterGen = extractTokenFromGenerateToken(g1.data);
  console.log(
    '\n[استخراج توكن بعد GenerateToken]',
    tokenAfterGen ? `${tokenAfterGen.slice(0, 40)}...` : 'لم يُعثر على توكن',
  );

  if (!tokenAfterGen) {
    console.log(
      '\nتوقف: لا يمكن المتابعة بدون توكن. تحقق من استجابة GenerateToken.',
    );
    return;
  }

  console.log('\n=== 2) LoginCustomerMRZ ===\n');
  const loginBody = {
    a2ARequest: {
      header: {
        channel: 'ITBEEB',
        DeviceID: '4566',
        UserID: 'ITBEEB',
        Password: 'Cx/PQu8EPIW7sL180gff+w==',
        srvID: 'LoginCustomerMRZ',
        Token: tokenAfterGen,
      },
      body: {
        CustProfile: {
          IsMerchant: '1',
          Usernmae: 'NiTeam',
          Password: 'Gg3#Gg3#',
        },
      },
    },
  };

  const g2 = await postGlobal(loginBody);
  console.log('HTTP', g2.status);
  console.log(JSON.stringify(g2.data, null, 2).slice(0, 6000));

  const sessionToken =
    extractTokenFromLogin(g2.data) || tokenAfterGen;
  console.log(
    '\n[توكن الجلسة للخطوة التالية]',
    sessionToken ? `${sessionToken.slice(0, 40)}...` : 'لا يوجد',
  );

  console.log('\n=== 3) GetCustomerAccount (OPID 2721) ===\n');
  const accBody = {
    A2ARequest: {
      Header: {
        Token: sessionToken,
        Channel: 'ITBEEB',
        SrvID: 'GetCustomerAccount',
        DeviceID: '4566',
        SessionID: '',
      },
      Body: {
        CustProfile: {
          OPID: '2721',
        },
      },
      Footer: { Signature: '' },
    },
  };

  const g3 = await postGlobal(accBody);
  console.log('HTTP', g3.status);
  const accStr = JSON.stringify(g3.data, null, 2);
  console.log(accStr.slice(0, 8000));

  const body = g3.data?.A2AResponse?.Body;
  const accounts = body?.AccountList;
  let fromAccount = { mobl: null, alias: null };
  if (Array.isArray(accounts) && accounts[0]) {
    const a = accounts[0];
    if (a.AliasValue) fromAccount.alias = String(a.AliasValue).trim();
    if (a.Mobile || a.Msisdn || a.Phone) {
      fromAccount.mobl = String(
        a.Mobile || a.Msisdn || a.Phone,
      ).replace(/\s/g, '');
    }
  }
  const allStrings = deepFindStrings(g3.data, []);
  const guessed = guessAliasOrMobile(allStrings);
  const merged = {
    mobl: fromAccount.mobl || guessed.mobl,
    alias: fromAccount.alias || guessed.alias,
  };
  console.log('\n[من AccountList]', fromAccount);
  console.log('[استخراج احتياطي من النصوص]', guessed);
  console.log('[المعتمد للدفع]', merged);

  const base = (process.env.A2A_CLIQ_BASE_URL || '').replace(/\/$/, '');
  const getTokenBearer =
    process.env.A2A_CLIQ_BEARER_TOKEN_GETTOKEN ||
    process.env.A2A_CLIQ_BEARER_TOKEN;
  const purchaseBearer = process.env.A2A_CLIQ_BEARER_TOKEN;

  let aliasType = 'MOBL';
  let aliasValue =
    merged.mobl ||
    merged.alias ||
    process.env.A2A_CLIQ_TEST_ALIAS_VALUE ||
    '962789001167';
  if (merged.alias && !merged.mobl) {
    aliasType = 'ALIAS';
    aliasValue = merged.alias;
  }

  console.log('\n=== 4) A2A GetToken + Purchase (Merchant) ===');
  console.log('استخدام RAliasType=', aliasType, 'RAliasValue=', aliasValue);

  const headersMerchant = {
    Authorization: `Bearer ${getTokenBearer}`,
    CorrelationID: process.env.A2A_CLIQ_CORRELATION_ID,
    MerchantID: process.env.A2A_CLIQ_MERCHANT_ID,
    UserID: process.env.A2A_CLIQ_USER_ID,
    Password: process.env.A2A_CLIQ_PASSWORD,
    'Content-Type': 'application/json',
  };

  const gt = await axios.post(
    `${base}/GetToken`,
    { SecurityKey: process.env.A2A_CLIQ_SECURITY_KEY },
    { headers: headersMerchant, validateStatus: () => true },
  );
  console.log('GetToken HTTP', gt.status);
  let sessionJwt = gt.data?.TokenInfo?.Token;
  if (gt.status === 401 && purchaseBearer && getTokenBearer !== purchaseBearer) {
    const gt2 = await axios.post(
      `${base}/GetToken`,
      { SecurityKey: process.env.A2A_CLIQ_SECURITY_KEY },
      {
        headers: { ...headersMerchant, Authorization: `Bearer ${purchaseBearer}` },
        validateStatus: () => true,
      },
    );
    sessionJwt = gt2.data?.TokenInfo?.Token;
    console.log('GetToken (fallback bearer) HTTP', gt2.status);
  }
  if (!sessionJwt) {
    console.log('فشل الحصول على JWT للـ Purchase من A2A GetToken');
    return;
  }

  const messageTrxId = `WST${Date.now()}${randomUUID().replace(/-/g, '').slice(0, 8)}`;
  const purchaseBody = {
    MessageTrxID: messageTrxId,
    MerchantID: process.env.A2A_CLIQ_MERCHANT_ID,
    RAliasType: aliasType,
    RAliasValue: aliasValue,
    Amount: 0.15,
    CallBackURL:
      process.env.A2A_CLIQ_CALLBACK_URL || 'https://example.com/cb',
  };

  const pr = await axios.post(`${base}/Purchase`, purchaseBody, {
    headers: {
      Authorization: `Bearer ${sessionJwt}`,
      CorrelationID: process.env.A2A_CLIQ_CORRELATION_ID,
      MerchantID: process.env.A2A_CLIQ_MERCHANT_ID,
      'Content-Type': 'application/json',
    },
    validateStatus: () => true,
  });
  console.log('Purchase HTTP', pr.status);
  console.log(JSON.stringify(pr.data, null, 2));

  const msgId = pr.data?.MSGID;
  if (msgId) {
    console.log('\n=== 5) PaymentInquiry (MSGID) ===\n');
    const inq = await axios.post(
      `${base}/PaymentInquiry`,
      { MessageTrxID: msgId },
      {
        headers: {
          Authorization: `Bearer ${sessionJwt}`,
          CorrelationID: process.env.A2A_CLIQ_CORRELATION_ID,
          MerchantID: process.env.A2A_CLIQ_MERCHANT_ID,
          'Content-Type': 'application/json',
        },
        validateStatus: () => true,
      },
    );
    console.log('Inquiry HTTP', inq.status);
    console.log(JSON.stringify(inq.data, null, 2));
  } else {
    console.log(
      '\n(لا يوجد MSGID بعد — الاستعلام لاحقًا بـ MessageTrxID:',
      messageTrxId,
      ')',
    );
    const inq2 = await axios.post(
      `${base}/PaymentInquiry`,
      { MessageTrxID: messageTrxId },
      {
        headers: {
          Authorization: `Bearer ${sessionJwt}`,
          CorrelationID: process.env.A2A_CLIQ_CORRELATION_ID,
          MerchantID: process.env.A2A_CLIQ_MERCHANT_ID,
          'Content-Type': 'application/json',
        },
        validateStatus: () => true,
      },
    );
    console.log('PaymentInquiry(MessageTrxID) HTTP', inq2.status);
    console.log(JSON.stringify(inq2.data, null, 2));
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
