// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'students_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$studentsNotifierHash() => r'492cad5254af8dbc9e81c8361e5b469ef0a7b466';

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

abstract class _$StudentsNotifier
    extends BuildlessAutoDisposeAsyncNotifier<List<StudentModel>> {
  late final String classID;

  FutureOr<List<StudentModel>> build(
    String classID,
  );
}

/// See also [StudentsNotifier].
@ProviderFor(StudentsNotifier)
const studentsNotifierProvider = StudentsNotifierFamily();

/// See also [StudentsNotifier].
class StudentsNotifierFamily extends Family<AsyncValue<List<StudentModel>>> {
  /// See also [StudentsNotifier].
  const StudentsNotifierFamily();

  /// See also [StudentsNotifier].
  StudentsNotifierProvider call(
    String classID,
  ) {
    return StudentsNotifierProvider(
      classID,
    );
  }

  @override
  StudentsNotifierProvider getProviderOverride(
    covariant StudentsNotifierProvider provider,
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
  String? get name => r'studentsNotifierProvider';
}

/// See also [StudentsNotifier].
class StudentsNotifierProvider extends AutoDisposeAsyncNotifierProviderImpl<
    StudentsNotifier, List<StudentModel>> {
  /// See also [StudentsNotifier].
  StudentsNotifierProvider(
    String classID,
  ) : this._internal(
          () => StudentsNotifier()..classID = classID,
          from: studentsNotifierProvider,
          name: r'studentsNotifierProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$studentsNotifierHash,
          dependencies: StudentsNotifierFamily._dependencies,
          allTransitiveDependencies:
              StudentsNotifierFamily._allTransitiveDependencies,
          classID: classID,
        );

  StudentsNotifierProvider._internal(
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
  FutureOr<List<StudentModel>> runNotifierBuild(
    covariant StudentsNotifier notifier,
  ) {
    return notifier.build(
      classID,
    );
  }

  @override
  Override overrideWith(StudentsNotifier Function() create) {
    return ProviderOverride(
      origin: this,
      override: StudentsNotifierProvider._internal(
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
  AutoDisposeAsyncNotifierProviderElement<StudentsNotifier, List<StudentModel>>
      createElement() {
    return _StudentsNotifierProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is StudentsNotifierProvider && other.classID == classID;
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
mixin StudentsNotifierRef
    on AutoDisposeAsyncNotifierProviderRef<List<StudentModel>> {
  /// The parameter `classID` of this provider.
  String get classID;
}

class _StudentsNotifierProviderElement
    extends AutoDisposeAsyncNotifierProviderElement<StudentsNotifier,
        List<StudentModel>> with StudentsNotifierRef {
  _StudentsNotifierProviderElement(super.provider);

  @override
  String get classID => (origin as StudentsNotifierProvider).classID;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
