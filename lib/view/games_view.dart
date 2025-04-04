import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:retroachievements_organizer/constants/constants.dart';
import 'package:retroachievements_organizer/controller/api_calls.dart';
import 'package:retroachievements_organizer/controller/login_controller.dart';
import 'package:retroachievements_organizer/widgets/common_widgets.dart';

class GamesScreen extends StatefulWidget {
  const GamesScreen({super.key});

  @override
  State<GamesScreen> createState() => _GamesScreenState();
}

class _GamesScreenState extends State<GamesScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _consoles = [];
  List<Map<String, dynamic>> _filteredConsoles = [];
  bool _showOnlyAvailable = false;
  String? _errorMessage;
  
  // Currently only Mega Drive is available
  final List<int> _availableConsoleIds = [1]; // Mega Drive ID
  
  // Sort option - default alphabetical
  bool _sortAlphabetically = true;

  @override
  void initState() {
    super.initState();
    _loadConsoles();
  }

  Future<void> _loadConsoles({bool forceRefresh = false}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      // Get login data for API key
      final loginController = GetIt.instance<LoginController>();
      final loginData = await loginController.getLoginData();
      
      if (loginData == null) {
        setState(() {
          _errorMessage = 'No login data available. Please log in again.';
          _isLoading = false;
        });
        return;
      }
      
      // Use the new method to get consoles list
      final consolesData = await ApiService.getConsolesList(loginData.apiKey);
      
      if (consolesData.isNotEmpty) {
        // Convert to List<Map<String, dynamic>>
        final consoles = List<Map<String, dynamic>>.from(consolesData);
        
        setState(() {
          _consoles = consoles;
          _applyFiltersAndSort();
          _isLoading = false;
        });
        
        debugPrint('_consoles updated with ${_consoles.length} consoles');
        debugPrint('_filteredConsoles updated with ${_filteredConsoles.length} consoles');
      } else {
        setState(() {
          _errorMessage = 'No consoles found. Try again later.';
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading consoles: $e');
      setState(() {
        _errorMessage = 'Error loading consoles: $e';
        _isLoading = false;
      });
    }
  }

  void _applyFiltersAndSort() {
    List<Map<String, dynamic>> filtered = List.from(_consoles);
    
    // Filter for active consoles
    filtered = filtered.where((console) => 
      console['Active'] == true && console['IsGameSystem'] == true
    ).toList();
    
    // Apply filter for available consoles if enabled
    if (_showOnlyAvailable) {
      filtered = filtered.where((console) => 
        _availableConsoleIds.contains(console['ID'])
      ).toList();
    }
    
    // Apply sorting
    if (_sortAlphabetically) {
      filtered.sort((a, b) => a['Name'].toString().compareTo(b['Name'].toString()));
    }
    
    setState(() {
      _filteredConsoles = filtered;
    });
    
    debugPrint('Filtered consoles: ${_filteredConsoles.length}');
  }
  
  void _toggleSort() {
    setState(() {
      _sortAlphabetically = !_sortAlphabetically;
      _applyFiltersAndSort();
    });
  }

  void _onConsoleSelected(int consoleId) {
    if (consoleId == 1) { // Mega Drive
      // Notify parent to switch to Mega Drive view
      if (mounted) {
        MegaDriveSelectedNotification().dispatch(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
                // Sort button
                IconButton(
                  icon: const Icon(Icons.sort_by_alpha, color: AppColors.primary),
                  onPressed: _toggleSort,
                  tooltip: 'Toggle sorting',
                ),
                // Refresh button
                IconButton(
                  icon: const Icon(Icons.refresh, color: AppColors.primary),
                  onPressed: () => _loadConsoles(forceRefresh: true),
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
              value: _showOnlyAvailable,
              onChanged: (value) {
                setState(() {
                  _showOnlyAvailable = value ?? false;
                  _applyFiltersAndSort();
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
        if (_errorMessage != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              _errorMessage!,
              style: const TextStyle(
                color: AppColors.error,
                fontSize: 14,
              ),
            ),
          ),
        
        // Display loading indicator or consoles grid
        _isLoading
            ? const Expanded(
                child: Center(
                  child: RALoadingIndicator(),
                ),
              )
            : Expanded(
                child: _filteredConsoles.isEmpty
                    ? const Center(
                        child: Text(
                          'No consoles found',
                          style: TextStyle(
                            color: AppColors.textLight,
                            fontSize: 18,
                          ),
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.all(8),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 0.85,
                        ),
                        itemCount: _filteredConsoles.length,
                        itemBuilder: (context, index) {
                          final console = _filteredConsoles[index];
                          final isAvailable = _availableConsoleIds.contains(console['ID']);
                          
                          return _buildConsoleCard(
                            name: console['Name'] ?? 'Unknown',
                            iconUrl: console['IconURL'] ?? '',
                            isEnabled: isAvailable,
                            consoleId: console['ID'] ?? 0,
                          );
                        },
                      ),
              ),
      ],
    );
  }
  
  Widget _buildConsoleCard({
    required String name, 
    required String iconUrl,
    required bool isEnabled,
    required int consoleId,
  }) {
    return Card(
      color: AppColors.cardBackground,
      elevation: 4,
      child: InkWell(
        onTap: isEnabled ? () => _onConsoleSelected(consoleId) : null,
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
            ],
          ),
        ),
      ),
    );
  }
}

// Custom notification to signal that Mega Drive is selected
class MegaDriveSelectedNotification extends Notification {}