// lib/view/login_view.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:retroachievements_organizer/constants/constants.dart';
// Ensure you're using the correct case for the import path
import 'package:retroachievements_organizer/providers/user_provider.dart';
import 'package:retroachievements_organizer/widgets/common_widgets.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _apiKeyController = TextEditingController();
  bool _rememberMe = true; // Default to true for remember me checkbox

  @override
  void initState() {
    super.initState();
    // No need to check login here, the provider does it automatically
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  // Handle login process
  Future<void> _handleLogin() async {
    final username = _usernameController.text.trim();
    final apiKey = _apiKeyController.text.trim();

    // Validate fields
    if (username.isEmpty || apiKey.isEmpty) {
      _showValidationError();
      return;
    }

    // Call login method in our provider
    await ref.read(userProvider.notifier).login(username, apiKey);
    
    final userState = ref.read(userProvider);
    
    if (userState.isAuthenticated) {
      // Save auto login preference
      await ref.read(userProvider.notifier).setAutoLogin(_rememberMe);
      
      // Show success and navigate to next screen
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(AppStrings.loginSuccessful),
            backgroundColor: AppColors.success,
          ),
        );
        
        // Navigate to the home screen
        Navigator.pushReplacementNamed(context, 'home');
      }
    } else if (userState.errorMessage != null) {
      // Show error message
      if (mounted) {
        _showAuthError(userState.errorMessage!);
      }
    }
  }
  
  // Show alert if validation fails
  void _showValidationError() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF333333),
          title: const Text(
            'Validation Error',
            style: TextStyle(color: Color(0xFFFFD700)),
          ),
          content: const Text(
            'Please fill in both username and API key fields.',
            style: TextStyle(color: Colors.white),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'OK',
                style: TextStyle(color: Color(0xFFFFD700)),
              ),
            ),
          ],
        );
      },
    );
  }

  // Show authentication error
  void _showAuthError(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF333333),
          title: const Text(
            'Authentication Error',
            style: TextStyle(color: Color(0xFFFFD700)),
          ),
          content: Text(
            message,
            style: const TextStyle(color: Colors.white),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'OK',
                style: TextStyle(color: Color(0xFFFFD700)),
              ),
            ),
          ],
        );
      },
    );
  }

  // Navigate to register screen
  void _navigateToRegister() {
    Navigator.pushNamed(context, 'register');
  }

  // Navigate to forgot password screen
  void _navigateToForgotPassword() {
    Navigator.pushNamed(context, 'forgot_password');
  }

  @override
  Widget build(BuildContext context) {
    // Watch the user state to react to changes
    final userState = ref.watch(userProvider);
    
    // If already authenticated, navigate to home
    if (userState.isAuthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacementNamed(context, 'home');
      });
    }
    
    // Populate username field if available
    if (userState.username != null && _usernameController.text.isEmpty) {
      _usernameController.text = userState.username!;
    }
    
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      appBar: const RAAppBar(
        title: AppStrings.appName,
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo
                Image.asset(
                  'images/ra-icon.png',
                  height: 100,
                  width: 100,
                ),
                const SizedBox(height: 40),
                
                // Username field
                RATextField(
                  controller: _usernameController,
                  labelText: AppStrings.username,
                  prefixIcon: Icons.person,
                ),
                const SizedBox(height: 24),
                
                // API Key field
                RATextField(
                  controller: _apiKeyController,
                  labelText: AppStrings.apiKey,
                  obscureText: true,
                  prefixIcon: Icons.vpn_key,
                ),
                const SizedBox(height: 16),
                
                // Remember me checkbox and forgot password link
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Checkbox(
                          value: _rememberMe,
                          onChanged: (value) {
                            setState(() {
                              _rememberMe = value ?? false;
                            });
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
                          AppStrings.rememberMe,
                          style: TextStyle(
                            color: AppColors.textLight,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    // Forgot password link
                    TextButton(
                      onPressed: _navigateToForgotPassword,
                      child: const Text(
                        AppStrings.forgotPassword,
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // Login button
                RAPrimaryButton(
                  text: AppStrings.login,
                  onPressed: _handleLogin,
                  isLoading: userState.isLoading,
                ),
                
                const SizedBox(height: 24),
                
                // Register link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      AppStrings.dontHaveAccount,
                      style: TextStyle(
                        color: AppColors.textLight,
                        fontSize: 14,
                      ),
                    ),
                    TextButton(
                      onPressed: _navigateToRegister,
                      child: const Text(
                        AppStrings.register,
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // Updated disclaimer text
                const Text(
                  AppStrings.apiKeyDisclaimer,
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}