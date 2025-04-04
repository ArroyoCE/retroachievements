import 'package:flutter/material.dart';
import 'package:retroachievements_organizer/model/login_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:retroachievements_organizer/controller/api_calls.dart';

class LoginController {
  // Secure storage for sensitive data like API key
  final _secureStorage = const FlutterSecureStorage();
  
  // Validation method
  bool validateFields(String username, String apiKey) {
    return username.isNotEmpty && apiKey.isNotEmpty;
  }

  // Show alert if validation fails
  void showValidationError(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF333333),
          title: const Text(
            'Validation Error',
            style: TextStyle(color: Color(0xFFFFD700)),
          ),
          content: const Text(
            'Please fill in both username and API key fields.',
            style: TextStyle(color: Colors.white),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'OK',
                style: TextStyle(color: Color(0xFFFFD700)),
              ),
            ),
          ],
        );
      },
    );
  }

  // Show authentication error
  void showAuthError(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF333333),
          title: const Text(
            'Authentication Error',
            style: TextStyle(color: Color(0xFFFFD700)),
          ),
          content: Text(
            message,
            style: const TextStyle(color: Colors.white),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'OK',
                style: TextStyle(color: Color(0xFFFFD700)),
              ),
            ),
          ],
        );
      },
    );
  }

  // Save login data securely
  Future<bool> saveLoginData(Login login) async {
    try {
      // Save username in shared preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('username', login.username);
      
      // Save API key in secure storage
      await _secureStorage.write(key: 'api_key', value: login.apiKey);
      
      return true;
    } catch (e) {
      debugPrint('Error saving login data: $e');
      return false;
    }
  }

  // Retrieve login data
  Future<Login?> getLoginData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final username = prefs.getString('username');
      final apiKey = await _secureStorage.read(key: 'api_key');
      
      if (username != null && apiKey != null) {
        return Login(username: username, apiKey: apiKey);
      }
      return null;
    } catch (e) {
      debugPrint('Error retrieving login data: $e');
      return null;
    }
  }
  
  // Save auto login preference
  Future<bool> setAutoLogin(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('auto_login', value);
      return true;
    } catch (e) {
      debugPrint('Error saving auto login preference: $e');
      return false;
    }
  }
  
  // Get auto login preference
  Future<bool> getAutoLogin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('auto_login') ?? false;
    } catch (e) {
      debugPrint('Error getting auto login preference: $e');
      return false;
    }
  }

  // Process login with API validation
  Future<bool> processLogin(BuildContext context, String username, String apiKey) async {
    // Create login object
    final login = Login(username: username, apiKey: apiKey);
    
    // Validate credentials with RetroAchievements API
    final response = await ApiService.getUserProfile(username, apiKey);
    
    if (!response['success']) {
      // Show authentication error if API validation fails
      if (context.mounted) {
        showAuthError(context, response['message']);
      }
      return false;
    }
    
    // Save login data if API validation succeeds
    final saved = await saveLoginData(login);
    
    if (!saved) {
      // Show error dialog if saving fails
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              backgroundColor: const Color(0xFF333333),
              title: const Text(
                'Error',
                style: TextStyle(color: Color(0xFFFFD700)),
              ),
              content: const Text(
                'Failed to save login data. Please try again.',
                style: TextStyle(color: Colors.white),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    'OK',
                    style: TextStyle(color: Color(0xFFFFD700)),
                  ),
                ),
              ],
            );
          },
        );
      }
      return false;
    }
    
    return true;
  }
  
  // Handle logout
  Future<void> logout() async {
    try {
      // Disable auto login setting
      await setAutoLogin(false);
      
      // You can optionally clear the stored credentials if needed
      // await _secureStorage.delete(key: 'api_key');
      // final prefs = await SharedPreferences.getInstance();
      // await prefs.remove('username');
      
      debugPrint('Logout completed successfully');
    } catch (e) {
      debugPrint('Error during logout: $e');
    }
  }
}