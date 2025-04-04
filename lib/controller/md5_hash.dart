import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class HashService {
  // Calculate MD5 hash for a file
  static Future<String> calculateMD5(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final digest = md5.convert(bytes);
      return digest.toString();
    } catch (e) {
      debugPrint('Error calculating MD5: $e');
      return '';
    }
  }
  
  // Calculate MD5 hashes for all files in a directory
  static Future<Map<String, String>> calculateDirectoryHashes(String directoryPath) async {
    try {
      final directory = Directory(directoryPath);
      final Map<String, String> fileHashes = {};
      
      if (await directory.exists()) {
        final List<FileSystemEntity> files = await directory.list().toList();
        
        for (var file in files) {
          if (file is File) {
            // Only process files, not directories
            final hash = await calculateMD5(file);
            if (hash.isNotEmpty) {
              fileHashes[file.path.split('/').last] = hash;
            }
          }
        }
      }
      
      return fileHashes;
    } catch (e) {
      debugPrint('Error calculating directory hashes: $e');
      return {};
    }
  }
  
  // Save hashes to a local file
  static Future<void> saveHashes(Map<String, String> hashes, String consoleName) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/${consoleName.toLowerCase().replaceAll(' ', '_')}_hashes.json');
      
      await file.writeAsString(json.encode(hashes));
      debugPrint('Hashes saved successfully for $consoleName');
    } catch (e) {
      debugPrint('Error saving hashes: $e');
    }
  }
  
  // Load hashes from a local file
  static Future<Map<String, String>> loadHashes(String consoleName) async {
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
      debugPrint('Error loading hashes: $e');
      return {};
    }
  }
  
  // Save console ROM directory path
  static Future<void> saveConsoleDirectory(String consoleName, String directoryPath) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/console_directories.json');
      
      Map<String, dynamic> directories = {};
      
      // Load existing directories if the file exists
      if (await file.exists()) {
        final jsonString = await file.readAsString();
        directories = json.decode(jsonString);
      }
      
      // Add or update the directory for this console
      directories[consoleName] = directoryPath;
      
      // Save the updated directories
      await file.writeAsString(json.encode(directories));
      debugPrint('Console directory saved for $consoleName: $directoryPath');
    } catch (e) {
      debugPrint('Error saving console directory: $e');
    }
  }
  
  // Load console ROM directory path
  static Future<String?> getConsoleDirectory(String consoleName) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/console_directories.json');
      
      if (await file.exists()) {
        final jsonString = await file.readAsString();
        final Map<String, dynamic> directories = json.decode(jsonString);
        
        if (directories.containsKey(consoleName)) {
          return directories[consoleName];
        }
      }
      
      return null;
    } catch (e) {
      debugPrint('Error loading console directory: $e');
      return null;
    }
  }
  
  // Fetch the game list from RetroAchievements API
  static Future<List<dynamic>> fetchGameList(String apiKey, int consoleId) async {
    try {
      final url = 'https://retroachievements.org/API/API_GetGameList.php?i=$consoleId&h=1&f=1&y=$apiKey';
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final List<dynamic> games = json.decode(response.body);
        debugPrint('Fetched ${games.length} games for console ID $consoleId');
        
        // Save the game list for offline access
        await _saveGameList(games, consoleId);
        
        return games;
      } else {
        debugPrint('Error fetching game list: ${response.statusCode}');
        
        // Try to load saved game list if fetch fails
        final savedGames = await loadSavedGameList(consoleId);
        if (savedGames.isNotEmpty) {
          return savedGames;
        }
        
        return [];
      }
    } catch (e) {
      debugPrint('Exception fetching game list: $e');
      
      // Try to load saved game list if fetch fails
      final savedGames = await loadSavedGameList(consoleId);
      if (savedGames.isNotEmpty) {
        return savedGames;
      }
      
      return [];
    }
  }
  
  // Save the game list to a local file
  static Future<void> _saveGameList(List<dynamic> games, int consoleId) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/game_list_$consoleId.json');
      
      await file.writeAsString(json.encode(games));
      debugPrint('Game list saved for console ID $consoleId');
    } catch (e) {
      debugPrint('Error saving game list: $e');
    }
  }
  
  // Load the saved game list
  static Future<List<dynamic>> loadSavedGameList(int consoleId) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/game_list_$consoleId.json');
      
      if (await file.exists()) {
        final jsonString = await file.readAsString();
        final List<dynamic> games = json.decode(jsonString);
        debugPrint('Loaded ${games.length} saved games for console ID $consoleId');
        return games;
      }
      
      return [];
    } catch (e) {
      debugPrint('Error loading saved game list: $e');
      return [];
    }
  }
  
  // Check which games from the API match the local ROM hashes
  static Map<String, List<String>> matchGamesWithHashes(
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
}