/// The kind of Pureflow reactive primitive.
enum FlowKind {
  /// A [Store] — mutable reactive value holder.
  store,

  /// A [Computed] — derived reactive value.
  computed,

  /// A [Pipeline] — async task executor.
  pipeline,
}

/// A global observer for monitoring Pureflow reactive primitives.
///
/// Set [Pureflow.observer] to an instance of [FlowObserver] to receive
/// callbacks when reactive values change, pipeline events occur, or
/// new observables are created.
///
/// All callbacks are optional. Only the callbacks you provide will be invoked.
///
/// **Important:** Observer callbacks MUST NOT modify reactive state (Store values,
/// Computed triggers, etc.) from within callbacks. Doing so may cause re-entrant
/// notifications and unpredictable behavior.
///
/// Observer callbacks are wrapped in try-catch internally — if a callback throws,
/// the error is silently swallowed to protect the reactive system.
///
/// ## Example
///
/// ```dart
/// Pureflow.observer = FlowObserver(
///   onObservableChanged: (label, kind, oldValue, newValue) {
///     print('[$kind] $label: $oldValue → $newValue');
///   },
///   onPipelineEvent: (pipelineLabel, eventLabel) {
///     print('[Pipeline] $pipelineLabel.$eventLabel');
///   },
///   onCreated: (label, kind) {
///     print('Created $kind: $label');
///   },
/// );
/// ```
class FlowObserver {
  /// Called when a [Store] or [Computed] value changes.
  ///
  /// - [debugLabel]: The label of the observable (null if not set).
  /// - [kind]: Whether this is a [Store] or [Computed].
  /// - [oldValue]: The previous value (null for first Computed evaluation).
  /// - [newValue]: The new value.
  final void Function(
    String? debugLabel,
    FlowKind kind,
    Object? oldValue,
    Object? newValue,
  )? onObservableChanged;

  /// Called when [Pipeline.run] is invoked.
  ///
  /// - [pipelineLabel]: The debugLabel of the pipeline (null if not set).
  /// - [eventLabel]: The debugLabel of the specific run() call (null if not set).
  final void Function(
    String? pipelineLabel,
    String? eventLabel,
  )? onPipelineEvent;

  /// Called when a new [Store], [Computed], or [Pipeline] is created.
  ///
  /// - [debugLabel]: The label of the created object (null if not set).
  /// - [kind]: The type of object created.
  final void Function(
    String? debugLabel,
    FlowKind kind,
  )? onCreated;

  /// Creates a [FlowObserver] with optional callbacks.
  const FlowObserver({
    this.onObservableChanged,
    this.onPipelineEvent,
    this.onCreated,
  });
}

/// Global entry point for Pureflow configuration.
///
/// Use [Pureflow.observer] to set a global observer for debugging
/// and monitoring reactive state changes.
///
/// ## Example
///
/// ```dart
/// Pureflow.observer = FlowObserver(
///   onObservableChanged: (label, kind, old, next) {
///     print('$label changed: $old → $next');
///   },
/// );
/// ```
abstract final class Pureflow {
  /// The global observer for all Pureflow reactive primitives.
  ///
  /// Set to a [FlowObserver] instance to receive callbacks.
  /// Set to `null` to disable observation (default).
  ///
  /// When `null`, all observer hooks are zero-cost (single null check).
  ///
  /// Set to `null` when observation is no longer needed to allow the observer
  /// (and any objects it captures in closures) to be garbage collected.
  static FlowObserver? observer;
}
