import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../models/user_model.dart';

class ApiService {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static const Duration _requestTimeout = Duration(seconds: 15);

  /// Chrome menggunakan localhost secara default.
  ///
  /// Untuk Android fisik, jalankan Flutter menggunakan:
  ///
  /// flutter run --dart-define=API_BASE_URL=http://IP_LAPTOP:3000/api
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://yuk-run-production.up.railway.app/api',
  );

  // ============================================================
  // DECODE RESPONSE JSON
  // ============================================================
  static Map<String, dynamic> _decodeResponse(String body) {
    if (body.trim().isEmpty) {
      return <String, dynamic>{};
    }

    final decoded = jsonDecode(body);

    if (decoded is Map<String, dynamic>) {
      return decoded;
    }

    return <String, dynamic>{'data': decoded};
  }

  // ============================================================
  // HEADER DENGAN TOKEN JWT
  // ============================================================
  static Future<Map<String, String>> _authHeaders() async {
    final token = await _storage.read(key: 'jwt_token');

    if (token == null || token.trim().isEmpty) {
      throw StateError('Sesi login tidak ditemukan. Silakan login kembali.');
    }

    return <String, String>{
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // ============================================================
  // LOGIN
  // ============================================================
  static Future<Map<String, dynamic>> login(
    String email,
    String password,
  ) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/login'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email.trim(), 'password': password}),
          )
          .timeout(_requestTimeout);

      final data = _decodeResponse(response.body);

      if (response.statusCode == 200) {
        final rawUser = data['user'];

        if (rawUser is! Map<String, dynamic>) {
          return {
            'success': false,
            'message': 'Data pengguna dari server tidak valid.',
          };
        }

        final token = data['token']?.toString();

        if (token == null || token.trim().isEmpty) {
          return {
            'success': false,
            'message': 'Token login dari server tidak tersedia.',
          };
        }

        return {
          'success': true,
          'token': token,
          'user': User.fromJson(rawUser),
        };
      }

      return {
        'success': false,
        'statusCode': response.statusCode,
        'message': data['message']?.toString() ?? 'Login gagal.',
      };
    } on TimeoutException {
      return {'success': false, 'message': 'Koneksi ke server terlalu lama.'};
    } on FormatException {
      return {
        'success': false,
        'message': 'Respons login dari server bukan JSON yang valid.',
      };
    } catch (error) {
      return {'success': false, 'message': 'Koneksi server gagal: $error'};
    }
  }

  // ============================================================
  // MAPBOX DIRECTIONS MELALUI BACKEND
  // ============================================================
  static Future<Map<String, dynamic>> getRoute({
    required LatLng origin,
    required LatLng destination,
  }) async {
    try {
      final headers = await _authHeaders();

      final response = await http
          .post(
            Uri.parse('$baseUrl/maps/get-route'),
            headers: headers,
            body: jsonEncode({
              'origin': {
                'latitude': origin.latitude,
                'longitude': origin.longitude,
              },
              'destination': {
                'latitude': destination.latitude,
                'longitude': destination.longitude,
              },
            }),
          )
          .timeout(_requestTimeout);

      final data = _decodeResponse(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      }

      return {
        'success': false,
        'statusCode': response.statusCode,
        'message':
            data['message']?.toString() ??
            'Gagal mendapatkan rute dari server.',
      };
    } on StateError catch (error) {
      return {'success': false, 'message': error.message};
    } on TimeoutException {
      return {
        'success': false,
        'message': 'Permintaan rute terlalu lama. Silakan coba kembali.',
      };
    } on FormatException {
      return {
        'success': false,
        'message': 'Respons rute dari server bukan JSON yang valid.',
      };
    } catch (error) {
      return {
        'success': false,
        'message': 'Gagal terhubung ke backend: $error',
      };
    }
  }

  // ============================================================
  // MENYIMPAN RUTE FAVORIT KE DATABASE
  // ============================================================
  static Future<Map<String, dynamic>> saveRoute({
    required String startName,
    required String finishName,
    required List<LatLng> routePoints,
    required double distanceKm,
  }) async {
    if (routePoints.length < 2) {
      return {'success': false, 'message': 'Koordinat jalur belum tersedia.'};
    }

    if (finishName.trim().isEmpty) {
      return {'success': false, 'message': 'Nama tujuan belum tersedia.'};
    }

    if (!distanceKm.isFinite || distanceKm <= 0) {
      return {'success': false, 'message': 'Total jarak rute tidak valid.'};
    }

    try {
      final headers = await _authHeaders();

      final coordinates = routePoints
          .map(
            (point) => {
              'latitude': point.latitude,
              'longitude': point.longitude,
            },
          )
          .toList();

      final response = await http
          .post(
            Uri.parse('$baseUrl/routes'),
            headers: headers,
            body: jsonEncode({
              'nama_lokasi_start': startName.trim().isEmpty
                  ? 'Lokasi Saya'
                  : startName.trim(),
              'nama_lokasi_finish': finishName.trim(),
              'koordinat_jalur': coordinates,
              'total_jarak_km': distanceKm,
            }),
          )
          .timeout(_requestTimeout);

      final data = _decodeResponse(response.body);

      if (response.statusCode == 201 || response.statusCode == 200) {
        return {
          'success': true,
          'message': data['message']?.toString() ?? 'Rute berhasil disimpan.',
          'id_rute': data['id_rute'],
        };
      }

      return {
        'success': false,
        'statusCode': response.statusCode,
        'message': data['message']?.toString() ?? 'Rute gagal disimpan.',
      };
    } on StateError catch (error) {
      return {'success': false, 'message': error.message};
    } on TimeoutException {
      return {
        'success': false,
        'message': 'Penyimpanan rute terlalu lama. Silakan coba kembali.',
      };
    } on FormatException {
      return {
        'success': false,
        'message': 'Respons penyimpanan dari server bukan JSON yang valid.',
      };
    } catch (error) {
      return {
        'success': false,
        'message': 'Gagal terhubung ke backend: $error',
      };
    }
  }

  // ============================================================
  // MENGAMBIL RUTE FAVORIT DARI DATABASE
  // ============================================================
  static Future<Map<String, dynamic>> getSavedRoutes() async {
    try {
      final headers = await _authHeaders();

      final response = await http
          .get(Uri.parse('$baseUrl/routes'), headers: headers)
          .timeout(_requestTimeout);

      final data = _decodeResponse(response.body);

      if (response.statusCode == 200) {
        final rawRoutes = data['data'];

        final routes = <Map<String, dynamic>>[];

        if (rawRoutes is List) {
          for (final item in rawRoutes) {
            if (item is Map<String, dynamic>) {
              routes.add(item);
            } else if (item is Map) {
              routes.add(Map<String, dynamic>.from(item));
            }
          }
        }

        return {
          'success': true,
          'message':
              data['message']?.toString() ?? 'Berhasil mengambil rute favorit.',
          'routes': routes,
        };
      }

      return {
        'success': false,
        'statusCode': response.statusCode,
        'message':
            data['message']?.toString() ?? 'Gagal mengambil rute favorit.',
        'routes': <Map<String, dynamic>>[],
      };
    } on StateError catch (error) {
      return {
        'success': false,
        'message': error.message,
        'routes': <Map<String, dynamic>>[],
      };
    } on TimeoutException {
      return {
        'success': false,
        'message': 'Pengambilan rute favorit terlalu lama.',
        'routes': <Map<String, dynamic>>[],
      };
    } on FormatException {
      return {
        'success': false,
        'message': 'Respons rute favorit dari server bukan JSON yang valid.',
        'routes': <Map<String, dynamic>>[],
      };
    } catch (error) {
      return {
        'success': false,
        'message': 'Gagal terhubung ke backend: $error',
        'routes': <Map<String, dynamic>>[],
      };
    }
  }
}
