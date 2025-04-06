// lib/providers/hash_service_provider.dart

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:http/http.dart' as http;

part 'hash_service_provider.g.dart';

@riverpod
class HashServiceProvider extends _$HashServiceProvider {
  final Map<String, Map<String, String>> _consoleHashes = {};
  final Map<String, List<String>> _consoleDirectories = {};
  
  @override
  Future<void> build() async {
    // Initialize provider
    debugPrint('[HashServiceProvider] Initializing');
  }
  
  // Calculate MD5 hash for a file
  Future<String> calculateMD5(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final digest = md5.convert(bytes);
      return digest.toString();
    } catch (e) {
      debugPrint('[HashServiceProvider] Error calculating MD5: $e');
      return '';
    }
  }
  
  // Check if a file is a ROM based on extension
  bool isRomFile(String filename) {
    final extension = filename.toLowerCase().split('.').last;
    
    // Common ROM extensions
    final romExtensions = [
      'rom', 'bin', 'md', 'sms', 'gg', 'sfc', 'smc', 'nes', 'n64', 'z64', 'v64',
      'gb', 'gbc', 'gba', 'nds', '32x', 'col', 'iso', 'cue', 'pce', 'vb', 'ws', 'wsc',
      'vgm', 'jag', 'lnx', 'ngp', 'ngc', 'pce', 'sg', 'st', '7z', 'zip', 'chd', 'vec', 'dsk', 
      'do', 'woz', 'a26', 'a78', 'j64', 'col', 'gg', 'gen', 'int', 'rom', 'ngp', 'ngc', 
      'd88', 'min', 'sg', 'vb', 'sv', 'wasm', 'ws', 'wsc'
    ];
    
    return romExtensions.contains(extension);
  }
  
  // Calculate MD5 hashes for all files in multiple directories
  Future<Map<String, String>> calculateDirectoriesHashes(List<String> directoryPaths) async {
    final Map<String, String> fileHashes = {};
    
    for (final directoryPath in directoryPaths) {
      try {
        debugPrint('[HashServiceProvider] Processing directory: $directoryPath');
        
        final directory = Directory(directoryPath);
        if (await directory.exists()) {
          // Get all files in the directory (and subdirectories)
          final List<FileSystemEntity> entities = await directory
              .list(recursive: true)
              .where((entity) => entity is File)
              .toList();
          
          debugPrint('[HashServiceProvider] Found ${entities.length} files in $directoryPath');
          
          // Process each file
          for (var entity in entities) {
            if (entity is File) {
              try {
                // Get filename without path
                final filename = entity.path.split('/').last;
                
                // Only hash ROM files based on extension
                if (isRomFile(filename)) {
                  final hash = await calculateMD5(entity);
                  if (hash.isNotEmpty) {
                    fileHashes[filename] = hash;
                  }
                }
              } catch (fileError) {
                debugPrint('[HashServiceProvider] Error hashing file ${entity.path}: $fileError');
              }
            }
          }
        } else {
          debugPrint('[HashServiceProvider] Directory does not exist: $directoryPath');
        }
      } catch (e) {
        debugPrint('[HashServiceProvider] Error processing directory $directoryPath: $e');
      }
    }
    
    debugPrint('[HashServiceProvider] Generated ${fileHashes.length} hashes from all directories');
    return fileHashes;
  }
  
  // Get console directories with caching
  Future<List<String>> getConsoleDirectories(String consoleName) async {
    final normalizedName = consoleName.toLowerCase().trim();
    
    if (_consoleDirectories.containsKey(normalizedName)) {
      debugPrint('[HashServiceProvider] Returning cached directories for $normalizedName');
      return _consoleDirectories[normalizedName]!;
    }
    
    debugPrint('[HashServiceProvider] Loading directories for $normalizedName from storage');
    final directories = await loadConsoleDirectories(consoleName);
    _consoleDirectories[normalizedName] = directories;
    return directories;
  }
  
  // Load console directories from storage
  Future<List<String>> loadConsoleDirectories(String consoleName) async {
    try {
      // Normalize the console name to avoid case sensitivity issues
      final normalizedName = consoleName.toLowerCase().trim();
      
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/console_directories.json');
      
      if (await file.exists()) {
        final jsonString = await file.readAsString();
        final Map<String, dynamic> directoriesMap = json.decode(jsonString);
        
        if (directoriesMap.containsKey(normalizedName)) {
          if (directoriesMap[normalizedName] is List) {
            return List<String>.from(directoriesMap[normalizedName]);
          } else if (directoriesMap[normalizedName] is String) {
            // Handle legacy format (single string)
            return [directoriesMap[normalizedName]];
          }
        }
      }
      
      return [];
    } catch (e) {
      debugPrint('[HashServiceProvider] Error loading console directories: $e');
      return [];
    }
  }
  
  // Get a specific console directory (first one if multiple exist)
  Future<String?> getConsoleDirectory(String consoleName) async {
    final directories = await getConsoleDirectories(consoleName);
    return directories.isNotEmpty ? directories.first : null;
  }
  
  // Get hashes for a specific console with caching
  Future<Map<String, String>> getConsoleHashes(String consoleName) async {
    final normalizedName = consoleName.toLowerCase().trim();
    
    if (_consoleHashes.containsKey(normalizedName)) {
      debugPrint('[HashServiceProvider] Returning cached hashes for $normalizedName');
      return _consoleHashes[normalizedName]!;
    }
    
    debugPrint('[HashServiceProvider] Loading hashes for $normalizedName from storage');
    final hashes = await loadHashes(consoleName);
    _consoleHashes[normalizedName] = hashes;
    return hashes;
  }
  
  // Load hashes from a local file
  Future<Map<String, String>> loadHashes(String consoleName) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/${consoleName.toLowerCase().replaceAll(' ', '_')}_hashes.json');
      
      if (await file.exists()) {
        final jsonString = await file.readAsString();
        final Map<String, dynamic> decoded = json.decode(jsonString);
        
        // Convert Map<String, dynamic> to Map<String, String>
        final Map<String, String> hashes = {};
        decoded.forEach((key, value) {
          hashes[key] = value.toString();
        });
        
        return hashes;
      }
      
      return {};
    } catch (e) {
      debugPrint('[HashServiceProvider] Error loading hashes: $e');
      return {};
    }
  }
  
  // Save console ROM directory paths
  Future<void> saveConsoleDirectories(String consoleName, List<String> directoryPaths) async {
    try {
      // Ensure inputs are valid
      if (consoleName.isEmpty) {
        debugPrint('[HashServiceProvider] Cannot save directories: Console name is empty');
        return;
      }
      
      if (directoryPaths.isEmpty) {
        debugPrint('[HashServiceProvider] Warning: Saving empty directory list for $consoleName');
      }
      
      // Normalize the console name to avoid case sensitivity issues
      final normalizedName = consoleName.toLowerCase().trim();
      
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/console_directories.json');
      
      Map<String, dynamic> directories = {};
      
      // Load existing directories if the file exists
      if (await file.exists()) {
        try {
          final jsonString = await file.readAsString();
          directories = json.decode(jsonString);
        } catch (e) {
          debugPrint('[HashServiceProvider] Error reading existing directories file, creating new one: $e');
          // Continue with empty map if file is corrupted
        }
      }
      
      // Add or update the directories for this console
      directories[normalizedName] = directoryPaths;
      
      // Save the updated directories
      final jsonString = json.encode(directories);
      await file.writeAsString(jsonString);
      
      // Update cache
      _consoleDirectories[normalizedName] = directoryPaths;
      
      debugPrint('[HashServiceProvider] Console directories saved for $normalizedName: $directoryPaths');
    } catch (e) {
      debugPrint('[HashServiceProvider] Error saving console directories: $e');
    }
  }
  
  // Save hashes to a local file
  Future<void> saveConsoleHashes(String consoleName, Map<String, String> hashes) async {
    try {
      final normalizedName = consoleName.toLowerCase().trim();
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/${normalizedName.replaceAll(' ', '_')}_hashes.json');
      
      await file.writeAsString(json.encode(hashes));
      _consoleHashes[normalizedName] = hashes;
      
      debugPrint('[HashServiceProvider] Hashes saved successfully for $consoleName');
    } catch (e) {
      debugPrint('[HashServiceProvider] Error saving hashes: $e');
    }
  }
  
  // Match games with hashes
  Map<String, List<String>> matchGamesWithHashes(
    List<dynamic> games, 
    Map<String, String> localHashes
  ) {
    final Map<String, List<String>> matchedGames = {};
    final localHashValues = localHashes.values.toList();
    
    for (var game in games) {
      if (game['Hashes'] != null && game['Hashes'] is List) {
        final List<String> gameHashes = List<String>.from(game['Hashes']);
        final List<String> matchedHashes = [];
        
        for (var hash in gameHashes) {
          if (localHashValues.contains(hash)) {
            matchedHashes.add(hash);
          }
        }
        
        if (matchedHashes.isNotEmpty) {
          matchedGames[game['ID'].toString()] = matchedHashes;
        }
      }
    }
    
    return matchedGames;
  }
  
  // Fetch the game list from RetroAchievements API
  Future<List<dynamic>> fetchGameList(String apiKey, int consoleId) async {
    debugPrint('[HashServiceProvider] Starting fetchGameList for console ID $consoleId');
    try {
      final url = 'https://retroachievements.org/API/API_GetGameList.php?i=$consoleId&h=1&f=1&y=$apiKey';
      debugPrint('[HashServiceProvider] Making API request to: $url');
      
      final response = await http.get(Uri.parse(url));
      
      debugPrint('[HashServiceProvider] API Response Status: ${response.statusCode}');
      if (response.statusCode == 200) {
        // Debug the raw response to check its format
        debugPrint('[HashServiceProvider] Raw response (first 200 chars): ${response.body.substring(0, min(200, response.body.length))}...');
        
        // Try to decode the response
        try {
          final List<dynamic> games = json.decode(response.body);
          debugPrint('[HashServiceProvider] Successfully decoded games: ${games.length}');
          
          // Save the game list for offline access
          await saveGameList(games, consoleId);
          
          return games;
        } catch (decodeError) {
          debugPrint('[HashServiceProvider] JSON decode error: $decodeError');
          debugPrint('[HashServiceProvider] Response is not a valid JSON array.');
          throw Exception('Invalid API response format: $decodeError');
        }
      } else {
        debugPrint('[HashServiceProvider] Error fetching game list: HTTP ${response.statusCode}');
        
        // Try to load saved game list if fetch fails
        final savedGames = await loadSavedGameList(consoleId);
        if (savedGames.isNotEmpty) {
          debugPrint('[HashServiceProvider] Returning ${savedGames.length} saved games as fallback');
          return savedGames;
        }
        
        throw Exception('Failed to fetch game list: HTTP ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[HashServiceProvider] Exception in fetchGameList: $e');
      
      // Try to load saved game list if fetch fails
      try {
        final savedGames = await loadSavedGameList(consoleId);
        if (savedGames.isNotEmpty) {
          debugPrint('[HashServiceProvider] Returning ${savedGames.length} saved games as fallback after exception');
          return savedGames;
        }
      } catch (loadError) {
        debugPrint('[HashServiceProvider] Error loading saved games: $loadError');
      }
      
      throw Exception('Failed to fetch game list: $e');
    }
  }
  
  // Save the game list to a local file
  Future<void> saveGameList(List<dynamic> games, int consoleId) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/game_list_$consoleId.json');
      
      await file.writeAsString(json.encode(games));
      debugPrint('[HashServiceProvider] Game list saved for console ID $consoleId');
    } catch (e) {
      debugPrint('[HashServiceProvider] Error saving game list: $e');
    }
  }
  
  // Load the saved game list
  Future<List<dynamic>> loadSavedGameList(int consoleId) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/game_list_$consoleId.json');
      
      if (await file.exists()) {
        final jsonString = await file.readAsString();
        final List<dynamic> games = json.decode(jsonString);
        debugPrint('[HashServiceProvider] Loaded ${games.length} saved games for console ID $consoleId');
        return games;
      }
      
      return [];
    } catch (e) {
      debugPrint('[HashServiceProvider] Error loading saved game list: $e');
      return [];
    }
  }
  
  // Test API connection
  Future<bool> testApiConnection(String apiKey) async {
    try {
      // Use a simple endpoint that doesn't require heavy processing
      final url = 'https://retroachievements.org/API/API_GetConsoleIDs.php?y=$apiKey';
      debugPrint('[HashServiceProvider] Testing API connection with URL: $url');
      
      final response = await http.get(Uri.parse(url));
      
      debugPrint('[HashServiceProvider] Test API connection response code: ${response.statusCode}');
      if (response.statusCode == 200) {
        debugPrint('[HashServiceProvider] Response body (first 100 chars): ${response.body.substring(0, min(100, response.body.length))}...');
        return true;
      } else {
        debugPrint('[HashServiceProvider] API test failed with status code: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('[HashServiceProvider] Test API connection failed with exception: $e');
      return false;
    }
  }
  
  // Clear cache for a specific console
  void clearConsoleCache(String consoleName) {
    final normalizedName = consoleName.toLowerCase().trim();
    _consoleHashes.remove(normalizedName);
    _consoleDirectories.remove(normalizedName);
    debugPrint('[HashServiceProvider] Cleared cache for $normalizedName');
  }
  
  // Clear all caches
  void clearAllCaches() {
    _consoleHashes.clear();
    _consoleDirectories.clear();
    debugPrint('[HashServiceProvider] Cleared all caches');
  }
  
  // Refresh all cached data for a console
  Future<void> refreshConsoleData(String consoleName, List<String> directories) async {
    final normalizedName = consoleName.toLowerCase().trim();
    debugPrint('[HashServiceProvider] Full refresh for $normalizedName');
    
    // Calculate fresh hashes
    final hashes = await calculateDirectoriesHashes(directories);
    
    // Save new data
    await saveConsoleHashes(consoleName, hashes);
    await saveConsoleDirectories(consoleName, directories);
    
    // Update cache
    _consoleHashes[normalizedName] = hashes;
    _consoleDirectories[normalizedName] = directories;
    
    // Notify all listeners that data has changed
    ref.notifyListeners();
  }
}