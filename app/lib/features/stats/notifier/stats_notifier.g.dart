// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'stats_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$statsNotifierHash() => r'fcd7e3121a79f4d81bdfedeb4d691a984be2972f';

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

abstract class _$StatsNotifier
    extends BuildlessAutoDisposeAsyncNotifier<StatsState> {
  late final String classID;

  FutureOr<StatsState> build(
    String classID,
  );
}

/// See also [StatsNotifier].
@ProviderFor(StatsNotifier)
const statsNotifierProvider = StatsNotifierFamily();

/// See also [StatsNotifier].
class StatsNotifierFamily extends Family<AsyncValue<StatsState>> {
  /// See also [StatsNotifier].
  const StatsNotifierFamily();

  /// See also [StatsNotifier].
  StatsNotifierProvider call(
    String classID,
  ) {
    return StatsNotifierProvider(
      classID,
    );
  }

  @override
  StatsNotifierProvider getProviderOverride(
    covariant StatsNotifierProvider provider,
  ) {
    return call(
      provider.classID,
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
  String? get name => r'statsNotifierProvider';
}

/// See also [StatsNotifier].
class StatsNotifierProvider
    extends AutoDisposeAsyncNotifierProviderImpl<StatsNotifier, StatsState> {
  /// See also [StatsNotifier].
  StatsNotifierProvider(
    String classID,
  ) : this._internal(
          () => StatsNotifier()..classID = classID,
          from: statsNotifierProvider,
          name: r'statsNotifierProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$statsNotifierHash,
          dependencies: StatsNotifierFamily._dependencies,
          allTransitiveDependencies:
              StatsNotifierFamily._allTransitiveDependencies,
          classID: classID,
        );

  StatsNotifierProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.classID,
  }) : super.internal();

  final String classID;

  @override
  FutureOr<StatsState> runNotifierBuild(
    covariant StatsNotifier notifier,
  ) {
    return notifier.build(
      classID,
    );
  }

  @override
  Override overrideWith(StatsNotifier Function() create) {
    return ProviderOverride(
      origin: this,
      override: StatsNotifierProvider._internal(
        () => create()..classID = classID,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        classID: classID,
      ),
    );
  }

  @override
  AutoDisposeAsyncNotifierProviderElement<StatsNotifier, StatsState>
      createElement() {
    return _StatsNotifierProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is StatsNotifierProvider && other.classID == classID;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, classID.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin StatsNotifierRef on AutoDisposeAsyncNotifierProviderRef<StatsState> {
  /// The parameter `classID` of this provider.
  String get classID;
}

class _StatsNotifierProviderElement
    extends AutoDisposeAsyncNotifierProviderElement<StatsNotifier, StatsState>
    with StatsNotifierRef {
  _StatsNotifierProviderElement(super.provider);

  @override
  String get classID => (origin as StatsNotifierProvider).classID;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
