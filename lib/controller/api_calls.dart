// ignore_for_file: prefer_const_declarations

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:retroachievements_organizer/constants/constants.dart';

class ApiService {
  // Get user profile from RetroAchievements API
  static Future<Map<String, dynamic>> getUserProfile(String username, String apiKey) async {
    try {
      final url = '${ApiConstants.baseUrl}${ApiConstants.getUserProfile}?u=$username&y=$apiKey';
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        
        // Check if response contains error
        if (data.containsKey('errors') || data.containsKey('message') && data['message'] == 'Unauthenticated.') {
          return {'success': false, 'message': AppStrings.authenticationError};
        }
        
        // Check if response contains user data
        if (data.containsKey('User')) {
          // Save user info
          await _saveUserInfo(data);
          
          // Save user pic if available
          if (data.containsKey('UserPic') && data['UserPic'] != null) {
            await _saveUserPic(data['UserPic']);
          }
          
          return {'success': true, 'data': data};
        }
        
        return {'success': false, 'message': AppStrings.invalidResponseFormat};
      } else {
        return {'success': false, 'message': '${AppStrings.serverError}${response.statusCode}'};
      }
    } catch (e) {
      debugPrint('Error getting user profile: $e');
      return {'success': false, 'message': '${AppStrings.networkError}$e'};
    }
  }
  
  // Get user awards from RetroAchievements API
  static Future<Map<String, dynamic>> getUserAwards(String username, String apiKey) async {
    try {
      final url = '${ApiConstants.baseUrl}${ApiConstants.getUserAwards}?u=$username&y=$apiKey';
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        
        // Save user awards info
        await _saveUserAwards(data);
        
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': '${AppStrings.serverError}${response.statusCode}'};
      }
    } catch (e) {
      debugPrint('Error getting user awards: $e');
      return {'success': false, 'message': '${AppStrings.networkError}$e'};
    }
  }
  
  // Get user completion progress from RetroAchievements API
  static Future<Map<String, dynamic>> getUserCompletionProgress(String username, String apiKey) async {
    try {
      final url = '${ApiConstants.baseUrl}${ApiConstants.getUserCompletionProgress}?u=$username&c=500&y=$apiKey';
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        
        // Save user completion progress
        await _saveUserCompletionProgress(data);
        
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': '${AppStrings.serverError}${response.statusCode}'};
      }
    } catch (e) {
      debugPrint('Error getting user completion progress: $e');
      return {'success': false, 'message': '${AppStrings.networkError}$e'};
    }
  }
  

static Future<List<dynamic>?> getPlatformsList() async {
  try {
    // First try to load from saved file
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/platforms_list.json');
    
    if (await file.exists()) {
      final jsonString = await file.readAsString();
      debugPrint('Loaded platforms from file: ${jsonString.substring(0, min(200, jsonString.length))}...');
      return json.decode(jsonString);
    }
    
    // If no saved file and no login data, return fallback platforms
    return createFallbackPlatforms();
  } catch (e) {
    debugPrint('Error getting platforms list: $e');
    return createFallbackPlatforms();
  }
}

// Create fallback platforms for testing when API fails
static List<dynamic> createFallbackPlatforms() {
  final fallbackPlatforms = [
    {
      "ID": 1,
      "Name": "Mega Drive",
      "IconURL": "https://static.retroachievements.org/assets/images/system/md.png",
      "Active": true,
      "IsGameSystem": true
    },
    {
      "ID": 3,
      "Name": "SNES",
      "IconURL": "https://static.retroachievements.org/assets/images/system/snes.png",
      "Active": true,
      "IsGameSystem": true
    },
    {
      "ID": 4,
      "Name": "Nintendo 64",
      "IconURL": "https://static.retroachievements.org/assets/images/system/n64.png",
      "Active": true,
      "IsGameSystem": true
    },
    {
      "ID": 7,
      "Name": "NES",
      "IconURL": "https://static.retroachievements.org/assets/images/system/nes.png",
      "Active": true,
      "IsGameSystem": true
    },
    {
      "ID": 18,
      "Name": "PlayStation",
      "IconURL": "https://static.retroachievements.org/assets/images/system/ps1.png",
      "Active": true,
      "IsGameSystem": true
    },
    {
      "ID": 12,
      "Name": "Game Boy Advance",
      "IconURL": "https://static.retroachievements.org/assets/images/system/gba.png",
      "Active": true,
      "IsGameSystem": true
    },
    {
      "ID": 11,
      "Name": "Game Boy / Color",
      "IconURL": "https://static.retroachievements.org/assets/images/system/gb.png",
      "Active": true,
      "IsGameSystem": true
    },
    {
      "ID": 2,
      "Name": "Nintendo GameCube",
      "IconURL": "https://static.retroachievements.org/assets/images/system/gc.png",
      "Active": true,
      "IsGameSystem": true
    }
  ];
  
  try {
    _savePlatformsList(fallbackPlatforms);
  } catch (e) {
    debugPrint('Error saving fallback platforms: $e');
  }
  
  return fallbackPlatforms;
}

