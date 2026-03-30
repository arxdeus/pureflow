import 'package:pureflow/pureflow.dart';
import 'package:test/test.dart';

void main() {
  tearDown(() {
    Pureflow.observer = null;
  });

  group('FlowObserver - class structure', () {
    test('FlowObserver can be instantiated with no callbacks', () {
      final obs = FlowObserver();
      expect(obs.onObservableChanged, isNull);
      expect(obs.onPipelineEvent, isNull);
      expect(obs.onCreated, isNull);
    });

    test('FlowObserver stores onObservableChanged callback', () {
      void cb(String? label, FlowKind kind, Object? old, Object? next) {}
      final obs = FlowObserver(onObservableChanged: cb);
      expect(obs.onObservableChanged, isNotNull);
    });

    test('FlowObserver stores onPipelineEvent callback', () {
      void cb(String? pipelineLabel, String? eventLabel) {}
      final obs = FlowObserver(onPipelineEvent: cb);
      expect(obs.onPipelineEvent, isNotNull);
    });

    test('FlowObserver stores onCreated callback', () {
      void cb(String? label, FlowKind kind) {}
      final obs = FlowObserver(onCreated: cb);
      expect(obs.onCreated, isNotNull);
    });

    test('FlowObserver is const-constructible', () {
      const obs = FlowObserver();
      expect(obs, isNotNull);
    });
  });

  group('FlowKind enum', () {
    test('FlowKind has store variant', () {
      expect(FlowKind.store, isNotNull);
    });

    test('FlowKind has computed variant', () {
      expect(FlowKind.computed, isNotNull);
    });

    test('FlowKind has pipeline variant', () {
      expect(FlowKind.pipeline, isNotNull);
    });

    test('FlowKind has exactly 3 values', () {
      expect(FlowKind.values.length, 3);
    });
  });

  group('Pureflow global accessor', () {
    test('Pureflow.observer is null by default', () {
      expect(Pureflow.observer, isNull);
    });

    test('Pureflow.observer can be set to a FlowObserver', () {
      Pureflow.observer = FlowObserver();
      expect(Pureflow.observer, isNotNull);
    });

    test('Pureflow.observer can be set back to null', () {
      Pureflow.observer = FlowObserver();
      Pureflow.observer = null;
      expect(Pureflow.observer, isNull);
    });
  });
}
