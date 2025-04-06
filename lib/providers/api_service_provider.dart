// lib/providers/api_service_provider.dart
import 'package:flutter/material.dart';
import 'package:retroachievements_organizer/controller/api_calls.dart';
import 'package:retroachievements_organizer/providers/hash_service_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'api_service_provider.g.dart';

@riverpod
class ApiServiceProvider extends _$ApiServiceProvider {
  // Caches
  final Map<int, List<dynamic>> _gameListCache = {};
  final Map<int, Map<String, dynamic>> _gameDataCache = {};
  final Map<int, Map<String, dynamic>> _gameExtendedDataCache = {};
  final Map<int, Map<String, dynamic>> _gameHashesCache = {};
  final Map<String, Map<String, dynamic>> _userProfileCache = {};
  final Map<String, Map<String, dynamic>> _userAwardsCache = {};
  final Map<String, Map<String, dynamic>> _userCompletionCache = {};
  final Map<String, List<dynamic>> _userRecentAchievementsCache = {};
  final Map<String, Map<String, dynamic>> _userSummaryCache = {};
  final Map<String, String?> _gameIconPathCache = {};
  
  @override
  Future<void> build() async {
    // Initialize provider
  }
  
  // Generic method to handle API calls with common error handling
  Future<T> _handleApiCall<T>(String apiName, Future<T> Function() apiCall) async {
    try {
      return await apiCall();
    } catch (e) {
      debugPrint('ApiServiceProvider: Error in $apiName: $e');
      rethrow;
    }
  }
  
  // Get game list with caching
  Future<List<dynamic>> getGameList(String apiKey, int consoleId) async {
    if (_gameListCache.containsKey(consoleId)) {
      return _gameListCache[consoleId]!;
    }
    
    return _handleApiCall('getGameList', () async {
      try {
        final hashProvider = ref.read(hashServiceProviderProvider.notifier);
        final games = await hashProvider.fetchGameList(apiKey, consoleId);
        _gameListCache[consoleId] = games;
        return games;
      } catch (e) {
        debugPrint('ApiServiceProvider: Error fetching game list: $e');
        // Try to load saved game list if fetch fails

        final hashProvider = ref.read(hashServiceProviderProvider.notifier);
        final savedGames = await hashProvider.loadSavedGameList(consoleId);
        if (savedGames.isNotEmpty) {
          _gameListCache[consoleId] = savedGames;
          return savedGames;
        }
        rethrow;
      }
    });
  }
  
  // Get game data with caching
  Future<Map<String, dynamic>> getGameData(String apiKey, int gameId) async {
    if (_gameDataCache.containsKey(gameId)) {
      return _gameDataCache[gameId]!;
    }
    
    return _handleApiCall('getGameData', () async {
      final response = await ApiService.getGameData(apiKey, gameId);
      if (response['success']) {
        _gameDataCache[gameId] = response['data'];
        return response['data'];
      }
      
      throw Exception(response['message'] ?? 'Failed to get game data');
    });
  }
  
  // Get extended game data with caching
  Future<Map<String, dynamic>> getGameExtendedData(String apiKey, int gameId) async {
    if (_gameExtendedDataCache.containsKey(gameId)) {
      return _gameExtendedDataCache[gameId]!;
    }
    
    return _handleApiCall('getGameExtendedData', () async {
      final response = await ApiService.getGameExtendedData(apiKey, gameId);
      if (response['success']) {
        _gameExtendedDataCache[gameId] = response['data'];
        return response['data'];
      }
      
      throw Exception(response['message'] ?? 'Failed to get extended game data');
    });
  }
  
  // Get game hashes with caching
  Future<Map<String, dynamic>> getGameHashes(String apiKey, int gameId) async {
    if (_gameHashesCache.containsKey(gameId)) {
      return _gameHashesCache[gameId]!;
    }
    
    return _handleApiCall('getGameHashes', () async {
      final response = await ApiService.getGameHashes(apiKey, gameId);
      if (response['success']) {
        _gameHashesCache[gameId] = response['data'];
        return response['data'];
      }
      
      throw Exception(response['message'] ?? 'Failed to get game hashes');
    });
  }
  
