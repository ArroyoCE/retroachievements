// lib/constants/constants.dart
import 'package:flutter/material.dart';

/// API URL Constants
class ApiConstants {
  static const String baseUrl = 'https://retroachievements.org';
  static const String apiPath = '/API';
  static const String getUserProfile = '$apiPath/API_GetUserProfile.php';
  static const String getUserAwards = '$apiPath/API_GetUserAwards.php';
  static const String getUserCompletionProgress = '$apiPath/API_GetUserCompletionProgress.php';
  static const String getGameList = '$apiPath/API_GetGameList.php';
  static const String getConsolePage = '$apiPath/API_GetConsoleID.php';
  static const String getPlatforms = '$apiPath/API_GetConsoleIDs.php';
  static const String getConsoleIDs = '$apiPath/API_GetConsoleIDs.php';
  static const String getGame = '$apiPath/API_GetGame.php';
  static const String getGameExtended = '$apiPath/API_GetGameExtended.php';
  static const String getGameHashes = '$apiPath/API_GetGameHashes.php';
  static const String getUserRecentAchievements = '$apiPath/API_GetUserRecentAchievements.php';
  static const String getUserSummary = '$apiPath/API_GetUserSummary.php';
  static const String getUserProgress = '$apiPath/API_GetUserProgress.php';
  static const String getUserGameCompletion = '$apiPath/API_GetUserGameCompletion.php';
  static const String getGameInfoAndUserProgress = '$apiPath/API_GetGameInfoAndUserProgress.php';
  static const String getAchievementCount = '$apiPath/API_GetAchievementCount.php';
  static const String getAchievementDistribution = '$apiPath/API_GetAchievementDistribution.php';
  static const String getAchievementOfTheWeek = '$apiPath/API_GetAchievementOfTheWeek.php';
  }

/// Color Constants
class AppColors {
  // Primary colors
  static const Color primary = Color(0xFFFFD700);
  static const Color darkBackground = Color(0xFF262626);
  static const Color cardBackground = Color(0xFF353535);
  static const Color appBarBackground = Color(0xFF222222);
  static const Color inputBorder = Color(0xFFFFD700);
  
  static const double defaultPadding = 16.0;
static const double smallPadding = 8.0;
static const double tinyPadding = 4.0;
static const double largePadding = 24.0;

// Font sizes
static const double fontSizeSmall = 10.0;
static const double fontSizeDefault = 14.0;
static const double fontSizeMedium = 16.0;
static const double fontSizeLarge = 18.0;
static const double fontSizeXLarge = 24.0;

// Border radius
static const double borderRadiusSmall = 4.0;
static const double borderRadiusDefault = 8.0;
static const double borderRadiusLarge = 12.0;

// Icon sizes
static const double iconSizeSmall = 16.0;
static const double iconSizeDefault = 24.0;
static const double iconSizeLarge = 36.0;
  // Game Details
  static const String gameDetails = 'Game Details';
  static const String developer = 'Developer';
  static const String publisher = 'Publisher';
  static const String genre = 'Genre';
  static const String released = 'Released';
  static const String players = 'Players';
  static const String gameHashes = 'Game Hashes';
  static const String availableInLibrary = 'Available in library';
  static const String notAvailableInLibrary = 'Not available in library';
  static const String loading = 'Loading...';


  // Text colors
  static const Color textLight = Colors.white;
  static const Color textHighlight = Color(0xFFFFD700);
  static const Color textSubtle = Colors.grey;
  
  // Status colors
  static const Color success = Colors.green;
  static const Color warning = Colors.orange;
  static const Color error = Colors.red;
  static const Color info = Colors.lightBlue;
  
  // Game status colors
  static const Color gameAvailable = Colors.green;
  static const Color gamePartiallyAvailable = Colors.blue;
  static const Color gameUnavailable = Colors.red;
}

/// Text Constants
class AppStrings {
  // App name
  static const String appName = 'RetroAchievements Library Organizer';
  

static const String romDirectories = 'ROM Directories';
static const String addFolder = 'Add Folder';
static const String save = 'Save';
static const String directoryAlreadyInList = 'This directory is already in the list';
static const String manageDirectories = 'Manage Directories';
static const String availableInLibrary = 'Available in library';
  static const String notAvailableInLibrary = 'Not available in library';
  // Common
  static const String loading = 'Loading...';
  static const String error = 'Error';
  static const String success = 'Success';
  static const String ok = 'OK';
  static const String cancel = 'Cancel';
  static const String return_ = 'Return';
  