// Save platforms list to file
static Future<void> _savePlatformsList(List<dynamic> platforms) async {
  try {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/platforms_list.json');
    await file.writeAsString(json.encode(platforms));
    debugPrint('Platforms list saved successfully');
  } catch (e) {
    debugPrint('Error saving platforms list: $e');
  }
}

  // Save user info to local file
  static Future<void> _saveUserInfo(Map<String, dynamic> userData) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/user_info.json');
      await file.writeAsString(json.encode(userData));
      debugPrint('User info saved successfully');
    } catch (e) {
      debugPrint('Error saving user info: $e');
    }
  }
  
  // Save user awards to local file
  static Future<void> _saveUserAwards(Map<String, dynamic> awardsData) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/user_awards.json');
      await file.writeAsString(json.encode(awardsData));
      debugPrint('User awards saved successfully');
    } catch (e) {
      debugPrint('Error saving user awards: $e');
    }
  }
  
  // Save user completion progress to local file
  static Future<void> _saveUserCompletionProgress(Map<String, dynamic> progressData) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/user_completion_progress.json');
      await file.writeAsString(json.encode(progressData));
      debugPrint('User completion progress saved successfully');
    } catch (e) {
      debugPrint('Error saving user completion progress: $e');
    }
  }
  
  // Save user pic to local file
  static Future<void> _saveUserPic(String picPath) async {
    try {
      if (picPath.isEmpty) return;
      
      // Get full URL of the user pic
      final picUrl = '${ApiConstants.baseUrl}$picPath';
      final response = await http.get(Uri.parse(picUrl));
      
      if (response.statusCode == 200) {
        final directory = await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/user_pic.png');
        await file.writeAsBytes(response.bodyBytes);
        debugPrint('User pic saved successfully');
      }
    } catch (e) {
      debugPrint('Error saving user pic: $e');
    }
  }
  
  // Get saved user info
  static Future<Map<String, dynamic>?> getSavedUserInfo() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/user_info.json');
      
      if (await file.exists()) {
        final jsonString = await file.readAsString();
        return json.decode(jsonString);
      }
      
      return null;
    } catch (e) {
      debugPrint('Error getting saved user info: $e');
      return null;
    }
  }
  
  // Get saved user awards
  static Future<Map<String, dynamic>?> getSavedUserAwards() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/user_awards.json');
      
      if (await file.exists()) {
        final jsonString = await file.readAsString();
        return json.decode(jsonString);
      }
      
      return null;
    } catch (e) {
      debugPrint('Error getting saved user awards: $e');
      return null;
    }
  }
  
  // Get saved user completion progress
  static Future<Map<String, dynamic>?> getSavedUserCompletionProgress() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/user_completion_progress.json');
      
      if (await file.exists()) {
        final jsonString = await file.readAsString();
        return json.decode(jsonString);
      }
      
      return null;
    } catch (e) {
      debugPrint('Error getting saved user completion progress: $e');
      return null;
    }
  }
  
  // Get path to saved user pic
  static Future<String?> getUserPicPath() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/user_pic.png');
      
      if (await file.exists()) {
        return file.path;
      }
      
      return null;
    } catch (e) {
      debugPrint('Error getting user pic path: $e');
      return null;
    }
  }
  


