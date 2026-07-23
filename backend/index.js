const express = require("express");
const cors = require("cors");
require("dotenv").config();

const axios = require("axios");
const bcrypt = require("bcrypt");
const jwt = require("jsonwebtoken");

const db = require("./db");

const app = express();
const port = process.env.PORT || 3000;

// ==========================================
// KONFIGURASI UMUM
// ==========================================
const MAPBOX_TIMEOUT_MS = 45_000;
const GNEWS_TIMEOUT_MS = 10_000;
const REQUEST_BODY_LIMIT = "5mb";

// ==========================================
// IN-MEMORY CACHE UNTUK GNEWS
// Cache per kategori, TTL 30 menit
// ==========================================
const newsCache = new Map();
const CACHE_TTL_MS = 30 * 60 * 1000;

// ==========================================
// MIDDLEWARE
// ==========================================
app.use(cors());

// Batas request diperbesar karena penyimpanan rute dapat
// membawa banyak titik koordinat polyline.
app.use(
  express.json({
    limit: REQUEST_BODY_LIMIT,
  }),
);

app.use(
  express.urlencoded({
    extended: true,
    limit: REQUEST_BODY_LIMIT,
  }),
);

// ==========================================
// CEK KONEKSI DATABASE
// ==========================================
async function testDBConnection() {
  try {
    await db.query("SELECT 1");

    console.log("✅ Berhasil terhubung ke database Supabase (PostgreSQL)!");
  } catch (error) {
    console.error("❌ Gagal terhubung ke database:", error.message);
  }
}

testDBConnection();

// ==========================================
// ROUTE DASAR
// ==========================================
app.get("/", (req, res) => {
  return res.status(200).json({
    success: true,
    message: "Selamat datang di API RunNotPace!",
  });
});

// ==========================================
// ENDPOINT REGISTRASI
// ==========================================
app.post("/api/auth/register", async (req, res) => {
  const nama = req.body.nama?.toString().trim();
  const email = req.body.email?.toString().trim().toLowerCase();
  const password = req.body.password?.toString();

  if (!nama || !email || !password) {
    return res.status(400).json({
      success: false,
      message: "Nama, email, dan password wajib diisi.",
    });
  }

  if (password.length < 6) {
    return res.status(400).json({
      success: false,
      message: "Password minimal terdiri dari 6 karakter.",
    });
  }

  try {
    const existingUser = await db.query(
      `
      SELECT id_user
      FROM tabel_users
      WHERE LOWER(email) = LOWER($1)
      LIMIT 1
      `,
      [email],
    );

    if (existingUser.rows.length > 0) {
      return res.status(400).json({
        success: false,
        message: "Email sudah terdaftar!",
      });
    }

    const hashedPassword = await bcrypt.hash(password, 10);

    const result = await db.query(
      `
      INSERT INTO tabel_users (
        nama,
        email,
        password
      )
      VALUES ($1, $2, $3)
      RETURNING id_user
      `,
      [nama, email, hashedPassword],
    );

    return res.status(201).json({
      success: true,
      message: "Registrasi berhasil!",
      id_user: result.rows[0].id_user,
    });
  } catch (error) {
    console.error("Register error:", {
      message: error.message,
      code: error.code,
      detail: error.detail,
    });

    return res.status(500).json({
      success: false,
      message: "Terjadi kesalahan pada server saat registrasi.",
    });
  }
});

