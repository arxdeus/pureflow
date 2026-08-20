/// Runs only the Pureflow benchmarks and prints `name<TAB>microseconds`.
///
/// Fast feedback loop for optimization work:
/// `dart compile exe benchmark/bin/pf_only.dart -o pf.exe && ./pf.exe`
library;

import 'package:benchmark/impls/pureflow_benchmarks.dart' as pureflow;

Future<void> main() async {
  final results = await pureflow.runBenchmark();
  for (final r in results) {
    print('${r.name}\t${r.value.toStringAsFixed(4)}');
  }
}
