// lib/providers/game_provider.dart

import 'package:flutter/material.dart';
import 'package:retroachievements_organizer/providers/api_service_provider.dart';
import 'package:retroachievements_organizer/providers/hash_service_provider.dart';
import 'package:retroachievements_organizer/providers/user_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'game_provider.g.dart';

class GameState {
  final bool isLoading;
  final String? errorMessage;
  final int consoleId;
  final String consoleName;
  final List<dynamic> games;
  final Map<String, String> localHashes;
  final Map<String, List<String>> matchedGames;
  final List<String> romsDirectories;
  final Map<int, String?> gameIconPaths;

  GameState({
    this.isLoading = false,
    this.errorMessage,
    this.consoleId = 0,
    this.consoleName = '',
    this.games = const [],
    this.localHashes = const {},
    this.matchedGames = const {},
    this.romsDirectories = const [],
    this.gameIconPaths = const {},
  });

  GameState copyWith({
    bool? isLoading,
    String? errorMessage,
    int? consoleId,
    String? consoleName,
    List<dynamic>? games,
    Map<String, String>? localHashes,
    Map<String, List<String>>? matchedGames,
    List<String>? romsDirectories,
    Map<int, String?>? gameIconPaths,
  }) {
    return GameState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
      consoleId: consoleId ?? this.consoleId,
      consoleName: consoleName ?? this.consoleName,
      games: games ?? this.games,
      localHashes: localHashes ?? this.localHashes,
      matchedGames: matchedGames ?? this.matchedGames,
      romsDirectories: romsDirectories ?? this.romsDirectories,
      gameIconPaths: gameIconPaths ?? this.gameIconPaths,
    );
  }
}

@riverpod
class Games extends _$Games {
  @override
  GameState build({int consoleId = 0, String consoleName = ''}) {
    return GameState(
      consoleId: consoleId,
      consoleName: consoleName,
    );
  }

Future<void> loadGames({bool forceRefresh = false}) async {
  if (state.consoleId == 0) return;
  
  debugPrint('[GamesProvider] Starting loadGames for console ${state.consoleId} (${state.consoleName})');
  
  state = state.copyWith(isLoading: true, errorMessage: null);
  
  try {
    // Get API key from user provider
    final apiKey = await ref.read(userProvider.notifier).getApiKey();
    debugPrint('[GamesProvider] API key retrieved: ${apiKey != null ? "Yes" : "No"}');
    
    if (apiKey == null) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'No API key available. Please login again.',
      );
      return;
    }
    
    // Use hash service provider to get ROM directories
    final hashProvider = ref.read(hashServiceProviderProvider.notifier);
    final directories = await hashProvider.getConsoleDirectories(state.consoleName);
    debugPrint('[GamesProvider] ROM directories: ${directories.length}');
    
    state = state.copyWith(romsDirectories: directories);
    
    // Try to load saved game list first
    List<dynamic> games = [];
    if (!forceRefresh) {
      debugPrint('[GamesProvider] Attempting to load saved game list');
      final hashProvider = ref.read(hashServiceProviderProvider.notifier);
      final games = await hashProvider.loadSavedGameList(consoleId);
      debugPrint('[GamesProvider] Saved games loaded: ${games.length}');
    }
    
    if (!forceRefresh && games.isNotEmpty) {
      // Use saved games
      debugPrint('[GamesProvider] Using saved game list with ${games.length} games');
    } else {
      // Fetch from API
      debugPrint('[GamesProvider] Fetching game list from API for console ${state.consoleId}');
      try {
        final hashProvider = ref.read(hashServiceProviderProvider.notifier);
        games = await hashProvider.fetchGameList(apiKey, state.consoleId);
        debugPrint('[GamesProvider] Fetched ${games.length} games from API');
      } catch (apiError) {
        debugPrint('[GamesProvider] API fetch failed: $apiError');
        // If direct fetch fails, try with API provider
        final apiProvider = ref.read(apiServiceProviderProvider.notifier);
        games = await apiProvider.getGameList(apiKey, state.consoleId);
        debugPrint('[GamesProvider] Fetched ${games.length} games via provider');
      }
    }
    
    // Set games
    state = state.copyWith(games: games);
    debugPrint('[GamesProvider] Updated state with ${games.length} games');
    
