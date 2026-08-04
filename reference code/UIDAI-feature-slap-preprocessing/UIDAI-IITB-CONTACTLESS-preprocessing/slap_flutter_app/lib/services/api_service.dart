import 'dart:io';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // Multi-finger (slap) pipeline server — GPU VM (Tesla P4) on GCP.
  // Override at runtime in Settings.
  static const String _defaultUrl = 'http://35.255.138.39:5010';
  static const String _prefKey    = 'server_url';
  static const String _verKey     = 'server_url_version';
  // Bump this whenever _defaultUrl changes — forces a one-time override of any
  // stale saved URL (e.g. an old LAN IP) on the next app launch.
  static const int _urlVersion    = 2;

  static String baseUrl = _defaultUrl;

  static final Dio _dio = Dio(BaseOptions(
    baseUrl: _defaultUrl,
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 90),
  ));

  /// Call once at app startup — loads persisted URL from SharedPreferences,
  /// but migrates past a stale saved URL when the baked-in default changes.
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final savedVer = prefs.getInt(_verKey) ?? 1;
    final saved = prefs.getString(_prefKey);
    if (savedVer < _urlVersion || saved == null || saved.isEmpty) {
      baseUrl = _defaultUrl;
      _dio.options.baseUrl = _defaultUrl;
      await prefs.setString(_prefKey, _defaultUrl);
      await prefs.setInt(_verKey, _urlVersion);
    } else {
      baseUrl = saved;
      _dio.options.baseUrl = saved;
    }
  }

  /// Updates the in-memory URL and persists it so it survives restarts.
  static Future<void> setBaseUrl(String url) async {
    baseUrl = url;
    _dio.options.baseUrl = url;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, url);
    await prefs.setInt(_verKey, _urlVersion);
  }

  static Future<Map<String, dynamic>> healthCheck() async {
    final r = await _dio.get('/health');
    return r.data;
  }

  static Future<Map<String, dynamic>> qualityCheck(File image) async {
    final fd = FormData.fromMap({
      'image': await MultipartFile.fromFile(image.path, filename: 'fp.jpg'),
    });
    try {
      final r = await _dio.post('/quality_check', data: fd,
          options: Options(receiveTimeout: const Duration(seconds: 5)));
      return r.data;
    } on DioException {
      return {};
    }
  }

  static Future<Map<String, dynamic>> enroll({
    required String name,
    required String uid,
    required String batch,
    required File image,
  }) async {
    final fd = FormData.fromMap({
      'name': name, 'uid': uid, 'batch': batch,
      'image': await MultipartFile.fromFile(image.path, filename: 'fp.jpg'),
    });
    try {
      final r = await _dio.post('/enroll', data: fd);
      return r.data;
    } on DioException catch (e) {
      return e.response?.data ?? {'success': false, 'error': e.message};
    }
  }

  static Future<Map<String, dynamic>> authenticate({
    required String batch,
    required File image,
  }) async {
    final fd = FormData.fromMap({
      'batch': batch,
      'image': await MultipartFile.fromFile(image.path, filename: 'fp.jpg'),
    });
    try {
      final r = await _dio.post('/authenticate', data: fd);
      return r.data;
    } on DioException catch (e) {
      return e.response?.data ?? {'success': false, 'error': e.message};
    }
  }

  static Future<Map<String, dynamic>> verify({
    required String uid,
    required String batch,
    required File image,
  }) async {
    final fd = FormData.fromMap({
      'uid': uid, 'batch': batch,
      'image': await MultipartFile.fromFile(image.path, filename: 'fp.jpg'),
    });
    try {
      final r = await _dio.post('/verify', data: fd);
      return r.data;
    } on DioException catch (e) {
      return e.response?.data ?? {'success': false, 'error': e.message};
    }
  }

  // ── Multi-finger (slap) ──────────────────────────────────────────────────
  static Future<Map<String, dynamic>> processSlap({
    required File image,
    String handSide = 'right',
    bool vis = true,
  }) async {
    final fd = FormData.fromMap({
      'image': await MultipartFile.fromFile(image.path, filename: 'slap.jpg'),
      'hand_side': handSide,
      'vis': vis ? '1' : '0',
    });
    try {
      final r = await _dio.post('/process_slap', data: fd);
      return r.data;
    } on DioException catch (e) {
      return e.response?.data ?? {'error': e.message, 'offline': true};
    }
  }

  static Future<Map<String, dynamic>> enrollSlap({
    required File image,
    required String name,
    required String uid,
    required String batch,
    String handSide = 'right',
  }) async {
    final fd = FormData.fromMap({
      'image': await MultipartFile.fromFile(image.path, filename: 'slap.jpg'),
      'name': name, 'uid': uid, 'batch': batch, 'hand_side': handSide,
    });
    try {
      final r = await _dio.post('/enroll_slap', data: fd);
      return r.data;
    } on DioException catch (e) {
      return e.response?.data ?? {'error': e.message, 'offline': true};
    }
  }

  static Future<Map<String, dynamic>> process(File image) async {
    final fd = FormData.fromMap({
      'image': await MultipartFile.fromFile(image.path, filename: 'fp.jpg'),
    });
    try {
      final r = await _dio.post('/process', data: fd);
      return r.data;
    } on DioException catch (e) {
      return e.response?.data ?? {'success': false, 'error': e.message};
    }
  }

  static Future<List<dynamic>> getUsers({String batch = ''}) async {
    final r = await _dio.get('/users', queryParameters: {'batch': batch});
    return r.data['users'] ?? [];
  }

  static Future<List<dynamic>> getHistory({String batch = ''}) async {
    final r = await _dio.get('/history', queryParameters: {'batch': batch});
    return r.data['history'] ?? [];
  }

  static Future<Map<String, dynamic>> readiness(File image) async {
    final fd = FormData.fromMap({
      'image': await MultipartFile.fromFile(image.path, filename: 'fp.jpg'),
    });
    try {
      final r = await _dio.post('/readiness', data: fd);
      return r.data;
    } on DioException catch (e) {
      return e.response?.data ?? {'success': false, 'error': e.message};
    }
  }

  static Future<Map<String, dynamic>> checkRoi(File image) async {
    final fd = FormData.fromMap({
      'image': await MultipartFile.fromFile(image.path, filename: 'fp.jpg'),
    });
    try {
      final r = await _dio.post('/check_roi', data: fd,
          options: Options(receiveTimeout: const Duration(seconds: 5)));
      return r.data;
    } on DioException {
      return {};
    }
  }

  static Future<Map<String, dynamic>> livenessGesture({
    required File image,
    required int expectedCount,
  }) async {
    final fd = FormData.fromMap({
      'image': await MultipartFile.fromFile(image.path, filename: 'fp.jpg'),
      'expected_count': expectedCount.toString(),
    });
    try {
      final r = await _dio.post('/liveness_gesture', data: fd);
      return r.data;
    } on DioException catch (e) {
      return e.response?.data ?? {'success': false, 'error': e.message};
    }
  }
}
