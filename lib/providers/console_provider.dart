// lib/providers/console_provider.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:retroachievements_organizer/providers/api_service_provider.dart';
import 'package:retroachievements_organizer/providers/user_provider.dart';

part 'console_provider.g.dart';

class ConsoleState {
  final bool isLoading;
  final String? errorMessage;
  final List<Map<String, dynamic>> consoles;
  final List<Map<String, dynamic>> filteredConsoles;
  final bool showOnlyAvailable;
  final bool sortAlphabetically;
  
  // Available console IDs for MD5 hash support
  final List<int> availableConsoleIds;
  
  // Track when consoles are fully loaded
  final bool consolesLoaded;

  ConsoleState({
    this.isLoading = false,
    this.errorMessage,
    this.consoles = const [],
    this.filteredConsoles = const [],
    this.showOnlyAvailable = false,
    this.sortAlphabetically = true,
    this.availableConsoleIds = const [],
    this.consolesLoaded = false,
  });

  ConsoleState copyWith({
    bool? isLoading,
    String? errorMessage,
    List<Map<String, dynamic>>? consoles,
    List<Map<String, dynamic>>? filteredConsoles,
    bool? showOnlyAvailable,
    bool? sortAlphabetically,
    List<int>? availableConsoleIds,
    bool? consolesLoaded,
  }) {
    return ConsoleState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
      consoles: consoles ?? this.consoles,
      filteredConsoles: filteredConsoles ?? this.filteredConsoles,
      showOnlyAvailable: showOnlyAvailable ?? this.showOnlyAvailable,
      sortAlphabetically: sortAlphabetically ?? this.sortAlphabetically,
      availableConsoleIds: availableConsoleIds ?? this.availableConsoleIds,
      consolesLoaded: consolesLoaded ?? this.consolesLoaded,
    );
  }
}

@riverpod
class Consoles extends _$Consoles {
  @override
  ConsoleState build() {
    return ConsoleState(
      availableConsoleIds: [
        1, 4, 6, 10, 11, 14, 15, 17, 23, 24, 25, 28, 29, 33, 37, 38, 44, 45, 46, 47, 51, 53, 57, 63, 69, 71, 72,
      ],
    );
  }

  Future<void> loadConsoles({bool forceRefresh = false}) async {
    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      consolesLoaded: false,  // Reset the loaded flag
    );
    
    try {
      // Get API key from user provider
      final apiKey = await ref.read(userProvider.notifier).getApiKey();
      
      if (apiKey == null) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'No login data available. Please log in again.',
        );
        return;
      }
      
      // Use API service provider
      final apiProvider = ref.read(apiServiceProviderProvider.notifier);
      
      // Get consoles list
      final consolesData = await apiProvider.getConsolesList(apiKey);
      
      if (consolesData.isNotEmpty) {
        // Convert to List<Map<String, dynamic>>
        final consoles = List<Map<String, dynamic>>.from(consolesData);
        
        state = state.copyWith(
          consoles: consoles,
          isLoading: false,
        );
        
        // Apply filters and sort
        applyFiltersAndSort();
        
        // Set consolesLoaded to true AFTER everything is done
        state = state.copyWith(consolesLoaded: true);
      } else {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'No consoles found. Try again later.',
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Error loading consoles: $e',
      );
    }
  }

 void applyFiltersAndSort() {
    List<Map<String, dynamic>> filtered = List.from(state.consoles);
    
    // Filter for active consoles
    filtered = filtered.where((console) => 
      console['Active'] == true && console['IsGameSystem'] == true
    ).toList();
    
    // Apply filter for available consoles if enabled
    if (state.showOnlyAvailable) {
      filtered = filtered.where((console) => 
        state.availableConsoleIds.contains(console['ID'])
      ).toList();
    }
    
    // Apply sorting
    if (state.sortAlphabetically) {
      filtered.sort((a, b) => a['Name'].toString().compareTo(b['Name'].toString()));
    }
    
    state = state.copyWith(filteredConsoles: filtered);
  }

  void toggleSort() {
    state = state.copyWith(sortAlphabetically: !state.sortAlphabetically);
    applyFiltersAndSort();
  }
  
  void toggleAvailableFilter(bool value) {
    state = state.copyWith(showOnlyAvailable: value);
    applyFiltersAndSort();
  }
  
  String getConsoleName(int consoleId) {
    // Get console name from the consoles list first if available
    final console = state.consoles.firstWhere(
      (c) => c['ID'] == consoleId,
      orElse: () => {'Name': ''}
    );
    
    if (console['Name'].toString().isNotEmpty) {
      return console['Name'].toString();
    }
    
    // Fall back to the hardcoded mapping
    switch (consoleId) {
      case 1:
        return 'Mega Drive';
      case 4:
        return 'Game Boy';
      // Add more mappings as needed
      default:
        return 'Console $consoleId';
    }
  }
}