// ==========================================
// ENDPOINT LOGIN
// ==========================================
app.post("/api/auth/login", async (req, res) => {
  const email = req.body.email?.toString().trim().toLowerCase();
  const password = req.body.password?.toString();

  if (!email || !password) {
    return res.status(400).json({
      success: false,
      message: "Email dan password wajib diisi.",
    });
  }

  try {
    const users = await db.query(
      `
      SELECT
        id_user,
        nama,
        email,
        password
      FROM tabel_users
      WHERE LOWER(email) = LOWER($1)
      LIMIT 1
      `,
      [email],
    );

    if (users.rows.length === 0) {
      return res.status(404).json({
        success: false,
        message: "Akun tidak ditemukan!",
      });
    }

    const user = users.rows[0];

    const isPasswordValid = await bcrypt.compare(password, user.password);

    if (!isPasswordValid) {
      return res.status(401).json({
        success: false,
        message: "Password salah!",
      });
    }

    if (!process.env.JWT_SECRET) {
      console.error("JWT_SECRET belum dikonfigurasi pada file .env.");

      return res.status(500).json({
        success: false,
        message: "Konfigurasi autentikasi server belum tersedia.",
      });
    }

    const token = jwt.sign(
      {
        id_user: user.id_user,
        email: user.email,
      },
      process.env.JWT_SECRET,
      {
        expiresIn: "7d",
      },
    );

    return res.status(200).json({
      success: true,
      message: "Login berhasil!",
      token,
      user: {
        id_user: user.id_user,
        nama: user.nama,
        email: user.email,
      },
    });
  } catch (error) {
    console.error("Login error:", {
      message: error.message,
      code: error.code,
      detail: error.detail,
    });

    return res.status(500).json({
      success: false,
      message: "Terjadi kesalahan pada server saat login.",
    });
  }
});

// ==========================================
// MIDDLEWARE VERIFIKASI JWT
// ==========================================
const verifyToken = (req, res, next) => {
  const authorizationHeader = req.headers.authorization;

  if (!authorizationHeader) {
    return res.status(403).json({
      success: false,
      message: "Akses ditolak! Token tidak tersedia.",
    });
  }

  const tokenParts = authorizationHeader.trim().split(/\s+/);

  const token =
    tokenParts.length === 2 && tokenParts[0].toLowerCase() === "bearer"
      ? tokenParts[1]
      : authorizationHeader.trim();

  if (!token) {
    return res.status(403).json({
      success: false,
      message: "Akses ditolak! Token tidak tersedia.",
    });
  }

  try {
    if (!process.env.JWT_SECRET) {
      return res.status(500).json({
        success: false,
        message: "Konfigurasi autentikasi server belum tersedia.",
      });
    }

    const decoded = jwt.verify(token, process.env.JWT_SECRET);

    req.user = decoded;
    next();
  } catch (error) {
    return res.status(401).json({
      success: false,
      message: "Token tidak valid atau sudah kadaluarsa!",
    });
  }
};

