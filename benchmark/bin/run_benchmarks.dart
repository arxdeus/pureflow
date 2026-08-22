import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:benchmark/common/benchmark_report.dart';
import 'package:benchmark/common/benchmark_result.dart';
import 'package:benchmark/common/benchmark_trial_aggregation.dart';

const _defaultTrials = 3;
const _defaultSeed = 1337;
const _snapshotPaths = <String>[
  'benchmark/bin',
  'benchmark/lib',
  'benchmark/pubspec.yaml',
  'benchmark/pubspec.lock',
  'packages/pureflow',
];
const _resolvedInputPaths = <String>[
  'benchmark/.dart_tool/package_config.json',
];

const _libraries = <_LibrarySpec>[
  _LibrarySpec('pureflow', 'Pureflow', 'https://pub.dev/packages/pureflow'),
  _LibrarySpec('bloc', 'Bloc', 'https://pub.dev/packages/bloc'),
  _LibrarySpec(
    'bloc_signals',
    'BlocSignals',
    'https://pub.dev/packages/bloc_signals',
  ),
  _LibrarySpec('riverpod', 'Riverpod', 'https://pub.dev/packages/riverpod'),
  _LibrarySpec('signals', 'Signals', 'https://pub.dev/packages/signals_core'),
  _LibrarySpec(
    'alien_signals',
    'AlienSignals',
    'https://pub.dev/packages/alien_signals',
  ),
  _LibrarySpec('caffeine', 'Caffeine', 'https://pub.dev/packages/caffeine'),
  _LibrarySpec('mobx', 'MobX', 'https://pub.dev/packages/mobx'),
];

const _featureOrder = <String>[
  'State Holder: Lifecycle (Create + Use + Release)',
  'State Holder: Read',
  'State Holder: Write',
  'State Holder: Notify',
  'State Holder: Notify - Many Dependents (1000)',
  'Recomputable View: Lifecycle (Create + Evaluate + Release)',
  'Recomputable View: Read',
  'Recomputable View: Recompute',
  'Recomputable View: Chain',
  'Recomputable View: Many Dependents (1000)',
  'Async Concurrency: Sequential',
];

Future<void> main(List<String> arguments) async {
  final root = _findRepositoryRoot();
  final trials = _readOption(arguments, '--trials', _defaultTrials);
  final seed = _readOption(arguments, '--seed', _defaultSeed);

  if (trials < 3 || trials.isEven) {
    throw ArgumentError.value(
      trials,
      'trials',
      'must be an odd number greater than or equal to 3',
    );
  }

  final initialSnapshot = await _captureSourceSnapshot(root);
  stdout.writeln('Compiling isolated AOT benchmark worker...');
  final worker = await _compileWorker(root);
  stdout.writeln('  ✓ ${worker.path}\n');

  final trialResults = <List<BenchmarkResult>>[];
  for (var trialIndex = 0; trialIndex < trials; trialIndex++) {
    final order = _libraries.toList()..shuffle(Random(seed + trialIndex));
    stdout.writeln(
      'Trial ${trialIndex + 1}/$trials: '
      '${order.map((library) => library.displayName).join(', ')}',
    );

    final results = <BenchmarkResult>[];
    for (final library in order) {
      stdout.write('  ${library.displayName}...');
      final libraryResults = await _runWorker(root, worker, library.id);
      results.addAll(libraryResults);
      stdout.writeln(' ${libraryResults.length} benchmarks');
    }
    trialResults.add(results);
    stdout.writeln();
  }

  final finalSnapshot = await _captureSourceSnapshot(root);
  if (finalSnapshot.fingerprint != initialSnapshot.fingerprint) {
    throw StateError(
      'Benchmark source files changed while benchmarks were running. '
      'Discard these results and rerun from a stable snapshot.\n'
      'Before: ${initialSnapshot.fingerprint}\n'
      'After:  ${finalSnapshot.fingerprint}',
    );
  }

  final statistics = aggregateBenchmarkTrials(trialResults);
  final provenance = await _collectProvenance(
    root,
    trials,
    seed,
    initialSnapshot,
  );
  final report = renderBenchmarkReport(
    statistics: statistics,
    provenance: provenance,
    libraries: _libraries.map((library) => library.reportSpec).toList(),
    featureOrder: _featureOrder,
  );
  final reportFile = File('${root.path}/benchmark/BENCHMARK_README.md');
  await reportFile.writeAsString(report);
  stdout.writeln('Generated ${reportFile.path}');
}

