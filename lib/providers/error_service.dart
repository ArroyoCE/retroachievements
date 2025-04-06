// lib/services/error_service.dart
import 'package:flutter/material.dart';
import 'package:retroachievements_organizer/constants/constants.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';

// Provider for error handling service
final errorServiceProvider = Provider<ErrorService>((ref) {
  return ErrorService();
});

class ErrorService {
  // Log error with severity level
  void logError(String source, dynamic error, [StackTrace? stackTrace]) {
    debugPrint('ERROR [$source]: $error');
    if (stackTrace != null) {
      debugPrint('STACK TRACE: $stackTrace');
    }
    
    // Here you could also log to a remote service like Firebase Crashlytics or Sentry
  }
  
  // Handle API errors and return a standardized error response
  Map<String, dynamic> handleApiError(String apiName, dynamic error) {
    logError('API:$apiName', error);
    
    // You could categorize errors based on type
    String userMessage;
    if (error.toString().contains('SocketException') || 
        error.toString().contains('Connection refused')) {
      userMessage = 'Network error: Please check your internet connection.';
    } else if (error.toString().contains('TimeoutException')) {
      userMessage = 'Request timed out. Please try again.';
    } else if (error.toString().contains('Unauthenticated')) {
      userMessage = 'Authentication error: Please log in again.';
    } else {
      userMessage = 'An error occurred: ${error.toString()}';
    }
    
    return {
      'success': false,
      'message': userMessage,
      'technical_details': error.toString(),
    };
  }
  
  // Show error dialog
  Future<void> showErrorDialog(BuildContext context, String title, String message) async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.cardBackground,
          title: Text(
            title,
            style: const TextStyle(color: AppColors.primary),
          ),
          content: Text(
            message,
            style: const TextStyle(color: AppColors.textLight),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'OK',
                style: TextStyle(color: AppColors.primary),
              ),
            ),
          ],
        );
      },
    );
  }
  
  // Show error snackbar
  void showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'OK',
          textColor: AppColors.textLight,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }
  
  // Try function with error handling
  Future<T?> tryFunction<T>(
    String source, 
    Future<T> Function() function, 
    {BuildContext? context, bool showError = true}
  ) async {
    try {
      return await function();
    } catch (error, stackTrace) {
      logError(source, error, stackTrace);
      
      if (context != null && showError) {
        showErrorSnackBar(context, 'Error in $source: ${error.toString()}');
      }
      
      return null;
    }
  }
}