import 'dart:async';

import 'package:pureflow/pureflow.dart';

Future<void> main() async {
  final results = Store<List<String>>(<String>[]);
  final pipeline = Pipeline(transformer: restartable());

  final subscription = results.listen((items) {
    print('applied results: ${items.join(', ')}');
  });

  Future<List<String>> search(String query) {
    print('queued query: $query');
    return pipeline.run<List<String>>((context) async {
      await Future<void>.delayed(const Duration(milliseconds: 80));
      if (!context.isActive) {
        print('ignored stale query: $query');
        return const <String>[];
      }

      final matches = _catalog
          .where((item) => item.toLowerCase().contains(query.toLowerCase()))
          .toList();
      results.value = matches;
      return matches;
    }, debugLabel: 'search:$query');
  }

  final pending = <Future<List<String>>>[];
  pending.add(search('d'));
  await Future<void>.delayed(const Duration(milliseconds: 10));
  pending.add(search('da'));
  await Future<void>.delayed(const Duration(milliseconds: 10));
  pending.add(search('dar'));

  await Future.wait(pending);
  print('latest visible results: ${results.value.join(', ')}');

  await subscription.cancel();
  results.dispose();
  await pipeline.dispose();
}

const _catalog = <String>[
  'Dart streams',
  'Dart isolates',
  'Flutter widgets',
  'State management',
  'Data pipelines',
];