    // If we have directories and games, match hashes
    if (directories.isNotEmpty && games.isNotEmpty) {
      Map<String, String> localHashes;
      
      if (forceRefresh || state.localHashes.isEmpty) {
        debugPrint('[GamesProvider] Calculating hashes for ${directories.length} directories');
        localHashes = await hashProvider.calculateDirectoriesHashes(directories);
        await hashProvider.saveConsoleHashes(state.consoleName, localHashes);
      } else {
        debugPrint('[GamesProvider] Loading saved hashes');
        localHashes = await hashProvider.getConsoleHashes(state.consoleName);
      }
      
      if (localHashes.isNotEmpty) {
        debugPrint('[GamesProvider] Matching ${games.length} games with ${localHashes.length} hashes');
        final matchedGames = hashProvider.matchGamesWithHashes(games, localHashes);
        
        state = state.copyWith(
          localHashes: localHashes,
          matchedGames: matchedGames,
        );
        
        debugPrint('[GamesProvider] Matched ${matchedGames.length} games with local ROMs');
      }
    }
    
    // Update loading state
    state = state.copyWith(isLoading: false);
    debugPrint('[GamesProvider] Finished loading games');
    
  } catch (e, stackTrace) {
    debugPrint('[GamesProvider] Error in loadGames: $e');
    debugPrint('[GamesProvider] Stack trace: $stackTrace');
    state = state.copyWith(
      errorMessage: 'Error loading games: $e',
      isLoading: false,
    );
  }
}

  
  Future<String?> getGameIcon(int gameId, String iconPath) async {
    // Check cache first
    if (state.gameIconPaths.containsKey(gameId)) {
      return state.gameIconPaths[gameId];
    }
    
    // Otherwise fetch and cache
    final apiProvider = ref.read(apiServiceProviderProvider.notifier);
    final localPath = await apiProvider.getGameIcon(iconPath, gameId);
    
    final updatedIconPaths = Map<int, String?>.from(state.gameIconPaths);
    updatedIconPaths[gameId] = localPath;
    
    state = state.copyWith(gameIconPaths: updatedIconPaths);
    
    return localPath;
  }
  
  Future<void> setRomsDirectories(List<String> directories) async {
    try {
      // Use hash service provider
      final hashProvider = ref.read(hashServiceProviderProvider.notifier);
      await hashProvider.saveConsoleDirectories(state.consoleName, directories);
      
      state = state.copyWith(romsDirectories: directories);
      
      // Process directories to get hash matches, but don't force refresh games
      if (directories.isNotEmpty) {
        // Calculate hashes
        final localHashes = await hashProvider.calculateDirectoriesHashes(directories);
        await hashProvider.saveConsoleHashes(state.consoleName, localHashes);
        
        // Match with existing games
        final matchedGames = hashProvider.matchGamesWithHashes(state.games, localHashes);
        
        state = state.copyWith(
          localHashes: localHashes,
          matchedGames: matchedGames,
        );
      }
    } catch (e) {
      debugPrint('Error setting ROMs directories: $e');
      state = state.copyWith(
        errorMessage: 'Failed to set ROM directories: $e',
      );
    }
  }
  
  // Batch load game icons for performance
  Future<void> batchLoadGameIcons(List<int> gameIds) async {
    final apiProvider = ref.read(apiServiceProviderProvider.notifier);
    final updatedIconPaths = Map<int, String?>.from(state.gameIconPaths);
    
    for (final gameId in gameIds) {
      if (!updatedIconPaths.containsKey(gameId)) {
        final game = state.games.firstWhere(
          (g) => g['ID'] == gameId,
          orElse: () => {'ImageIcon': ''},
        );
        
        if (game['ImageIcon'] != null && game['ImageIcon'].isNotEmpty) {
          final localPath = await apiProvider.getGameIcon(game['ImageIcon'], gameId);
          updatedIconPaths[gameId] = localPath;
        }
      }
    }
    
    state = state.copyWith(gameIconPaths: updatedIconPaths);
  }
  
  // Force refresh data
  Future<void> refreshData() async {
  // Force refresh data
  await loadGames(forceRefresh: true);
  
  // Notify anyone who might be observing this provider
  ref.notifyListeners();
}
  
  // Check if a specific hash is matched in our local collection
  bool isHashMatched(String hash) {
    return state.localHashes.values.contains(hash);
  }
  
  // Get the file name for a matched hash
  String? getFileNameForHash(String hash) {
    for (final entry in state.localHashes.entries) {
      if (entry.value == hash) {
        return entry.key;
      }
    }
    return null;
  }
  
  // Get game by ID
  dynamic getGameById(int gameId) {
    return state.games.firstWhere(
      (game) => game['ID'] == gameId,
      orElse: () => null,
    );
  }
}