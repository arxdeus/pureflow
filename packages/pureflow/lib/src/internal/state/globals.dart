// ============================================================================
// Bit Flags for Status
// ============================================================================

import 'package:pureflow/src/internal/state/reactive_source.dart';

/// Bit flags for ReactiveSource status.
const int disposedBit = 1 << 0;
const int notifyingBit = 1 << 1;

/// Bit flags for Computed status.
const int dirtyBit = 1 << 0;
const int runningBit = 1 << 1;
const int viewDisposedBit = 1 << 2;

// ============================================================================
// Global State for Reactive System
// ============================================================================

/// Currently evaluating Computed (for dependency tracking).
/// Using dynamic to avoid circular imports with Computed.
ReactiveSource<Object?>? currentView;

/// Current batch depth for batched updates.
int batchDepth = 0;

/// Pre-allocated batch buffer for better performance.
final List<ReactiveSource<Object?>?> batchBuffer =
    List.filled(64, null, growable: true);
int batchCount = 0;
