import 'package:meta/meta.dart';
import 'package:pureflow/src/internal/state/reactive_source.dart';

// ============================================================================
// Dependency Node (Optimized for reactive tracking only)
// ============================================================================

/// Node for tracking dependencies between sources and Computed values.
@internal
class DependencyNode {
  /// The source this dependency is attached to.
  ReactiveSource<Object?> source;

  /// Target Computed that depends on the source.
  ReactiveSource<Object?> target;

  /// Whether this dependency is still active (false = recyclable).
  bool isActive = true;

  /// Links for source's dependency list.
  DependencyNode? prev;
  DependencyNode? next;

  /// Links for target's dependency list (what this target depends on).
  DependencyNode? prevSource;
  DependencyNode? nextSource;

  /// Rollback pointer for context switching.
  DependencyNode? rollback;

  DependencyNode({required this.source, required this.target});
}

// ============================================================================
// Node Allocation Functions
// ============================================================================

/// Allocates a new DependencyNode.
/// Dart VM's bump-pointer new-space allocator is faster than pooling.
@internal
@pragma('vm:prefer-inline')
DependencyNode acquireNode(
  ReactiveSource<Object?> source,
  ReactiveSource<Object?> target,
) {
  return DependencyNode(source: source, target: target);
}

/// No-op. Dart VM's bump-pointer new-space allocator is faster than pooling.
@internal
@pragma('vm:prefer-inline')
void releaseNode(DependencyNode node) {}