// Add this method to ApiService class in api_calls.dart
static Future<List<dynamic>> getConsolesList(String apiKey) async {
  try {
    // First try to load from saved file
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/consoles_list.json');
    
    if (await file.exists()) {
      final jsonString = await file.readAsString();
      debugPrint('Loaded consoles from file: ${jsonString.substring(0, min(200, jsonString.length))}...');
      return json.decode(jsonString);
    }
    
    // If no saved file, fetch from API
    final url = '${ApiConstants.baseUrl}${ApiConstants.getConsoleIDs}?y=$apiKey';
    debugPrint('Fetching consoles from URL: $url');
    
    final response = await http.get(Uri.parse(url));
    
    debugPrint('API response status code: ${response.statusCode}');
    
    if (response.statusCode == 200) {
      final List<dynamic> consoles = json.decode(response.body);
      
      if (consoles.isNotEmpty) {
        // Save the consoles list for offline access
        await _saveConsolesList(consoles);
        return consoles;
      }
    }
    
    // If API call fails, use fallback
    return createFallbackConsoles();
  } catch (e) {
    debugPrint('Error getting consoles list: $e');
    return createFallbackConsoles();
  }
}

// Add this helper method to save consoles list
static Future<void> _saveConsolesList(List<dynamic> consoles) async {
  try {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/consoles_list.json');
    await file.writeAsString(json.encode(consoles));
    debugPrint('Consoles list saved successfully');
  } catch (e) {
    debugPrint('Error saving consoles list: $e');
  }
}

// Update the createFallbackConsoles method to match the API response format
static List<dynamic> createFallbackConsoles() {
  final fallbackConsoles = [
    {
      "ID": 1,
      "Name": "Mega Drive",
      "IconURL": "https://static.retroachievements.org/assets/images/system/md.png",
      "Active": true,
      "IsGameSystem": true
    },
    {
      "ID": 3,
      "Name": "SNES",
      "IconURL": "https://static.retroachievements.org/assets/images/system/snes.png",
      "Active": true,
      "IsGameSystem": true
    },
    // Keep other fallback consoles as needed
  ];
  
  try {
    _saveConsolesList(fallbackConsoles);
  } catch (e) {
    debugPrint('Error saving fallback consoles: $e');
  }
  
  return fallbackConsoles;
}

// Get user recent achievements from RetroAchievements API
static Future<Map<String, dynamic>> getUserRecentAchievements(String username, String apiKey) async {
  try {
    final url = '${ApiConstants.baseUrl}${ApiConstants.getUserRecentAchievements}?u=$username&y=$apiKey';
    final response = await http.get(Uri.parse(url));
    
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return {'success': true, 'data': data};
    } else {
      return {'success': false, 'message': '${AppStrings.serverError}${response.statusCode}'};
    }
  } catch (e) {
    debugPrint('Error getting user recent achievements: $e');
    return {'success': false, 'message': '${AppStrings.networkError}$e'};
  }
}

// Get user progress
static Future<Map<String, dynamic>> getUserProgress(String username, String apiKey) async {
  try {
    final url = '${ApiConstants.baseUrl}${ApiConstants.getUserProgress}?u=$username&y=$apiKey';
    final response = await http.get(Uri.parse(url));
    
    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      return {'success': true, 'data': data};
    } else {
      return {'success': false, 'message': '${AppStrings.serverError}${response.statusCode}'};
    }
  } catch (e) {
    debugPrint('Error getting user progress: $e');
    return {'success': false, 'message': '${AppStrings.networkError}$e'};
  }
}

// Get user game completion
static Future<Map<String, dynamic>> getUserGameCompletion(String username, int gameId, String apiKey) async {
  try {
    final url = '${ApiConstants.baseUrl}${ApiConstants.getUserGameCompletion}?u=$username&g=$gameId&y=$apiKey';
    final response = await http.get(Uri.parse(url));
    
    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      return {'success': true, 'data': data};
    } else {
      return {'success': false, 'message': '${AppStrings.serverError}${response.statusCode}'};
    }
  } catch (e) {
    debugPrint('Error getting user game completion: $e');
    return {'success': false, 'message': '${AppStrings.networkError}$e'};
  }
}

