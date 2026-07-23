const express = require('express');
const cors = require('cors');
require('dotenv').config();
const axios = require('axios');
const db = require('./db');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');

const app = express();
const port = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Cek Koneksi Database
async function testDBConnection() {
    try {
        await db.query('SELECT 1');
        console.log('✅ Berhasil terhubung ke database Supabase (PostgreSQL)!');
    } catch (error) {
        console.error('❌ Gagal terhubung ke database:', error.message);
    }
}
testDBConnection();

// Route Dasar
app.get('/', (req, res) => {
    res.json({ message: 'Selamat datang di API RunNotPace!' });
});

// ==========================================
// ENDPOINT REGISTRASI (DAFTAR AKUN BARU)
// ==========================================
app.post('/api/auth/register', async (req, res) => {
    const { nama, email, password } = req.body;
    try {
        // Cek apakah email sudah pernah didaftarkan
        const existingUser = await db.query(
            'SELECT * FROM tabel_users WHERE email = $1',
            [email]
        );
        if (existingUser.rows.length > 0) {
            return res.status(400).json({ message: 'Email sudah terdaftar!' });
        }

        // Enkripsi password sebelum disimpan ke database
        const hashedPassword = await bcrypt.hash(password, 10);

        // Masukkan data pengguna baru — RETURNING untuk mendapatkan id hasil insert
        const result = await db.query(
            'INSERT INTO tabel_users (nama, email, password) VALUES ($1, $2, $3) RETURNING id_user',
            [nama, email, hashedPassword]
        );

        res.status(201).json({
            message: 'Registrasi berhasil!',
            id_user: result.rows[0].id_user,
        });
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Terjadi kesalahan pada server saat registrasi.' });
    }
});

// ==========================================
// ENDPOINT LOGIN (MASUK APLIKASI)
// ==========================================
app.post('/api/auth/login', async (req, res) => {
    const { email, password } = req.body;
    try {
        // Cari pengguna berdasarkan email di database
        const users = await db.query(
            'SELECT * FROM tabel_users WHERE email = $1',
            [email]
        );
        if (users.rows.length === 0) {
            return res.status(404).json({ message: 'Akun tidak ditemukan!' });
        }

        const user = users.rows[0];

        // Cocokkan password yang diinput dengan password terenkripsi di database
        const isPasswordValid = await bcrypt.compare(password, user.password);
        if (!isPasswordValid) {
            return res.status(401).json({ message: 'Password salah!' });
        }

        // Buat Token JWT yang berlaku selama 7 hari
        const token = jwt.sign(
            { id_user: user.id_user, email: user.email },
            process.env.JWT_SECRET,
            { expiresIn: '7d' }
        );

        res.json({
            message: 'Login berhasil!',
            token: token,
            user: { id_user: user.id_user, nama: user.nama, email: user.email },
        });
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Terjadi kesalahan pada server saat login.' });
    }
});

// ==========================================
// MIDDLEWARE: VERIFIKASI TOKEN JWT
// ==========================================
const verifyToken = (req, res, next) => {
    const token = req.headers['authorization'];

    if (!token) {
        return res.status(403).json({ message: 'Akses ditolak! Token tidak tersedia.' });
    }

    try {
        const tokenBody = token.split(' ')[1] || token;
        const decoded = jwt.verify(tokenBody, process.env.JWT_SECRET);
        req.user = decoded;
        next();
    } catch (error) {
        return res.status(401).json({ message: 'Token tidak valid atau sudah kadaluarsa!' });
    }
};

// ==========================================
// ENDPOINT CEK RUTE LARI (MAPBOX DIRECTIONS)
// ==========================================
app.post('/api/maps/get-route', verifyToken, async (req, res) => {
    const { origin, destination } = req.body;

    const isValidCoordinate = (point) => {
        if (!point || typeof point !== 'object') return false;
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
            message: 'Koordinat origin dan destination tidak valid.',
            expected_format: {
                origin: { latitude: -6.2000, longitude: 106.8166 },
                destination: { latitude: -6.2100, longitude: 106.8266 },
            },
        });
    }

    const mapboxToken = process.env.MAPBOX_ACCESS_TOKEN;
    if (!mapboxToken) {
        return res.status(500).json({
            message: 'MAPBOX_ACCESS_TOKEN belum dikonfigurasi pada file .env backend.',
        });
    }

    try {
        const coordinates = [
            `${Number(origin.longitude)},${Number(origin.latitude)}`,
            `${Number(destination.longitude)},${Number(destination.latitude)}`,
        ].join(';');

        const url = `https://api.mapbox.com/directions/v5/mapbox/walking/${coordinates}`;

        const response = await axios.get(url, {
            params: {
                access_token: mapboxToken,
                alternatives: false,
                geometries: 'geojson',
                overview: 'full',
                steps: true,
                language: 'id',
            },
            timeout: 10000,
        });

        const data = response.data;

        if (data.code !== 'Ok' || !Array.isArray(data.routes) || data.routes.length === 0) {
            return res.status(404).json({
                message: data.message || 'Rute lari tidak ditemukan.',
                mapbox_code: data.code || 'Unknown',
            });
        }

        const route = data.routes[0];
        const distanceMeters = Number(route.distance || 0);
        const durationSeconds = Number(route.duration || 0);
        const geometry = route.geometry;

        return res.json({
            message: 'Rute lari berhasil ditemukan!',
            profile: 'walking',
            distance_meters: Math.round(distanceMeters),
            distance_km: Number((distanceMeters / 1000).toFixed(2)),
            duration_seconds: Math.round(durationSeconds),
            duration_minutes: Number((durationSeconds / 60).toFixed(1)),
            geometry: geometry,
            coordinates: geometry?.coordinates || [],
            waypoints: data.waypoints || [],
            legs: route.legs || [],
        });
    } catch (error) {
        const status = error.response?.status;
        const mapboxMessage = error.response?.data?.message;

        console.error('Mapbox Directions error:', {
            status,
            message: mapboxMessage || error.message,
        });

        return res.status(status && status < 500 ? status : 502).json({
            message: mapboxMessage || 'Terjadi kesalahan saat menghubungi Mapbox Directions API.',
        });
    }
});