// ==========================================
// ENDPOINT MAPBOX DIRECTIONS
// ==========================================
app.post("/api/maps/get-route", verifyToken, async (req, res) => {
  const { origin, destination } = req.body;

  const isValidCoordinate = (point) => {
    if (!point || typeof point !== "object") {
      return false;
    }

    const latitude = Number(point.latitude);
    const longitude = Number(point.longitude);

    return (
      Number.isFinite(latitude) &&
      Number.isFinite(longitude) &&
      latitude >= -90 &&
      latitude <= 90 &&
      longitude >= -180 &&
      longitude <= 180
    );
  };

  if (!isValidCoordinate(origin) || !isValidCoordinate(destination)) {
    return res.status(400).json({
      success: false,
      message: "Koordinat origin dan destination tidak valid.",
      expected_format: {
        origin: {
          latitude: -6.2,
          longitude: 106.8166,
        },
        destination: {
          latitude: -6.21,
          longitude: 106.8266,
        },
      },
    });
  }

  const mapboxToken = process.env.MAPBOX_ACCESS_TOKEN?.trim();

  if (!mapboxToken) {
    return res.status(500).json({
      success: false,
      message:
        "MAPBOX_ACCESS_TOKEN belum dikonfigurasi pada file .env backend.",
    });
  }

  const originLatitude = Number(origin.latitude);

  const originLongitude = Number(origin.longitude);

  const destinationLatitude = Number(destination.latitude);

  const destinationLongitude = Number(destination.longitude);

  const coordinates = [
    `${originLongitude},${originLatitude}`,
    `${destinationLongitude},${destinationLatitude}`,
  ].join(";");

  const mapboxUrl =
    `https://api.mapbox.com/directions/v5/` + `mapbox/walking/${coordinates}`;

  const startedAt = Date.now();

  try {
    console.log("Mapbox Directions request:", {
      origin: {
        latitude: originLatitude,
        longitude: originLongitude,
      },
      destination: {
        latitude: destinationLatitude,
        longitude: destinationLongitude,
      },
    });

    const response = await axios.get(mapboxUrl, {
      params: {
        access_token: mapboxToken,
        alternatives: false,
        geometries: "geojson",

        // Mengurangi jumlah koordinat untuk rute jauh.
        overview: "simplified",

        // Belum memerlukan instruksi belokan.
        steps: false,

        language: "id",
      },

      // Lebih panjang agar rute antarkota tidak cepat dibatalkan.
      timeout: MAPBOX_TIMEOUT_MS,
    });

    const data = response.data;

    if (
      data?.code !== "Ok" ||
      !Array.isArray(data?.routes) ||
      data.routes.length === 0
    ) {
      return res.status(404).json({
        success: false,
        message: data?.message || "Rute lari tidak ditemukan.",
        mapbox_code: data?.code || "Unknown",
      });
    }

    const route = data.routes[0];

    const distanceMeters = Number(route.distance) || 0;

    const durationSeconds = Number(route.duration) || 0;

    const geometry = route.geometry ?? {
      type: "LineString",
      coordinates: [],
    };

    const routeCoordinates = Array.isArray(geometry?.coordinates)
      ? geometry.coordinates
      : [];

    const elapsedMs = Date.now() - startedAt;

    console.log("Mapbox Directions success:", {
      waktu_ms: elapsedMs,
      jarak_km: Number((distanceMeters / 1000).toFixed(2)),
      durasi_menit: Number((durationSeconds / 60).toFixed(1)),
      total_titik: routeCoordinates.length,
    });

    return res.status(200).json({
      success: true,
      message: "Rute lari berhasil ditemukan!",
      profile: "walking",

      distance_meters: Math.round(distanceMeters),

      distance_km: Number((distanceMeters / 1000).toFixed(2)),

      duration_seconds: Math.round(durationSeconds),

      duration_minutes: Number((durationSeconds / 60).toFixed(1)),

      geometry,
      coordinates: routeCoordinates,

      waypoints: Array.isArray(data.waypoints) ? data.waypoints : [],

      legs: Array.isArray(route.legs) ? route.legs : [],
    });
  } catch (error) {
    const status = error.response?.status;

    const mapboxMessage = error.response?.data?.message;

    const isTimeout =
      error.code === "ECONNABORTED" ||
      error.code === "ETIMEDOUT" ||
      error.message?.toLowerCase().includes("timeout");

    const elapsedMs = Date.now() - startedAt;

    console.error("Mapbox Directions error:", {
      status,
      code: error.code,
      timeout: isTimeout,
      waktu_ms: elapsedMs,
      message: mapboxMessage || error.message,
    });

    if (isTimeout) {
      return res.status(504).json({
        success: false,
        message:
          "Mapbox terlalu lama merespons rute tersebut. Silakan coba kembali.",
      });
    }

    if (status === 401) {
      return res.status(401).json({
        success: false,
        message: "Token Mapbox tidak valid atau tidak aktif.",
      });
    }

    if (status === 403) {
      return res.status(403).json({
        success: false,
        message:
          "Token Mapbox tidak memiliki izin untuk mengakses Directions API.",
      });
    }

    if (status === 422) {
      return res.status(422).json({
        success: false,
        message:
          mapboxMessage ||
          "Mapbox tidak dapat membuat rute dari kedua lokasi tersebut.",
      });
    }

    return res
      .status(status && status >= 400 && status < 500 ? status : 502)
      .json({
        success: false,
        message:
          mapboxMessage ||
          "Terjadi kesalahan saat menghubungi Mapbox Directions API.",
      });
  }
});

