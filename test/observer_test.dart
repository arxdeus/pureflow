import 'package:pureflow/pureflow.dart';
import 'package:test/test.dart';

void main() {
  tearDown(() {
    Pureflow.observer = null;
  });

  group('FlowObserver', () {
    group('onCreated', () {
      test('fires when Store is created', () {
        String? capturedLabel;
        FlowKind? capturedKind;

        Pureflow.observer = FlowObserver(
          onCreated: (label, kind) {
            capturedLabel = label;
            capturedKind = kind;
          },
        );

        Store<int>(0, debugLabel: 'counter');

        expect(capturedLabel, 'counter');
        expect(capturedKind, FlowKind.store);
      });

      test('fires when Computed is created', () {
        String? capturedLabel;
        FlowKind? capturedKind;

        Pureflow.observer = FlowObserver(
          onCreated: (label, kind) {
            capturedLabel = label;
            capturedKind = kind;
          },
        );

        final store = Store<int>(0);
        Computed(() => store.value * 2, debugLabel: 'doubled');

        expect(capturedLabel, 'doubled');
        expect(capturedKind, FlowKind.computed);
      });

      test('fires when Pipeline is created', () {
        String? capturedLabel;
        FlowKind? capturedKind;

        Pureflow.observer = FlowObserver(
          onCreated: (label, kind) {
            capturedLabel = label;
            capturedKind = kind;
          },
        );

        Pipeline(
          transformer: (source, process) => source.asyncExpand(process),
          debugLabel: 'testPipeline',
        );

        expect(capturedLabel, 'testPipeline');
        expect(capturedKind, FlowKind.pipeline);
      });

      test('fires with null label when no debugLabel set', () {
        var called = false;

        Pureflow.observer = FlowObserver(
          onCreated: (label, kind) {
            called = true;
          },
        );

        Store<int>(0);
        expect(called, isTrue);
      });
    });

    group('onObservableChanged', () {
      test('fires when Store value changes', () {
        String? capturedLabel;
        FlowKind? capturedKind;
        Object? capturedOld;
        Object? capturedNew;

        Pureflow.observer = FlowObserver(
          onObservableChanged: (label, kind, oldValue, newValue) {
            capturedLabel = label;
            capturedKind = kind;
            capturedOld = oldValue;
            capturedNew = newValue;
          },
        );

        final store = Store<int>(0, debugLabel: 'counter');
        store.value = 42;

        expect(capturedLabel, 'counter');
        expect(capturedKind, FlowKind.store);
        expect(capturedOld, 0);
        expect(capturedNew, 42);
      });

      test('does not fire when value is equal', () {
        var callCount = 0;

        Pureflow.observer = FlowObserver(
          onObservableChanged: (_, __, ___, ____) => callCount++,
        );

        final store = Store<int>(0, debugLabel: 'counter');
        store.value = 0;

        expect(callCount, 0);
      });

      test('fires when Computed value changes', () {
        final changes = <(FlowKind, Object?, Object?)>[];

        Pureflow.observer = FlowObserver(
          onObservableChanged: (label, kind, oldValue, newValue) {
            changes.add((kind, oldValue, newValue));
          },
        );

        final store = Store<int>(1, debugLabel: 'source');
        final doubled = Computed(() => store.value * 2, debugLabel: 'doubled');

        doubled.value; // initial: null → 2
        final initial = changes.where((c) => c.$1 == FlowKind.computed).toList();
        expect(initial.length, 1);
        expect(initial[0].$2, isNull);
        expect(initial[0].$3, 2);

        changes.clear();
        store.value = 5;
        doubled.value; // recompute: 2 → 10

        final recompute = changes.where((c) => c.$1 == FlowKind.computed).toList();
        expect(recompute.length, 1);
        expect(recompute[0].$2, 2);
        expect(recompute[0].$3, 10);
      });
    });

    group('onPipelineEvent', () {
      test('fires when pipeline.run is called', () async {
        String? capturedPipelineLabel;
        String? capturedEventLabel;

        Pureflow.observer = FlowObserver(
          onPipelineEvent: (pipelineLabel, eventLabel) {
            capturedPipelineLabel = pipelineLabel;
            capturedEventLabel = eventLabel;
          },
        );

        final pipeline = Pipeline(
          transformer: (source, process) => source.asyncExpand(process),
          debugLabel: 'testPipeline',
        );

        await pipeline.run(
          (ctx) async => 42,
          debugLabel: 'fetchData',
        );

        expect(capturedPipelineLabel, 'testPipeline');
        expect(capturedEventLabel, 'fetchData');
      });
    });

    group('exception safety', () {
      test('observer exception does not break Store', () {
        var listenerCalled = false;
        Pureflow.observer = FlowObserver(
          onObservableChanged: (_, __, ___, ____) => throw Exception('boom'),
        );
        final store = Store<int>(0, debugLabel: 'test');
        store.addListener(() => listenerCalled = true);
        store.value = 1;
        expect(store.value, 1);
        expect(listenerCalled, isTrue);
      });

      test('observer exception does not break Computed', () {
        Pureflow.observer = FlowObserver(
          onObservableChanged: (_, __, ___, ____) => throw Exception('boom'),
        );
        final store = Store<int>(1);
        final doubled = Computed(() => store.value * 2, debugLabel: 'doubled');
        doubled.value;
        store.value = 5;
        expect(doubled.value, 10);
      });

      test('observer exception in onCreated does not prevent creation', () {
        Pureflow.observer = FlowObserver(
          onCreated: (_, __) => throw Exception('boom'),
        );
        final store = Store<int>(42, debugLabel: 'test');
        expect(store.value, 42);
      });
    });

    group('zero-cost when no observer', () {
      test('Store works without observer', () {
        final store = Store<int>(0, debugLabel: 'counter');
        store.value = 1;
        expect(store.value, 1);
      });

      test('Computed works without observer', () {
        final store = Store<int>(1);
        final doubled = Computed(() => store.value * 2, debugLabel: 'doubled');
        expect(doubled.value, 2);
        store.value = 5;
        expect(doubled.value, 10);
      });
    });

    group('debugLabel', () {
      test('Store.debugLabel is accessible', () {
        final store = Store<int>(0, debugLabel: 'myStore');
        expect(store.debugLabel, 'myStore');
      });

      test('Store.debugLabel defaults to null', () {
        final store = Store<int>(0);
        expect(store.debugLabel, isNull);
      });

      test('Computed.debugLabel is accessible', () {
        final store = Store<int>(0);
        final computed = Computed(() => store.value, debugLabel: 'myComputed');
        expect(computed.debugLabel, 'myComputed');
      });

      test('Pipeline.debugLabel is accessible', () {
        final pipeline = Pipeline(
          transformer: (source, process) => source.asyncExpand(process),
          debugLabel: 'myPipeline',
        );
        expect(pipeline.debugLabel, 'myPipeline');
      });

      test('Store.toString includes debugLabel', () {
        final store = Store<int>(42, debugLabel: 'counter');
        expect(store.toString(), 'Store<int>[counter](42)');
      });

      test('Store.toString without debugLabel unchanged', () {
        final store = Store<int>(42);
        expect(store.toString(), 'Store<int>(42)');
      });

      test('Computed.toString includes debugLabel', () {
        final store = Store<int>(0);
        final computed = Computed(() => store.value, debugLabel: 'derived');
        computed.value;
        expect(computed.toString(), contains('derived'));
      });
    });
  });
}