  // Login
  static const String login = 'LOGIN';
  static const String username = 'Username';
  static const String apiKey = 'API Key';
  static const String rememberMe = 'Remember me';
  static const String forgotPassword = 'Forgot Password?';
  static const String dontHaveAccount = 'Don\'t have an account?';
  static const String register = 'Register';
  static const String loginSuccessful = 'Login successful!';
  static const String apiKeyDisclaimer = 'Disclaimer: Your RetroAchievements username and API key are encrypted and stored locally for API communication only. They are not shared online.';
  
  // Errors
  static const String validationError = 'Validation Error';
  static const String pleaseEnterBothFields = 'Please fill in both username and API key fields.';
  static const String authenticationError = 'Authentication Error';
  static const String serverError = 'Server error: ';
  static const String networkError = 'Network error: ';
  static const String invalidResponseFormat = 'Invalid response format';
  
  // Navigation
  static const String dashboard = 'Dashboard';
  static const String myGames = 'My Games';
  static const String myAchievements = 'My Achievements';
  static const String settings = 'Settings';
  static const String about = 'About';
  static const String logout = 'Logout';
  
  // Games
  static const String selectConsole = 'Select a console to view your games:';
  static const String comingSoon = 'Coming Soon';
  static const String achievements = 'achievements';
  static const String points = 'points';
  static const String noGamesFound = 'No games found';
  
  // Mega Drive specific
  static const String megaDriveTitle = 'Mega Drive / Genesis Games';
  static const String romDirectory = 'ROM Directory:';
  static const String notSelected = 'Not selected';
  static const String gamesFound = 'Games found: ';
  static const String gamesWithMatchingROMs = 'Games with matching ROMs: ';
  static const String allROMsAvailable = 'All ROMs available';
  static const String someROMsAvailable = 'Some ROMs available';
  static const String noROMsAvailable = 'No ROMs available';
  static const String selectROMsFolder = 'Select Mega Drive ROMs Folder';
  static const String selectFolderInstructions = 'Please select the folder containing your Mega Drive ROMs. The app will scan this folder to identify your games.';
  static const String selectFolder = 'Select Folder';
  
  // Achievements
  static const String played = 'Played';
  static const String unfinished = 'Unfinished';
  static const String beaten = 'Beaten';
  static const String mastered = 'Mastered';
  static const String viewing = 'Viewing';
  static const String games = 'games';
  static const String noGameData = 'No game data available';
  static const String of = 'of';
  static const String lastPlayed = 'Last played: ';
  static const String today = 'Today';
  static const String yesterday = 'Yesterday';
  static const String daysAgo = 'days ago';
  static const String sortBy = 'Sort By';
  static const String filterBy = 'Filter By';
  static const String showOnlyCompleted = 'Show only completed games';
  static const String filterByPlatform = 'Filter by Platform';
  static const String clearAllFilters = 'Clear All Filters';
  static const String noGamesMatchFilters = 'No games match your filters';
  
  // Registration
  static const String registerAccount = 'Register Account';
  static const String name = 'Name';
  static const String email = 'Email';
  static const String phoneNumber = 'Phone Number';
  static const String password = 'Password';
  static const String confirmPassword = 'Confirm Password';
  static const String registrationSuccessful = 'Registration successful! You can now login.';
  


  // Validation messages
  static const String pleaseEnterName = 'Please enter your name';
  static const String pleaseEnterEmail = 'Please enter your email';
  static const String pleaseEnterValidEmail = 'Please enter a valid email';
  static const String pleaseEnterPhone = 'Please enter your phone number';
  static const String pleaseEnterPassword = 'Please enter a password';
  static const String passwordMinLength = 'Password must be at least 6 characters';
  static const String pleaseConfirmPassword = 'Please confirm your password';
  static const String passwordsDoNotMatch = 'Passwords do not match';
  
  // Forgot password
  static const String forgotPasswordTitle = 'Forgot Password';
  static const String enterEmailToRecover = 'Enter your email address to recover your password';
  static const String retrieve = 'Retrieve';
  static const String passwordResetLinkSent = 'Password reset link has been sent to your email.';
  
  // About screen
  static const String aboutTitle = 'About RetroAchievements Organizer';
  
}

/// Default pagination values
class PaginationConstants {
  static const int defaultPageSize = 20;
  static const int defaultInitialPage = 1;
}