// ==========================================
// ENDPOINT SIMPAN RUTE FAVORIT
// ==========================================
app.post("/api/routes", verifyToken, async (req, res) => {
  const {
    nama_lokasi_start,
    nama_lokasi_finish,
    koordinat_jalur,
    total_jarak_km,
  } = req.body;

  const idUser = Number(req.user.id_user);

  const distanceKm = Number(total_jarak_km);

  if (!Number.isInteger(idUser) || idUser <= 0) {
    return res.status(401).json({
      success: false,
      message: "Identitas pengguna tidak valid.",
    });
  }

  if (
    typeof nama_lokasi_start !== "string" ||
    nama_lokasi_start.trim() === ""
  ) {
    return res.status(400).json({
      success: false,
      message: "Nama lokasi awal wajib diisi.",
    });
  }

  if (
    typeof nama_lokasi_finish !== "string" ||
    nama_lokasi_finish.trim() === ""
  ) {
    return res.status(400).json({
      success: false,
      message: "Nama lokasi tujuan wajib diisi.",
    });
  }

  if (!Array.isArray(koordinat_jalur) || koordinat_jalur.length < 2) {
    return res.status(400).json({
      success: false,
      message: "Koordinat jalur tidak valid.",
    });
  }

  if (!Number.isFinite(distanceKm) || distanceKm <= 0) {
    return res.status(400).json({
      success: false,
      message: "Total jarak rute tidak valid.",
    });
  }

  const invalidCoordinate = koordinat_jalur.find((point) => {
    if (!point || typeof point !== "object") {
      return true;
    }

    const latitude = Number(point.latitude);

    const longitude = Number(point.longitude);

    return !(
      Number.isFinite(latitude) &&
      Number.isFinite(longitude) &&
      latitude >= -90 &&
      latitude <= 90 &&
      longitude >= -180 &&
      longitude <= 180
    );
  });

  if (invalidCoordinate) {
    return res.status(400).json({
      success: false,
      message: "Terdapat titik koordinat jalur yang tidak valid.",
    });
  }

  try {
    const normalizedCoordinates = koordinat_jalur.map((point) => ({
      latitude: Number(point.latitude),
      longitude: Number(point.longitude),
    }));

    const coordinatesJson = JSON.stringify(normalizedCoordinates);

    const payloadSizeKb = Buffer.byteLength(coordinatesJson, "utf8") / 1024;

    console.log("Save route payload:", {
      id_user: idUser,
      tujuan: nama_lokasi_finish,
      total_titik: normalizedCoordinates.length,
      ukuran_kb: Number(payloadSizeKb.toFixed(2)),
      jarak_km: distanceKm,
    });

    const result = await db.query(
      `
          INSERT INTO tabel_routes (
            id_user,
            nama_lokasi_start,
            nama_lokasi_finish,
            koordinat_jalur,
            total_jarak_km
          )
          VALUES (
            $1,
            $2,
            $3,
            $4::jsonb,
            $5
          )
          RETURNING id_rute
          `,
      [
        idUser,
        nama_lokasi_start.trim(),
        nama_lokasi_finish.trim(),
        coordinatesJson,
        distanceKm,
      ],
    );

    return res.status(201).json({
      success: true,
      message: "Rute lari berhasil disimpan!",
      id_rute: result.rows[0].id_rute,
    });
  } catch (error) {
    console.error("Save route database error:", {
      message: error.message,
      code: error.code,
      detail: error.detail,
      constraint: error.constraint,
      column: error.column,
    });

    return res.status(500).json({
      success: false,
      message: "Gagal menyimpan rute lari.",
    });
  }
});