int _readOption(List<String> arguments, String name, int fallback) {
  final prefix = '$name=';
  final matches = arguments.where((argument) => argument.startsWith(prefix));
  if (matches.isEmpty) {
    return fallback;
  }
  if (matches.length > 1) {
    throw ArgumentError('Option $name may only be specified once.');
  }
  return int.parse(matches.single.substring(prefix.length));
}

Directory _findRepositoryRoot() {
  var current = Directory.current.absolute;
  while (true) {
    if (File('${current.path}/benchmark/pubspec.yaml').existsSync()) {
      return current;
    }
    final parent = current.parent;
    if (parent.path == current.path) {
      throw StateError('Could not locate benchmark/pubspec.yaml.');
    }
    current = parent;
  }
}

Future<File> _compileWorker(Directory root) async {
  final extension = Platform.isWindows ? '.exe' : '';
  final output = File(
    '${root.path}/benchmark/.dart_tool/benchmark_worker$extension',
  );
  await output.parent.create(recursive: true);
  if (output.existsSync()) {
    await output.delete();
  }

  final result = await Process.run(
    Platform.resolvedExecutable,
    [
      'compile',
      'exe',
      '--enable-asserts',
      'benchmark/bin/benchmark_worker.dart',
      '-o',
      output.path,
    ],
    workingDirectory: root.path,
  );
  if (result.exitCode != 0) {
    throw ProcessException(
      Platform.resolvedExecutable,
      const ['compile', 'exe', 'benchmark/bin/benchmark_worker.dart'],
      '${result.stdout}\n${result.stderr}',
      result.exitCode,
    );
  }
  return output;
}

Future<List<BenchmarkResult>> _runWorker(
  Directory root,
  File worker,
  String library,
) async {
  final result = await Process.run(
    worker.path,
    [library],
    workingDirectory: root.path,
  );
  if (result.exitCode != 0) {
    throw ProcessException(
      worker.path,
      [library],
      '${result.stdout}\n${result.stderr}',
      result.exitCode,
    );
  }

  final outputLines = (result.stdout as String)
      .split('\n')
      .where((line) => line.trim().isNotEmpty)
      .toList();
  if (outputLines.isEmpty) {
    throw StateError('Benchmark worker $library produced no results.');
  }
  final decoded = jsonDecode(outputLines.last) as List<Object?>;
  return decoded
      .map(
        (entry) => BenchmarkResult.fromJson(
          (entry! as Map<Object?, Object?>).cast<String, Object?>(),
        ),
      )
      .toList();
}

Future<BenchmarkReportProvenance> _collectProvenance(
  Directory root,
  int trials,
  int seed,
  _SourceSnapshot snapshot,
) async {
  var cpu = Platform.environment['PROCESSOR_IDENTIFIER'] ?? 'unknown';
  if (Platform.isMacOS) {
    final result = await Process.run(
      'sysctl',
      const ['-n', 'machdep.cpu.brand_string'],
    );
    if (result.exitCode == 0) {
      cpu = (result.stdout as String).trim();
    }
  }

  return BenchmarkReportProvenance(
    generatedAt: DateTime.now().toUtc().toIso8601String(),
    sourceFingerprint: snapshot.fingerprint,
    dartVersion: Platform.version.split('\n').first,
    operatingSystem:
        '${Platform.operatingSystem} ${Platform.operatingSystemVersion}',
    cpu: cpu,
    logicalProcessors: Platform.numberOfProcessors,
    trials: trials,
    seed: seed,
    packageVersions: _readPackageVersions(root),
  );
}

