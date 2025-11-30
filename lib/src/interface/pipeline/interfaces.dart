/// EventTransformer processes a stream of events using an EventMapper.
typedef EventTransformer<EventType, ResultType> = Stream<ResultType> Function(
  Stream<EventType> source,
  Stream<ResultType> Function(EventType event) process,
);
typedef EventMapper<EventType, ResultType> = Stream<ResultType> Function(
    EventType event);
