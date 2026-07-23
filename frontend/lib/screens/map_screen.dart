import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../services/api_service.dart';
import '../widgets/hover_button.dart';

class MapScreen extends StatefulWidget {
  final Map<String, dynamic>? initialSavedRoute;

  const MapScreen({super.key, this.initialSavedRoute});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _destinationController = TextEditingController();

  final FocusNode _searchFocusNode = FocusNode();

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  // ============================================================
  // KONFIGURASI MAPBOX DAN GPS
  // ============================================================

  static const String mapboxToken = String.fromEnvironment(
    'MAPBOX_ACCESS_TOKEN',
    defaultValue: '',
  );

  final MapController _mapController = MapController();

  LatLng _currentLocation = const LatLng(-6.1751, 106.8272);

  StreamSubscription<Position>? _positionStream;

  // ============================================================
  // KONFIGURASI PENCARIAN
  // ============================================================

  Timer? _debounce;

  List<dynamic> _searchResults = [];

  LatLng? _destinationLocation;

  // Titik awal yang berasal dari rute favorit tersimpan.
  LatLng? _savedRouteStartLocation;

  // Menandai bahwa jalur yang sedang ditampilkan berasal dari database.
  bool _isViewingSavedRoute = false;

  // ============================================================
  // DATA HASIL DIRECTIONS DARI BACKEND
  // ============================================================

  List<LatLng> _routePoints = [];

  bool _isLoadingRoute = false;

  double? _routeDistanceKm;

  double? _routeDurationMinutes;

  String? _routeError;

  bool _isSavingRoute = false;

  int? _savedRouteId;

