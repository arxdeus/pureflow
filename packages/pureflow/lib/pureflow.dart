/// Pureflow - A Pipeline-first reactive state toolkit for Dart and Flutter.
///
/// Pureflow makes async concurrency policy explicit with Pipeline, while Store,
/// Computed, and batching keep state small and predictable.
library;

export 'src/batch.dart' show batch;
export 'src/computed.dart' show Computed;
export 'src/interfaces.dart'
    show Observable, ReactiveValueObservable, ValueObservable;
export 'src/observer.dart' show FlowKind, FlowObserver, Pureflow;
export 'src/pipeline.dart'
    show EventMapper, EventTransformer, Pipeline, PipelineEventContext;
export 'src/store.dart' show Store;
export 'src/transformers.dart'
    show concurrent, droppable, restartable, sequential;
