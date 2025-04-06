// ignore_for_file: use_build_context_synchronously

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:retroachievements_organizer/constants/constants.dart';
import 'package:retroachievements_organizer/controller/api_calls.dart';
import 'package:retroachievements_organizer/providers/game_provider.dart';
import 'package:retroachievements_organizer/providers/hash_service_provider.dart';
import 'package:retroachievements_organizer/providers/user_provider.dart';
import 'package:retroachievements_organizer/view/game_data_view.dart';
import 'package:retroachievements_organizer/widgets/common_widgets.dart';
import 'package:retroachievements_organizer/widgets/pagination_widget.dart';

// Custom notification to signal that we want to go back to games screen
class BackToGamesNotification extends Notification {}

class MD5GamesScreen extends ConsumerStatefulWidget {
  final bool embedded;
  final int consoleId;
  final String consoleName;
  
  const MD5GamesScreen({
    super.key, 
    this.embedded = false,
    required this.consoleId,
    required this.consoleName,
  });

  @override
  ConsumerState<MD5GamesScreen> createState() => _MD5GamesScreenState();
}

class _MD5GamesScreenState extends ConsumerState<MD5GamesScreen> {
  bool _isLoading = true;
  List<dynamic> _games = [];
  Map<String, String> _localHashes = {};
  Map<String, List<String>> _matchedGames = {};
  List<String> _romsDirectories = [];
  
  // Game icons cache
  Map<int, String?> _gameIconPaths = {};

  @override
  void initState() {
    super.initState();
    _loadGames();
  }

 Future<void> _loadGames({bool forceRefresh = false}) async {
  if (!mounted) return;
  
  debugPrint('[MD5GamesScreen] Starting to load games for console ${widget.consoleId} (${widget.consoleName})');
  
  setState(() {
    _isLoading = true;
  });
  
  try {
    // First, attempt to load ROM directories
    final hashProvider = ref.read(hashServiceProviderProvider.notifier);
    _romsDirectories = await hashProvider.getConsoleDirectories(widget.consoleName);
    debugPrint('[MD5GamesScreen] Loaded ${_romsDirectories.length} ROM directories');
    
    // Get API key first to test if authentication is working
    final userProviderRef = ref.read(userProvider.notifier);
    final apiKey = await userProviderRef.getApiKey();
    debugPrint('[MD5GamesScreen] API Key retrieved: ${apiKey != null ? "Yes" : "No"}');
    
    if (apiKey == null) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No API key available. Please login again.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }
    
    // Try to load saved game list first if not forcing refresh
    if (!forceRefresh) {
      final hashProvider = ref.read(hashServiceProviderProvider.notifier);
      final savedGames = await hashProvider.loadSavedGameList(widget.consoleId);
      if (savedGames.isNotEmpty) {
        debugPrint('[MD5GamesScreen] Loaded ${savedGames.length} games from saved list');
        _games = savedGames;
        
        // Also load hashes
        final hashProvider = ref.read(hashServiceProviderProvider.notifier);
        _localHashes = await hashProvider.loadHashes(widget.consoleName);
        
        // Match games with hashes if both exist
        if (_games.isNotEmpty && _localHashes.isNotEmpty) {
          final hashProvider = ref.read(hashServiceProviderProvider.notifier);
          _matchedGames = hashProvider.matchGamesWithHashes(_games, _localHashes);
          debugPrint('[MD5GamesScreen] Matched ${_matchedGames.length} games with local ROMs');
        }
        
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
        return;
      }
    }
    
    // If no saved games or forcing refresh, fetch from API
    debugPrint('[MD5GamesScreen] Fetching games from API for console ${widget.consoleId}');
    try {
      final hashProvider = ref.read(hashServiceProviderProvider.notifier);
      final games = await hashProvider.fetchGameList(apiKey, widget.consoleId);
      if (games.isEmpty) {
        throw Exception('No games returned from API');
      }
      _games = games;
      debugPrint('[MD5GamesScreen] Successfully fetched ${games.length} games from API');
      
      // Process directories if we have any
      if (_romsDirectories.isNotEmpty) {
        await _processDirectories(_romsDirectories, forceRefresh: forceRefresh);
      }
    } catch (apiError) {
      debugPrint('[MD5GamesScreen] API fetch failed: $apiError');
      // Try one more time with provider
      try {
        final gamesNotifier = ref.read(gamesProvider(
          consoleId: widget.consoleId,
          consoleName: widget.consoleName,
        ).notifier);
        
        await gamesNotifier.loadGames(forceRefresh: forceRefresh);
        
        final gameState = ref.read(gamesProvider(
          consoleId: widget.consoleId,
          consoleName: widget.consoleName,
        ));
        
        if (gameState.games.isNotEmpty) {
          _games = gameState.games;
          _localHashes = gameState.localHashes;
          _matchedGames = gameState.matchedGames;
          _romsDirectories = gameState.romsDirectories;
          _gameIconPaths = Map.from(gameState.gameIconPaths);
          debugPrint('[MD5GamesScreen] Loaded ${_games.length} games via provider');
        } else {
          throw Exception('Provider returned empty game list');
        }
      } catch (providerError) {
        debugPrint('[MD5GamesScreen] Provider fetch also failed: $providerError');
        // Try to load saved games one more time
        final hashProvider = ref.read(hashServiceProviderProvider.notifier);
        final savedGames = await hashProvider.loadSavedGameList(widget.consoleId);
        if (savedGames.isNotEmpty) {
          _games = savedGames;
          debugPrint('[MD5GamesScreen] Falling back to saved game list with ${savedGames.length} games');
          await _loadSavedData();
        } else {
          throw Exception('Unable to load games from any source');
        }
      }
    }
    
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  } catch (e, stackTrace) {
    debugPrint('[MD5GamesScreen] Exception in _loadGames: $e');
    debugPrint('[MD5GamesScreen] Stack trace: $stackTrace');
    
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading games: $e'),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }
}

