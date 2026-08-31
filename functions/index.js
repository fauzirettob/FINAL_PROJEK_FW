const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { logger } = require("firebase-functions/v2");
const admin = require("firebase-admin");

admin.initializeApp();

const db = admin.firestore();

// ─── Helper: cek apakah caller adalah admin ──
async function requireAdmin(uid) {
  const adminDoc = await db.collection("admin").doc(uid).get();
  if (!adminDoc.exists) {
    throw new HttpsError(
      "permission-denied",
      "Hanya admin yang bisa melakukan operasi ini."
    );
  }
}

/**
 * addGuru - Cloud Function callable dari Flutter.
 *
 * Membuat akun Firebase Auth + data Guru di Firestore
 * tanpa mengubah session admin yang sedang login.
 *
 * Parameter (dikirim dari Flutter):
 *   email    (string) - Email guru baru
 *   password (string) - Password guru baru
 *   nama     (string) - Nama lengkap guru baru
 *
 * Return:
 *   { success: true, uid: string }
 */
exports.addGuru = onCall(async (request) => {
  // ── 1. Wajib login ──
  if (!request.auth) {
    throw new HttpsError(
      "unauthenticated",
      "Anda harus login untuk menambah guru.",
    );
  }

  const adminUid = request.auth.uid;
  const { email, password, nama } = request.data;

  // ── 2. Validasi input ──
  if (!email || typeof email !== "string" || email.trim().length === 0) {
    throw new HttpsError("invalid-argument", "Email wajib diisi.");
  }
  if (!password || typeof password !== "string" || password.length < 6) {
    throw new HttpsError(
      "invalid-argument",
      "Password minimal 6 karakter.",
    );
  }
  if (!nama || typeof nama !== "string" || nama.trim().length === 0) {
    throw new HttpsError("invalid-argument", "Nama wajib diisi.");
  }

  logger.info(`Admin ${adminUid} menambah guru: ${email}`);

  // ── 3. Cek apakah admin benar-benar admin ──
  const adminDoc = await db.collection("admin").doc(adminUid).get();
  if (!adminDoc.exists) {
    throw new HttpsError(
      "permission-denied",
      "Hanya admin yang bisa menambah guru.",
    );
  }

  // ── 4. Buat user di Firebase Auth ──
  let userRecord;
  try {
    userRecord = await admin.auth().createUser({
      email: email.trim(),
      password,
      displayName: nama.trim(),
    });
  } catch (authError) {
    logger.error("Gagal membuat user auth:", authError);
    if (authError.code === "auth/email-already-exists") {
      throw new HttpsError(
        "already-exists",
        "Email sudah terdaftar. Gunakan email lain.",
      );
    }
    throw new HttpsError(
      "internal",
      `Gagal membuat akun Firebase Auth: ${authError.message}`,
    );
  }

  const uid = userRecord.uid;

  // ── 5. Simpan data guru ke Firestore ──
  try {
    await db
      .collection("guru")
      .doc(uid)
      .set({
        nama: nama.trim(),
        email: email.trim(),
        role: "guru",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
  } catch (firestoreError) {
    logger.error("addGuru: Firestore write gagal, rollback auth user:", firestoreError);

    // Rollback — hapus auth user yang baru dibuat
    try {
      await admin.auth().deleteUser(uid);
    } catch (deleteError) {
      logger.error("addGuru: Gagal rollback auth user:", deleteError);
    }

    throw new HttpsError(
      "internal",
      "Gagal menyimpan data guru. Silakan coba lagi.",
    );
  }

  logger.info(`addGuru sukses: ${uid} (${email})`);

  return {
    success: true,
    uid,
  };
});

/**
 * resetGuruPassword - Cloud Function callable dari Flutter.
 *
 * Admin mengubah password akun Firebase Auth seorang guru.
 * Menggunakan Firebase Admin SDK yang bisa update password
 * tanpa perlu login sebagai guru tersebut.
 *
 * Parameter:
 *   guruUid     (string) - UID guru yang password-nya akan direset
 *   newPassword (string) - Password baru (minimal 6 karakter)
 *
 * Return:
 *   { success: true, message: string }
 */
exports.resetGuruPassword = onCall(async (request) => {
  // ── 1. Wajib login ──
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Anda harus login.");
  }

  // ── 2. Verifikasi admin ──
  await requireAdmin(request.auth.uid);

  const { guruUid, newPassword } = request.data;

  // ── 3. Validasi input ──
  if (!guruUid || typeof guruUid !== "string") {
    throw new HttpsError("invalid-argument", "UID guru wajib diisi.");
  }
  if (!newPassword || typeof newPassword !== "string" || newPassword.length < 6) {
    throw new HttpsError("invalid-argument", "Password minimal 6 karakter.");
  }

  // ── 4. Pastikan guru ada di Firestore ──
  const guruDoc = await db.collection("guru").doc(guruUid).get();
  if (!guruDoc.exists) {
    throw new HttpsError("not-found", "Data guru tidak ditemukan.");
  }

  // ── 5. Update password via Firebase Auth Admin SDK ──
  try {
    await admin.auth().updateUser(guruUid, {
      password: newPassword,
    });
  } catch (authError) {
    logger.error("resetGuruPassword: Gagal update password:", authError);
    if (authError.code === "auth/user-not-found") {
      throw new HttpsError("not-found", "Akun guru tidak ditemukan di Firebase Auth.");
    }
    throw new HttpsError("internal", `Gagal update password: ${authError.message}`);
  }

  logger.info(`resetGuruPassword: Password guru ${guruUid} berhasil direset oleh admin ${request.auth.uid}`);

  return {
    success: true,
    message: "Password guru berhasil direset.",
  };
});
