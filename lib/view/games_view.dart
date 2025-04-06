// lib/view/games_view.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:retroachievements_organizer/constants/constants.dart';
import 'package:retroachievements_organizer/providers/console_provider.dart';
import 'package:retroachievements_organizer/providers/hash_service_provider.dart';
import 'package:retroachievements_organizer/providers/user_provider.dart';
import 'package:retroachievements_organizer/widgets/common_widgets.dart';

class GamesScreen extends ConsumerStatefulWidget {
  const GamesScreen({super.key});

  @override
  ConsumerState<GamesScreen> createState() => _GamesScreenState();
}

class _GamesScreenState extends ConsumerState<GamesScreen> {
  bool _isGridView = true;
  final Map<int, Map<String, dynamic>> _libraryStats = {};
  bool _statsLoaded = false;
  

  void _toggleView() {
    setState(() {
      _isGridView = !_isGridView;
    });
  }

  @override
  void initState() {
    super.initState();
    // Load consoles when screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(consolesProvider.notifier).loadConsoles();
      _preloadGameData(); // This is the new method to preload game data
    });
  }

    // New method to preload game data for all consoles
  Future<void> _preloadGameData() async {
    if (!mounted) return;
    
    final consoleState = ref.read(consolesProvider);
    if (!consoleState.consolesLoaded) return;
    
    // Get login data
    final loginData = await ref.read(userProvider.notifier).getLoginData();
    if (loginData == null) return;
    
    // Load data for each available console
    for (int consoleId in consoleState.availableConsoleIds) {
      final consolesNotifier = ref.read(consolesProvider.notifier);
      String consoleName = consolesNotifier.getConsoleName(consoleId);
      
      if (consoleName.isEmpty) continue;
      
      try {
        // This is similar to what's done in md5_games_view.dart
        // First try to load saved game list
        final hashProvider = ref.read(hashServiceProviderProvider.notifier);
        final savedGames = await hashProvider.loadSavedGameList(consoleId);
        
        List<dynamic> games = savedGames;
        // If no saved games or we need to refresh
        if (savedGames.isEmpty) {
          // Fetch games from API
          final hashProvider = ref.read(hashServiceProviderProvider.notifier);
          games = await hashProvider.fetchGameList(loginData.apiKey, consoleId);
        }
        
        // Get ROM directories for this console
        
        final directories = await hashProvider.getConsoleDirectories(consoleName);
        
        // Initialize stats
        final stats = {
          'totalGames': games.length,
          'totalHashes': games.fold<int>(0, (sum, game) => 
            sum + (game['Hashes'] != null ? (game['Hashes'] as List).length : 0)),
          'matchedGames': 0,
          'matchedHashes': 0,
          'romsDirectory': directories.isNotEmpty ? directories.first : null,
        };
        
        // If we have directories, match with hashes
        if (directories.isNotEmpty) {
          // Load hashes
          final hashProvider = ref.read(hashServiceProviderProvider.notifier);
          final localHashes = await hashProvider.loadHashes(consoleName);
          
          if (localHashes.isNotEmpty) {
            // Match games with hashes
            final hashProvider = ref.read(hashServiceProviderProvider.notifier);
            final matchedGames = hashProvider.matchGamesWithHashes(games, localHashes);
            
            stats['matchedGames'] = matchedGames.length;
            stats['matchedHashes'] = matchedGames.values.fold<int>(0, (sum, hashes) => sum + hashes.length);
          }
        }
        
        // Update stats
        if (mounted) {
          setState(() {
            _libraryStats[consoleId] = stats;
          });
        }
      } catch (e) {
        debugPrint('Error preloading game data for $consoleName: $e');
      }
    }
    
    if (mounted) {
      setState(() {
        _statsLoaded = true;
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // Get the current state of consoles
    final consoleState = ref.read(consolesProvider);
    
    // If consoles are loaded and we haven't loaded stats yet
    if (consoleState.consolesLoaded && !_statsLoaded) {
      _preloadGameData();
    }
  }


Future<void> _loadLibraryStats() async {
  final consoleState = ref.read(consolesProvider);
  // Load all available console stats
  for (int consoleId in consoleState.availableConsoleIds) {
    await _loadConsoleStats(consoleId);
  }
}

Future<void> _loadConsoleStats(int consoleId) async {
  final consolesNotifier = ref.read(consolesProvider.notifier);
  String consoleName = consolesNotifier.getConsoleName(consoleId);
  
  if (consoleName.isEmpty) {
    debugPrint('Console name empty for ID: $consoleId, skipping stats loading');
    return;
  }

  // Initialize stats with zeros
  final stats = {
    'totalGames': 0,
    'totalHashes': 0,
    'matchedGames': 0,
    'matchedHashes': 0,
    'romsDirectory': null as String?,
  };
  
  try {
    // Load games list regardless of directory
    final hashProvider = ref.read(hashServiceProviderProvider.notifier);
    final games = await hashProvider.loadSavedGameList(consoleId);
    
    if (games.isNotEmpty) {
      stats['totalGames'] = games.length;
      stats['totalHashes'] = games.fold<int>(0, (sum, game) => 
        sum + (game['Hashes'] != null ? (game['Hashes'] as List).length : 0));
      
      // Check if console ROM directory is set
      final hashProvider = ref.read(hashServiceProviderProvider.notifier);
      final romsDirectory = await hashProvider.getConsoleDirectory(consoleName);
      if (romsDirectory != null) {
        stats['romsDirectory'] = romsDirectory;
        
        // Load local hashes
        final hashProvider = ref.read(hashServiceProviderProvider.notifier);
        final localHashes = await hashProvider.loadHashes(consoleName);
        
        // Match games with hashes
        
        
        final matchedGames = hashProvider.matchGamesWithHashes(games, localHashes);
        
        stats['matchedGames'] = matchedGames.length;
        stats['matchedHashes'] = matchedGames.values.fold<int>(0, (sum, hashes) => sum + hashes.length);
      }
    }
    
    setState(() {
      _libraryStats[consoleId] = stats;
    });
  } catch (e) {
    debugPrint('Error loading stats for $consoleName: $e');
    
    // Still add the console with zero stats
    setState(() {
      _libraryStats[consoleId] = stats;
    });
  }
}

  void _onConsoleSelected(int consoleId, String consoleName) {
    final consoleState = ref.read(consolesProvider);
    if (consoleState.availableConsoleIds.contains(consoleId)) {
      // Notify parent to switch to MD5 Games view with the selected console
      if (mounted) {
        ConsoleSelectedNotification(
          consoleId: consoleId,
          consoleName: consoleName,
        ).dispatch(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch console state
    final consoleState = ref.watch(consolesProvider);
    if (consoleState.consolesLoaded && !_statsLoaded) {
    // Load library stats if not loaded already
    _loadLibraryStats();
    _statsLoaded = true;
  }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with title and action buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              AppStrings.myGames,
              style: TextStyle(
                color: AppColors.textLight,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            Row(
              children: [
                // View toggle button
                IconButton(
                  icon: Icon(
                    _isGridView ? Icons.view_list : Icons.grid_view,
                    color: AppColors.primary,
                  ),
                  onPressed: _toggleView,
                  tooltip: _isGridView ? 'Switch to list view' : 'Switch to grid view',
                ),
                // Sort button
                IconButton(
                  icon: const Icon(Icons.sort_by_alpha, color: AppColors.primary),
                  onPressed: () => ref.read(consolesProvider.notifier).toggleSort(),
                  tooltip: 'Toggle sorting',
                ),
                // Refresh button
                IconButton(
                  icon: const Icon(Icons.refresh, color: AppColors.primary),
                  onPressed: () {
                    ref.read(consolesProvider.notifier).loadConsoles(forceRefresh: true);
                    _loadLibraryStats();
                  },
                  tooltip: 'Refresh consoles',
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        // Filter option
        Row(
          children: [
            Checkbox(
              value: consoleState.showOnlyAvailable,
              onChanged: (value) {
                ref.read(consolesProvider.notifier).toggleAvailableFilter(value ?? false);
              },
              fillColor: WidgetStateProperty.resolveWith<Color>(
                (Set<WidgetState> states) {
                  if (states.contains(WidgetState.selected)) {
                    return AppColors.primary;
                  }
                  return Colors.grey;
                },
              ),
              checkColor: AppColors.darkBackground,
            ),
            const Text(
              'Show only available consoles',
              style: TextStyle(
                color: AppColors.textLight,
                fontSize: 16,
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 16),
        const Text(
          AppStrings.selectConsole,
          style: TextStyle(
            color: AppColors.textLight,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 20),
        
        // Show error message if any
        if (consoleState.errorMessage != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              consoleState.errorMessage!,
              style: const TextStyle(
                color: AppColors.error,
                fontSize: 14,
              ),
            ),
          ),
        
        // Display loading indicator or consoles grid/list
        consoleState.isLoading
            ? const Expanded(
                child: Center(
                  child: RALoadingIndicator(),
                ),
              )
            : Expanded(
                child: consoleState.filteredConsoles.isEmpty
                    ? const Center(
                        child: Text(
                          'No consoles found',
                          style: TextStyle(
                            color: AppColors.textLight,
                            fontSize: 18,
                          ),
                        ),
                      )
                    : _isGridView
                        ? _buildConsolesGrid(consoleState)
                        : _buildConsolesList(consoleState),
              ),
      ],
    );
  }
  
  Widget _buildConsolesGrid(ConsoleState consoleState) {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.85,
      ),
      itemCount: consoleState.filteredConsoles.length,
      itemBuilder: (context, index) {
        final console = consoleState.filteredConsoles[index];
        final consoleId = console['ID'] ?? 0;
        final consoleName = ref.read(consolesProvider.notifier).getConsoleName(consoleId);
        final isAvailable = consoleState.availableConsoleIds.contains(consoleId);
        
        return _buildConsoleCard(
          name: console['Name'] ?? 'Unknown',
          iconUrl: console['IconURL'] ?? '',
          isEnabled: isAvailable,
          consoleId: consoleId,
          consoleName: consoleName,
        );
      },
    );
  }
  
  Widget _buildConsolesList(ConsoleState consoleState) {
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: consoleState.filteredConsoles.length,
      itemBuilder: (context, index) {
        final console = consoleState.filteredConsoles[index];
        final consoleId = console['ID'] ?? 0;
        final consoleName = ref.read(consolesProvider.notifier).getConsoleName(consoleId);
        final isAvailable = consoleState.availableConsoleIds.contains(consoleId);
        
        return _buildConsoleListItem(
          name: console['Name'] ?? 'Unknown',
          iconUrl: console['IconURL'] ?? '',
          isEnabled: isAvailable,
          consoleId: consoleId,
          consoleName: consoleName,
        );
      },
    );
  }
  
 Widget _buildConsoleCard({
  required String name, 
  required String iconUrl,
  required bool isEnabled,
  required int consoleId,
  required String consoleName,
}) {
  final hasLibraryStats = _libraryStats.containsKey(consoleId);
  final totalGames = hasLibraryStats ? _libraryStats[consoleId]!['totalGames'] ?? 0 : 0;
  final totalHashes = hasLibraryStats ? _libraryStats[consoleId]!['totalHashes'] ?? 0 : 0;
  final matchedGames = hasLibraryStats ? _libraryStats[consoleId]!['matchedGames'] ?? 0 : 0;
  final matchedHashes = hasLibraryStats ? _libraryStats[consoleId]!['matchedHashes'] ?? 0 : 0;
  
  return Card(
    color: AppColors.cardBackground,
    elevation: 4,
    child: InkWell(
      onTap: isEnabled ? () => _onConsoleSelected(consoleId, consoleName) : null,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                // Use network image with URL from API
                Image.network(
                  iconUrl,
                  height: 80,
                  width: 80,
                  fit: BoxFit.contain,
                  color: isEnabled ? null : Colors.grey.withOpacity(0.5),
                  colorBlendMode: isEnabled ? null : BlendMode.saturation,
                  errorBuilder: (context, error, stackTrace) {
                    debugPrint('Error loading image: $error');
                    // Fallback icon if network image fails to load
                    return const Icon(
                      Icons.videogame_asset,
                      color: AppColors.primary,
                      size: 80,
                    );
                  },
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const SizedBox(
                      height: 80,
                      width: 80,
                      child: Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                          strokeWidth: 2,
                        ),
                      ),
                    );
                  },
                ),
                if (!isEnabled)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      AppStrings.comingSoon,
                      style: TextStyle(
                        color: AppColors.textLight,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              name,
              style: TextStyle(
                color: isEnabled ? AppColors.primary : AppColors.textSubtle,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            
            // Always show the library statistics if console is enabled, even with 0 values
            if (isEnabled)
              Column(
                children: [
                  const SizedBox(height: 8),
                  Text(
                    'Games: $matchedGames/$totalGames (${totalGames > 0 ? (matchedGames / totalGames * 100).toStringAsFixed(1) : "0.0"}%)',
                    style: const TextStyle(
                      color: AppColors.textLight,
                      fontSize: 10,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Hashes: $matchedHashes/$totalHashes (${totalHashes > 0 ? (matchedHashes / totalHashes * 100).toStringAsFixed(1) : "0.0"}%)',
                    style: const TextStyle(
                      color: AppColors.textLight,
                      fontSize: 10,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
          ],
        ),
      ),
    ),
  );
}

Widget _buildConsoleListItem({
  required String name, 
  required String iconUrl,
  required bool isEnabled,
  required int consoleId,
  required String consoleName,
}) {
  final hasLibraryStats = _libraryStats.containsKey(consoleId);
  final totalGames = hasLibraryStats ? _libraryStats[consoleId]!['totalGames'] ?? 0 : 0;
  final totalHashes = hasLibraryStats ? _libraryStats[consoleId]!['totalHashes'] ?? 0 : 0;
  final matchedGames = hasLibraryStats ? _libraryStats[consoleId]!['matchedGames'] ?? 0 : 0;
  final matchedHashes = hasLibraryStats ? _libraryStats[consoleId]!['matchedHashes'] ?? 0 : 0;
  final romsDirectory = hasLibraryStats ? _libraryStats[consoleId]!['romsDirectory'] : null;
  
  return Card(
    color: AppColors.cardBackground,
    elevation: 4,
    margin: const EdgeInsets.only(bottom: 8),
    child: InkWell(
      onTap: isEnabled ? () => _onConsoleSelected(consoleId, consoleName) : null,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Console icon
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Image.network(
                    iconUrl,
                    height: 60,
                    width: 60,
                    fit: BoxFit.contain,
                    color: isEnabled ? null : Colors.grey.withOpacity(0.5),
                    colorBlendMode: isEnabled ? null : BlendMode.saturation,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(
                        Icons.videogame_asset,
                        color: AppColors.primary,
                        size: 60,
                      );
                    },
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                          strokeWidth: 2,
                        ),
                      );
                    },
                  ),
                ),
                if (!isEnabled)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      AppStrings.comingSoon,
                      style: TextStyle(
                        color: AppColors.textLight,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 16),
            
            // Console info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      color: isEnabled ? AppColors.primary : AppColors.textSubtle,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  
                  // Always show statistics for enabled consoles
                  if (isEnabled)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.folder,
                              color: AppColors.primary,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                romsDirectory ?? 'No directory set',
                                style: const TextStyle(
                                  color: AppColors.textSubtle,
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.games,
                              color: AppColors.primary,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Games: $matchedGames/$totalGames (${totalGames > 0 ? (matchedGames / totalGames * 100).toStringAsFixed(1) : "0.0"}%)',
                              style: const TextStyle(
                                color: AppColors.textLight,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(
                              Icons.tag,
                              color: AppColors.primary,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Hashes: $matchedHashes/$totalHashes (${totalHashes > 0 ? (matchedHashes / totalHashes * 100).toStringAsFixed(1) : "0.0"}%)',
                              style: const TextStyle(
                                color: AppColors.textLight,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                ],
              ),
            ),
            
            // Arrow icon if enabled
            if (isEnabled)
              const Icon(
                Icons.chevron_right,
                color: AppColors.primary,
                size: 24,
              ),
          ],
        ),
      ),
    ),
  );
}
}

// Custom notification to signal that a console is selected
class ConsoleSelectedNotification extends Notification {
  final int consoleId;
  final String consoleName;
  
  ConsoleSelectedNotification({
    required this.consoleId,
    required this.consoleName,
  });
}