  // Helper method to load saved data when API fails
  Future<void> _loadSavedData() async {
    try {
      final hashProvider = ref.read(hashServiceProviderProvider.notifier);
      _localHashes = await hashProvider.loadHashes(widget.consoleName);

      _romsDirectories = await hashProvider.getConsoleDirectories(widget.consoleName);
      
      if (_games.isNotEmpty && _localHashes.isNotEmpty) {
        _matchedGames = hashProvider.matchGamesWithHashes(_games, _localHashes);
      }
      
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('[MD5GamesScreen] Error loading saved data: $e');
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // Check for changes in the provider state when dependencies change
    if (!_isLoading) {
      final gameState = ref.read(gamesProvider(
        consoleId: widget.consoleId,
        consoleName: widget.consoleName,
      ));
      
      if (_games.isEmpty && gameState.games.isNotEmpty) {
        setState(() {
          _games = gameState.games;
          _localHashes = gameState.localHashes;
          _matchedGames = gameState.matchedGames;
          _romsDirectories = gameState.romsDirectories;
          _gameIconPaths = Map.from(gameState.gameIconPaths);
        });
      }
    }
  }

 Future<void> _processDirectories(List<String> directoryPaths, {bool forceRefresh = false}) async {
  try {
    final hashProvider = ref.read(hashServiceProviderProvider.notifier);
    // Save directories first to ensure they persist
    await hashProvider.saveConsoleDirectories(widget.consoleName, directoryPaths);
    
    setState(() {
      _romsDirectories = directoryPaths;
    });

    // Use hash service provider
    
    
    // Calculate hashes for all files in all directories only if forced or if hashes are empty
    if (forceRefresh || _localHashes.isEmpty) {
      debugPrint('[MD5GamesScreen] Calculating hashes for ${directoryPaths.length} directories');
      _localHashes = await hashProvider.calculateDirectoriesHashes(directoryPaths);
      
      // Save to both provider and disk
      await hashProvider.saveConsoleHashes(widget.consoleName, _localHashes);
      
      // Notify game provider about new hashes
      final gameProvider = ref.read(gamesProvider(
        consoleId: widget.consoleId,
        consoleName: widget.consoleName,
      ).notifier);
      
      // Set state immediately instead of waiting
      setState(() {});
      
      // Update game provider to reflect new hash state
      await gameProvider.setRomsDirectories(directoryPaths);
    } else {
      // Load saved hashes
      _localHashes = await hashProvider.getConsoleHashes(widget.consoleName);
      debugPrint('[MD5GamesScreen] Loaded ${_localHashes.length} saved hashes');
    }
    
    // Match local ROM hashes with game hashes
    if (_games.isNotEmpty && _localHashes.isNotEmpty) {
      _matchedGames = hashProvider.matchGamesWithHashes(_games, _localHashes);
      debugPrint('[MD5GamesScreen] Matched ${_matchedGames.length} games with local ROMs');
    } else {
      debugPrint('[MD5GamesScreen] Unable to match games: games=${_games.length}, hashes=${_localHashes.length}');
    }
  } catch (e, stackTrace) {
    debugPrint('[MD5GamesScreen] Error in hash provider: $e');
    debugPrint('[MD5GamesScreen] Stack trace: $stackTrace');
    
    // Fallback direct calculation
    try {
      if (forceRefresh || _localHashes.isEmpty) {
        final hashProvider = ref.read(hashServiceProviderProvider.notifier);
        _localHashes = await hashProvider.calculateDirectoriesHashes(directoryPaths);
        await hashProvider.saveConsoleHashes(widget.consoleName, _localHashes);
      } else {
        final hashProvider = ref.read(hashServiceProviderProvider.notifier);
        _localHashes = await hashProvider.loadHashes(widget.consoleName);
      }
      
      // Match local ROM hashes with game hashes
      if (_games.isNotEmpty && _localHashes.isNotEmpty) {
        final hashProvider = ref.read(hashServiceProviderProvider.notifier);
        _matchedGames = hashProvider.matchGamesWithHashes(_games, _localHashes);
      }
    } catch (fallbackError) {
      debugPrint('[MD5GamesScreen] Fallback error: $fallbackError');
    }
  }
  
  // Ensure UI is updated regardless of approach
  setState(() {});
}
  
  
  Future<String?> _getGameIcon(int gameId, String iconPath) async {
    // Check cache first
    if (_gameIconPaths.containsKey(gameId)) {
      return _gameIconPaths[gameId];
    }
    
    // Otherwise fetch and cache
    final localPath = await ApiService.getGameIcon(iconPath, gameId);
    
    if (mounted) {
      setState(() {
        _gameIconPaths[gameId] = localPath;
      });
    }
    
    return localPath;
  }
  
  // Show dialog to pick ROM directory
  Future<void> _showDirectoryPickerDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: true, // Allow dismiss by tapping outside
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.cardBackground,
          title: Text(
            'Select ${widget.consoleName} ROMs Folders',
            style: const TextStyle(color: AppColors.primary),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Please select folders containing your ROMs.',
                style: TextStyle(color: AppColors.textLight),
              ),
              const SizedBox(height: 16),
              if (_romsDirectories.isNotEmpty)
                SizedBox(
                  height: 200,
                  width: double.maxFinite,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _romsDirectories.length,
                    itemBuilder: (context, index) {
                      return Card(
                        color: AppColors.darkBackground,
                        child: ListTile(
                          title: Text(
                            _romsDirectories[index],
                            style: const TextStyle(color: AppColors.textLight, fontSize: 14),
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: AppColors.error),
                            onPressed: () {
                              // Remove the directory from the list
                              setState(() {
                                _romsDirectories.removeAt(index);
                              });
                              Navigator.of(context).pop();
                              _showDirectoryPickerDialog(); // Reopen dialog to show updated list
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
          actions: [
            // Skip button removed
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                AppStrings.cancel,
                style: TextStyle(color: AppColors.textSubtle),
              ),
            ),
            TextButton(
              onPressed: () async {
                // Show directory picker
                String? selectedDirectory = await _pickDirectory();
                
                if (selectedDirectory != null && !_romsDirectories.contains(selectedDirectory)) {
                  // Add the new directory to the list
                  setState(() {
                    _romsDirectories.add(selectedDirectory);
                  });
                  
                  // Don't close dialog, allow adding more directories
                  Navigator.of(context).pop();
                  _showDirectoryPickerDialog();
                } else if (selectedDirectory != null) {
                  // Selected directory is already in the list
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('This directory is already in the list'),
                      backgroundColor: AppColors.warning,
                    ),
                  );
                }
              },
              child: const Text(
                'Add Folder',
                style: TextStyle(color: AppColors.primary),
              ),
            ),
            TextButton(
  onPressed: () async {
    Navigator.of(context).pop();
    
    if (_romsDirectories.isNotEmpty) {
      setState(() {
        _isLoading = true;
      });
      
      try {
        // First save directories
        final hashProvider = ref.read(hashServiceProviderProvider.notifier);
        await hashProvider.saveConsoleDirectories(widget.consoleName, _romsDirectories);
        debugPrint('[MD5GamesScreen] Saved ${_romsDirectories.length} directories for ${widget.consoleName}');
        
        // Also save in games provider
        final gamesNotifier = ref.read(gamesProvider(
          consoleId: widget.consoleId,
          consoleName: widget.consoleName,
        ).notifier);
        
        await gamesNotifier.setRomsDirectories(_romsDirectories);
        
        // Process the directories
        await _processDirectories(_romsDirectories, forceRefresh: true);
      } catch (e) {
        debugPrint('[MD5GamesScreen] Error saving directories: $e');
        // Show error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving directories: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  },
  child: const Text(
    'Save',
    style: TextStyle(color: AppColors.success),
  ),
),
          ],
        );
      },
    );
  }
  
  // Pick directory using FilePicker
  Future<String?> _pickDirectory() async {
    try {
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
      return selectedDirectory;
    } catch (e) {
      debugPrint('Error picking directory: $e');
      return null;
    }
  }
  
  // Get text color based on hash matches
  Color _getGameTextColor(dynamic game) {
    final gameId = game['ID'].toString();
    
    // If we don't have any directories set, show all games as unavailable
    if (_romsDirectories.isEmpty) {
      return AppColors.gameUnavailable;
    }
    
    if (!_matchedGames.containsKey(gameId)) {
      // No matching hashes - red
      return AppColors.gameUnavailable;
    }
      
    // Get game hashes and matched hashes
    final List<String> gameHashes = List<String>.from(game['Hashes'] ?? []);
    final List<String> matchedHashes = _matchedGames[gameId] ?? [];
    
    if (gameHashes.length == 1 && matchedHashes.length == 1) {
      // Only one hash and it matches - green
      return AppColors.gameAvailable;
    } else if (matchedHashes.length == gameHashes.length) {
      // All hashes match - green
      return AppColors.gameAvailable;
    } else {
      // Some but not all hashes match - blue
      return AppColors.gamePartiallyAvailable;
    }
  }

  // Handle back button press in embedded mode
  void _handleBackToGames() {
    if (widget.embedded) {
      BackToGamesNotification().dispatch(context);
    } else {
      Navigator.of(context).pop();
    }
  }

  // Navigate to game details screen
  void _navigateToGameDetails(dynamic game) {
    final gameId = game['ID'];
    final title = game['Title'];
    final iconPath = game['ImageIcon'];
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GameDataScreen(
          gameId: gameId,
          gameTitle: title,
          iconPath: iconPath,
          consoleName: widget.consoleName,
        ),
      ),
    );
  }

  // Manage ROM directories
  void _manageDirectories() async {
    await _showDirectoryPickerDialog();
  }

  @override
  Widget build(BuildContext context) {
    return widget.embedded
        ? _buildContent() // Just return the content if embedded
        : Scaffold(
            backgroundColor: AppColors.darkBackground,
            appBar: RAAppBar(
              title: '${widget.consoleName} Games',
              showBackButton: true,
              onBackPressed: _handleBackToGames,
              actions: [
                // Refresh button
                IconButton(
                  icon: const Icon(Icons.refresh, color: AppColors.textLight),
                  onPressed: () => _loadGames(forceRefresh: true),
                ),
                // Manage directories button
                IconButton(
                  icon: const Icon(Icons.folder, color: AppColors.textLight),
                  onPressed: _manageDirectories,
                ),
              ],
            ),
            body: _buildContent(),
          );
  }
  
  Widget _buildContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Back button if embedded
        if (widget.embedded)
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: AppColors.textLight),
                  onPressed: _handleBackToGames,
                ),
                Text(
                  '${widget.consoleName} Games',
                  style: const TextStyle(
                    color: AppColors.textLight,
                    fontWeight: FontWeight.bold,
                    fontSize: 24,
                  ),
                ),
                const Spacer(),
                // Refresh button
                IconButton(
                  icon: const Icon(Icons.refresh, color: AppColors.textLight),
                  onPressed: () => _loadGames(forceRefresh: true),
                ),
                // Manage directories button
                IconButton(
                  icon: const Icon(Icons.folder, color: AppColors.textLight),
                  onPressed: _manageDirectories,
                ),
              ],
            ),
          ),
        
        // Loading indicator or main content
        _isLoading
            ? const Expanded(child: Center(child: RALoadingIndicator()))
            : Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Directories info
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'ROM Directories',
                            style: TextStyle(
                              color: AppColors.textLight,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (_romsDirectories.isEmpty)
                            const Text(
                              AppStrings.notSelected,
                              style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 14,
                              ),
                            )
                          else
                            SizedBox(
                              height: 60,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: _romsDirectories.length,
                                itemBuilder: (context, index) {
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 8.0),
                                    child: Chip(
                                      backgroundColor: AppColors.darkBackground,
                                      label: Text(
                                        _romsDirectories[index].split('/').last,
                                        style: const TextStyle(color: AppColors.primary),
                                      ),
                                      avatar: const Icon(Icons.folder, color: AppColors.primary, size: 16),
                                    ),
                                  );
                                },
                              ),
                            ),
                          const SizedBox(height: 8),
                          Text(
                            '${AppStrings.gamesFound}${_games.length} | ${AppStrings.gamesWithMatchingROMs}${_matchedGames.length}',
                            style: const TextStyle(
                              color: AppColors.textLight,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Color legend
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Row(
                        children: [
                          _buildLegendItem(AppColors.gameAvailable, AppStrings.allROMsAvailable),
                          const SizedBox(width: 16),
                          _buildLegendItem(AppColors.gamePartiallyAvailable, AppStrings.someROMsAvailable),
                          const SizedBox(width: 16),
                          _buildLegendItem(AppColors.gameUnavailable, AppStrings.noROMsAvailable),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Games grid with pagination
                    Expanded(
                      child: _games.isEmpty
                          ? Center(
                              child: Text(
                                AppStrings.noGamesFound,
                                style: const TextStyle(color: AppColors.textLight, fontSize: 18),
                              ),
                            )
                          : SingleGridView(
                              items: _games,
                              crossAxisCount: 8,
                              childAspectRatio: 0.85,
                              noItemsMessage: AppStrings.noGamesFound,
                              itemBuilder: (context, game, index) {
                                final gameId = game['ID'];
                                final title = game['Title'];
                                final iconPath = game['ImageIcon'];
                                final numAchievements = game['NumAchievements'];
                                final points = game['Points'];
                                
                                return _buildGameCard(
                                  gameId: gameId,
                                  title: title,
                                  iconPath: iconPath,
                                  numAchievements: numAchievements,
                                  points: points,
                                  textColor: _getGameTextColor(game),
                                  onTap: () => _navigateToGameDetails(game),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
      ],
    );
  }
  
  // Build game card
  Widget _buildGameCard({
    required int gameId,
    required String title,
    required String iconPath,
    required int numAchievements,
    required int points,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return Card(
      color: AppColors.cardBackground,
      elevation: 4,
      margin: const EdgeInsets.all(4), // Reduced margin
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.all(4.0), // Reduced padding
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Game icon
              Expanded(
                child: Center(
                  child: FutureBuilder<String?>(
                    future: _getGameIcon(gameId, iconPath),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.done && 
                          snapshot.hasData && 
                          snapshot.data != null) {
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Image.file(
                            File(snapshot.data!),
                            width: 80,
                            fit: BoxFit.cover,
                          ),
                        );
                      } else {
                        return Container(
                          width: 45, // Reduced from 45
                          height: 45, // Reduced from 45
                          color: AppColors.darkBackground,
                          child: const Icon(
                            Icons.videogame_asset,
                            color: AppColors.primary,
                            size: 30, // Reduced from 30
                          ),
                        );
                      }
                    },
                  ),
                ),
              ),
              
              // Game info
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 11, // Reduced from 14
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2), // Reduced from 4
                  Row(
                    children: [
                      const Icon(
                        Icons.emoji_events_outlined,
                        color: AppColors.primary,
                        size: 10, // Reduced from 16
                      ),
                      const SizedBox(width: 2), // Reduced from 4
                      Text(
                        '$numAchievements ${AppStrings.achievements}',
                        style: const TextStyle(
                          color: AppColors.textLight,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 1), // Reduced from 2
                  Row(
                    children: [
                      const Icon(
                        Icons.star_outline,
                        color: AppColors.primary,
                        size: 10, // Reduced from 16
                      ),
                      const SizedBox(width: 2), // Reduced from 4
                      Text(
                        '$points ${AppStrings.points}',
                        style: const TextStyle(
                          color: AppColors.textLight,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  // Build legend item
  Widget _buildLegendItem(Color color, String text) {
    return RAStatusBadge(color: color, text: text);
  }
}