// ==========================================
// ENDPOINT AMBIL RUTE FAVORIT
// ==========================================
app.get("/api/routes", verifyToken, async (req, res) => {
  const idUser = Number(req.user.id_user);

  if (!Number.isInteger(idUser) || idUser <= 0) {
    return res.status(401).json({
      success: false,
      message: "Identitas pengguna tidak valid.",
    });
  }

  try {
    const result = await db.query(
      `
          SELECT
            id_rute,
            id_user,
            nama_lokasi_start,
            nama_lokasi_finish,
            koordinat_jalur,
            total_jarak_km
          FROM tabel_routes
          WHERE id_user = $1
          ORDER BY id_rute DESC
          `,
      [idUser],
    );

    console.log("GET /api/routes:", {
      id_user: idUser,
      total_rute: result.rows.length,
    });

    return res.status(200).json({
      success: true,
      message: "Berhasil mengambil rute favorit.",
      data: result.rows,
    });
  } catch (error) {
    console.error("Get routes database error:", {
      message: error.message,
      code: error.code,
      detail: error.detail,
      constraint: error.constraint,
      column: error.column,
    });

    return res.status(500).json({
      success: false,
      message: "Gagal mengambil rute favorit.",
    });
  }
});

// ==========================================
// ENDPOINT JURNAL LARI
// ==========================================

// Menyimpan riwayat lari baru.
app.post("/api/logs", verifyToken, async (req, res) => {
  const { id_rute, durasi_menit, catatan_kondisi, tanggal_latihan } = req.body;

  const idUser = Number(req.user.id_user);

  const routeId = Number(id_rute);

  const durationMinutes = Number(durasi_menit);

  if (!Number.isInteger(idUser) || idUser <= 0) {
    return res.status(401).json({
      success: false,
      message: "Identitas pengguna tidak valid.",
    });
  }

  if (!Number.isInteger(routeId) || routeId <= 0) {
    return res.status(400).json({
      success: false,
      message: "ID rute tidak valid.",
    });
  }

  if (!Number.isFinite(durationMinutes) || durationMinutes <= 0) {
    return res.status(400).json({
      success: false,
      message: "Durasi lari tidak valid.",
    });
  }

  if (!tanggal_latihan) {
    return res.status(400).json({
      success: false,
      message: "Tanggal latihan wajib diisi.",
    });
  }

  try {
    const ownedRoute = await db.query(
      `
          SELECT id_rute
          FROM tabel_routes
          WHERE id_rute = $1
            AND id_user = $2
          LIMIT 1
          `,
      [routeId, idUser],
    );

    if (ownedRoute.rows.length === 0) {
      return res.status(404).json({
        success: false,
        message: "Rute tidak ditemukan atau bukan milik pengguna.",
      });
    }

    const result = await db.query(
      `
          INSERT INTO tabel_run_logs (
            id_user,
            id_rute,
            durasi_menit,
            catatan_kondisi,
            tanggal_latihan
          )
          VALUES (
            $1,
            $2,
            $3,
            $4,
            $5
          )
          RETURNING id_log
          `,
      [
        idUser,
        routeId,
        durationMinutes,
        catatan_kondisi ?? null,
        tanggal_latihan,
      ],
    );

    return res.status(201).json({
      success: true,
      message: "Jurnal lari berhasil dicatat!",
      id_log: result.rows[0].id_log,
    });
  } catch (error) {
    console.error("Save run log error:", {
      message: error.message,
      code: error.code,
      detail: error.detail,
    });

    return res.status(500).json({
      success: false,
      message: "Gagal menyimpan jurnal lari.",
    });
  }
});

