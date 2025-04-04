import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:retroachievements_organizer/constants/constants.dart';
import 'package:retroachievements_organizer/controller/api_calls.dart';
import 'package:retroachievements_organizer/controller/login_controller.dart';
import 'package:retroachievements_organizer/view/achievement_view.dart';
import 'package:retroachievements_organizer/view/games_view.dart';
import 'package:retroachievements_organizer/view/md_games_view.dart';

class MainAppScreen extends StatefulWidget {
  const MainAppScreen({super.key});

  @override
  State<MainAppScreen> createState() => _MainAppScreenState();
}

class _MainAppScreenState extends State<MainAppScreen> {
  final LoginController _loginController = GetIt.instance<LoginController>();
  String _username = '';
  int _selectedIndex = 0;
  String? _userPicPath;
  Map<String, dynamic>? _userInfo;
  bool _showMegaDriveGames = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    // Get login data
    final loginData = await _loginController.getLoginData();
    if (loginData != null) {
      setState(() {
        _username = loginData.username;
      });
      
      // Load user achievements data in background
      _loadAchievementsData(loginData.username, loginData.apiKey);
    }
    
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
  }
  
  // Load achievements data
  Future<void> _loadAchievementsData(String username, String apiKey) async {
    // Load user awards and completion progress in the background
    await ApiService.getUserAwards(username, apiKey);
    await ApiService.getUserCompletionProgress(username, apiKey);
  }

  void _onSidebarItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      // Reset any sub-views when changing main navigation
      _showMegaDriveGames = false;
    });
  }
  
  // Handle logout
  Future<void> _handleLogout() async {
    // Call logout method from LoginController to disable auto login
    await _loginController.logout();
    
    // Navigate to login screen
    if (mounted) {
      Navigator.pushReplacementNamed(context, 'login');
    }
  }
  
  // Navigate to about screen
  void _navigateToAbout() {
    Navigator.pushNamed(context, 'about');
  }
  
  // Navigate to register screen
  void _navigateToRegister() {
    Navigator.pushNamed(context, 'register');
  }
  
  // Navigate to forgot password screen
  void _navigateToForgotPassword() {
    Navigator.pushNamed(context, 'forgot_password');
  }

  // Content for each sidebar option
  Widget _buildContent() {
    switch (_selectedIndex) {
      case 0:
        return _buildDashboard();
      case 1:
        return _buildGamesSection();
      case 2:
        return const AchievementsScreen();
      case 3:
        return _buildSettings();
      default:
        return _buildDashboard();
    }
  }
  
  // Build Settings screen
  Widget _buildSettings() {
    return const Center(
      child: Text(
        'Settings',
        style: TextStyle(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
  
  // Build Games section with either console selection or specific console games
  Widget _buildGamesSection() {
    if (_showMegaDriveGames) {
      return NotificationListener<BackToGamesNotification>(
        onNotification: (notification) {
          setState(() {
            _showMegaDriveGames = false;
          });
          return true;
        },
        child: const MegaDriveGamesScreen(embedded: true),
      );
    } else {
      return NotificationListener<MegaDriveSelectedNotification>(
        onNotification: (notification) {
          setState(() {
            _showMegaDriveGames = true;
          });
          return true;
        },
        child: const GamesScreen(),
      );
    }
  }
  
  // Build dashboard with user info
  Widget _buildDashboard() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User Profile Card
          if (_userInfo != null)
            Card(
              color: AppColors.cardBackground,
              elevation: 4,
              margin: const EdgeInsets.only(bottom: 20),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    // User pic
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppColors.darkBackground,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: _userPicPath != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
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
                          Text(
                            _userInfo!['User'] ?? _username,
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
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
                          Text(
                            'Total Points: ${_userInfo!['TotalPoints'] ?? 'N/A'}',
                            style: const TextStyle(
                              color: AppColors.textLight,
                              fontSize: 14,
                            ),
                          ),
                          if (_userInfo!['RichPresenceMsg'] != null && _userInfo!['RichPresenceMsg'].toString().isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                '${_userInfo!['RichPresenceMsg']}',
                                style: const TextStyle(
                                  color: AppColors.textSubtle,
                                  fontStyle: FontStyle.italic,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          
          const SizedBox(height: 16),
          
          // Dashboard content
          const Text(
            'Dashboard',
            style: TextStyle(
              color: AppColors.textLight,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Welcome to the RetroAchievements Library Organizer!',
            style: TextStyle(
              color: AppColors.textLight,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Use the sidebar to navigate through your games and achievements.',
            style: TextStyle(
              color: AppColors.textLight,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      appBar: AppBar(
        backgroundColor: AppColors.appBarBackground,
        title: Row(
          children: [
            Image.asset(
              'images/ra-icon.png',
              height: 24,
              width: 24,
            ),
            const SizedBox(width: 8),
            const Text(
              'RetroAchievements Library Organizer',
              style: TextStyle(
                color: AppColors.textLight,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          // User profile dropdown
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: PopupMenuButton<String>(
              offset: const Offset(0, 40),
              onSelected: (value) {
                if (value == 'logout') {
                  _handleLogout();
                } else if (value == 'about') {
                  _navigateToAbout();
                } else if (value == 'register') {
                  _navigateToRegister();
                } else if (value == 'forgot_password') {
                  _navigateToForgotPassword();
                }
              },
              itemBuilder: (BuildContext context) => [
                PopupMenuItem<String>(
                  value: 'profile',
                  enabled: false,
                  child: Row(
                    children: [
                      // User profile pic
                      _userPicPath != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(
                                File(_userPicPath!),
                                height: 24,
                                width: 24,
                                fit: BoxFit.cover,
                              ),
                            )
                          : const Icon(
                              Icons.account_circle,
                              color: AppColors.primary,
                              size: 24,
                            ),
                      const SizedBox(width: 8),
                      Text(
                        _username,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem<String>(
                  value: 'register',
                  child: Row(
                    children: [
                      Icon(Icons.person_add),
                      SizedBox(width: 8),
                      Text('Register'),
                    ],
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'forgot_password',
                  child: Row(
                    children: [
                      Icon(Icons.password),
                      SizedBox(width: 8),
                      Text('Forgot Password'),
                    ],
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'about',
                  child: Row(
                    children: [
                      Icon(Icons.info_outline),
                      SizedBox(width: 8),
                      Text('About'),
                    ],
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Icons.logout),
                      SizedBox(width: 8),
                      Text('Logout'),
                    ],
                  ),
                ),
              ],
              child: Row(
                children: [
                  // User profile pic
                  _userPicPath != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            File(_userPicPath!),
                            height: 24,
                            width: 24,
                            fit: BoxFit.cover,
                          ),
                        )
                      : const Icon(
                          Icons.account_circle,
                          color: AppColors.primary,
                          size: 24,
                        ),
                  const SizedBox(width: 8),
                  Text(
                    _username,
                    style: const TextStyle(
                      color: AppColors.textLight,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.arrow_drop_down,
                    color: AppColors.textLight,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: Row(
        children: [
          // Sidebar
          Container(
            width: 250,
            color: AppColors.cardBackground,
            child: Column(
              children: [
                const SizedBox(height: 20),
                _buildSidebarItem(0, Icons.dashboard, AppStrings.dashboard),
                _buildSidebarItem(1, Icons.games, AppStrings.myGames),
                _buildSidebarItem(2, Icons.emoji_events, AppStrings.myAchievements),
                _buildSidebarItem(3, Icons.settings, AppStrings.settings),
                // Removed the logout button from here since it's now in the dropdown menu
              ],
            ),
          ),
          // Content area
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: _buildContent(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarItem(int index, IconData icon, String title) {
    final isSelected = _selectedIndex == index;
    
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? AppColors.primary : AppColors.textLight,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? AppColors.primary : AppColors.textLight,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      tileColor: isSelected ? AppColors.darkBackground : Colors.transparent,
      onTap: () => _onSidebarItemTapped(index),
    );
  }
}