import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:retroachievements_organizer/constants/constants.dart';
import 'package:retroachievements_organizer/controller/api_calls.dart';
import 'package:retroachievements_organizer/providers/hash_service_provider.dart';
import 'package:retroachievements_organizer/providers/user_provider.dart';
import 'package:retroachievements_organizer/widgets/common_widgets.dart';
import 'package:url_launcher/url_launcher.dart';

class GameDataScreen extends ConsumerStatefulWidget {
  final int gameId;
  final String gameTitle;
  final String iconPath;
  final String consoleName; // Add this parameter

  const GameDataScreen({
    super.key,
    required this.gameId,
    required this.gameTitle,
    required this.iconPath,
    required this.consoleName, // Add this parameter
  });

  @override
  ConsumerState<GameDataScreen> createState() => _GameDataScreenState();
}

class _GameDataScreenState extends ConsumerState<GameDataScreen> with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _gameData;
  Map<String, dynamic>? _gameExtendedData;
  Map<String, dynamic>? _gameHashes;
  Map<String, String> _localHashes = {};
  String? _localGameIconPath;
  String? _localBoxArtPath;
  
  // Tab controller
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Load local hashes first, then game data
    _loadLocalHashes().then((_) => _loadGameData());
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

 Future<void> _loadLocalHashes() async {
  try {
    final hashServiceProvider = ref.read(hashServiceProviderProvider.notifier);
    
    // Load hashes for this specific console
    _localHashes = await hashServiceProvider.getConsoleHashes(widget.consoleName);
    debugPrint('GameDataScreen: Loaded ${_localHashes.length} local hashes for ${widget.consoleName}');
    
    // Debug log to see what hashes we have
    if (_localHashes.isNotEmpty) {
      debugPrint('GameDataScreen: Sample hashes: ${_localHashes.values.take(min(3, _localHashes.values.length)).join(", ")}...');
    }
  } catch (e) {
    debugPrint('GameDataScreen: Error loading local hashes: $e');
    
    // Fallback to direct hash loading
    final hashProvider = ref.read(hashServiceProviderProvider.notifier);
    _localHashes = await hashProvider.loadHashes(widget.consoleName);
    debugPrint('GameDataScreen: Loaded ${_localHashes.length} local hashes via fallback');
  }
}

  Future<void> _loadGameData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      // Get login data using Riverpod provider
      final loginData = await ref.read(userProvider.notifier).getLoginData();
      
      if (loginData == null) {
        setState(() {
          _errorMessage = 'No login data available. Please log in again.';
          _isLoading = false;
        });
        return;
      }
      
      // Load game icon
      _localGameIconPath = await ApiService.getGameIcon(widget.iconPath, widget.gameId);
      
      // Get basic game data
      final gameDataResponse = await ApiService.getGameData(loginData.apiKey, widget.gameId);
      
      if (gameDataResponse['success']) {
        _gameData = gameDataResponse['data'];
        
        // Get box art if available
        if (_gameData != null && _gameData!.containsKey('ImageBoxArt') && _gameData!['ImageBoxArt'] != null) {
          _localBoxArtPath = await _getBoxArt(_gameData!['ImageBoxArt'], widget.gameId);
        }
      } else {
        _errorMessage = gameDataResponse['message'];
      }
      
      // Get extended game data
      final gameExtendedResponse = await ApiService.getGameExtendedData(loginData.apiKey, widget.gameId);
      
      if (gameExtendedResponse['success']) {
        _gameExtendedData = gameExtendedResponse['data'];
      }
      
      // Get game hashes
      final gameHashesResponse = await ApiService.getGameHashes(loginData.apiKey, widget.gameId);
      
      if (gameHashesResponse['success']) {
        _gameHashes = gameHashesResponse['data'];
        debugPrint('GameDataScreen: Received game hashes: ${_gameHashes != null}');
        if (_gameHashes != null && _gameHashes!.containsKey('Results')) {
          final results = _gameHashes!['Results'] as List;
          debugPrint('GameDataScreen: Number of hash results: ${results.length}');
          if (results.isNotEmpty) {
            // Log a few sample hashes for debugging
            for (var i = 0; i < min(3, results.length); i++) {
              final hash = results[i];
              final md5 = hash['MD5'];
              debugPrint('GameDataScreen: Hash ${i+1} MD5: $md5');
              if (md5 != null) {
                final isAvailable = _isHashAvailable(md5);
                debugPrint('GameDataScreen: Hash is available: $isAvailable');
              }
            }
          }
        }
      }
      
    } catch (e) {
      debugPrint('Error loading game data: $e');
      _errorMessage = 'Error loading game data: $e';
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  Future<String?> _getBoxArt(String imagePath, int gameId) async {
    try {
      // Check if already downloaded
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/game_boxart_$gameId.png');
      
      if (await file.exists()) {
        return file.path;
      }
      
      // Download boxart
      final imageUrl = '${ApiConstants.baseUrl}$imagePath';
      final response = await http.get(Uri.parse(imageUrl));
      
      if (response.statusCode == 200) {
        await file.writeAsBytes(response.bodyBytes);
        return file.path;
      }
      
      return null;
    } catch (e) {
      debugPrint('Error getting box art: $e');
      return null;
    }
  }
  
  // Format release date
  String _formatReleaseDate(String? releaseDate) {
    if (releaseDate == null || releaseDate.isEmpty) {
      return 'Unknown';
    }
    
    try {
      final date = DateTime.parse(releaseDate);
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    } catch (e) {
      return releaseDate;
    }
  }
  
  // Check if hash is in local library
  bool _isHashAvailable(String hash) {
    if (hash.isEmpty || _localHashes.isEmpty) return false;
    
    // Check if any hash in our local collection matches (case insensitive)
    for (var localHash in _localHashes.values) {
      if (localHash.toLowerCase() == hash.toLowerCase()) {
        return true;
      }
    }
    return false;
  }
  
  // Get ROM filename for a hash if available
  String? _getRomNameForHash(String hash) {
    if (hash.isEmpty || _localHashes.isEmpty) return null;
    
    for (var entry in _localHashes.entries) {
      if (entry.value.toLowerCase() == hash.toLowerCase()) {
        return entry.key;
      }
    }
    return null;
  }
  
  // Launch URL in browser
  Future<void> _launchURL(String urlString) async {
  try {
    final Uri url = Uri.parse(urlString);
    
    // Check if the scheme is http or https
    if (!url.scheme.startsWith('http')) {
      // If URL doesn't have a proper scheme, add https:// prefix
      final fixedUrl = Uri.parse('https://${url.toString()}');
      if (await canLaunchUrl(fixedUrl)) {
        await launchUrl(fixedUrl, mode: LaunchMode.externalApplication);
        return;
      }
    }
    
    final canLaunch = await canLaunchUrl(url);
    if (canLaunch) {
      final launched = await launchUrl(
        url, 
        mode: LaunchMode.externalApplication
      );
      
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open the URL. Please copy and open it manually.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } else {
      // Show error if URL can't be launched
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cannot open the URL: $urlString'),
            backgroundColor: AppColors.error,
            action: SnackBarAction(
              label: 'Copy URL',
              textColor: AppColors.textLight,
              onPressed: () async {
                // This would typically use Clipboard, which needs to be added to your dependencies
                // For now we just acknowledge the action
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('URL copying requires Clipboard package')),
                );
              },
            ),
          ),
        );
      }
    }
  } catch (e) {
    debugPrint('Error launching URL: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening URL: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      appBar: RAAppBar(
        title: widget.gameTitle,
        showBackButton: true,
        actions: [
          // Refresh button
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.textLight),
            onPressed: _loadGameData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: RALoadingIndicator())
          : _errorMessage != null
              ? RAErrorDisplay(
                  message: _errorMessage!,
                  onRetry: _loadGameData,
                )
              : _buildGameContent(),
    );
  }
  
  Widget _buildGameContent() {
    return Column(
      children: [
        // Header with game info
        _buildGameHeader(),
        
        // Tab bar
        TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textLight,
          tabs: const [
            Tab(
              icon: Icon(Icons.info),
              text: 'Game Details',
            ),
            Tab(
              icon: Icon(Icons.tag),
              text: 'Game Hashes',
            ),
          ],
        ),
        
        // Tab content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildGameDetailsTab(),
              _buildGameHashesTab(),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildGameHeader() {
    return Card(
      color: AppColors.cardBackground,
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Game icon
            Column(
              children: [
                ClipRRect(
  borderRadius: BorderRadius.circular(8),
  child: _localGameIconPath != null
    ? Image.file(
        File(_localGameIconPath!),
        width: 100,
        height: 100,
        fit: BoxFit.contain,
      )
    : Container(
        width: 100,
        height: 100,
        color: AppColors.darkBackground,
        child: const Icon(
          Icons.videogame_asset,
          color: AppColors.primary,
          size: 50,
        ),
      ),
),
                
                // Box art if available
                if (_localBoxArtPath != null)
  Padding(
    padding: const EdgeInsets.only(top: 8),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.file(
        File(_localBoxArtPath!),
        width: 100,
        height: 140,
        fit: BoxFit.contain,
      ),
    ),
  ),
              ],
            ),
            
            const SizedBox(width: 16),
            
            // Game details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _gameData?['Title'] ?? widget.gameTitle,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  // Console
                  Row(
                    children: [
                      const Icon(Icons.videogame_asset, color: AppColors.primary, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        _gameData?['ConsoleName'] ?? widget.consoleName,
                        style: const TextStyle(
                          color: AppColors.textLight,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  
                  // Developer
                  if (_gameData?['Developer'] != null && _gameData!['Developer'].toString().isNotEmpty)
                    Row(
                      children: [
                        const Icon(Icons.code, color: AppColors.primary, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'Developer: ${_gameData!['Developer']}',
                          style: const TextStyle(
                            color: AppColors.textLight,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  
                  // Publisher
                  if (_gameData?['Publisher'] != null && _gameData!['Publisher'].toString().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.business, color: AppColors.primary, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            'Publisher: ${_gameData!['Publisher']}',
                            style: const TextStyle(
                              color: AppColors.textLight,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  // Genre
                  if (_gameData?['Genre'] != null && _gameData!['Genre'].toString().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.category, color: AppColors.primary, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            'Genre: ${_gameData!['Genre']}',
                            style: const TextStyle(
                              color: AppColors.textLight,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  // Release date
                  if (_gameData?['Released'] != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today, color: AppColors.primary, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            'Released: ${_formatReleaseDate(_gameData!['Released'])}',
                            style: const TextStyle(
                              color: AppColors.textLight,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  // Number of players if available from extended data
                  if (_gameExtendedData?['NumDistinctPlayers'] != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.people, color: AppColors.primary, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            'Players: ${_gameExtendedData!['NumDistinctPlayers']}',
                            style: const TextStyle(
                              color: AppColors.textLight,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  // Number of achievements if available
                  if (_gameExtendedData?['NumAchievements'] != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.emoji_events, color: AppColors.primary, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            'Achievements: ${_gameExtendedData!['NumAchievements']}',
                            style: const TextStyle(
                              color: AppColors.textLight,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildGameDetailsTab() {
    if (_gameExtendedData == null) {
      return const Center(
        child: Text(
          'No detailed information available for this game.',
          style: TextStyle(
            color: AppColors.textLight,
            fontSize: 16,
          ),
        ),
      );
    }

    // If we have achievements data, display them
    final achievements = _gameExtendedData!['Achievements'];
    if (achievements == null || achievements is! Map || achievements.isEmpty) {
      return const Center(
        child: Text(
          'No achievements data available for this game.',
          style: TextStyle(
            color: AppColors.textLight,
            fontSize: 16,
          ),
        ),
      );
    }

    // Build a list of achievements
    final achievementsList = achievements.entries.map<Map<String, dynamic>>((entry) {
      final achievementData = entry.value;
      return {
        'id': achievementData['ID'],
        'title': achievementData['Title'],
        'description': achievementData['Description'],
        'points': achievementData['Points'],
        'numAwarded': achievementData['NumAwarded'],
        'numAwardedHardcore': achievementData['NumAwardedHardcore'],
        'badgeName': achievementData['BadgeName'],
        'type': achievementData['type'],
        'displayOrder': achievementData['DisplayOrder'] ?? 0,
      };
    }).toList();

    // Sort achievements by display order if available
    achievementsList.sort((a, b) => a['displayOrder'].compareTo(b['displayOrder']));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: achievementsList.length,
      itemBuilder: (context, index) {
        final achievement = achievementsList[index];
        return Card(
          color: AppColors.cardBackground,
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: Text(
                  '${achievement['points']}',
                  style: const TextStyle(
                    color: AppColors.darkBackground,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            title: Text(
              '${achievement['title']}',
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${achievement['description']}',
                  style: const TextStyle(
                    color: AppColors.textLight,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Unlocked by ${achievement['numAwarded']} players (${achievement['numAwardedHardcore']} in hardcore)',
                  style: const TextStyle(
                    color: AppColors.textSubtle,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            trailing: Icon(
              achievement['type'] == 'progression' ? Icons.linear_scale : Icons.emoji_events,
              color: AppColors.primary,
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildGameHashesTab() {
    if (_gameHashes == null || !_gameHashes!.containsKey('Results') || _gameHashes!['Results'] == null) {
      debugPrint('GameDataScreen: No Results key in game hashes or it is null');
      return const Center(
        child: Text(
          'No hash information available for this game.',
          style: TextStyle(
            color: AppColors.textLight,
            fontSize: 16,
          ),
        ),
      );
    }

    final hashes = _gameHashes!['Results'] as List;
    
    if (hashes.isEmpty) {
      debugPrint('GameDataScreen: Results list is empty');
      return const Center(
        child: Text(
          'No hash information available for this game.',
          style: TextStyle(
            color: AppColors.textLight,
            fontSize: 16,
          ),
        ),
      );
    }

    debugPrint('GameDataScreen: Found ${hashes.length} hashes in Results');
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: hashes.length,
      itemBuilder: (context, index) {
        final hash = hashes[index];
        final md5Hash = hash['MD5'];
        final name = hash['Name'];
        final isAvailable = _isHashAvailable(md5Hash);
        final localRomName = isAvailable ? _getRomNameForHash(md5Hash) : null;
        
        return Card(
          color: AppColors.cardBackground,
          margin: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      isAvailable ? Icons.check_circle : Icons.cancel,
                      color: isAvailable ? AppColors.success : AppColors.error,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isAvailable ? AppStrings.availableInLibrary : AppStrings.notAvailableInLibrary,
                        style: TextStyle(
                          color: isAvailable ? AppColors.success : AppColors.error,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'ROM Name: $name',
                  style: const TextStyle(
                    color: AppColors.textLight,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'MD5: $md5Hash',
                  style: const TextStyle(
                    color: AppColors.textSubtle,
                    fontSize: 12,
                  ),
                ),
                if (isAvailable && localRomName != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Local ROM: $localRomName',
                    style: const TextStyle(
                      color: AppColors.success,
                      fontSize: 12,
                    ),
                  ),
                ],
                // Show labels if available
                if (hash['Labels'] != null && hash['Labels'] is List && (hash['Labels'] as List).isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: (hash['Labels'] as List).map<Widget>((label) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.darkBackground,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.primary),
                        ),
                        child: Text(
                          label.toString(),
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 10,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
                // Show patch URL if available with clickable link
                if (hash['PatchUrl'] != null && hash['PatchUrl'].toString().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () {
                      // Launch the URL using url_launcher
                      final patchUrl = hash['PatchUrl'].toString();
                      _launchURL(patchUrl);
                    },
                    child: Row(
                      children: const [
                        Icon(
                          Icons.download,
                          color: AppColors.info,
                          size: 16,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Download Patch',
                          style: TextStyle(
                            color: AppColors.info,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}