// Mengambil daftar riwayat lari.
app.get("/api/logs", verifyToken, async (req, res) => {
  const idUser = Number(req.user.id_user);

  if (!Number.isInteger(idUser) || idUser <= 0) {
    return res.status(401).json({
      success: false,
      message: "Identitas pengguna tidak valid.",
    });
  }

  try {
    const logs = await db.query(
      `
          SELECT
            l.id_log,
            l.id_rute,
            l.durasi_menit,
            l.catatan_kondisi,
            l.tanggal_latihan,
            r.nama_lokasi_start,
            r.nama_lokasi_finish,
            r.total_jarak_km
          FROM tabel_run_logs l
          JOIN tabel_routes r
            ON l.id_rute = r.id_rute
          WHERE l.id_user = $1
          ORDER BY
            l.tanggal_latihan DESC,
            l.id_log DESC
          `,
      [idUser],
    );

    const summary = await db.query(
      `
          SELECT
            COUNT(l.id_log)
              AS total_sesi,
            COALESCE(
              SUM(r.total_jarak_km),
              0
            ) AS total_jarak
          FROM tabel_run_logs l
          JOIN tabel_routes r
            ON l.id_rute = r.id_rute
          WHERE l.id_user = $1
          `,
      [idUser],
    );

    return res.status(200).json({
      success: true,
      message: "Berhasil mengambil riwayat lari.",
      data: logs.rows,
      summary: {
        total_sesi: Number.parseInt(summary.rows[0].total_sesi, 10) || 0,

        total_jarak_km: Number.parseFloat(summary.rows[0].total_jarak) || 0,
      },
    });
  } catch (error) {
    console.error("Get run logs error:", {
      message: error.message,
      code: error.code,
      detail: error.detail,
    });

    return res.status(500).json({
      success: false,
      message: "Gagal mengambil riwayat lari.",
    });
  }
});

// ==========================================
// ENDPOINT EVENT LARI
// ==========================================

// Menambahkan event.
app.post("/api/events", verifyToken, async (req, res) => {
  const {
    nama_event,
    tanggal_event,
    lokasi_event,
    biaya_pendaftaran,
    status_persiapan,
  } = req.body;

  const idUser = Number(req.user.id_user);

  if (!Number.isInteger(idUser) || idUser <= 0) {
    return res.status(401).json({
      success: false,
      message: "Identitas pengguna tidak valid.",
    });
  }

  if (typeof nama_event !== "string" || nama_event.trim() === "") {
    return res.status(400).json({
      success: false,
      message: "Nama event wajib diisi.",
    });
  }

  if (!tanggal_event) {
    return res.status(400).json({
      success: false,
      message: "Tanggal event wajib diisi.",
    });
  }

  try {
    const result = await db.query(
      `
          INSERT INTO tabel_events (
            id_user,
            nama_event,
            tanggal_event,
            lokasi_event,
            biaya_pendaftaran,
            status_persiapan
          )
          VALUES (
            $1,
            $2,
            $3,
            $4,
            $5,
            $6
          )
          RETURNING id_event
          `,
      [
        idUser,
        nama_event.trim(),
        tanggal_event,
        lokasi_event ?? null,
        biaya_pendaftaran ?? 0,
        status_persiapan || "Wishlist",
      ],
    );

    return res.status(201).json({
      success: true,
      message: "Event lari berhasil ditambahkan!",
      id_event: result.rows[0].id_event,
    });
  } catch (error) {
    console.error("Save event error:", {
      message: error.message,
      code: error.code,
      detail: error.detail,
    });

    return res.status(500).json({
      success: false,
      message: "Gagal menyimpan event lari.",
    });
  }
});

// Mengambil daftar event.
app.get("/api/events", verifyToken, async (req, res) => {
  const idUser = Number(req.user.id_user);

  if (!Number.isInteger(idUser) || idUser <= 0) {
    return res.status(401).json({
      success: false,
      message: "Identitas pengguna tidak valid.",
    });
  }

  try {
    const events = await db.query(
      `
          SELECT *
          FROM tabel_events
          WHERE id_user = $1
          ORDER BY tanggal_event ASC
          `,
      [idUser],
    );

    return res.status(200).json({
      success: true,
      message: "Berhasil mengambil daftar event.",
      data: events.rows,
    });
  } catch (error) {
    console.error("Get events error:", {
      message: error.message,
      code: error.code,
      detail: error.detail,
    });

    return res.status(500).json({
      success: false,
      message: "Gagal mengambil daftar event.",
    });
  }
});

