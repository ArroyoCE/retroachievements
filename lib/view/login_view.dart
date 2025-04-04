// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:retroachievements_organizer/constants/constants.dart';
import 'package:retroachievements_organizer/controller/login_controller.dart';
import 'package:retroachievements_organizer/widgets/common_widgets.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _apiKeyController = TextEditingController();
  final LoginController _loginController = GetIt.instance<LoginController>();
  bool _isLoading = false;
  bool _rememberMe = true; // Default to true for remember me checkbox

  @override
  void initState() {
    super.initState();
    // Check if user is already logged in
    _checkExistingLogin();
  }

  // Check for existing login data
  Future<void> _checkExistingLogin() async {
    final loginData = await _loginController.getLoginData();
    if (loginData != null) {
      setState(() {
        _usernameController.text = loginData.username;
        // We don't prefill the API key for security reasons
      });
      
      // Check if auto-login is enabled and credentials exist
      final autoLogin = await _loginController.getAutoLogin();
      if (autoLogin) {
        // Auto login
        _performAutoLogin(loginData.username, loginData.apiKey);
      }
    }
  }
  
  // Perform auto login
  Future<void> _performAutoLogin(String username, String apiKey) async {
    setState(() {
      _isLoading = true;
    });

    // Process login
    final success = await _loginController.processLogin(
      context, 
      username, 
      apiKey,
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
      });

      if (success) {
        // Navigate to the home screen
        Navigator.pushReplacementNamed(context, 'home');
      }
    }
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
    if (!_loginController.validateFields(username, apiKey)) {
      _loginController.showValidationError(context);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // Process login
    final success = await _loginController.processLogin(
      context, 
      username, 
      apiKey,
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
      });

      if (success) {
        // Save auto login preference
        await _loginController.setAutoLogin(_rememberMe);
        
        // Show success and navigate to next screen
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(AppStrings.loginSuccessful),
            backgroundColor: AppColors.success,
          ),
        );
        
        // Navigate to the home screen
        Navigator.pushReplacementNamed(context, 'home');
      }
    }
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
                  isLoading: _isLoading,
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