  // Get user profile with caching
  Future<Map<String, dynamic>> getUserProfile(String username, String apiKey) async {
    final cacheKey = username;
    if (_userProfileCache.containsKey(cacheKey)) {
      return _userProfileCache[cacheKey]!;
    }
    
    return _handleApiCall('getUserProfile', () async {
      final response = await ApiService.getUserProfile(username, apiKey);
      if (response['success']) {
        _userProfileCache[cacheKey] = response['data'];
        return response['data'];
      }
      
      throw Exception(response['message'] ?? 'Failed to get user profile');
    });
  }
  
  // Get user awards with caching
  Future<Map<String, dynamic>> getUserAwards(String username, String apiKey) async {
    final cacheKey = username;
    if (_userAwardsCache.containsKey(cacheKey)) {
      return _userAwardsCache[cacheKey]!;
    }
    
    return _handleApiCall('getUserAwards', () async {
      try {
        final response = await ApiService.getUserAwards(username, apiKey);
        if (response['success']) {
          _userAwardsCache[cacheKey] = response['data'];
          return response['data'];
        }
        
        throw Exception(response['message'] ?? 'Failed to get user awards');
      } catch (e) {
        debugPrint('ApiServiceProvider: Error getting user awards: $e');
        
        // Try to load from saved data
        final savedData = await ApiService.getSavedUserAwards();
        if (savedData != null) {
          _userAwardsCache[cacheKey] = savedData;
          return savedData;
        }
        
        rethrow;
      }
    });
  }
  
  // Get user completion progress with caching
  Future<Map<String, dynamic>> getUserCompletionProgress(String username, String apiKey) async {
    final cacheKey = username;
    if (_userCompletionCache.containsKey(cacheKey)) {
      return _userCompletionCache[cacheKey]!;
    }
    
    return _handleApiCall('getUserCompletionProgress', () async {
      try {
        final response = await ApiService.getUserCompletionProgress(username, apiKey);
        if (response['success']) {
          _userCompletionCache[cacheKey] = response['data'];
          return response['data'];
        }
        
        throw Exception(response['message'] ?? 'Failed to get user completion progress');
      } catch (e) {
        debugPrint('ApiServiceProvider: Error getting user completion progress: $e');
        
        // Try to load from saved data
        final savedData = await ApiService.getSavedUserCompletionProgress();
        if (savedData != null) {
          _userCompletionCache[cacheKey] = savedData;
          return savedData;
        }
        
        rethrow;
      }
    });
  }
  
  // Get user recent achievements with caching
  Future<List<dynamic>> getUserRecentAchievements(String username, String apiKey) async {
    final cacheKey = username;
    if (_userRecentAchievementsCache.containsKey(cacheKey)) {
      return _userRecentAchievementsCache[cacheKey]!;
    }
    
    return _handleApiCall('getUserRecentAchievements', () async {
      final response = await ApiService.getUserRecentAchievements(username, apiKey);
      if (response['success']) {
        _userRecentAchievementsCache[cacheKey] = response['data'];
        return response['data'];
      }
      
      throw Exception(response['message'] ?? 'Failed to get user recent achievements');
    });
  }
  
  // Get user summary with caching
  Future<Map<String, dynamic>> getUserSummary(String username, String apiKey) async {
    final cacheKey = username;
    if (_userSummaryCache.containsKey(cacheKey)) {
      return _userSummaryCache[cacheKey]!;
    }
    
    return _handleApiCall('getUserSummary', () async {
      final response = await ApiService.getUserSummary(username, apiKey);
      if (response['success']) {
        _userSummaryCache[cacheKey] = response['data'];
        return response['data'];
      }
      
      throw Exception(response['message'] ?? 'Failed to get user summary');
    });
  }
  
  // Get game icon with caching
  Future<String?> getGameIcon(String iconPath, int gameId) async {
    final cacheKey = '$gameId:$iconPath';
    if (_gameIconPathCache.containsKey(cacheKey)) {
      return _gameIconPathCache[cacheKey];
    }
    
    return _handleApiCall('getGameIcon', () async {
      try {
        final iconFilePath = await ApiService.getGameIcon(iconPath, gameId);
        _gameIconPathCache[cacheKey] = iconFilePath;
        return iconFilePath;
      } catch (e) {
        debugPrint('ApiServiceProvider: Error getting game icon: $e');
        return null;
      }
    });
  }
  
