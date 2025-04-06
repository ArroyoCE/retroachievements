import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:retroachievements_organizer/constants/constants.dart';
import 'package:retroachievements_organizer/controller/api_calls.dart';
import 'package:retroachievements_organizer/providers/user_provider.dart';
import 'package:retroachievements_organizer/widgets/common_widgets.dart';




class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  
  bool _isLoading = true;
  String _username = '';
  String? _userPicPath;
  Map<String, dynamic>? _userInfo;
  Map<String, dynamic>? _userAwards;
  Map<String, dynamic>? _userRecentAchievements;
  Map<String, dynamic>? _userSummary;
  Map<String, dynamic>? _userCompletionProgress;
  
  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

Future<void> _loadDashboardData() async {
  setState(() {
    _isLoading = true;
  });

  // Get login data using Riverpod
  final loginData = await ref.read(userProvider.notifier).getLoginData();
  if (loginData != null) {
    setState(() {
      _username = loginData.username;
    });
    
    // Get saved user info from file
    final userInfo = await ApiService.getSavedUserInfo();
    if (userInfo != null) {
      setState(() {
        _userInfo = userInfo;
      });
    }
    
    // Get user pic path
    final userPicPath = await ApiService.getUserPicPath();
    if (userPicPath != null) {
      setState(() {
        _userPicPath = userPicPath;
      });
    }
    
    // Get user awards
    final savedAwards = await ApiService.getSavedUserAwards();
    if (savedAwards != null) {
      setState(() {
        _userAwards = savedAwards;
      });
    }
    
    // Get user completion progress
    final savedCompletionProgress = await ApiService.getSavedUserCompletionProgress();
    if (savedCompletionProgress != null) {
      setState(() {
        _userCompletionProgress = savedCompletionProgress;
      });
    } else {
      // If we don't have saved completion progress, try to fetch it
      try {
        final completionResponse = await ApiService.getUserCompletionProgress(
          loginData.username, 
          loginData.apiKey
        );
        
        if (completionResponse['success']) {
          setState(() {
            _userCompletionProgress = completionResponse['data'];
          });
        }
      } catch (e) {
        debugPrint('Error fetching completion progress: $e');
      }
    }
    
    // Get user recent achievements
    await _loadRecentAchievements(loginData.username, loginData.apiKey);
    
    // Get user summary
    await _loadUserSummary(loginData.username, loginData.apiKey);
  }
  
  setState(() {
    _isLoading = false;
  });
}


  Future<void> _loadRecentAchievements(String username, String apiKey) async {
    try {
      final response = await ApiService.getUserRecentAchievements(username, apiKey);
      if (response['success']) {
        setState(() {
          _userRecentAchievements = response['data'];
        });
      }
    } catch (e) {
      debugPrint('Error loading recent achievements: $e');
    }
  }

  Future<void> _loadUserSummary(String username, String apiKey) async {
    try {
      final response = await ApiService.getUserSummary(username, apiKey);
      if (response['success']) {
        setState(() {
          _userSummary = response['data'];
        });
      }
    } catch (e) {
      debugPrint('Error loading user summary: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
  return _isLoading
      ? const RALoadingIndicator()
      : RefreshIndicator(
          onRefresh: _loadDashboardData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Dashboard header with stats summary
                  Row(
                    children: [
                      const Text(
                        'Dashboard',
                        style: TextStyle(
                          color: AppColors.textLight,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      // Last updated timestamp
                      Text(
                        'Last updated: ${_formatDate(DateTime.now())}',
                        style: const TextStyle(
                          color: AppColors.textSubtle,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // User Profile Card
                  if (_userInfo != null)
                    _buildUserProfileCard(),
                  
                  const SizedBox(height: 24),
                  
                  // Global User Stats Summary
                  _buildGlobalStatsSummary(),
                  
                  const SizedBox(height: 24),
                  
                  // Points Chart - Shows points earned over time
                  if (_userSummary != null && _userSummary!.containsKey('RecentlyPlayed'))
                    _buildPointsChart(),
                  
                  const SizedBox(height: 24),
                  
                  // Recently Played Games
                  if (_userSummary != null && _userSummary!.containsKey('RecentlyPlayed'))
                    _buildRecentlyPlayedGames(),
                  
                  const SizedBox(height: 24),
                  
                  // Recent Achievements
                  if (_userRecentAchievements != null)
                    _buildRecentAchievements(),
                  
                  const SizedBox(height: 24),
                  
                  // Game Completion Progress
                  if (_userCompletionProgress != null)
                    _buildCompletionProgress(),
                ],
              ),
            ),
          ),
        );
}
  
  Widget _buildUserProfileCard() {
    return Card(
      color: AppColors.cardBackground,
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User pic
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.darkBackground,
                border: Border.all(color: AppColors.primary, width: 2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: _userPicPath != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.file(
                        File(_userPicPath!),
                        fit: BoxFit.cover,
                      ),
                    )
                  : const Icon(
                      Icons.account_circle,
                      color: AppColors.primary,
                      size: 60,
                    ),
            ),
            const SizedBox(width: 16),
            // User info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        _userInfo!['User'] ?? _username,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (_userSummary != null && _userSummary!.containsKey('Status'))
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _userSummary!['Status'] == 'Online' 
                                ? Colors.green.withOpacity(0.2) 
                                : AppColors.darkBackground,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: _userSummary!['Status'] == 'Online' 
                                  ? Colors.green 
                                  : AppColors.textSubtle,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _userSummary!['Status'] == 'Online' 
                                    ? Icons.circle 
                                    : Icons.circle_outlined,
                                color: _userSummary!['Status'] == 'Online' 
                                    ? Colors.green 
                                    : AppColors.textSubtle,
                                size: 12,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _userSummary!['Status'],
                                style: TextStyle(
                                  color: _userSummary!['Status'] == 'Online' 
                                      ? Colors.green 
                                      : AppColors.textSubtle,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Member since: ${_userInfo!['MemberSince']?.toString().split(' ')[0] ?? 'N/A'}',
                    style: const TextStyle(
                      color: AppColors.textLight,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  
                  // Stats in horizontal row
                  Row(
                    children: [
                      _buildUserStatItem(
                        Icons.emoji_events,
                        'Points',
                        _userInfo!['TotalPoints']?.toString() ?? 'N/A',
                      ),
                      const SizedBox(width: 16),
                      if (_userSummary != null && _userSummary!.containsKey('TotalGames'))
                        _buildUserStatItem(
                          Icons.videogame_asset,
                          'Games',
                          _userSummary!['TotalGames']?.toString() ?? '0',
                        ),
                      const SizedBox(width: 16),
                      if (_userSummary != null && _userSummary!.containsKey('TotalAchievements'))
                        _buildUserStatItem(
                          Icons.military_tech,
                          'Achievements',
                          _userSummary!['TotalAchievements']?.toString() ?? '0',
                        ),
                    ],
                  ),
                  
                  const SizedBox(height: 8),
                  
                  if (_userSummary != null && _userSummary!.containsKey('Rank'))
                    Row(
                      children: [
                        const Icon(Icons.leaderboard, color: AppColors.primary, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          'Global Rank: ${_userSummary!['Rank']} of ${_userSummary!['TotalRanked']}',
                          style: const TextStyle(
                            color: AppColors.textLight,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Percentage in top players
                        if (_userSummary!['TotalRanked'] != null) 
                          Text(
                            '(Top ${((double.parse(_userSummary!['Rank'].toString()) / double.parse(_userSummary!['TotalRanked'].toString())) * 100).toStringAsFixed(2)}%)',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                      ],
                    ),
                  
                  if (_userInfo!['RichPresenceMsg'] != null && _userInfo!['RichPresenceMsg'].toString().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.darkBackground,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppColors.primary.withOpacity(0.5)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.gamepad, color: AppColors.primary, size: 16),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                '${_userInfo!['RichPresenceMsg']}',
                                style: const TextStyle(
                                  color: AppColors.textLight,
                                  fontStyle: FontStyle.italic,
                                  fontSize: 14,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
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
  
  Widget _buildUserStatItem(IconData icon, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.primary, size: 16),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textSubtle,
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.textLight,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
  
Widget _buildGlobalStatsSummary() {
  if (_userSummary == null && _userCompletionProgress == null && _userAwards == null) {
    return const SizedBox.shrink();
  }
  
  // Calculate total achievements from completion progress if available
  int totalAchievements = 0;
  double averageCompletion = 0;
  int masteredCount = 0;
  
  // Get mastered count from user awards if available
  if (_userAwards != null && _userAwards!.containsKey('MasteryAwardsCount')) {
    masteredCount = (_userAwards!['MasteryAwardsCount'] ?? 0) as num > 0 
        ? (_userAwards!['MasteryAwardsCount'] as num).toInt() 
        : 0;
  }
  
  if (_userCompletionProgress != null && _userCompletionProgress!.containsKey('Results')) {
    final results = _userCompletionProgress!['Results'] as List;
    int completableGames = 0;
    
    for (var game in results) {
      final maxPossible = (game['MaxPossible'] ?? 0) as num;
      final awarded = (game['NumAwardedHardcore'] ?? 0) as num;
      
      if (maxPossible > 0) {
        totalAchievements += awarded.toInt();
        averageCompletion += (awarded / maxPossible) * 100;
        completableGames++;
      }
    }
    
    // Calculate average completion percentage
    if (completableGames > 0) {
      averageCompletion = averageCompletion / completableGames;
    }
  }
  
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Global Statistics',
        style: TextStyle(
          color: AppColors.textLight,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(16),
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Wrap(
          alignment: WrapAlignment.spaceAround,
          spacing: 20,
          runSpacing: 16,
          children: [
            _buildGlobalStatItem(
              'Rank',
              _userSummary?.containsKey('Rank') == true ? _userSummary!['Rank'].toString() : 'N/A',
              Colors.amber,
            ),
            _buildGlobalStatItem(
              'Points',
              _userSummary?.containsKey('TotalPoints') == true ? _formatNumber(_userSummary!['TotalPoints']) : 
                (_userInfo?.containsKey('TotalPoints') == true ? _formatNumber(_userInfo!['TotalPoints']) : 'N/A'),
              AppColors.primary,
            ),
            _buildGlobalStatItem(
              'Achievements',
              totalAchievements > 0 ? _formatNumber(totalAchievements) : 
                (_userSummary?.containsKey('TotalAchievements') == true ? _formatNumber(_userSummary!['TotalAchievements']) : 'N/A'),
              AppColors.success,
            ),
            _buildGlobalStatItem(
              'Mastered',
              masteredCount > 0 ? masteredCount.toString() : 'N/A',
              AppColors.primary,
            ),
            _buildGlobalStatItem(
              'Completion',
              averageCompletion > 0 ? '${averageCompletion.toStringAsFixed(1)}%' : 
                (_userSummary?.containsKey('TotalCompletionPercentage') == true ? 
                '${(_userSummary!['TotalCompletionPercentage'] as num).toStringAsFixed(1)}%' : 'N/A'),
              AppColors.info,
            ),
          ],
        ),
      ),
    ],
  );
}
  
  Widget _buildGlobalStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textLight,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
  
  
  
  Widget _buildPointsChart() {
    // Ideally, this would show a chart of points earned over time
    // For now, showing a simple summary of points based on available data
    final pointsData = _userSummary!.containsKey('PointsEarnedByDayOfWeek') 
        ? _userSummary!['PointsEarnedByDayOfWeek'] as Map<String, dynamic>
        : null;
    
    if (pointsData == null) {
      return const SizedBox.shrink();
    }
    
    int maxPoints = 0;
    pointsData.forEach((key, value) {
      if (value is int && value > maxPoints) {
        maxPoints = value;
      }
    });
    
    final daysOfWeek = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Points by Day of Week',
          style: TextStyle(
            color: AppColors.textLight,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: daysOfWeek.map((day) {
              final value = pointsData[day] ?? 0;
              final percentage = maxPoints > 0 ? (value / maxPoints) * 100 : 0;
              
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 80,
                      child: Text(
                        day,
                        style: const TextStyle(
                          color: AppColors.textLight,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Stack(
                        children: [
                          Container(
                            height: 16,
                            decoration: BoxDecoration(
                              color: AppColors.darkBackground,
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          Container(
                            height: 16,
                            width: percentage * MediaQuery.of(context).size.width * 0.5 / 100,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 50,
                      child: Text(
                        value.toString(),
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
  
  
  Widget _buildRecentlyPlayedGames() {
    final recentlyPlayed = _userSummary!['RecentlyPlayed'] as List;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            Text(
              'Recently Played Games',
              style: TextStyle(
                color: AppColors.textLight,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Spacer(),
            
          ],
        ),
        const SizedBox(height: 12),
        Container(
          height: 200,
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(8),
          ),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: min(recentlyPlayed.length, 7),
            itemBuilder: (context, index) {
              final game = recentlyPlayed[index];
              
              return Container(
                width: 150,
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.darkBackground,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(8),
                        topRight: Radius.circular(8),
                      ),
                      child: Image.network(
                        'https://retroachievements.org${game['ImageIcon']}',
                        height: 100,
                        width: 150,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            height: 100,
                            width: 150,
                            color: AppColors.darkBackground,
                            child: const Icon(
                              Icons.videogame_asset,
                              color: AppColors.primary,
                              size: 40,
                            ),
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            game['Title'],
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            game['ConsoleName'],
                            style: const TextStyle(
                              color: AppColors.textSubtle,
                              fontSize: 10,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.calendar_today,
                                color: AppColors.primary,
                                size: 10,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _formatDate(DateTime.parse(game['LastPlayed'])),
                                style: const TextStyle(
                                  color: AppColors.textSubtle,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
  
  Widget _buildRecentAchievements() {
    final achievements = _userRecentAchievements as List;
    const int maxToShow = 5; // Limit to top 5 recent achievements
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            Text(
              'Recent Achievements',
              style: TextStyle(
                color: AppColors.textLight,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Spacer(),
            ],
        ),
        const SizedBox(height: 12),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: achievements.length > maxToShow ? maxToShow : achievements.length,
          itemBuilder: (context, index) {
            final achievement = achievements[index];
            return Card(
              color: AppColors.cardBackground,
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                contentPadding: const EdgeInsets.all(8),
                leading: Stack(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: AppColors.darkBackground,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Image.network(
                          'https://retroachievements.org${achievement['BadgeURL']}',
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: AppColors.primary.withOpacity(0.5),
                              child: const Center(
                                child: Icon(
                                  Icons.emoji_events,
                                  color: AppColors.darkBackground,
                                  size: 30,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    if (achievement['HardcoreMode'] == 1)
                      Positioned(
                        top: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'HC',
                            style: TextStyle(
                              color: AppColors.darkBackground,
                              fontWeight: FontWeight.bold,
                              fontSize: 8,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                title: Text(
                  achievement['Title'],
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          achievement['GameTitle'],
                          style: const TextStyle(
                            color: AppColors.textLight,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const Spacer(),
                        Text(
                          '${achievement['Points']} pts',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      achievement['Description'],
                      style: const TextStyle(
                        color: AppColors.textSubtle,
                        fontSize: 11,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_today, 
                          color: AppColors.primary,
                          size: 10,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatDate(DateTime.parse(achievement['Date'])),
                          style: const TextStyle(
                            color: AppColors.textSubtle,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                trailing: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: achievement['HardcoreMode'] == 1 ? AppColors.primary : Colors.grey,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    achievement['HardcoreMode'] == 1 ? 'HC' : 'SC',
                    style: TextStyle(
                      color: achievement['HardcoreMode'] == 1 ? AppColors.darkBackground : Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
  
  Widget _buildCompletionProgress() {
    if (_userCompletionProgress == null || !_userCompletionProgress!.containsKey('Results')) {
      return const SizedBox.shrink();
    }
    
    final results = _userCompletionProgress!['Results'] as List;
    if (results.isEmpty) {
      return const SizedBox.shrink();
    }
    
    // Sort by completion percentage, highest first
    final sortedResults = List.from(results);
    sortedResults.sort((a, b) {
      final aMax = a['MaxPossible'] ?? 0;
      final aAwarded = (a['NumAwardedHardcore'] ?? 0).toInt();
      final bMax = b['MaxPossible'] ?? 0;
      final bAwarded = (b['NumAwardedHardcore'] ?? 0).toInt();
      
      final aPercentage = aMax > 0 ? (aAwarded / aMax) : 0;
      final bPercentage = bMax > 0 ? (bAwarded / bMax) : 0;
      
      return bPercentage.compareTo(aPercentage);
    });
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            Text(
              'Top Game Completions',
              style: TextStyle(
                color: AppColors.textLight,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Spacer(),
           
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              for (int i = 0; i < min(5, sortedResults.length); i++)
                _buildCompletionProgressItem(sortedResults[i], i),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildCompletionProgressItem(Map<String, dynamic> game, int index) {
    final title = game['Title'] ?? 'Unknown Game';
    final maxPossible = game['MaxPossible'] ?? 0;
    final awarded = game['NumAwardedHardcore'] ?? 0;
    final percentage = maxPossible > 0 ? (awarded / maxPossible) * 100 : 0;
    final isCompleted = percentage >= 100;
    
    Color progressColor;
    if (isCompleted) {
      progressColor = AppColors.primary;
    } else if (percentage >= 75) {
      progressColor = AppColors.success;
    } else if (percentage >= 50) {
      progressColor = AppColors.warning;
    } else {
      progressColor = AppColors.error;
    }
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '${index + 1}. $title',
                style: const TextStyle(
                  color: AppColors.textLight,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const Spacer(),
              Text(
                '$awarded/$maxPossible',
                style: TextStyle(
                  color: progressColor,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${percentage.toStringAsFixed(1)}%',
                style: TextStyle(
                  color: progressColor,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Progress bar
          Stack(
            children: [
              Container(
                height: 8,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.darkBackground,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
FractionallySizedBox(
  widthFactor: percentage / 100,
  child: Container(
    height: 8,
    decoration: BoxDecoration(
      color: progressColor,
      borderRadius: BorderRadius.circular(4),
    ),
  ),
),
            ],
          ),
        ],
      ),
    );
  }
  
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays < 1) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    }
  }
  
  String _formatNumber(dynamic number) {
    if (number == null) return 'N/A';
    
    try {
      int parsedNumber = int.parse(number.toString());
      
      if (parsedNumber >= 1000000) {
        return '${(parsedNumber / 1000000).toStringAsFixed(1)}M';
      } else if (parsedNumber >= 1000) {
        return '${(parsedNumber / 1000).toStringAsFixed(1)}K';
      } else {
        return parsedNumber.toString();
      }
    } catch (e) {
      return number.toString();
    }
  }
}