// ==========================================
// ENDPOINT STATISTIK MINGGU INI
// ==========================================
app.get("/api/stats/weekly", verifyToken, async (req, res) => {
  const idUser = Number(req.user.id_user);

  if (!Number.isInteger(idUser) || idUser <= 0) {
    return res.status(401).json({
      success: false,
      message: "Identitas pengguna tidak valid.",
    });
  }

  try {
    const result = await db.query(
      `
          SELECT
            COALESCE(
              SUM(r.total_jarak_km),
              0
            ) AS total_jarak,

            COALESCE(
              SUM(l.durasi_menit),
              0
            ) AS total_durasi_menit,

            COUNT(l.id_log)
              AS total_sesi
          FROM tabel_run_logs l
          JOIN tabel_routes r
            ON l.id_rute = r.id_rute
          WHERE l.id_user = $1
            AND l.tanggal_latihan >=
              CURRENT_DATE -
              INTERVAL '7 days'
          `,
      [idUser],
    );

    const row = result.rows[0];

    const totalMinutes = Number.parseInt(row.total_durasi_menit, 10) || 0;

    const hours = Math.floor(totalMinutes / 60);

    const minutes = totalMinutes % 60;

    return res.status(200).json({
      success: true,

      total_jarak_km: Number.parseFloat(row.total_jarak) || 0,

      total_durasi_menit: totalMinutes,

      durasi_label: hours > 0 ? `${hours}j ${minutes}m` : `${minutes}m`,

      total_sesi: Number.parseInt(row.total_sesi, 10) || 0,
    });
  } catch (error) {
    console.error("Weekly stats error:", {
      message: error.message,
      code: error.code,
      detail: error.detail,
    });

    return res.status(500).json({
      success: false,
      message: "Gagal mengambil statistik mingguan.",
    });
  }
});

// ==========================================
// ENDPOINT STATISTIK PROFIL
// ==========================================
app.get("/api/profile/stats", verifyToken, async (req, res) => {
  const idUser = Number(req.user.id_user);

  if (!Number.isInteger(idUser) || idUser <= 0) {
    return res.status(401).json({
      success: false,
      message: "Identitas pengguna tidak valid.",
    });
  }

  try {
    const jarakResult = await db.query(
      `
          SELECT
            COALESCE(
              SUM(r.total_jarak_km),
              0
            ) AS total_jarak
          FROM tabel_run_logs l
          JOIN tabel_routes r
            ON l.id_rute = r.id_rute
          WHERE l.id_user = $1
          `,
      [idUser],
    );

    const sessionResult = await db.query(
      `
          SELECT
            COUNT(*) AS total_sesi
          FROM tabel_run_logs
          WHERE id_user = $1
          `,
      [idUser],
    );

    const eventResult = await db.query(
      `
          SELECT
            COUNT(*) AS total_event
          FROM tabel_events
          WHERE id_user = $1
          `,
      [idUser],
    );

    return res.status(200).json({
      success: true,

      total_jarak_km: Number.parseFloat(jarakResult.rows[0].total_jarak) || 0,

      total_sesi: Number.parseInt(sessionResult.rows[0].total_sesi, 10) || 0,

      total_pencapaian:
        Number.parseInt(eventResult.rows[0].total_event, 10) || 0,
    });
  } catch (error) {
    console.error("Profile stats error:", {
      message: error.message,
      code: error.code,
      detail: error.detail,
    });

    return res.status(500).json({
      success: false,
      message: "Gagal mengambil statistik profil.",
    });
  }
});

// ==========================================
// ENDPOINT PROXY BERITA GNEWS
// ==========================================
const categoryQueries = {
  0: "lari kesehatan olahraga",
  1: "tips lari maraton",
  2: "kesehatan tubuh kebugaran",
  3: "nutrisi olahraga pelari",
  4: "kebugaran fitness gym",
};