  // ============================================================
  // INIT STATE
  // ============================================================

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);

    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
        );

    _animController.forward();

    _initializeScreen();
  }

  // ============================================================
  // INISIALISASI PETA, GPS, DAN RUTE FAVORIT
  // ============================================================

  void _initializeScreen() {
    // GPS tetap berjalan untuk memperbarui posisi pengguna.
    unawaited(_initializeLocation());

    final savedRoute = widget.initialSavedRoute;

    if (savedRoute == null) return;

    // Tunggu FlutterMap terpasang sebelum menyesuaikan kamera.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      _loadSavedRoute(Map<String, dynamic>.from(savedRoute));
    });
  }

  // ============================================================
  // MENGAMBIL LOKASI GPS PENGGUNA
  // ============================================================

  Future<void> _initializeLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      _showMessage(
        'GPS belum aktif. Aktifkan lokasi perangkat terlebih dahulu.',
        isError: true,
      );

      return;
    }

    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();

      if (permission == LocationPermission.denied) {
        _showMessage('Izin lokasi ditolak.', isError: true);

        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showMessage(
        'Izin lokasi ditolak permanen. Aktifkan melalui pengaturan aplikasi.',
        isError: true,
      );

      return;
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (!mounted) return;

      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
      });

      if (widget.initialSavedRoute == null) {
        _mapController.move(_currentLocation, 16);
      }

      const locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      );

      _positionStream =
          Geolocator.getPositionStream(
            locationSettings: locationSettings,
          ).listen(
            (newPosition) {
              if (!mounted) return;

              setState(() {
                _currentLocation = LatLng(
                  newPosition.latitude,
                  newPosition.longitude,
                );
              });
            },
            onError: (Object error) {
              debugPrint('GPS stream error: $error');
            },
          );
    } catch (error) {
      debugPrint('Gagal mengambil lokasi: $error');

      _showMessage('Lokasi perangkat gagal dibaca.', isError: true);
    }
  }

  // ============================================================
  // PENCARIAN TUJUAN MELALUI MAPBOX GEOCODING
  // ============================================================

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) {
      _debounce!.cancel();
    }

    final cleanedQuery = query.trim();

    if (cleanedQuery.isEmpty) {
      setState(() {
        _searchResults = [];
      });

      return;
    }

    _debounce = Timer(const Duration(milliseconds: 250), () async {
      final url = Uri.https(
        'api.mapbox.com',
        '/geocoding/v5/mapbox.places/$cleanedQuery.json',
        {
          'access_token': mapboxToken,
          'country': 'id',
          'proximity':
              '${_currentLocation.longitude},'
              '${_currentLocation.latitude}',
          'limit': '5',
        },
      );

      try {
        final response = await http
            .get(url)
            .timeout(const Duration(seconds: 10));

        if (!mounted) return;

        if (response.statusCode == 200) {
          final decoded = jsonDecode(response.body);

          setState(() {
            if (decoded is Map<String, dynamic> &&
                decoded['features'] is List) {
              _searchResults = List<dynamic>.from(decoded['features'] as List);
            } else {
              _searchResults = [];
            }
          });
        } else {
          setState(() {
            _searchResults = [];
          });

          debugPrint(
            'Mapbox Geocoding gagal: '
            '${response.statusCode} '
            '${response.body}',
          );
        }
      } on TimeoutException {
        if (!mounted) return;

        setState(() {
          _searchResults = [];
        });

        _showMessage('Pencarian lokasi terlalu lama.', isError: true);
      } catch (error) {
        if (!mounted) return;

        setState(() {
          _searchResults = [];
        });

        debugPrint('Error mencari lokasi: $error');
      }
    });
  }

  // ============================================================
  // MEMILIH TUJUAN DARI HASIL PENCARIAN
  // ============================================================

  void _selectDestination(dynamic feature) {
    final geometry = feature is Map<String, dynamic>
        ? feature['geometry']
        : null;

    final coordinates = geometry is Map<String, dynamic>
        ? geometry['coordinates']
        : null;

    if (coordinates is! List || coordinates.length < 2) {
      _showMessage('Koordinat tujuan tidak valid.', isError: true);

      return;
    }

    final longitude = double.tryParse(coordinates[0].toString());

    final latitude = double.tryParse(coordinates[1].toString());

    if (latitude == null || longitude == null) {
      _showMessage('Koordinat tujuan tidak dapat dibaca.', isError: true);

      return;
    }

    final placeName = feature is Map<String, dynamic>
        ? feature['place_name']?.toString() ?? 'Tujuan'
        : 'Tujuan';

    setState(() {
      _destinationLocation = LatLng(latitude, longitude);

      _destinationController.text = placeName.split(',').first;

      _searchResults = [];

      // Hapus data rute sebelumnya.
      _routePoints = [];

      _routeDistanceKm = null;

      _routeDurationMinutes = null;

      _routeError = null;

      _isSavingRoute = false;

      _savedRouteId = null;

      _savedRouteStartLocation = null;

      _isViewingSavedRoute = false;
    });

    _searchFocusNode.unfocus();

    _mapController.move(_destinationLocation!, 15);
  }

  // ============================================================
  // MEMUAT RUTE FAVORIT DARI DATABASE
  // ============================================================

  void _loadSavedRoute(Map<String, dynamic> route) {
    try {
      dynamic rawCoordinates = route['koordinat_jalur'];

      // Antisipasi jika PostgreSQL/backend mengirim JSON sebagai String.
      if (rawCoordinates is String) {
        rawCoordinates = jsonDecode(rawCoordinates);
      }

      if (rawCoordinates is! List) {
        throw const FormatException('Koordinat rute tersimpan tidak valid.');
      }

      final routePoints = <LatLng>[];

      for (final rawPoint in rawCoordinates) {
        double? latitude;
        double? longitude;

        // Format yang disimpan aplikasi:
        // {"latitude": -7.0, "longitude": 110.0}
        if (rawPoint is Map) {
          latitude = double.tryParse(rawPoint['latitude']?.toString() ?? '');

          longitude = double.tryParse(rawPoint['longitude']?.toString() ?? '');
        } else if (rawPoint is List && rawPoint.length >= 2) {
          // Antisipasi format Mapbox: [longitude, latitude].
          longitude = double.tryParse(rawPoint[0].toString());
          latitude = double.tryParse(rawPoint[1].toString());
        }

        if (latitude == null || longitude == null) {
          continue;
        }

        if (latitude < -90 ||
            latitude > 90 ||
            longitude < -180 ||
            longitude > 180) {
          continue;
        }

        routePoints.add(LatLng(latitude, longitude));
      }

      if (routePoints.length < 2) {
        throw const FormatException('Titik rute tersimpan tidak mencukupi.');
      }

      final finishName = route['nama_lokasi_finish']?.toString().trim();

      final distanceKm = double.tryParse(
        route['total_jarak_km']?.toString() ?? '',
      );

      final rawRouteId = route['id_rute'];
      final routeId = rawRouteId is int
          ? rawRouteId
          : int.tryParse(rawRouteId?.toString() ?? '');

      final startPoint = routePoints.first;
      final destinationPoint = routePoints.last;

      setState(() {
        _routePoints = routePoints;
        _savedRouteStartLocation = startPoint;
        _destinationLocation = destinationPoint;
        _destinationController.text = finishName == null || finishName.isEmpty
            ? 'Tujuan'
            : finishName;
        _routeDistanceKm = distanceKm;

        // Durasi belum disimpan pada tabel_routes.
        _routeDurationMinutes = null;
        _routeError = null;
        _searchResults = [];
        _isLoadingRoute = false;
        _isSavingRoute = false;
        _savedRouteId = routeId ?? -1;
        _isViewingSavedRoute = true;
      });

      _searchFocusNode.unfocus();

      _mapController.fitCamera(
        CameraFit.coordinates(
          coordinates: routePoints,
          padding: const EdgeInsets.fromLTRB(40, 140, 40, 260),
          maxZoom: 17,
        ),
      );

      _showMessage('Rute favorit berhasil ditampilkan.');
    } catch (error, stackTrace) {
      debugPrint('Gagal membuka rute favorit: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      setState(() {
        _routeError = 'Rute favorit gagal dibuka.';
        _isViewingSavedRoute = false;
        _savedRouteStartLocation = null;
      });

      _showMessage('Gagal membuka rute favorit: $error', isError: true);
    }
  }

  // ============================================================
  // MENGAMBIL RUTE DARI BACKEND MAPBOX
  // ============================================================

  Future<void> _getRoute() async {
    final destination = _destinationLocation;

    if (destination == null) {
      _showMessage('Pilih tujuan terlebih dahulu.', isError: true);

      return;
    }

    if (_isLoadingRoute) return;

    setState(() {
      _isLoadingRoute = true;

      _isSavingRoute = false;

      _savedRouteId = null;

      _savedRouteStartLocation = null;

      _isViewingSavedRoute = false;

      _routeError = null;
    });

    final result = await ApiService.getRoute(
      origin: _currentLocation,
      destination: destination,
    );

    if (!mounted) return;

    if (result['success'] != true) {
      final message =
          result['message']?.toString() ??
          'Gagal mendapatkan rute dari server.';

      setState(() {
        _isLoadingRoute = false;

        _routeError = message;
      });

      _showMessage(message, isError: true);

      return;
    }

    try {
      final data = result['data'];

      if (data is! Map<String, dynamic>) {
        throw const FormatException('Respons rute dari server tidak valid.');
      }

      final rawCoordinates = data['coordinates'];

      if (rawCoordinates is! List) {
        throw const FormatException('Koordinat rute tidak ditemukan.');
      }

      final routePoints = <LatLng>[];

      for (final coordinate in rawCoordinates) {
        if (coordinate is! List || coordinate.length < 2) {
          continue;
        }

        // Format Mapbox:
        // [longitude, latitude]
        final longitude = double.tryParse(coordinate[0].toString());

        final latitude = double.tryParse(coordinate[1].toString());

        if (latitude == null || longitude == null) {
          continue;
        }

        routePoints.add(LatLng(latitude, longitude));
      }

      if (routePoints.length < 2) {
        throw const FormatException('Titik jalur dari Mapbox tidak mencukupi.');
      }

      final distanceKm = double.tryParse(data['distance_km']?.toString() ?? '');

      final durationMinutes = double.tryParse(
        data['duration_minutes']?.toString() ?? '',
      );

      setState(() {
        _routePoints = routePoints;

        _routeDistanceKm = distanceKm;

        _routeDurationMinutes = durationMinutes;

        _isLoadingRoute = false;

        _routeError = null;
      });

      // Menyesuaikan kamera agar seluruh rute terlihat.
      _mapController.fitCamera(
        CameraFit.coordinates(
          coordinates: routePoints,
          padding: const EdgeInsets.fromLTRB(40, 140, 40, 260),
          maxZoom: 17,
        ),
      );

      _showMessage('Rute lari berhasil dibuat.');
    } catch (error) {
      setState(() {
        _isLoadingRoute = false;

        _routeError = error.toString();
      });

      _showMessage('Gagal membaca data rute: $error', isError: true);
    }
  }

  // ============================================================
  // MENYIMPAN RUTE FAVORIT KE DATABASE
  // ============================================================

  Future<void> _saveCurrentRoute() async {
    if (_isSavingRoute) return;

    if (_savedRouteId != null) {
      _showMessage('Rute ini sudah tersimpan.');
      return;
    }

    if (_destinationLocation == null) {
      _showMessage('Pilih tujuan terlebih dahulu.', isError: true);
      return;
    }

    if (_routePoints.length < 2 || _routeDistanceKm == null) {
      _showMessage(
        'Tampilkan rute terlebih dahulu sebelum menyimpannya.',
        isError: true,
      );
      return;
    }

    final finishName = _destinationController.text.trim();

    if (finishName.isEmpty) {
      _showMessage('Nama tujuan tidak tersedia.', isError: true);
      return;
    }

    setState(() {
      _isSavingRoute = true;
    });

    final result = await ApiService.saveRoute(
      startName: 'Lokasi Saya',
      finishName: finishName,
      routePoints: List<LatLng>.from(_routePoints),
      distanceKm: _routeDistanceKm!,
    );

    if (!mounted) return;

    if (result['success'] == true) {
      final rawId = result['id_rute'];

      final savedId = rawId is int
          ? rawId
          : int.tryParse(rawId?.toString() ?? '');

      setState(() {
        _isSavingRoute = false;
        _savedRouteId = savedId ?? -1;
      });

      _showMessage(result['message']?.toString() ?? 'Rute berhasil disimpan.');

      return;
    }

    final message = result['message']?.toString() ?? 'Rute gagal disimpan.';

    setState(() {
      _isSavingRoute = false;
    });

    _showMessage(message, isError: true);
  }

  // ============================================================
  // MENGHAPUS TUJUAN DAN RUTE
  // ============================================================

  void _clearDestination() {
    _destinationController.clear();

    _searchFocusNode.unfocus();

    setState(() {
      _searchResults = [];

      _destinationLocation = null;

      _savedRouteStartLocation = null;

      _routePoints = [];

      _routeDistanceKm = null;

      _routeDurationMinutes = null;

      _routeError = null;

      _isSavingRoute = false;

      _savedRouteId = null;

      _isViewingSavedRoute = false;
    });

    _mapController.move(_currentLocation, 16);
  }

  // ============================================================
  // MENAMPILKAN PESAN
  // ============================================================

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : const Color(0xFF00A844),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _debounce?.cancel();

    _positionStream?.cancel();

    _animController.dispose();

    _destinationController.dispose();

    _searchFocusNode.dispose();

    _mapController.dispose();

    super.dispose();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    const accentColor = Color(0xFF00FF66);

    final distanceText = _routeDistanceKm == null
        ? '-- KM'
        : '${_routeDistanceKm!.toStringAsFixed(2)} KM';

    final String routeDescription;

    if (_routeError != null) {
      routeDescription = _routeError!;
    } else if (_destinationLocation == null) {
      routeDescription = 'Cari dan pilih tujuan lari terlebih dahulu.';
    } else if (_routeDistanceKm == null) {
      routeDescription = 'Tujuan: ${_destinationController.text}';
    } else if (_isViewingSavedRoute) {
      routeDescription =
          'Rute favorit tersimpan'
          ' • Tujuan: ${_destinationController.text}';
    } else {
      routeDescription =
          'Tujuan: ${_destinationController.text}'
          ' • Estimasi '
          '${_routeDurationMinutes?.toStringAsFixed(1) ?? '-'} menit';
    }

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SlideTransition(
          position: _slideAnim,
          child: Stack(
            children: [
              // =================================================
              // KANVAS PETA
              // =================================================
              Container(
                width: double.infinity,
                height: double.infinity,
                decoration: const BoxDecoration(color: Color(0xFF181818)),
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _currentLocation,
                    initialZoom: 15,
                  ),
                  children: [
                    // TILE MAPBOX
                    TileLayer(
                      urlTemplate:
                          'https://api.mapbox.com/styles/v1/'
                          'mapbox/dark-v11/tiles/'
                          '{z}/{x}/{y}'
                          '?access_token={accessToken}',
                      additionalOptions: {'accessToken': mapboxToken},
                    ),

                    // GARIS RUTE
                    if (_routePoints.isNotEmpty)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: _routePoints,
                            color: accentColor,
                            strokeWidth: 6,
                            borderColor: Colors.black87,
                            borderStrokeWidth: 2,
                          ),
                        ],
                      ),

                    // MARKER
                    MarkerLayer(
                      markers: [
                        // MARKER POSISI PENGGUNA
                        Marker(
                          point: _currentLocation,
                          width: 60,
                          height: 60,
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                              border: Border.all(color: accentColor, width: 2),
                            ),
                            child: const Icon(
                              Icons.navigation_rounded,
                              color: accentColor,
                              size: 24,
                            ),
                          ),
                        ),

                        // MARKER TITIK AWAL RUTE FAVORIT
                        if (_savedRouteStartLocation != null)
                          Marker(
                            point: _savedRouteStartLocation!,
                            width: 50,
                            height: 50,
                            child: Container(
                              decoration: BoxDecoration(
                                color: accentColor.withValues(alpha: 0.18),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: accentColor,
                                  width: 2,
                                ),
                              ),
                              child: const Icon(
                                Icons.flag_rounded,
                                color: accentColor,
                                size: 24,
                              ),
                            ),
                          ),

                        // MARKER TUJUAN
                        if (_destinationLocation != null)
                          Marker(
                            point: _destinationLocation!,
                            width: 50,
                            height: 50,
                            child: const Icon(
                              Icons.location_on,
                              color: Colors.white,
                              size: 40,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              // =================================================
              // TOP BAR DAN HASIL PENCARIAN
              // =================================================
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 15,
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF1E1E1E,
                          ).withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.search_rounded,
                              color: accentColor,
                              size: 22,
                            ),

                            const SizedBox(width: 12),

                            Expanded(
                              child: TextField(
                                controller: _destinationController,
                                focusNode: _searchFocusNode,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                                decoration: const InputDecoration(
                                  hintText: 'Cari rute atau tujuan lari...',
                                  hintStyle: TextStyle(color: Colors.white54),
                                  border: InputBorder.none,
                                ),
                                onChanged: (value) {
                                  setState(() {});

                                  _onSearchChanged(value);
                                },
                              ),
                            ),

                            if (_destinationController.text.isNotEmpty)
                              HoverButton(
                                builder: (context, progress) => IconButton(
                                  icon: Icon(
                                    Icons.close_rounded,
                                    color: Color.lerp(
                                      Colors.white54,
                                      Colors.white,
                                      progress,
                                    ),
                                    size: 20,
                                  ),
                                  style: IconButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                  ),
                                  onPressed: _clearDestination,
                                ),
                              ),
                          ],
                        ),
                      ),

                      // HASIL PENCARIAN
                      if (_searchResults.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 10),
                          constraints: const BoxConstraints(maxHeight: 250),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF1E1E1E,
                            ).withValues(alpha: 0.95),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: _searchResults.length,
                            separatorBuilder: (context, index) => Divider(
                              color: Colors.white.withValues(alpha: 0.05),
                              height: 1,
                            ),
                            itemBuilder: (context, index) {
                              final feature = _searchResults[index];

                              final title = feature is Map<String, dynamic>
                                  ? feature['text']?.toString() ?? 'Lokasi'
                                  : 'Lokasi';

                              final subtitle = feature is Map<String, dynamic>
                                  ? feature['place_name']?.toString() ?? ''
                                  : '';

                              return ListTile(
                                leading: const Icon(
                                  Icons.place_outlined,
                                  color: Colors.white54,
                                ),
                                title: Text(
                                  title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text(
                                  subtitle,
                                  style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 12,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                onTap: () => _selectDestination(feature),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // =================================================
              // KARTU INFORMASI RUTE
              // =================================================
              Positioned(
                bottom: 30,
                left: 20,
                right: 20,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.alt_route_rounded,
                                color: accentColor,
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Rekomendasi Jalur Terbaik',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),

                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              distanceText,
                              style: const TextStyle(
                                color: accentColor,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      Text(
                        routeDescription,
                        style: TextStyle(
                          color: _routeError == null
                              ? Colors.white54
                              : Colors.redAccent,
                          fontSize: 13,
                        ),
                      ),

                      const SizedBox(height: 18),

                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: HoverButton(
                          builder: (context, progress) => ElevatedButton.icon(
                            onPressed: _isLoadingRoute ? null : _getRoute,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color.lerp(
                                accentColor,
                                Colors.transparent,
                                progress,
                              ),
                              foregroundColor: Color.lerp(
                                Colors.black,
                                accentColor,
                                progress,
                              ),
                              disabledBackgroundColor: accentColor.withValues(
                                alpha: 0.45,
                              ),
                              disabledForegroundColor: Colors.black54,
                              elevation: 0,
                              side: BorderSide(
                                color: Color.lerp(
                                  Colors.transparent,
                                  Colors.white,
                                  progress,
                                )!,
                                width: 2,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            icon: _isLoadingRoute
                                ? SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Color.lerp(
                                        Colors.black,
                                        accentColor,
                                        progress,
                                      ),
                                    ),
                                  )
                                : Icon(
                                    Icons.alt_route_rounded,
                                    size: 20,
                                    color: Color.lerp(
                                      Colors.black,
                                      accentColor,
                                      progress,
                                    ),
                                  ),
                            label: Text(
                              _isLoadingRoute
                                  ? 'MENCARI RUTE...'
                                  : 'MULAI NAVIGASI RUTE',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                letterSpacing: 1,
                                color: Color.lerp(
                                  Colors.black,
                                  accentColor,
                                  progress,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      if (_routePoints.isNotEmpty &&
                          _routeDistanceKm != null) ...[
                        const SizedBox(height: 12),

                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: HoverButton(
                            builder: (context, progress) => OutlinedButton.icon(
                              onPressed: _isSavingRoute || _savedRouteId != null
                                  ? null
                                  : _saveCurrentRoute,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: accentColor,
                                disabledForegroundColor: Colors.white54,
                                backgroundColor: Color.lerp(
                                  Colors.transparent,
                                  accentColor.withValues(alpha: 0.12),
                                  progress,
                                ),
                                side: BorderSide(
                                  color: _savedRouteId != null
                                      ? Colors.white24
                                      : accentColor,
                                  width: 1.5,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              icon: _isSavingRoute
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: accentColor,
                                      ),
                                    )
                                  : Icon(
                                      _savedRouteId != null
                                          ? Icons.check_circle_rounded
                                          : Icons.bookmark_add_outlined,
                                      size: 20,
                                    ),
                              label: Text(
                                _isSavingRoute
                                    ? 'MENYIMPAN RUTE...'
                                    : _savedRouteId != null
                                    ? 'RUTE TERSIMPAN'
                                    : 'SIMPAN RUTE FAVORIT',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
