// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'attendance_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$attendanceNotifierHash() =>
    r'ab3c460324463b86224086b7e3b50e968e6fb5a9';

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

abstract class _$AttendanceNotifier
    extends BuildlessAutoDisposeAsyncNotifier<AttendanceSession2> {
  late final String classID;

  FutureOr<AttendanceSession2> build(
    String classID,
  );
}

/// See also [AttendanceNotifier].
@ProviderFor(AttendanceNotifier)
const attendanceNotifierProvider = AttendanceNotifierFamily();

/// See also [AttendanceNotifier].
class AttendanceNotifierFamily extends Family<AsyncValue<AttendanceSession2>> {
  /// See also [AttendanceNotifier].
  const AttendanceNotifierFamily();

  /// See also [AttendanceNotifier].
  AttendanceNotifierProvider call(
    String classID,
  ) {
    return AttendanceNotifierProvider(
      classID,
    );
  }

  @override
  AttendanceNotifierProvider getProviderOverride(
    covariant AttendanceNotifierProvider provider,
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
  String? get name => r'attendanceNotifierProvider';
}

/// See also [AttendanceNotifier].
class AttendanceNotifierProvider extends AutoDisposeAsyncNotifierProviderImpl<
    AttendanceNotifier, AttendanceSession2> {
  /// See also [AttendanceNotifier].
  AttendanceNotifierProvider(
    String classID,
  ) : this._internal(
          () => AttendanceNotifier()..classID = classID,
          from: attendanceNotifierProvider,
          name: r'attendanceNotifierProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$attendanceNotifierHash,
          dependencies: AttendanceNotifierFamily._dependencies,
          allTransitiveDependencies:
              AttendanceNotifierFamily._allTransitiveDependencies,
          classID: classID,
        );

  AttendanceNotifierProvider._internal(
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
  FutureOr<AttendanceSession2> runNotifierBuild(
    covariant AttendanceNotifier notifier,
  ) {
    return notifier.build(
      classID,
    );
  }

  @override
  Override overrideWith(AttendanceNotifier Function() create) {
    return ProviderOverride(
      origin: this,
      override: AttendanceNotifierProvider._internal(
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
  AutoDisposeAsyncNotifierProviderElement<AttendanceNotifier,
      AttendanceSession2> createElement() {
    return _AttendanceNotifierProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is AttendanceNotifierProvider && other.classID == classID;
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
mixin AttendanceNotifierRef
    on AutoDisposeAsyncNotifierProviderRef<AttendanceSession2> {
  /// The parameter `classID` of this provider.
  String get classID;
}

class _AttendanceNotifierProviderElement
    extends AutoDisposeAsyncNotifierProviderElement<AttendanceNotifier,
        AttendanceSession2> with AttendanceNotifierRef {
  _AttendanceNotifierProviderElement(super.provider);

  @override
  String get classID => (origin as AttendanceNotifierProvider).classID;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
