import 'package:benchmark/common/benchmark_report.dart';
import 'package:benchmark/common/benchmark_result.dart';
import 'package:benchmark/common/benchmark_statistics.dart';
import 'package:test/test.dart';

BenchmarkStatistics _statistics({
  required String name,
  required String library,
  required String feature,
  required BenchmarkTiming timing,
  required double value,
}) {
  return BenchmarkStatistics(
    name: name,
    library: library,
    feature: feature,
    timing: timing,
    samples: [value, value, value],
  );
}

String _section(String report, String heading, String nextHeading) {
  final start = report.indexOf(heading);
  final end = report.indexOf(nextHeading, start + heading.length);
  return report.substring(start, end);
}

void main() {
  test('separates synchronous and async-settled summary tables', () {
    final report = renderBenchmarkReport(
      statistics: [
        _statistics(
          name: 'Store.notify',
          library: 'Pureflow',
          feature: 'State Holder: Notify',
          timing: BenchmarkTiming.synchronous,
          value: 1,
        ),
        _statistics(
          name: 'Cubit.notify',
          library: 'Bloc',
          feature: 'State Holder: Notify',
          timing: BenchmarkTiming.asyncSettled,
          value: 2,
        ),
        _statistics(
          name: 'Pipeline.sequential',
          library: 'Pureflow',
          feature: 'Async Concurrency: Sequential',
          timing: BenchmarkTiming.asyncSettled,
          value: 3,
        ),
        _statistics(
          name: 'Sequential',
          library: 'Bloc',
          feature: 'Async Concurrency: Sequential',
          timing: BenchmarkTiming.asyncSettled,
          value: 6,
        ),
      ],
      provenance: const BenchmarkReportProvenance(
        generatedAt: '2026-08-23T00:00:00Z',
        sourceFingerprint: '0123456789012345678901234567890123456789',
        dartVersion: 'Dart test',
        operatingSystem: 'test OS',
        cpu: 'test CPU',
        logicalProcessors: 1,
        trials: 3,
        seed: 1337,
        packageVersions: {},
      ),
      libraries: const [
        BenchmarkLibrarySpec('Pureflow', 'https://example.com/pureflow'),
        BenchmarkLibrarySpec('Bloc', 'https://example.com/bloc'),
      ],
      featureOrder: const [
        'State Holder: Notify',
        'Async Concurrency: Sequential',
      ],
    );

    final synchronous = _section(
      report,
      '## Synchronous Results Summary',
      '## Synchronous Performance Comparison',
    );
    expect(
      synchronous,
      contains('| State Holder: Notify | 1.00 ± 0.0000 μs | — |'),
    );
    expect(synchronous, isNot(contains('2.00 ± 0.0000 μs')));

    final asyncSettled = _section(
      report,
      '## Asynchronously Settled Results Summary',
      '## Asynchronously Settled Performance Comparison',
    );
    expect(
      asyncSettled,
      contains('| State Holder: Notify | — | 2.00 ± 0.0000 μs |'),
    );
    expect(
      asyncSettled,
      contains(
          '| Async Concurrency: Sequential | 3.00 ± 0.0000 μs | 6.00 ± 0.0000 μs |'),
    );
  });

  test('only compares results with a Pureflow baseline in the same domain', () {
    final report = renderBenchmarkReport(
      statistics: [
        _statistics(
          name: 'Cubit.notify',
          library: 'Bloc',
          feature: 'State Holder: Notify',
          timing: BenchmarkTiming.asyncSettled,
          value: 2,
        ),
        _statistics(
          name: 'Pipeline.sequential',
          library: 'Pureflow',
          feature: 'Async Concurrency: Sequential',
          timing: BenchmarkTiming.asyncSettled,
          value: 3,
        ),
        _statistics(
          name: 'Sequential',
          library: 'Bloc',
          feature: 'Async Concurrency: Sequential',
          timing: BenchmarkTiming.asyncSettled,
          value: 6,
        ),
      ],
      provenance: const BenchmarkReportProvenance(
        generatedAt: '2026-08-23T00:00:00Z',
        sourceFingerprint: '0123456789012345678901234567890123456789',
        dartVersion: 'Dart test',
        operatingSystem: 'test OS',
        cpu: 'test CPU',
        logicalProcessors: 1,
        trials: 3,
        seed: 1337,
        packageVersions: {},
      ),
      libraries: const [
        BenchmarkLibrarySpec('Pureflow', 'https://example.com/pureflow'),
        BenchmarkLibrarySpec('Bloc', 'https://example.com/bloc'),
      ],
      featureOrder: const [
        'State Holder: Notify',
        'Async Concurrency: Sequential',
      ],
    );

    final comparison = _section(
      report,
      '## Asynchronously Settled Performance Comparison',
      '## Detailed Results',
    );
    expect(comparison, contains('| Async Concurrency: Sequential | 100.0% |'));
    expect(comparison, isNot(contains('State Holder: Notify')));
  });

  test('labels each detailed result with its timing domain', () {
    final report = renderBenchmarkReport(
      statistics: [
        _statistics(
          name: 'Store.read',
          library: 'Pureflow',
          feature: 'State Holder: Read',
          timing: BenchmarkTiming.synchronous,
          value: 1,
        ),
        _statistics(
          name: 'Pipeline.sequential',
          library: 'Pureflow',
          feature: 'Async Concurrency: Sequential',
          timing: BenchmarkTiming.asyncSettled,
          value: 2,
        ),
      ],
      provenance: const BenchmarkReportProvenance(
        generatedAt: '2026-08-23T00:00:00Z',
        sourceFingerprint: '0123456789012345678901234567890123456789',
        dartVersion: 'Dart test',
        operatingSystem: 'test OS',
        cpu: 'test CPU',
        logicalProcessors: 1,
        trials: 3,
        seed: 1337,
        packageVersions: {},
      ),
      libraries: const [
        BenchmarkLibrarySpec('Pureflow', 'https://example.com/pureflow'),
      ],
      featureOrder: const [
        'State Holder: Read',
        'Async Concurrency: Sequential',
      ],
    );

    expect(
      report,
      contains(
          '| Benchmark | Timing | Median (μs/op) | MAD | Min | Max | Samples |'),
    );
    expect(report, contains('| Store.read | Synchronous | 1.00 |'));
    expect(report, contains('| Pipeline.sequential | Async settled | 2.00 |'));
  });
}
