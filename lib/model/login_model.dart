class Login {
  final String username;
  final String apiKey;

  Login({required this.username, required this.apiKey});

  // Convert model to Map for storage
  Map<String, dynamic> toMap() {
    return {
      'username': username,
      'apiKey': apiKey,
    };
  }

  // Create model from Map (for retrieval)
  factory Login.fromMap(Map<String, dynamic> map) {
    return Login(
      username: map['username'],
      apiKey: map['apiKey'],
    );
  }

  @override
  String toString() {
    return 'Login(username: $username, apiKey: ${apiKey.substring(0, 3)}***)';
  }
}