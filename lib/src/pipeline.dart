import 'package:pureflow/src/implementation/pipeline/pipeline.dart';

/// EventTransformer processes a stream of events using an EventMapper.
typedef EventTransformer<E, R> = Stream<R> Function(
  Stream<E> source,
  Stream<R> Function(E event) process,
);
typedef EventMapper<E, R> = Stream<R> Function(E event);

abstract class Pipeline {
  factory Pipeline({
    required EventTransformer<dynamic, dynamic> transformer,
  }) = PipelineImpl;

  Future<R> run<R>(
    Future<R> Function(PipelineEventContext context) task,
  );
  Future<void> dispose({bool force = false});
}
