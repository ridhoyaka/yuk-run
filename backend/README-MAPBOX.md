# RunNotPace Backend — Mapbox Directions

## Konfigurasi

1. Salin `.env.example` menjadi `.env`.
2. Isi `MAPBOX_ACCESS_TOKEN` dengan public token Mapbox Anda (`pk...`).
3. Isi konfigurasi database dan `JWT_SECRET`.
4. Jalankan:

```bash
npm install
node index.js
```

## Endpoint rute

`POST /api/maps/get-route`

Header:

```http
Authorization: Bearer <jwt_token>
Content-Type: application/json
```

Body:

```json
{
  "origin": {
    "latitude": -6.2000,
    "longitude": 106.8166
  },
  "destination": {
    "latitude": -6.2100,
    "longitude": 106.8266
  }
}
```

Backend menggunakan profil `mapbox/walking` dan mengembalikan geometry GeoJSON, daftar koordinat, jarak, durasi, waypoint, dan legs.