// Get game info and user progress
static Future<Map<String, dynamic>> getGameInfoAndUserProgress(String username, int gameId, String apiKey) async {
  try {
    final url = '${ApiConstants.baseUrl}${ApiConstants.getGameInfoAndUserProgress}?u=$username&g=$gameId&y=$apiKey';
    final response = await http.get(Uri.parse(url));
    
    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      return {'success': true, 'data': data};
    } else {
      return {'success': false, 'message': '${AppStrings.serverError}${response.statusCode}'};
    }
  } catch (e) {
    debugPrint('Error getting game info and user progress: $e');
    return {'success': false, 'message': '${AppStrings.networkError}$e'};
  }
}

// Get achievement count
static Future<Map<String, dynamic>> getAchievementCount(String apiKey) async {
  try {
    final url = '${ApiConstants.baseUrl}${ApiConstants.getAchievementCount}?y=$apiKey';
    final response = await http.get(Uri.parse(url));
    
    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      return {'success': true, 'data': data};
    } else {
      return {'success': false, 'message': '${AppStrings.serverError}${response.statusCode}'};
    }
  } catch (e) {
    debugPrint('Error getting achievement count: $e');
    return {'success': false, 'message': '${AppStrings.networkError}$e'};
  }
}



// Get user summary from RetroAchievements API
static Future<Map<String, dynamic>> getUserSummary(String username, String apiKey) async {
  try {
    final url = '${ApiConstants.baseUrl}${ApiConstants.getUserSummary}?u=$username&g=10&a=10&y=$apiKey';
    final response = await http.get(Uri.parse(url));
    
    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      return {'success': true, 'data': data};
    } else {
      return {'success': false, 'message': '${AppStrings.serverError}${response.statusCode}'};
    }
  } catch (e) {
    debugPrint('Error getting user summary: $e');
    return {'success': false, 'message': '${AppStrings.networkError}$e'};
  }
}

// Get game details from RetroAchievements API
static Future<Map<String, dynamic>> getGameData(String apiKey, int gameId) async {
  try {
    final url = '${ApiConstants.baseUrl}${ApiConstants.getGame}?i=$gameId&y=$apiKey';
    final response = await http.get(Uri.parse(url));
    
    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      return {'success': true, 'data': data};
    } else {
      return {'success': false, 'message': '${AppStrings.serverError}${response.statusCode}'};
    }
  } catch (e) {
    debugPrint('Error getting game data: $e');
    return {'success': false, 'message': '${AppStrings.networkError}$e'};
  }
}

// Get extended game details from RetroAchievements API
static Future<Map<String, dynamic>> getGameExtendedData(String apiKey, int gameId) async {
  try {
    final url = '${ApiConstants.baseUrl}${ApiConstants.getGameExtended}?i=$gameId&y=$apiKey';
    final response = await http.get(Uri.parse(url));
    
    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      return {'success': true, 'data': data};
    } else {
      return {'success': false, 'message': '${AppStrings.serverError}${response.statusCode}'};
    }
  } catch (e) {
    debugPrint('Error getting extended game data: $e');
    return {'success': false, 'message': '${AppStrings.networkError}$e'};
  }
}

// Get game hashes from RetroAchievements API
static Future<Map<String, dynamic>> getGameHashes(String apiKey, int gameId) async {
  try {
    final url = '${ApiConstants.baseUrl}${ApiConstants.getGameHashes}?i=$gameId&y=$apiKey';
    final response = await http.get(Uri.parse(url));
    
    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      return {'success': true, 'data': data};
    } else {
      return {'success': false, 'message': '${AppStrings.serverError}${response.statusCode}'};
    }
  } catch (e) {
    debugPrint('Error getting game hashes: $e');
    return {'success': false, 'message': '${AppStrings.networkError}$e'};
  }
}


  // Get game icon from RetroAchievements and save it locally
  static Future<String?> getGameIcon(String iconPath, int gameId) async {
    try {
      if (iconPath.isEmpty) return null;
      
      // Check if already downloaded
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/game_icon_$gameId.png');
      
      if (await file.exists()) {
        return file.path;
      }
      
      // Download icon
      final iconUrl = '${ApiConstants.baseUrl}$iconPath';
      final response = await http.get(Uri.parse(iconUrl));
      
      if (response.statusCode == 200) {
        await file.writeAsBytes(response.bodyBytes);
        return file.path;
      }
      
      return null;
    } catch (e) {
      debugPrint('Error getting game icon: $e');
      return null;
    }
  }
}