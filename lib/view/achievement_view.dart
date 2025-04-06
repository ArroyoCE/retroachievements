import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:retroachievements_organizer/constants/constants.dart';
import 'package:retroachievements_organizer/controller/api_calls.dart';
import 'package:retroachievements_organizer/providers/user_provider.dart';
import 'package:retroachievements_organizer/widgets/common_widgets.dart';
import 'package:retroachievements_organizer/widgets/pagination_widget.dart';

enum SortOption {
  completionAsc,
  completionDesc,
  alphabeticalAsc,
  alphabeticalDesc,
  platformAsc,
  platformDesc,
}

class AchievementsScreen extends ConsumerStatefulWidget {
  const AchievementsScreen({super.key});

  @override
  ConsumerState<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends ConsumerState<AchievementsScreen> {
  bool _isLoading = true;
  // ignore: unused_field
  Map<String, dynamic>? _userAwards;
  Map<String, dynamic>? _userCompletionProgress;
  
  // Stats
  int _gamesPlayed = 0;
  int _unfinished = 0;
  int _beaten = 0;
  int _mastered = 0;
  
  // Game icons cache
  final Map<int, String?> _gameIconPaths = {};
  
  // Filtering and sorting
  SortOption _currentSortOption = SortOption.alphabeticalAsc;
  bool _showOnlyCompleted = false;
  Set<String> _selectedPlatforms = {};
  List<dynamic> _filteredResults = [];
  bool _isFilterExpanded = false;

  @override
  void initState() {
    super.initState();
    _loadPlatforms();
    _loadAchievementsData(forceRefresh: false);
  }
  
  Future<void> _loadPlatforms() async {
    // Load platforms from API or use the provided list
    try {
      final platformsString = await ApiService.getPlatformsList();
      if (platformsString != null) {
        setState(() {
        });
      }
    } catch (e) {
      debugPrint('Error loading platforms: $e');
    }
  }

  Future<void> _loadAchievementsData({bool forceRefresh = false}) async {
    setState(() {
      _isLoading = true;
    });
    
    // Get saved data first
    final savedAwards = await ApiService.getSavedUserAwards();
    final savedCompletionProgress = await ApiService.getSavedUserCompletionProgress();
    
    // If we have saved data and we're not forcing a refresh, use the saved data
    if (!forceRefresh && savedAwards != null && savedCompletionProgress != null) {
      _processAchievementsData(savedAwards, savedCompletionProgress);
      setState(() {
        _isLoading = false;
      });
      return;
    }
    
    // Get login data for API refresh using Riverpod
    final loginData = await ref.read(userProvider.notifier).getLoginData();
    if (loginData != null) {
      // Fetch fresh data from API
      final awardsResponse = await ApiService.getUserAwards(
        loginData.username, 
        loginData.apiKey
      );
      
      final completionResponse = await ApiService.getUserCompletionProgress(
        loginData.username, 
        loginData.apiKey
      );
      
      if (awardsResponse['success'] && completionResponse['success']) {
        _processAchievementsData(
          awardsResponse['data'], 
          completionResponse['data']
        );
      } else {
        // If API call fails but we have saved data, fall back to saved data
        if (savedAwards != null && savedCompletionProgress != null) {
          _processAchievementsData(savedAwards, savedCompletionProgress);
        }
      }
    }
    
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  void _processAchievementsData(
    Map<String, dynamic> awards, 
    Map<String, dynamic> completion
  ) {
    setState(() {
      _userAwards = awards;
      _userCompletionProgress = completion;
      
      // Calculate stats
      _mastered = awards['MasteryAwardsCount'] ?? 0;
      
      // Beaten = BeatenHardcoreAwardsCount - MasteryAwardsCount
      int beatenHardcore = awards['BeatenHardcoreAwardsCount'] ?? 0;
      _beaten = beatenHardcore - _mastered;
      
      // Games played from completion data
      _gamesPlayed = completion['Total'] ?? 0;
      
      // Unfinished = Total - BeatenHardcoreAwardsCount
      _unfinished = _gamesPlayed - beatenHardcore;
      
      // Apply filtering and sorting to results
      _applyFiltersAndSort();
    });
    
    // Preload some game icons
    if (_userCompletionProgress != null && 
        _userCompletionProgress!.containsKey('Results')) {
      _preloadGameIcons();
    }
  }
  
  void _applyFiltersAndSort() {
    if (_userCompletionProgress == null || !_userCompletionProgress!.containsKey('Results')) {
      _filteredResults = [];
      return;
    }
    
    final results = _userCompletionProgress!['Results'] as List;
    
    // Apply filters
    List<dynamic> filtered = List.from(results);
    
    // Filter for completed games if needed
    if (_showOnlyCompleted) {
      filtered = filtered.where((game) {
        final maxPossible = game['MaxPossible'] ?? 0;
        final numAwarded = game['NumAwardedHardcore'] ?? 0;
        return maxPossible > 0 && numAwarded == maxPossible;
      }).toList();
    }
    
    // Filter by selected platforms
    if (_selectedPlatforms.isNotEmpty) {
      filtered = filtered.where((game) {
        final consoleName = game['ConsoleName'] ?? '';
        return _selectedPlatforms.contains(consoleName);
      }).toList();
    }
    
    // Apply sorting
    switch (_currentSortOption) {
      case SortOption.completionAsc:
        filtered.sort((a, b) {
          final aMax = a['MaxPossible'] ?? 0;
          final aAwarded = a['NumAwardedHardcore'] ?? 0;
          final bMax = b['MaxPossible'] ?? 0;
          final bAwarded = b['NumAwardedHardcore'] ?? 0;
          
          final aPercentage = aMax > 0 ? (aAwarded / aMax) : 0;
          final bPercentage = bMax > 0 ? (bAwarded / bMax) : 0;
          
          return aPercentage.compareTo(bPercentage);
        });
        break;
      case SortOption.completionDesc:
        filtered.sort((a, b) {
          final aMax = a['MaxPossible'] ?? 0;
          final aAwarded = a['NumAwardedHardcore'] ?? 0;
          final bMax = b['MaxPossible'] ?? 0;
          final bAwarded = b['NumAwardedHardcore'] ?? 0;
          
          final aPercentage = aMax > 0 ? (aAwarded / aMax) : 0;
          final bPercentage = bMax > 0 ? (bAwarded / bMax) : 0;
          
          return bPercentage.compareTo(aPercentage);
        });
        break;
      case SortOption.alphabeticalAsc:
        filtered.sort((a, b) {
          final aTitle = a['Title'] ?? '';
          final bTitle = b['Title'] ?? '';
          return aTitle.compareTo(bTitle);
        });
        break;
      case SortOption.alphabeticalDesc:
        filtered.sort((a, b) {
          final aTitle = a['Title'] ?? '';
          final bTitle = b['Title'] ?? '';
          return bTitle.compareTo(aTitle);
        });
        break;
      case SortOption.platformAsc:
        filtered.sort((a, b) {
          final aConsole = a['ConsoleName'] ?? '';
          final bConsole = b['ConsoleName'] ?? '';
          if (aConsole == bConsole) {
            final aTitle = a['Title'] ?? '';
            final bTitle = b['Title'] ?? '';
            return aTitle.compareTo(bTitle);
          }
          return aConsole.compareTo(bConsole);
        });
        break;
      case SortOption.platformDesc:
        filtered.sort((a, b) {
          final aConsole = a['ConsoleName'] ?? '';
          final bConsole = b['ConsoleName'] ?? '';
          if (aConsole == bConsole) {
            final aTitle = a['Title'] ?? '';
            final bTitle = b['Title'] ?? '';
            return aTitle.compareTo(bTitle);
          }
          return bConsole.compareTo(aConsole);
        });
        break;
    }
    
    setState(() {
      _filteredResults = filtered;
    });
  }
  
  Future<void> _preloadGameIcons() async {
    final results = _userCompletionProgress!['Results'] as List;
    
    // Preload first 10 game icons
    for (int i = 0; i < 10 && i < results.length; i++) {
      final game = results[i];
      final gameId = game['GameID'];
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
  
  // Get appropriate award badge icon based on highest award
  IconData _getAwardIcon(String? awardKind) {
    if (awardKind == 'mastery') {
      return Icons.workspace_premium;
    } else if (awardKind == 'beaten-hardcore') {
      return Icons.military_tech;
    } else {
      return Icons.emoji_events_outlined;
    }
  }
  
  // Get appropriate color for progress
  Color _getProgressColor(int awarded, int total) {
    final percentage = (awarded / total) * 100;
    
    if (percentage == 100) {
      return AppColors.primary; // Gold for 100%
    } else if (percentage >= 75) {
      return AppColors.success;
    } else if (percentage >= 50) {
      return AppColors.warning;
    } else {
      return AppColors.error;
    }
  }
  
  // Show sort options dialog
  void _showSortDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.cardBackground,
          title: const Text(
            'Sort Games By',
            style: TextStyle(color: AppColors.primary),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSortOption(SortOption.completionAsc, 'Completion Rate (Low to High)'),
              _buildSortOption(SortOption.completionDesc, 'Completion Rate (High to Low)'),
              _buildSortOption(SortOption.alphabeticalAsc, 'Game Title (A to Z)'),
              _buildSortOption(SortOption.alphabeticalDesc, 'Game Title (Z to A)'),
              _buildSortOption(SortOption.platformAsc, 'Platform (A to Z)'),
              _buildSortOption(SortOption.platformDesc, 'Platform (Z to A)'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Close',
                style: TextStyle(color: AppColors.primary),
              ),
            ),
          ],
        );
      },
    );
  }
  
  // Build sort option radio button
  Widget _buildSortOption(SortOption option, String label) {
    return RadioListTile<SortOption>(
      title: Text(
        label,
        style: const TextStyle(color: AppColors.textLight),
      ),
      value: option,
      groupValue: _currentSortOption,
      activeColor: AppColors.primary,
      onChanged: (SortOption? value) {
        if (value != null) {
          setState(() {
            _currentSortOption = value;
          });
          _applyFiltersAndSort();
          Navigator.of(context).pop();
        }
      },
    );
  }
  
  // Toggle filter panel
  void _toggleFilterPanel() {
    setState(() {
      _isFilterExpanded = !_isFilterExpanded;
    });
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? const RALoadingIndicator()
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row with title, sort and filter buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'My Achievements',
                    style: TextStyle(
                      color: AppColors.textLight,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: [
                      // Sort button
                      IconButton(
                        icon: const Icon(Icons.sort, color: AppColors.primary),
                        onPressed: _showSortDialog,
                        tooltip: 'Sort games',
                      ),
                      // Filter button
                      IconButton(
                        icon: Icon(
                          _isFilterExpanded ? Icons.filter_list_off : Icons.filter_list,
                          color: AppColors.primary,
                        ),
                        onPressed: _toggleFilterPanel,
                        tooltip: 'Filter games',
                      ),
                      // Refresh button
                      IconButton(
                        icon: const Icon(Icons.refresh, color: AppColors.primary),
                        onPressed: () => _loadAchievementsData(forceRefresh: true),
                        tooltip: 'Refresh achievements data',
                      ),
                    ],
                  ),
                ],
              ),
              
              // Filter panel (expandable)
              if (_isFilterExpanded)
                Card(
                  color: AppColors.cardBackground,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Filters',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        
                        // Show only completed games checkbox
                        Row(
                          children: [
                            Checkbox(
                              value: _showOnlyCompleted,
                              onChanged: (value) {
                                setState(() {
                                  _showOnlyCompleted = value ?? false;
                                });
                                _applyFiltersAndSort();
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
                              'Show only completed games',
                              style: TextStyle(color: AppColors.textLight),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 12),
                        const Text(
                          'Filter by Platform:',
                          style: TextStyle(
                            color: AppColors.textLight,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        
                        // Get unique platforms from the results
                        _buildPlatformFilterChips(),
                        
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _selectedPlatforms = {};
                                  _showOnlyCompleted = false;
                                });
                                _applyFiltersAndSort();
                              },
                              child: const Text(
                                'Clear All Filters',
                                style: TextStyle(color: AppColors.primary),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              
              const SizedBox(height: 16),
              
              // Stats summary cards
              Container(
                padding: const EdgeInsets.all(16),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatCard('$_gamesPlayed', AppStrings.played, Colors.amber),
                    _buildStatCard('$_unfinished', AppStrings.unfinished, AppColors.info),
                    _buildStatCard('$_beaten', AppStrings.beaten, AppColors.success),
                    _buildStatCard('$_mastered', AppStrings.mastered, AppColors.primary),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Games list header
              Text(
                '${AppStrings.viewing} ${_filteredResults.length} ${AppStrings.games}',
                style: const TextStyle(
                  color: AppColors.info,
                  fontSize: 18,
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Games list with pagination
              Expanded(
                child: _filteredResults.isNotEmpty
                    ? _buildGamesList()
                    : Center(
                        child: Text(
                          _userCompletionProgress != null && _userCompletionProgress!.containsKey('Results')
                              ? 'No games match your filters'
                              : AppStrings.noGameData,
                          style: const TextStyle(color: AppColors.textLight),
                        ),
                      ),
              ),
            ],
          );
  }
  
  Widget _buildPlatformFilterChips() {
    // Get unique console names from results
    Set<String> consoleNames = {};
    if (_userCompletionProgress != null && _userCompletionProgress!.containsKey('Results')) {
      final results = _userCompletionProgress!['Results'] as List;
      for (var game in results) {
        final consoleName = game['ConsoleName'] ?? '';
        if (consoleName.isNotEmpty) {
          consoleNames.add(consoleName);
        }
      }
    }
    
    // Convert to sorted list
    final platforms = consoleNames.toList()..sort();
    
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: platforms.map((platform) {
        final isSelected = _selectedPlatforms.contains(platform);
        return FilterChip(
          label: Text(platform),
          selected: isSelected,
          selectedColor: AppColors.primary.withOpacity(0.3),
          checkmarkColor: AppColors.primary,
          backgroundColor: AppColors.darkBackground,
          labelStyle: TextStyle(
            color: isSelected ? AppColors.primary : AppColors.textLight,
          ),
          onSelected: (selected) {
            setState(() {
              if (selected) {
                _selectedPlatforms.add(platform);
              } else {
                _selectedPlatforms.remove(platform);
              }
            });
            _applyFiltersAndSort();
          },
        );
      }).toList(),
    );
  }
  
  Widget _buildStatCard(String value, String label, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textLight,
            fontSize: 16,
          ),
        ),
      ],
    );
  }
  
  Widget _buildGamesList() {
    return SingleListView(
      items: _filteredResults,
      itemBuilder: (context, game, index) {
        final gameId = game['GameID'];
        final title = game['Title'];
        final iconPath = game['ImageIcon'];
        final consoleName = game['ConsoleName'];
        final maxPossible = game['MaxPossible'];
        final numAwarded = game['NumAwardedHardcore'];
        final percentage = maxPossible > 0 
            ? ((numAwarded / maxPossible) * 100).round() 
            : 0;
        final highestAward = game['HighestAwardKind'];
        final mostRecentDate = game['MostRecentAwardedDate'] != null 
            ? DateTime.parse(game['MostRecentAwardedDate']) 
            : null;
        
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(4),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: FutureBuilder<String?>(
              future: _getGameIcon(gameId, iconPath),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done && 
                    snapshot.hasData && 
                    snapshot.data != null) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Image.file(
                      File(snapshot.data!),
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                    ),
                  );
                } else {
                  return Container(
                    width: 64,
                    height: 64,
                    color: AppColors.darkBackground,
                    child: const Icon(
                      Icons.videogame_asset,
                      color: AppColors.primary,
                    ),
                  );
                }
              },
            ),
            title: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            '${AppStrings.achievements} $numAwarded ${AppStrings.of} $maxPossible',
                            style: const TextStyle(
                              color: AppColors.textLight,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      if (mostRecentDate != null) 
                        Text(
                          '${AppStrings.lastPlayed}${_formatDate(mostRecentDate)}',
                          style: const TextStyle(
                            color: AppColors.textSubtle,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.darkBackground,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    consoleName,
                    style: const TextStyle(
                      color: AppColors.textLight,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 20,
                      decoration: BoxDecoration(
                        color: AppColors.darkBackground,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: percentage / 100,
                          backgroundColor: AppColors.darkBackground,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _getProgressColor(numAwarded, maxPossible),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$percentage%',
                    style: TextStyle(
                      color: _getProgressColor(numAwarded, maxPossible),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (highestAward != null) 
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Icon(
                        _getAwardIcon(highestAward),
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
  
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays < 1) {
      return AppStrings.today;
    } else if (difference.inDays == 1) {
      return AppStrings.yesterday;
    } else if (difference.inDays < 7) {
      return '${difference.inDays} ${AppStrings.daysAgo}';
    } else {
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    }
  }
}