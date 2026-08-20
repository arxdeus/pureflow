// ============================================================================
// Bit Flags for Status
// ============================================================================

import 'package:pureflow/src/internal/state/reactive_source.dart';

/// Bit flags for ReactiveSource status.
const int disposedBit = 1 << 0;
const int notifyingBit = 1 << 1;
const int inBatchBit = 1 << 2;

/// Bit flags for Computed view state.
///
/// These live in the same `status` field as the ReactiveSource flags above
/// (single int per object, single load on the hot paths), so their bit
/// positions must not overlap.
const int dirtyBit = 1 << 3;
const int runningBit = 1 << 4;
const int viewDisposedBit = 1 << 5;
const int hasValueBit = 1 << 6;

// ============================================================================
// Global State for Reactive System
// ============================================================================

/// Currently evaluating Computed (for dependency tracking).
DependentSource<Object?>? currentView;
