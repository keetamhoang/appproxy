import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart'; // Để dùng kDebugMode

// Lấy base URL từ biến môi trường, có giá trị fallback
const String _apiBaseUrl = 'https://yeuproxy.com';


class ApiClient {
  // Singleton pattern: Đảm bảo chỉ có một instance của ApiClient
  ApiClient._internal() {
    // Khởi tạo Dio với các cấu hình cơ bản
    _dio = Dio(
      BaseOptions(
        baseUrl: _apiBaseUrl,
        connectTimeout: const Duration(seconds: 15), // Timeout kết nối
        receiveTimeout: const Duration(seconds: 30), // Timeout nhận dữ liệu
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Accept': 'application/json',
        },
      ),
    );

    // (Tùy chọn) Thêm Interceptor để log request/response khi debug
    if (kDebugMode) { // Chỉ log ở chế độ debug
      _dio.interceptors.add(LogInterceptor(
        requestHeader: true,
        requestBody: true,
        responseHeader: true,
        responseBody: true,
        error: true,
      ));
    }

    // (Tùy chọn) Thêm Interceptor để xử lý token (ví dụ)
    // _dio.interceptors.add(InterceptorsWrapper(
    //   onRequest:(options, handler) async {
    //      // Lấy token từ SharedPreferences hoặc Secure Storage
    //      String? token = await getToken();
    //      if (token != null) {
    //         options.headers['Authorization'] = 'Bearer $token';
    //      }
    //      return handler.next(options); // Tiếp tục request
    //   },
    //   onError: (DioException e, handler) async {
    //      // Xử lý lỗi 401 Unauthorized (ví dụ: refresh token)
    //      if (e.response?.statusCode == 401) {
    //        // Logic refresh token...
    //      }
    //      return handler.next(e); // Tiếp tục báo lỗi
    //   },
    // ));

    debugPrint('ApiClient initialized with baseUrl: $_apiBaseUrl');
    if (_apiBaseUrl.contains('default.api.url')) {
      debugPrint('WARNING: API_BASE_URL is not set via --dart-define, using default.');
    }
  }

  static final ApiClient _instance = ApiClient._internal();
  static ApiClient get instance => _instance;

  late Dio _dio;

  // --- Các phương thức HTTP ---

  /// Thực hiện GET request
  Future<Response> get(
      String path, {
        Map<String, dynamic>? queryParameters,
        Options? options,
        CancelToken? cancelToken,
        ProgressCallback? onReceiveProgress,
      }) async {
    try {
      final response = await _dio.get(
        path,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onReceiveProgress: onReceiveProgress,
      );
      return response;
    } on DioException catch (e) {
      // Xử lý lỗi Dio hoặc throw lại để lớp gọi xử lý
      _handleDioError(e);
      rethrow; // Throw lại để lớp gọi biết có lỗi
    } catch (e) {
      debugPrint("ApiClient GET Error (non-Dio): $e");
      rethrow;
    }
  }

  /// Thực hiện POST request
  Future<Response> post(
      String path, {
        dynamic data,
        Map<String, dynamic>? queryParameters,
        Options? options,
        CancelToken? cancelToken,
        ProgressCallback? onSendProgress,
        ProgressCallback? onReceiveProgress,
      }) async {
    try {
      final response = await _dio.post(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
      );
      return response;
    } on DioException catch (e) {
      _handleDioError(e);
      rethrow;
    } catch (e) {
      debugPrint("ApiClient POST Error (non-Dio): $e");
      rethrow;
    }
  }

  /// Thực hiện PUT request
  Future<Response> put(
      String path, {
        dynamic data,
        Map<String, dynamic>? queryParameters,
        Options? options,
        CancelToken? cancelToken,
        ProgressCallback? onSendProgress,
        ProgressCallback? onReceiveProgress,
      }) async {
    try {
      final response = await _dio.put(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
      );
      return response;
    } on DioException catch (e) {
      _handleDioError(e);
      rethrow;
    } catch (e) {
      debugPrint("ApiClient PUT Error (non-Dio): $e");
      rethrow;
    }
  }

  /// Thực hiện DELETE request
  Future<Response> delete(
      String path, {
        dynamic data,
        Map<String, dynamic>? queryParameters,
        Options? options,
        CancelToken? cancelToken,
      }) async {
    try {
      final response = await _dio.delete(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
      return response;
    } on DioException catch (e) {
      _handleDioError(e);
      rethrow;
    } catch (e) {
      debugPrint("ApiClient DELETE Error (non-Dio): $e");
      rethrow;
    }
  }

  // --- Xử lý lỗi cơ bản ---
  void _handleDioError(DioException e) {
    // Log lỗi chi tiết
    String errorMessage = "ApiClient Error: ";
    if (e.response != null) {
      // Lỗi từ phía server (status code không phải 2xx)
      errorMessage += "StatusCode: ${e.response?.statusCode}, Path: ${e.requestOptions.path}\nData: ${e.response?.data}";
    } else {
      // Lỗi kết nối, timeout, hoặc lỗi trước khi gửi request
      errorMessage += "Type: ${e.type}, Path: ${e.requestOptions.path}\nMessage: ${e.message}";
    }
    debugPrint(errorMessage);
    // Ở đây bạn có thể:
    // 1. Throw một exception cụ thể hơn (ví dụ: NetworkException, ApiException)
    // 2. Hiển thị thông báo lỗi chung cho người dùng (không khuyến khích làm ở lớp này)
    // 3. Gửi lỗi lên hệ thống logging (Sentry, Firebase Crashlytics, ...)
  }
}