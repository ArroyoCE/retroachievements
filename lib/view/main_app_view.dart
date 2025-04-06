import 'dart:io';

import 'package:flutter/material.dart';
import 'package:retroachievements_organizer/constants/constants.dart';
import 'package:retroachievements_organizer/view/achievement_view.dart';
import 'package:retroachievements_organizer/view/dashboard_view.dart';
import 'package:retroachievements_organizer/view/games_view.dart';
import 'package:retroachievements_organizer/view/md5_games_view.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:retroachievements_organizer/providers/user_provider.dart';

class MainAppScreen extends ConsumerStatefulWidget {
  const MainAppScreen({super.key});

  @override
  ConsumerState<MainAppScreen> createState() => _MainAppScreenState();
}

class _MainAppScreenState extends ConsumerState<MainAppScreen> {
  int _selectedIndex = 0;
  
  // State for the selected console
  bool _showConsoleGames = false;
  int _selectedConsoleId = 0;
  String _selectedConsoleName = '';

  @override
  void initState() {
    super.initState();
    // No need to load user data here as our provider handles it
  }

  void _onSidebarItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      // Reset any sub-views when changing main navigation
      _showConsoleGames = false;
    });
  }
  
  // Handle logout
  Future<void> _handleLogout() async {
    // Call logout method in user provider
    await ref.read(userProvider.notifier).logout();
    
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
        return const DashboardScreen();
      case 1:
        return _buildGamesSection();
      case 2:
        return const AchievementsScreen();
      case 3:
        return _buildSettings();
      default:
        return const DashboardScreen();
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
    if (_showConsoleGames) {
      return NotificationListener<BackToGamesNotification>(
        onNotification: (notification) {
          setState(() {
            _showConsoleGames = false;
          });
          return true;
        },
        child: MD5GamesScreen(
          embedded: true,
          consoleId: _selectedConsoleId,
          consoleName: _selectedConsoleName,
        ),
      );
    } else {
      return NotificationListener<ConsoleSelectedNotification>(
        onNotification: (notification) {
          setState(() {
            _showConsoleGames = true;
            _selectedConsoleId = notification.consoleId;
            _selectedConsoleName = notification.consoleName;
          });
          return true;
        },
        child: const GamesScreen(),
      );
    }
  }

  @override
    @override
  Widget build(BuildContext context) {
    // Watch user state
    final userState = ref.watch(userProvider);
    
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
                      userState.userPicPath != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(
                                File(userState.userPicPath!),
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
                        userState.username ?? '',
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
                  userState.userPicPath != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            File(userState.userPicPath!),
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
                    userState.username ?? '',
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