app.get("/api/news", async (req, res) => {
  const categoryIndex = req.query.category?.toString() || "0";

  const customQuery = req.query.q?.toString().trim();

  const query =
    customQuery || categoryQueries[categoryIndex] || "lari kesehatan";

  const apiKey = process.env.GNEWS_API_KEY?.trim();

  if (!apiKey) {
    return res.status(500).json({
      success: false,
      message: "GNEWS_API_KEY belum dikonfigurasi.",
    });
  }

  const cacheKey = customQuery || categoryIndex;

  const cached = newsCache.get(cacheKey);

  const now = Date.now();

  if (cached && now - cached.fetchedAt < CACHE_TTL_MS) {
    const ageMinutes = Math.floor((now - cached.fetchedAt) / 60_000);

    console.log(
      `📦 Cache hit [kategori: ${cacheKey}] — umur cache: ${ageMinutes} menit`,
    );

    return res.status(200).json(cached.data);
  }

  try {
    const url = "https://gnews.io/api/v4/search";

    const response = await axios.get(url, {
      params: {
        q: query,
        lang: "id",
        country: "id",
        max: 10,
        sortby: "publishedAt",
        apikey: apiKey,
      },
      timeout: GNEWS_TIMEOUT_MS,
    });

    newsCache.set(cacheKey, {
      data: response.data,
      fetchedAt: now,
    });

    console.log(
      `🌐 GNews fetched [kategori: ${cacheKey}] — disimpan ke cache 30 menit`,
    );

    return res.status(200).json(response.data);
  } catch (error) {
    const status = error.response?.status;

    const message =
      error.response?.data?.errors?.[0] ||
      error.response?.data?.message ||
      error.message;

    console.error("GNews error:", {
      status,
      message,
    });

    if (status === 429 && cached) {
      console.warn("⚠️ Rate limited, mengembalikan cache lama.");

      return res.status(200).json(cached.data);
    }

    return res
      .status(status && status >= 400 && status < 500 ? status : 502)
      .json({
        success: false,
        message:
          status === 429
            ? "Batas request harian GNews tercapai. Coba lagi nanti."
            : message || "Gagal mengambil berita dari GNews.",
      });
  }
});

// ============================================================
// HEALTH CHECK
// ============================================================
app.get("/api/health", (req, res) => {
  res.status(200).json({
    success: true,
    message: "Backend RunNotPace aktif",
    environment: process.env.NODE_ENV || "development",
    timestamp: new Date().toISOString(),
  });
});

// ==========================================
// ENDPOINT TIDAK DITEMUKAN
// ==========================================
app.use((req, res) => {
  return res.status(404).json({
    success: false,
    message: `Endpoint ${req.method} ${req.originalUrl} tidak ditemukan.`,
  });
});

// ==========================================
// GLOBAL ERROR HANDLER
// ==========================================
app.use((error, req, res, next) => {
  if (error?.type === "entity.too.large") {
    console.error("Request body terlalu besar:", {
      method: req.method,
      path: req.originalUrl,
      limit: error.limit,
      length: error.length,
    });

    return res.status(413).json({
      success: false,
      message: "Data koordinat rute terlalu besar untuk disimpan.",
    });
  }

  if (error instanceof SyntaxError && error.status === 400 && "body" in error) {
    return res.status(400).json({
      success: false,
      message: "Format JSON request tidak valid.",
    });
  }

  console.error("Unhandled server error:", {
    message: error.message,
    stack: error.stack,
  });

  return res.status(500).json({
    success: false,
    message: "Terjadi kesalahan internal pada server.",
  });
});

// ==========================================
// MENYALAKAN SERVER
// ==========================================
app.listen(port, () => {
  console.log(`🚀 Server RunNotPace berjalan di http://localhost:${port}`);

  console.log(`🧭 Timeout Mapbox: ${MAPBOX_TIMEOUT_MS / 1000} detik`);

  console.log(`📦 Batas request body: ${REQUEST_BODY_LIMIT}`);
});
