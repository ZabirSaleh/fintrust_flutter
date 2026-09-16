const crypto = require("crypto");
const admin = require("firebase-admin");
const {ethers} = require("ethers");
const {onCall, HttpsError} = require("firebase-functions/v2/https");

admin.initializeApp();

const db = admin.firestore();
const OTP_TTL_MS = 5 * 60 * 1000;
const MAIL_COLLECTION = "mail";
const CHAIN_NETWORK = "sepolia";
const LEDGER_CONTRACT_ADDRESS =
  process.env.FINTRUST_LEDGER_ADDRESS || "0xdDD652A8Cb6D0D56AA7Ad157b10Ec839559B591C";
const LEDGER_ABI = [
  "function anchorProof(string transactionId, bytes32 transactionHash, bytes32 previousHash, uint256 blockIndex) external",
];

exports.requestOtp = onCall(async (request) => {
  const purpose = cleanString(request.data && request.data.purpose);
  const email = cleanString(request.data && request.data.email).toLowerCase();
  const uid = request.auth && request.auth.uid;

  if (!["login", "transaction"].includes(purpose)) {
    throw new HttpsError("invalid-argument", "Unsupported OTP purpose.");
  }
  if (!email) {
    throw new HttpsError("invalid-argument", "Email is required for OTP.");
  }
  if (purpose === "transaction" && !uid) {
    throw new HttpsError("unauthenticated", "Sign in before requesting a transaction OTP.");
  }

  const code = generateOtp();
  const expiresAt = admin.firestore.Timestamp.fromMillis(Date.now() + OTP_TTL_MS);
  const challengeRef = db.collection("otpChallenges").doc();
  await challengeRef.set({
    purpose,
    email,
    uid: uid || null,
    codeHash: hashValue(code),
    consumed: false,
    expiresAt,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  await queueOtpEmail({email, code, purpose, expiresAt});

  return {
    challengeId: challengeRef.id,
    expiresAt: expiresAt.toDate().toISOString(),
    delivery: "email",
  };
});
exports.executeTransaction = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in before making a transaction.");
  }

  const uid = request.auth.uid;
  const type = cleanString(request.data && request.data.type);
  const amount = Number(request.data && request.data.amount);
  const recipientAccount = normalizeAccountNumber(
    cleanString(request.data && request.data.recipientAccount),
  );
  const challengeId = cleanString(request.data && request.data.challengeId);
  const code = cleanString(request.data && request.data.code);
  if (!["deposit", "send"].includes(type)) {
    throw new HttpsError("invalid-argument", "Unsupported transaction type.");
  }
  if (!Number.isFinite(amount) || amount <= 0) {
    throw new HttpsError("invalid-argument", "Enter an amount greater than zero.");
  }
  await verifyOtpChallenge({
    request,
    purpose: "transaction",
    challengeId,
    code,
    consume: true,
  });

  const result = await db.runTransaction(async (txn) => {
    const senderProfileRef = db.collection("users").doc(uid);
    const senderWalletRef = senderProfileRef.collection("wallets").doc("main");
    const senderProfileSnap = await txn.get(senderProfileRef);
    const senderWalletSnap = await txn.get(senderWalletRef);
    const senderProfile = senderProfileSnap.data() || {};
    const senderWallet = senderWalletSnap.data() || {};
    const currency = senderWallet.currency || "MYR";
    const senderBalance = Number(senderWallet.balance || 0);

    if (type === "deposit") {
      const secureTxn = await buildSecureTransaction(txn, uid, {
        title: "Deposit",
        counterparty: senderProfile.accountNumber || "Own account",
        amount,
        currency,
        direction: "Incoming",
        status: "Settled",
        category: "Deposit",
      });
      txn.set(senderWalletRef, {
        balance: senderBalance + amount,
        currency,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, {merge: true});
      txn.set(senderProfileRef.collection("transactions").doc(secureTxn.id), secureTxn);
      txn.set(senderProfileRef.collection("activity").doc(`act-${secureTxn.id}`), {
        title: "Deposit received",
        subtitle: `${currency} ${amount.toFixed(2)} added with server OTP approval`,
        iconKey: "deposit",
        occurredAt: secureTxn.occurredAt,
        isCritical: false,
      });
      return {
        balance: senderBalance + amount,
        anchors: [anchorPayload(uid, secureTxn)],
      };
    }

    if (!recipientAccount) {
      throw new HttpsError("invalid-argument", "Recipient account is required.");
    }
    if (recipientAccount === senderProfile.accountNumber) {
      throw new HttpsError("invalid-argument", "You cannot send money to your own account.");
    }
    if (senderBalance < amount) {
      throw new HttpsError("failed-precondition", "Insufficient balance.");
    }

    const directoryRef = db.collection("accountDirectory").doc(recipientAccount);
    const directorySnap = await txn.get(directoryRef);
    const directory = directorySnap.data();
    if (!directory || !directory.uid) {
      throw new HttpsError("not-found", "Recipient account was not found.");
    }

    const recipientUid = directory.uid;
    const recipientProfileRef = db.collection("users").doc(recipientUid);
    const recipientWalletRef = recipientProfileRef.collection("wallets").doc("main");
    const recipientWalletSnap = await txn.get(recipientWalletRef);
    const recipientWallet = recipientWalletSnap.data() || {};
    const recipientBalance = Number(recipientWallet.balance || 0);

    const senderSecureTxn = await buildSecureTransaction(txn, uid, {
      title: "Transfer sent",
      counterparty: directory.fullName || recipientAccount,
      amount: -amount,
      currency,
      direction: "Outgoing",
      status: "Settled",
      category: "Transfer",
    });
    const recipientSecureTxn = await buildSecureTransaction(txn, recipientUid, {
      title: "Transfer received",
      counterparty: senderProfile.fullName || "FINTRUST member",
      amount,
      currency,
      direction: "Incoming",
      status: "Settled",
      category: "Transfer",
    });

    txn.set(senderWalletRef, {
      balance: senderBalance - amount,
      currency,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, {merge: true});
    txn.set(recipientWalletRef, {
      balance: recipientBalance + amount,
      currency,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, {merge: true});
    txn.set(senderProfileRef.collection("transactions").doc(senderSecureTxn.id), senderSecureTxn);
    txn.set(recipientProfileRef.collection("transactions").doc(recipientSecureTxn.id), recipientSecureTxn);
    txn.set(senderProfileRef.collection("activity").doc(`act-${senderSecureTxn.id}`), {
      title: "Transfer sent",
      subtitle: `${currency} ${amount.toFixed(2)} approved by server OTP`,
      iconKey: "transfer",
      occurredAt: senderSecureTxn.occurredAt,
      isCritical: false,
    });
    txn.set(recipientProfileRef.collection("activity").doc(`act-${recipientSecureTxn.id}`), {
      title: "Transfer received",
      subtitle: `From ${senderProfile.fullName || "FINTRUST member"}`,
      iconKey: "deposit",
      occurredAt: recipientSecureTxn.occurredAt,
      isCritical: false,
    });
    return {
      balance: senderBalance - amount,
      anchors: [
        anchorPayload(uid, senderSecureTxn),
        anchorPayload(recipientUid, recipientSecureTxn),
      ],
    };
  });

  const blockchainAnchors = await anchorLedgerBlocks(result.anchors || []);
  return {
    ok: true,
    balance: result.balance,
    blockchainAnchors,
  };
});

exports.verifyOtp = onCall(async (request) => {
  const purpose = cleanString(request.data && request.data.purpose);
  const challengeId = cleanString(request.data && request.data.challengeId);
  const code = cleanString(request.data && request.data.code);
  const email = cleanString(request.data && request.data.email).toLowerCase();
  await verifyOtpChallenge({request, purpose, challengeId, code, email, consume: purpose === "login"});
  return {verified: true};
});

async function verifyOtpChallenge({request, purpose, challengeId, code, email = "", consume = false}) {
  if (!challengeId || !/^\d{6}$/.test(code)) {
    throw new HttpsError("invalid-argument", "Valid OTP challenge and 6-digit code are required.");
  }

  const ref = db.collection("otpChallenges").doc(challengeId);
  const snap = await ref.get();
  const challenge = snap.data();
  if (!challenge) {
    throw new HttpsError("not-found", "OTP challenge was not found.");
  }
  if (challenge.consumed) {
    throw new HttpsError("failed-precondition", "OTP challenge was already used.");
  }
  if (challenge.purpose !== purpose) {
    throw new HttpsError("failed-precondition", "OTP challenge purpose mismatch.");
  }
  if (challenge.expiresAt.toMillis() < Date.now()) {
    throw new HttpsError("deadline-exceeded", "OTP challenge expired.");
  }
  if (challenge.uid && (!request.auth || request.auth.uid !== challenge.uid)) {
    throw new HttpsError("permission-denied", "OTP challenge does not belong to this user.");
  }
  if (challenge.email && email && challenge.email !== email) {
    throw new HttpsError("permission-denied", "OTP challenge does not belong to this email.");
  }
  if (challenge.codeHash !== hashValue(code)) {
    throw new HttpsError("permission-denied", "OTP code is incorrect.");
  }

  if (consume) {
    await ref.update({
      consumed: true,
      consumedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }
}

async function buildSecureTransaction(txn, uid, fields) {
  const occurredAt = admin.firestore.Timestamp.now();
  const countQuery = db.collection("users").doc(uid).collection("transactions").orderBy("blockIndex", "desc").limit(1);
  const latestSnap = await txn.get(countQuery);
  const latest = latestSnap.empty ? null : latestSnap.docs[0].data();
  const previousHash = latest && latest.transactionHash ? latest.transactionHash : "GENESIS";
  const blockIndex = latest && latest.blockIndex ? latest.blockIndex + 1 : 1;
  const id = `${fields.category.toLowerCase()}-${Date.now()}-${Math.floor(Math.random() * 100000)}`;
  const payload = [
    id,
    fields.title,
    fields.counterparty,
    Number(fields.amount).toFixed(2),
    fields.currency,
    fields.direction,
    fields.status,
    fields.category,
    occurredAt.toDate().toISOString(),
    previousHash,
    blockIndex,
  ].join("|");
  const transactionHash = hashValue(payload);
  const serverSignature = signValue(transactionHash);

  return {
    id,
    ...fields,
    occurredAt,
    previousHash,
    transactionHash,
    blockIndex,
    serverSignature,
    signedBy: "fintrust-cloud-functions",
  };
}

function anchorPayload(uid, secureTxn) {
  return {
    uid,
    transactionId: secureTxn.id,
    transactionHash: secureTxn.transactionHash,
    previousHash: secureTxn.previousHash,
    blockIndex: secureTxn.blockIndex,
  };
}

async function anchorLedgerBlocks(anchors) {
  if (!anchors.length) {
    return [];
  }

  if (!process.env.SEPOLIA_RPC_URL || !process.env.BLOCKCHAIN_PRIVATE_KEY) {
    await markAnchorsSkipped(anchors, "Blockchain environment is not configured.");
    return anchors.map((anchor) => ({
      transactionId: anchor.transactionId,
      chainStatus: "skipped",
    }));
  }

  const provider = new ethers.JsonRpcProvider(process.env.SEPOLIA_RPC_URL);
  const wallet = new ethers.Wallet(process.env.BLOCKCHAIN_PRIVATE_KEY, provider);
  const ledger = new ethers.Contract(LEDGER_CONTRACT_ADDRESS, LEDGER_ABI, wallet);
  const anchored = [];

  for (const anchor of anchors) {
    try {
      const tx = await ledger.anchorProof(
        anchor.transactionId,
        asBytes32(anchor.transactionHash),
        asBytes32(anchor.previousHash),
        anchor.blockIndex,
      );
      const receipt = await tx.wait();
      const chainData = {
        chainNetwork: CHAIN_NETWORK,
        chainContract: LEDGER_CONTRACT_ADDRESS,
        chainTxHash: receipt.hash,
        chainBlockNumber: receipt.blockNumber,
        chainStatus: "anchored",
        chainAnchoredAt: admin.firestore.FieldValue.serverTimestamp(),
      };
      await updateAnchorStatus(anchor, chainData);
      anchored.push({
        transactionId: anchor.transactionId,
        chainStatus: "anchored",
        chainTxHash: receipt.hash,
      });
    } catch (error) {
      await updateAnchorStatus(anchor, {
        chainNetwork: CHAIN_NETWORK,
        chainContract: LEDGER_CONTRACT_ADDRESS,
        chainStatus: "anchor_failed",
        chainError: clipError(error),
        chainAnchoredAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      anchored.push({
        transactionId: anchor.transactionId,
        chainStatus: "anchor_failed",
      });
    }
  }

  return anchored;
}

async function markAnchorsSkipped(anchors, reason) {
  await Promise.all(anchors.map((anchor) => updateAnchorStatus(anchor, {
    chainNetwork: CHAIN_NETWORK,
    chainContract: LEDGER_CONTRACT_ADDRESS,
    chainStatus: "skipped",
    chainError: reason,
    chainAnchoredAt: admin.firestore.FieldValue.serverTimestamp(),
  })));
}

function updateAnchorStatus(anchor, fields) {
  return db
    .collection("users")
    .doc(anchor.uid)
    .collection("transactions")
    .doc(anchor.transactionId)
    .set(fields, {merge: true});
}

function asBytes32(value) {
  if (!value || value === "GENESIS") {
    return ethers.ZeroHash;
  }
  return value.startsWith("0x") ? value : `0x${value}`;
}

function clipError(error) {
  return String(error && error.message ? error.message : error).slice(0, 500);
}

function hashValue(value) {
  return crypto.createHash("sha256").update(String(value)).digest("hex");
}

function generateOtp() {
  return String(crypto.randomInt(100000, 1000000));
}

async function queueOtpEmail({email, code, purpose, expiresAt}) {
  const purposeLabel = purpose === "transaction" ? "transaction approval" : "login";
  const expiresText = expiresAt.toDate().toLocaleTimeString("en-US", {
    hour: "2-digit",
    minute: "2-digit",
    timeZone: "Asia/Kuala_Lumpur",
  });
  await db.collection(MAIL_COLLECTION).add({
    to: [email],
    message: {
      subject: `FINTRUST ${purposeLabel} OTP`,
      text: [
        `Your FINTRUST ${purposeLabel} OTP is ${code}.`,
        `This code expires at ${expiresText} Malaysia time.`,
        "If you did not request this, ignore this email and secure your account.",
      ].join("\n\n"),
      html: [
        "<div style=\"font-family:Arial,sans-serif;color:#111827;line-height:1.5\">",
        `<h2>FINTRUST ${purposeLabel} OTP</h2>`,
        "<p>Use the verification code below to continue.</p>",
        `<p style=\"font-size:28px;font-weight:700;letter-spacing:4px\">${code}</p>`,
        `<p>This code expires at ${expiresText} Malaysia time.</p>`,
        "<p>If you did not request this, ignore this email and secure your account.</p>",
        "</div>",
      ].join(""),
    },
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
}

function signValue(value) {
  const secret = process.env.FINTRUST_SIGNING_SECRET || "fintrust-development-signing-secret";
  return crypto.createHmac("sha256", secret).update(String(value)).digest("hex");
}

function cleanString(value) {
  return typeof value === "string" ? value.trim() : "";
}

function normalizeAccountNumber(value) {
  const cleaned = value.toUpperCase().replace(/[^A-Z0-9]/g, "");
  if (cleaned.startsWith("FT") && cleaned.length >= 12) {
    return `FT-${cleaned.slice(2, 6)}-${cleaned.slice(6)}`;
  }
  return value.trim().toUpperCase();
}
