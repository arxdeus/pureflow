import 'package:pureflow/pureflow.dart';

import 'controllers_example.dart';

void main() {
  final pipeline = Pipeline(
    transformer: (source, process) => source.switchMap(process),
  );

  pipeline.run<void>((context) async {
    await Future<void>.delayed(const Duration(seconds: 1));
    if (!context.isActive) {
      return print('NOT ACTIVE');
    }
    print('Hello, world!');
  });
  pipeline.run((context) async {
    await Future<void>.delayed(const Duration(seconds: 1));
    print('Hello, world!');
  });
}
