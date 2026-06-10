import 'package:dio/dio.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException({required this.message, this.statusCode});

  factory ApiException.fromDioException(DioException error) {
    String message = 'An unexpected error occurred.';
    int? statusCode = error.response?.statusCode;

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        message = 'Connection timeout. Please try again.';
        break;
      case DioExceptionType.badResponse:
        if (error.response?.data != null && error.response?.data is Map) {
          final detail = error.response?.data['detail'];
          if (detail != null) {
            message = detail.toString();
          } else {
            message = 'Server error ($statusCode).';
          }
        } else {
          message = 'Server returned a bad response.';
        }
        break;
      case DioExceptionType.cancel:
        message = 'Request was cancelled.';
        break;
      case DioExceptionType.connectionError:
        message = 'Connection failed. Please check your internet connection.';
        break;
      default:
        message = 'Something went wrong. Please try again.';
        break;
    }
    return ApiException(message: message, statusCode: statusCode);
  }

  @override
  String toString() => message;
}