Future<_SourceSnapshot> _captureSourceSnapshot(Directory root) async {
  final sourceArguments = [
    'ls-files',
    '--cached',
    '--others',
    '--exclude-standard',
    '-z',
    '--',
    ..._snapshotPaths,
  ];
  final sourceResult = await Process.run(
    'git',
    sourceArguments,
    workingDirectory: root.path,
    stdoutEncoding: null,
    stderrEncoding: null,
  );
  if (sourceResult.exitCode != 0) {
    throw ProcessException(
      'git',
      sourceArguments,
      utf8.decode(sourceResult.stderr as List<int>, allowMalformed: true),
      sourceResult.exitCode,
    );
  }

  final snapshot = BytesBuilder(copy: false);
  final sourcePaths = utf8
      .decode(sourceResult.stdout as List<int>)
      .split('\u0000')
      .where((path) => path.isNotEmpty)
      .toList()
    ..sort();
  for (final path in sourcePaths) {
    snapshot
      ..add(utf8.encode('\nSOURCE $path\n'))
      ..add(await File('${root.path}/$path').readAsBytes());
  }
  for (final path in _resolvedInputPaths) {
    final file = File('${root.path}/$path');
    if (!file.existsSync()) {
      throw StateError('Missing resolved benchmark input: $path');
    }
    snapshot
      ..add(utf8.encode('\nRESOLVED $path\n'))
      ..add(
        _normalizePackageConfiguration(
          jsonDecode(await file.readAsString()),
        ),
      );
  }

  final hashProcess = await Process.start(
    'git',
    const ['hash-object', '--stdin'],
    workingDirectory: root.path,
  );
  hashProcess.stdin.add(snapshot.takeBytes());
  await hashProcess.stdin.close();
  final hashOutput = await utf8.decoder.bind(hashProcess.stdout).join();
  final hashError = await utf8.decoder.bind(hashProcess.stderr).join();
  final hashExitCode = await hashProcess.exitCode;
  if (hashExitCode != 0) {
    throw ProcessException(
      'git',
      const ['hash-object', '--stdin'],
      hashError,
      hashExitCode,
    );
  }

  return _SourceSnapshot(hashOutput.trim());
}

List<int> _normalizePackageConfiguration(Object? decoded) {
  final configuration =
      (decoded! as Map<Object?, Object?>).cast<String, Object?>();
  final packages = (configuration['packages']! as List<Object?>).map((entry) {
    final package = (entry! as Map<Object?, Object?>).cast<String, Object?>();
    return <String, Object?>{
      'name': package['name'],
      'rootUri': package['rootUri'],
      'packageUri': package['packageUri'],
      'languageVersion': package['languageVersion'],
    };
  }).toList()
    ..sort(
      (a, b) => (a['name']! as String).compareTo(b['name']! as String),
    );
  return utf8.encode(
    jsonEncode({
      'configVersion': configuration['configVersion'],
      'packages': packages,
    }),
  );
}

Map<String, String> _readPackageVersions(Directory root) {
  const wanted = {
    'benchmark_harness',
    'pureflow',
    'bloc_signals',
    'caffeine',
    'alien_signals',
    'signals_core',
    'bloc',
    'bloc_concurrency',
    'riverpod',
    'mobx',
  };
  final versions = <String, String>{};
  final lines = File('${root.path}/benchmark/pubspec.lock').readAsLinesSync();
  String? package;
  for (final line in lines) {
    final packageMatch = RegExp(r'^  ([a-zA-Z0-9_]+):$').firstMatch(line);
    if (packageMatch != null) {
      package = packageMatch.group(1);
      continue;
    }
    if (package != null && wanted.contains(package)) {
      final versionMatch =
          RegExp(r'^    version: "?([^" ]+)"?$').firstMatch(line);
      if (versionMatch != null) {
        versions[package] = versionMatch.group(1)!;
        package = null;
      }
    }
  }
  return Map.fromEntries(
      versions.entries.toList()..sort((a, b) => a.key.compareTo(b.key)));
}

class _LibrarySpec {
  const _LibrarySpec(this.id, this.displayName, this.url);

  final String id;
  final String displayName;
  final String url;

  BenchmarkLibrarySpec get reportSpec => BenchmarkLibrarySpec(displayName, url);
}

class _SourceSnapshot {
  const _SourceSnapshot(this.fingerprint);

  final String fingerprint;
}
