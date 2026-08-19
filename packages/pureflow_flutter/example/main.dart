// ignore_for_file: depend_on_referenced_packages

import 'package:flutter/material.dart';
import 'package:pureflow_flutter/pureflow_flutter.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pureflow Example',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const CounterPage(),
    );
  }
}

class CounterController {
  final counter = Store<int>(0);
  final multiplier = Store<int>(1);

  late final doubled = Computed(() => counter.value * 2);
  late final result = Computed(() => counter.value * multiplier.value);

  final pipeline = Pipeline(
    transformer: (source, process) => source.asyncExpand(process),
  );

  void increment() => counter.value = counter.value + 1;
  void decrement() => counter.value = counter.value - 1;
  void incrementMultiplier() => multiplier.value = multiplier.value + 1;
  void decrementMultiplier() => multiplier.value = multiplier.value - 1;

  Future<String> addTenAsync() {
    return pipeline.run((context) async {
      if (!context.isActive) return 'Cancelled';

      await Future<void>.delayed(const Duration(seconds: 1));

      if (!context.isActive) return 'Cancelled during operation';

      counter.value = counter.value + 10;
      return 'Added 10 to counter';
    });
  }

  void dispose() {
    counter.dispose();
    multiplier.dispose();
    doubled.dispose();
    result.dispose();
    pipeline.dispose();
  }
}

class CounterPage extends StatefulWidget {
  const CounterPage({super.key});

  @override
  State<CounterPage> createState() => _CounterPageState();
}

class _CounterPageState extends State<CounterPage> {
  late final controller = CounterController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pureflow Example')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ValueListenableBuilder<int>(
              valueListenable: controller.counter.asListenable,
              builder: (context, value, child) {
                return Text(
                  'Counter: $value',
                  style: Theme.of(context).textTheme.headlineMedium,
                );
              },
            ),
            const SizedBox(height: 20),
            ValueListenableBuilder<int>(
              valueListenable: controller.doubled.asListenable,
              builder: (context, value, child) {
                return Text(
                  'Doubled: $value',
                  style: Theme.of(context).textTheme.headlineSmall,
                );
              },
            ),
            const SizedBox(height: 20),
            ValueListenableBuilder<int>(
              valueListenable: controller.result.asListenable,
              builder: (context, value, child) {
                return Text(
                  'Counter × Multiplier: $value',
                  style: Theme.of(context).textTheme.headlineSmall,
                );
              },
            ),
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Multiplier: '),
                ValueListenableBuilder<int>(
                  valueListenable: controller.multiplier.asListenable,
                  builder: (context, value, child) {
                    return Text(
                      '$value',
                      style: Theme.of(context).textTheme.titleLarge,
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: controller.decrement,
                  child: const Text('-'),
                ),
                const SizedBox(width: 20),
                ElevatedButton(
                  onPressed: controller.increment,
                  child: const Text('+'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: controller.decrementMultiplier,
                  child: const Text('Multiplier -'),
                ),
                const SizedBox(width: 20),
                ElevatedButton(
                  onPressed: controller.incrementMultiplier,
                  child: const Text('Multiplier +'),
                ),
              ],
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                final result = await controller.addTenAsync();
                if (!mounted) return;
                messenger.showSnackBar(
                  SnackBar(content: Text(result)),
                );
              },
              child: const Text('Pipeline: Add 10 (async)'),
            ),
          ],
        ),
      ),
    );
  }
}
