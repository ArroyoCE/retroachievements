// lib/providers/user_provider.dart
import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:retroachievements_organizer/controller/api_calls.dart';
import 'package:retroachievements_organizer/model/login_model.dart';
import 'package:retroachievements_organizer/providers/api_service_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

part 'user_provider.g.dart';

// User state class to manage all user-related state
class UserState {
  final bool isLoading;
  final bool isAuthenticated;
  final String? errorMessage;
  final String? username;
  final Map<String, dynamic>? userInfo;
  final Map<String, dynamic>? userAwards;
  final Map<String, dynamic>? userRecentAchievements;
  final Map<String, dynamic>? userSummary;
  final Map<String, dynamic>? userCompletionProgress;
  final String? userPicPath;

  UserState({
    this.isLoading = false,
    this.isAuthenticated = false,
    this.errorMessage,
    this.username,
    this.userInfo,
    this.userAwards,
    this.userRecentAchievements,
    this.userSummary,
    this.userCompletionProgress,
    this.userPicPath,
  });

  // Create a new state by copying the current one with some changes
  UserState copyWith({
    bool? isLoading,
    bool? isAuthenticated,
    String? errorMessage,
    String? username,
    Map<String, dynamic>? userInfo,
    Map<String, dynamic>? userAwards,
    Map<String, dynamic>? userRecentAchievements,
    Map<String, dynamic>? userSummary,
    Map<String, dynamic>? userCompletionProgress,
    String? userPicPath,
  }) {
    return UserState(
      isLoading: isLoading ?? this.isLoading,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      errorMessage: errorMessage ?? this.errorMessage,
      username: username ?? this.username,
      userInfo: userInfo ?? this.userInfo,
      userAwards: userAwards ?? this.userAwards,
      userRecentAchievements: userRecentAchievements ?? this.userRecentAchievements,
      userSummary: userSummary ?? this.userSummary,
      userCompletionProgress: userCompletionProgress ?? this.userCompletionProgress,
      userPicPath: userPicPath ?? this.userPicPath,
    );
  }
}

@Riverpod(keepAlive: true)
class User extends _$User {
  // Secure storage for sensitive data like API key
  final _secureStorage = const FlutterSecureStorage();
  
  @override
  UserState build() {
    // Check for existing login on initialization
    _checkExistingLogin();
    return UserState();
  }

  Future<void> _checkExistingLogin() async {
    // Get login data
    final loginData = await getLoginData();
    
    if (loginData != null) {
      state = state.copyWith(
        username: loginData.username,
        isAuthenticated: true,
      );
      
      // Load user data
      await loadUserData(loginData.username, loginData.apiKey);
    }
  }

  // Validate login credentials
  bool validateFields(String username, String apiKey) {
    return username.isNotEmpty && apiKey.isNotEmpty;
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

  Future<void> login(String username, String apiKey) async {
    // Set loading state
    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
    );

    try {
      // Use API service provider for API calls
      ref.read(apiServiceProviderProvider.notifier);
      
      // Call API to validate credentials
      try {
        final response = await ApiService.getUserProfile(username, apiKey);
        
        if (!response['success']) {
          state = state.copyWith(
            isLoading: false,
            isAuthenticated: false,
            errorMessage: response['message'] ?? 'Authentication failed',
          );
          return;
        }
        
        final userData = response['data'];
        
        // Save login data
        await saveLoginData(Login(username: username, apiKey: apiKey));
        
        // Update state with user info
        state = state.copyWith(
          isLoading: false,
          isAuthenticated: true,
          username: username,
          userInfo: userData,
        );
        
        // Load additional user data
        await loadUserData(username, apiKey);
      } catch (e) {
        // Authentication failed
        state = state.copyWith(
          isLoading: false,
          isAuthenticated: false,
          errorMessage: 'Authentication failed: $e',
        );
      }
    } catch (e) {
      // Handle exceptions
      state = state.copyWith(
        isLoading: false,
        isAuthenticated: false,
        errorMessage: 'Login failed: $e',
      );
    }
  }

  Future<void> loadUserData(String username, String apiKey) async {
    if (!state.isAuthenticated) return;
    
    state = state.copyWith(isLoading: true);
    
    try {
      final apiService = ref.read(apiServiceProviderProvider.notifier);
      
      // Load user pic path
      final userPicPath = await ApiService.getUserPicPath();
      
      // Get user data using the API service provider
      final userAwards = await apiService.getUserAwards(username, apiKey);
      final userCompletionProgress = await apiService.getUserCompletionProgress(username, apiKey);
      
      // Handle this differently since it returns a List instead of a Map
      final recentAchievementsResponse = await apiService.getUserRecentAchievements(username, apiKey);
      final userSummary = await apiService.getUserSummary(username, apiKey);
      
      // Update state with all user data
      state = state.copyWith(
        isLoading: false,
        userPicPath: userPicPath,
        userAwards: userAwards,
        userCompletionProgress: userCompletionProgress,
        // Convert List to Map or store it differently
        userRecentAchievements: {'data': recentAchievementsResponse}, // Wrap in a Map
        userSummary: userSummary,
      );
    } catch (e) {
      debugPrint('Error loading user data: $e');
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load user data: $e',
      );
    }
  }

  Future<void> logout() async {
    state = state.copyWith(isLoading: true);
    
    try {
      // Disable auto login setting
      await setAutoLogin(false);
      
      // You can optionally clear the stored credentials if needed
      // await _secureStorage.delete(key: 'api_key');
      // final prefs = await SharedPreferences.getInstance();
      // await prefs.remove('username');
      
      // Reset state
      state = UserState();
      
      debugPrint('Logout completed successfully');
    } catch (e) {
      debugPrint('Error during logout: $e');
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Logout failed: $e',
      );
    }
  }
  
  // Process login with API validation
  Future<bool> processLogin(String username, String apiKey) async {
    // Create login object
    final login = Login(username: username, apiKey: apiKey);
    
    // Validate credentials with RetroAchievements API
    final response = await ApiService.getUserProfile(username, apiKey);
    
    if (!response['success']) {
      // Authentication failed
      return false;
    }
    
    // Save login data if API validation succeeds
    final saved = await saveLoginData(login);
    
    if (!saved) {
      // Failed to save login data
      return false;
    }
    
    return true;
  }
  
  // Get API key (helpful for other providers)
  Future<String?> getApiKey() async {
    final loginData = await getLoginData();
    return loginData?.apiKey;
  }
}