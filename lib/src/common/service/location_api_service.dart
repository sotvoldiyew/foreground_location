import 'package:dio/dio.dart';
import 'package:logger/logger.dart';

final _log = Logger();

class LocationApiService {
  LocationApiService._();
  static final LocationApiService instance = LocationApiService._();

  static const _baseUrl = 'https://enpfgyujmeedyqispbtj.supabase.co/functions/v1';
  static const _apiKey  = 'sb_publishable_UlA1yHcU7DWeSEyC9HVH2w_-n0OBTzp';

  late final Dio _dio = Dio(
    BaseOptions(
      baseUrl:        _baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {
        'Authorization': 'Bearer $_apiKey',
        'apikey':        _apiKey,
        'Content-Type':  'application/json',
      },
    ),
  )..interceptors.addAll([
    LogInterceptor(
      request:        false,
      requestHeader:  false,
      requestBody:    true,
      responseHeader: false,
      responseBody:   true,
      error:          true,
      logPrint:       (o) => _log.d('[DIO] $o'),
    ),
    _RetryInterceptor(),
  ]);

  Future<bool> sendLocation({
    required double latitude,
    required double longitude,
    required double heading,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/save-location',
        data: {
          'latitude':  latitude,
          'longitude': longitude,
          'head':      heading,
        },
      );

      final success = response.data?['success'] == true;
      if (success) {
        final id = response.data?['data']?['id'];
        _log.i('✅ [API] Yuborildi: id=$id | '
            'lat=${latitude.toStringAsFixed(5)} '
            'lng=${longitude.toStringAsFixed(5)}');
      }
      return success;
    } on DioException catch (e) {
      _handleDioError(e);
      return false;
    } catch (e) {
      _log.e('❌ [API] Kutilmagan xato: $e');
      return false;
    }
  }

  void _handleDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        _log.w('⚠️ [API] Timeout: ${e.message}');
      case DioExceptionType.connectionError:
        _log.w('⚠️ [API] Internet yo\'q');
      case DioExceptionType.badResponse:
        _log.w('⚠️ [API] Server xato: ${e.response?.statusCode} | ${e.response?.data}');
      default:
        _log.e('❌ [API] Dio xato: ${e.message}');
    }
  }
}

class _RetryInterceptor extends Interceptor {
  static const _maxRetries = 3;
  static const _retryDelay = Duration(seconds: 2);

  @override
  Future<void> onError(
      DioException err,
      ErrorInterceptorHandler handler,
      ) async {
    final shouldRetry =
        err.type == DioExceptionType.connectionTimeout ||
            err.type == DioExceptionType.receiveTimeout    ||
            err.type == DioExceptionType.connectionError;

    if (!shouldRetry) return handler.next(err);

    final attempt = (err.requestOptions.extra['retryCount'] as int?) ?? 0;
    if (attempt >= _maxRetries) {
      _log.w('⚠️ [Retry] $attempt urinishdan keyin ham muvaffaqiyatsiz');
      return handler.next(err);
    }

    _log.i('🔄 [Retry] ${attempt + 1}/$_maxRetries urinish...');
    await Future.delayed(_retryDelay * (attempt + 1));

    err.requestOptions.extra['retryCount'] = attempt + 1;

    try {
      final dio = Dio(BaseOptions(
        baseUrl:        err.requestOptions.baseUrl,
        headers:        err.requestOptions.headers,
        connectTimeout: err.requestOptions.connectTimeout,
        receiveTimeout: err.requestOptions.receiveTimeout,
      ));
      final response = await dio.fetch(err.requestOptions);
      handler.resolve(response);
    } catch (e) {
      handler.next(err);
    }
  }
}