import 'package:meta/meta.dart';
import 'package:pureflow/src/internal/state/reactive_source.dart';

// ============================================================================
// Object Pool for DependencyNode
// ============================================================================

/// Object pool for DependencyNode to reduce allocations.
@internal
DependencyNode? nodePool;

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
// Object Pool Functions
// ============================================================================

/// Acquires a node from the pool or creates a new one.
@internal
@pragma('vm:prefer-inline')
DependencyNode acquireNode(
  ReactiveSource<Object?> source,
  ReactiveSource<Object?> target,
) {
  final pooled = nodePool;
  if (pooled != null) {
    nodePool = pooled.next;
    pooled
      ..source = source
      ..target = target
      ..isActive = true
      ..prev = null
      ..next = null
      ..prevSource = null
      ..nextSource = null
      ..rollback = null;
    return pooled;
  }
  return DependencyNode(source: source, target: target);
}

/// Returns a node to the pool for reuse.
@internal
@pragma('vm:prefer-inline')
void releaseNode(DependencyNode node) {
  node.next = nodePool;
  nodePool = node;
}