// ==========================================
// ENDPOINT SIMPAN RUTE FAVORIT
// ==========================================
app.post('/api/routes', verifyToken, async (req, res) => {
    const { nama_lokasi_start, nama_lokasi_finish, koordinat_jalur, total_jarak_km } = req.body;
    const id_user = req.user.id_user;

    try {
        const result = await db.query(
            `INSERT INTO tabel_routes (id_user, nama_lokasi_start, nama_lokasi_finish, koordinat_jalur, total_jarak_km)
             VALUES ($1, $2, $3, $4, $5) RETURNING id_rute`,
            [id_user, nama_lokasi_start, nama_lokasi_finish, koordinat_jalur, total_jarak_km]
        );
        res.status(201).json({
            message: 'Rute lari berhasil disimpan!',
            id_rute: result.rows[0].id_rute,
        });
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Gagal menyimpan rute lari.' });
    }
});

// ==========================================
// ENDPOINT JURNAL LARI (RUN LOGS)
// ==========================================

// A. Menyimpan riwayat lari baru
app.post('/api/logs', verifyToken, async (req, res) => {
    const { id_rute, durasi_menit, catatan_kondisi, tanggal_latihan } = req.body;
    const id_user = req.user.id_user;

    try {
        const result = await db.query(
            `INSERT INTO tabel_run_logs (id_user, id_rute, durasi_menit, catatan_kondisi, tanggal_latihan)
             VALUES ($1, $2, $3, $4, $5) RETURNING id_log`,
            [id_user, id_rute, durasi_menit, catatan_kondisi, tanggal_latihan]
        );
        res.status(201).json({
            message: 'Jurnal lari berhasil dicatat!',
            id_log: result.rows[0].id_log,
        });
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Gagal menyimpan jurnal lari.' });
    }
});

// B. Melihat daftar riwayat lari pengguna
app.get('/api/logs', verifyToken, async (req, res) => {
    const id_user = req.user.id_user;

    try {
        const logs = await db.query(
            `SELECT l.*, r.nama_lokasi_start, r.nama_lokasi_finish, r.total_jarak_km
             FROM tabel_run_logs l
             JOIN tabel_routes r ON l.id_rute = r.id_rute
             WHERE l.id_user = $1
             ORDER BY l.tanggal_latihan DESC`,
            [id_user]
        );
        res.json({ message: 'Berhasil mengambil riwayat lari', data: logs.rows });
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Gagal mengambil riwayat lari.' });
    }
});

// ==========================================
// ENDPOINT EVENT LARI (EVENT PLANNER)
// ==========================================

// A. Menambahkan rencana event lari
app.post('/api/events', verifyToken, async (req, res) => {
    const { nama_event, tanggal_event, lokasi_event, biaya_pendaftaran, status_persiapan } = req.body;
    const id_user = req.user.id_user;

    try {
        const result = await db.query(
            `INSERT INTO tabel_events (id_user, nama_event, tanggal_event, lokasi_event, biaya_pendaftaran, status_persiapan)
             VALUES ($1, $2, $3, $4, $5, $6) RETURNING id_event`,
            [id_user, nama_event, tanggal_event, lokasi_event, biaya_pendaftaran, status_persiapan || 'Wishlist']
        );
        res.status(201).json({
            message: 'Event lari berhasil ditambahkan!',
            id_event: result.rows[0].id_event,
        });
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Gagal menyimpan event lari.' });
    }
});

// B. Melihat daftar event
app.get('/api/events', verifyToken, async (req, res) => {
    const id_user = req.user.id_user;

    try {
        const events = await db.query(
            'SELECT * FROM tabel_events WHERE id_user = $1 ORDER BY tanggal_event ASC',
            [id_user]
        );
        res.json({ message: 'Berhasil mengambil daftar event', data: events.rows });
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Gagal mengambil daftar event.' });
    }
});

// Menyalakan Server
app.listen(port, () => {
    console.log(`🚀 Server RunNotPace berjalan di http://localhost:${port}`);
});
