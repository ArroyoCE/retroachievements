import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:retroachievements_organizer/constants/constants.dart';
import 'package:retroachievements_organizer/controller/api_calls.dart';
import 'package:retroachievements_organizer/controller/login_controller.dart';
import 'package:retroachievements_organizer/controller/md5_hash.dart';
import 'package:retroachievements_organizer/widgets/common_widgets.dart';
import 'package:retroachievements_organizer/widgets/pagination_widget.dart';

// Custom notification to signal that we want to go back to games screen
class BackToGamesNotification extends Notification {}

class MegaDriveGamesScreen extends StatefulWidget {
  final bool embedded;
  
  const MegaDriveGamesScreen({super.key, this.embedded = false});

  @override
  State<MegaDriveGamesScreen> createState() => _MegaDriveGamesScreenState();
}

class _MegaDriveGamesScreenState extends State<MegaDriveGamesScreen> {
  final LoginController _loginController = GetIt.instance<LoginController>();
  
  bool _isLoading = true;
  List<dynamic> _games = [];
  Map<String, String> _localHashes = {};
  Map<String, List<String>> _matchedGames = {};
  String? _romsDirectory;
  
  // Game icons cache
  final Map<int, String?> _gameIconPaths = {};

  @override
  void initState() {
    super.initState();
    _loadGames();
  }

  Future<void> _loadGames({bool forceRefresh = false}) async {
    setState(() {
      _isLoading = true;
    });
    
    // Get ROM directory path (if already set)
    _romsDirectory = await HashService.getConsoleDirectory('Mega Drive');
    
    if (_romsDirectory != null) {
      if (!forceRefresh) {
        // Try to load saved data first
        _localHashes = await HashService.loadHashes('Mega Drive');
        final savedGames = await HashService.loadSavedGameList(1); // 1 is Mega Drive console ID
        
        if (_localHashes.isNotEmpty && savedGames.isNotEmpty) {
          setState(() {
            _games = savedGames;
            _matchedGames = HashService.matchGamesWithHashes(_games, _localHashes);
            
            // Preload some game icons
            if (_games.isNotEmpty) {
              _preloadGameIcons();
            }
            
            _isLoading = false;
          });
          return; // Exit early, no need to process directory or make API calls
        }
      }
      
      // If we don't have saved data or force refresh is requested, process the directory
      await _processDirectory(_romsDirectory!, forceRefresh: forceRefresh);
    } else {
      // No directory set yet, show dialog to select one
      if (mounted) {
        await _showDirectoryPickerDialog();
      }
    }
    
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _processDirectory(String directoryPath, {bool forceRefresh = false}) async {
    // Calculate hashes for all files in the directory only if forced or if hashes are empty
    if (forceRefresh || _localHashes.isEmpty) {
      _localHashes = await HashService.calculateDirectoryHashes(directoryPath);
      debugPrint('Calculated ${_localHashes.length} file hashes');
      
      // Save the hashes for future use
      await HashService.saveHashes(_localHashes, 'Mega Drive');
    }
    
    // Get login data to fetch games from API
    final loginData = await _loginController.getLoginData();
    if (loginData != null) {
      // Only fetch from API if forced or if games list is empty
      if (forceRefresh || _games.isEmpty) {
        _games = await HashService.fetchGameList(loginData.apiKey, 1);
      }
      
      // Match local ROM hashes with game hashes
      _matchedGames = HashService.matchGamesWithHashes(_games, _localHashes);
      debugPrint('Matched ${_matchedGames.length} games with local ROMs');
    }
    
    // Preload some game icons
    if (_games.isNotEmpty) {
      _preloadGameIcons();
    }
  }
  
  Future<void> _preloadGameIcons() async {
    // Preload first 20 game icons
    for (int i = 0; i < 20 && i < _games.length; i++) {
      final game = _games[i];
      final gameId = game['ID'];
      final iconPath = game['ImageIcon'];
      
      final localPath = await ApiService.getGameIcon(iconPath, gameId);
      
      if (mounted) {
        setState(() {
          _gameIconPaths[gameId] = localPath;
        });
      }
    }
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
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.cardBackground,
          title: const Text(
            AppStrings.selectROMsFolder,
            style: TextStyle(color: AppColors.primary),
          ),
          content: const Text(
            AppStrings.selectFolderInstructions,
            style: TextStyle(color: AppColors.textLight),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                AppStrings.cancel,
                style: TextStyle(color: AppColors.textSubtle),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                
                // Show directory picker
                String? selectedDirectory = await _pickDirectory();
                
                if (selectedDirectory != null) {
                  // Save selected directory
                  await HashService.saveConsoleDirectory('Mega Drive', selectedDirectory);
                  
                  // Process the selected directory with force refresh
                  await _processDirectory(selectedDirectory, forceRefresh: true);
                }
              },
              child: const Text(
                AppStrings.selectFolder,
                style: TextStyle(color: AppColors.primary),
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

  @override
  Widget build(BuildContext context) {
    return widget.embedded
        ? _buildContent() // Just return the content if embedded
        : Scaffold(
            backgroundColor: AppColors.darkBackground,
            appBar: RAAppBar(
              title: AppStrings.megaDriveTitle,
              showBackButton: true,
              onBackPressed: _handleBackToGames,
              actions: [
                // Refresh button
                IconButton(
                  icon: const Icon(Icons.refresh, color: AppColors.textLight),
                  onPressed: () => _loadGames(forceRefresh: true),
                ),
                // Change directory button
                IconButton(
                  icon: const Icon(Icons.folder, color: AppColors.textLight),
                  onPressed: _showDirectoryPickerDialog,
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
                const Text(
                  AppStrings.megaDriveTitle,
                  style: TextStyle(
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
                // Change directory button
                IconButton(
                  icon: const Icon(Icons.folder, color: AppColors.textLight),
                  onPressed: _showDirectoryPickerDialog,
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
                    // Directory info
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            AppStrings.romDirectory,
                            style: TextStyle(
                              color: AppColors.textLight,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _romsDirectory ?? AppStrings.notSelected,
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 14,
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
  }) {
    return Card(
      color: AppColors.cardBackground,
      elevation: 4,
      margin: const EdgeInsets.all(4), // Reduced margin
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
    );
  }
  
  // Build legend item
  Widget _buildLegendItem(Color color, String text) {
    return RAStatusBadge(color: color, text: text);
  }
}