  // Batch load game data for multiple games
  Future<Map<int, Map<String, dynamic>>> batchLoadGameData(String apiKey, List<int> gameIds) async {
    final Map<int, Map<String, dynamic>> results = {};
    final List<int> missingIds = [];
    
    // Check cache first
    for (final gameId in gameIds) {
      if (_gameDataCache.containsKey(gameId)) {
        results[gameId] = _gameDataCache[gameId]!;
      } else {
        missingIds.add(gameId);
      }
    }
    
    // Fetch missing game data
    for (final gameId in missingIds) {
      try {
        final response = await ApiService.getGameData(apiKey, gameId);
        if (response['success']) {
          _gameDataCache[gameId] = response['data'];
          results[gameId] = response['data'];
        }
      } catch (e) {
        debugPrint('ApiServiceProvider: Error loading game data for ID $gameId: $e');
      }
    }
    
    return results;
  }
  
  // Batch load game icons for multiple games
  Future<Map<int, String?>> batchLoadGameIcons(List<Map<String, dynamic>> games) async {
    final Map<int, String?> results = {};
    
    for (final game in games) {
      final gameId = game['ID'];
      final iconPath = game['ImageIcon'];
      
      if (gameId != null && iconPath != null) {
        try {
          final iconFilePath = await getGameIcon(iconPath, gameId);
          results[gameId] = iconFilePath;
        } catch (e) {
          debugPrint('ApiServiceProvider: Error batch loading icon for game $gameId: $e');
        }
      }
    }
    
    return results;
  }
  
  // Get consoles list with caching
  Future<List<dynamic>> getConsolesList(String apiKey) async {
    return _handleApiCall('getConsolesList', () async {
      try {
        final consoles = await ApiService.getConsolesList(apiKey);
        return consoles;
      } catch (e) {
        debugPrint('ApiServiceProvider: Error getting consoles list: $e');
        rethrow;
      }
    });
  }
  
  // Clear caches for a specific console
  void clearConsoleCache(int consoleId) {
    _gameListCache.remove(consoleId);
  }
  
  // Clear caches for a specific game
  void clearGameCache(int gameId) {
    _gameDataCache.remove(gameId);
    _gameExtendedDataCache.remove(gameId);
    _gameHashesCache.remove(gameId);
    
    // Clear icon caches associated with this game
    final iconCacheKeys = _gameIconPathCache.keys.where((key) => key.startsWith('$gameId:')).toList();
    for (final key in iconCacheKeys) {
      _gameIconPathCache.remove(key);
    }
  }
  
  // Clear user-related caches
  void clearUserCache(String username) {
    _userProfileCache.remove(username);
    _userAwardsCache.remove(username);
    _userCompletionCache.remove(username);
    _userRecentAchievementsCache.remove(username);
    _userSummaryCache.remove(username);
  }
  
  // Clear all caches
  void clearAllCaches() {
    _gameListCache.clear();
    _gameDataCache.clear();
    _gameExtendedDataCache.clear();
    _gameHashesCache.clear();
    _userProfileCache.clear();
    _userAwardsCache.clear();
    _userCompletionCache.clear();
    _userRecentAchievementsCache.clear();
    _userSummaryCache.clear();
    _gameIconPathCache.clear();
  }
  
  // Force refresh user data
  Future<void> refreshUserData(String username, String apiKey) async {
    clearUserCache(username);
    await Future.wait([
      getUserProfile(username, apiKey),
      getUserAwards(username, apiKey),
      getUserCompletionProgress(username, apiKey),
      getUserRecentAchievements(username, apiKey),
      getUserSummary(username, apiKey),
    ]);
  }
  
  // Force refresh game data
  Future<void> refreshGameData(String apiKey, int gameId) async {
    clearGameCache(gameId);
    await Future.wait([
      getGameData(apiKey, gameId),
      getGameExtendedData(apiKey, gameId),
      getGameHashes(apiKey, gameId),
    ]);
  }
}