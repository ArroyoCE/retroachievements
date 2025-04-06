// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'game_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$gamesHash() => r'df781e4eb6d913ab3d813d8d8fece1137fe3272b';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

abstract class _$Games extends BuildlessAutoDisposeNotifier<GameState> {
  late final int consoleId;
  late final String consoleName;

  GameState build({
    int consoleId = 0,
    String consoleName = '',
  });
}

/// See also [Games].
@ProviderFor(Games)
const gamesProvider = GamesFamily();

/// See also [Games].
class GamesFamily extends Family<GameState> {
  /// See also [Games].
  const GamesFamily();

  /// See also [Games].
  GamesProvider call({
    int consoleId = 0,
    String consoleName = '',
  }) {
    return GamesProvider(
      consoleId: consoleId,
      consoleName: consoleName,
    );
  }

  @override
  GamesProvider getProviderOverride(
    covariant GamesProvider provider,
  ) {
    return call(
      consoleId: provider.consoleId,
      consoleName: provider.consoleName,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'gamesProvider';
}

/// See also [Games].
class GamesProvider extends AutoDisposeNotifierProviderImpl<Games, GameState> {
  /// See also [Games].
  GamesProvider({
    int consoleId = 0,
    String consoleName = '',
  }) : this._internal(
          () => Games()
            ..consoleId = consoleId
            ..consoleName = consoleName,
          from: gamesProvider,
          name: r'gamesProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$gamesHash,
          dependencies: GamesFamily._dependencies,
          allTransitiveDependencies: GamesFamily._allTransitiveDependencies,
          consoleId: consoleId,
          consoleName: consoleName,
        );

  GamesProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.consoleId,
    required this.consoleName,
  }) : super.internal();

  final int consoleId;
  final String consoleName;

  @override
  GameState runNotifierBuild(
    covariant Games notifier,
  ) {
    return notifier.build(
      consoleId: consoleId,
      consoleName: consoleName,
    );
  }

  @override
  Override overrideWith(Games Function() create) {
    return ProviderOverride(
      origin: this,
      override: GamesProvider._internal(
        () => create()
          ..consoleId = consoleId
          ..consoleName = consoleName,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        consoleId: consoleId,
        consoleName: consoleName,
      ),
    );
  }

  @override
  AutoDisposeNotifierProviderElement<Games, GameState> createElement() {
    return _GamesProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is GamesProvider &&
        other.consoleId == consoleId &&
        other.consoleName == consoleName;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, consoleId.hashCode);
    hash = _SystemHash.combine(hash, consoleName.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin GamesRef on AutoDisposeNotifierProviderRef<GameState> {
  /// The parameter `consoleId` of this provider.
  int get consoleId;

  /// The parameter `consoleName` of this provider.
  String get consoleName;
}

class _GamesProviderElement
    extends AutoDisposeNotifierProviderElement<Games, GameState> with GamesRef {
  _GamesProviderElement(super.provider);

  @override
  int get consoleId => (origin as GamesProvider).consoleId;
  @override
  String get consoleName => (origin as GamesProvider).consoleName;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
