// Portfolio Dashboard — the flagship Pureflow tour.
//
// One self-contained scenario that exercises every core concept:
//
//   1. Store     — mutable reactive state (positions, prices, settings)
//   2. Computed  — derived state with automatic dependency tracking
//   3. batch     — atomic multi-store updates, one notification
//   4. Pipeline  — explicit async concurrency:
//        * restartable() for search-as-you-type (latest query wins)
//        * droppable()   for refresh (ignore taps while one is running)
//   5. Streams   — every reactive value is also a Stream
//   6. Disposal  — graceful teardown of stores, computeds, and pipelines
//
// Run it:
//
//   dart run example/portfolio_dashboard.dart
//
// Read it top to bottom — sections are numbered and each prints what it does.

import 'dart:async';

import 'package:pureflow/pureflow.dart';

Future<void> main() async {
  _banner('1. Store — the source of truth');

  // A Store holds one mutable value. Writing a *different* value notifies
  // listeners; writing an equal value is a no-op.
  final positions = Store<List<Position>>(const [
    Position(ticker: 'AAPL', shares: 10),
    Position(ticker: 'NVDA', shares: 4),
    Position(ticker: 'TSLA', shares: 6),
  ]);

  // Maps are compared by identity by default, so a rebuilt-but-identical map
  // would still notify. A custom equality keeps notifications honest.
  final prices = Store<Map<String, double>>(
    const {'AAPL': 228.50, 'NVDA': 142.30, 'TSLA': 251.10},
    equality: _mapEquals,
  );

  // Display preference. Used below to demonstrate conditional dependencies.
  final currency = Store<DisplayCurrency>(DisplayCurrency.usd);
  final eurRate = Store<double>(0.92); // USD -> EUR

  print('Holding ${positions.value.length} positions.');

  _banner('2. Computed — derived state, tracked automatically');

  // Computed reads other reactive values and records exactly what it touched.
  // No manual subscriptions, no dependency lists to maintain.
  final portfolioValueUsd = Computed<double>(() {
    var total = 0.0;
    for (final position in positions.value) {
      total += position.shares * (prices.value[position.ticker] ?? 0);
    }
    return total;
  });

  // Computeds chain freely: this one depends on another Computed.
  // Dependencies are re-recorded on every run, so when `currency` is USD the
  // `eurRate` store is not tracked at all — changing it costs nothing.
  final displayValue = Computed<String>(() {
    switch (currency.value) {
      case DisplayCurrency.usd:
        return '\$${portfolioValueUsd.value.toStringAsFixed(2)}';
      case DisplayCurrency.eur:
        final eur = portfolioValueUsd.value * eurRate.value;
        return '€${eur.toStringAsFixed(2)}';
    }
  });

  print('Portfolio value: ${displayValue.value}');

  currency.value = DisplayCurrency.eur;
  print('Same portfolio in EUR: ${displayValue.value}');
  currency.value = DisplayCurrency.usd;

  _banner('3. Streams — observe changes as they happen');

  // Every Store and Computed is also a Stream. Perfect for logging,
  // analytics, or bridging into stream-based APIs. This subscription stays
  // live until teardown, so it will narrate every mutation below — including
  // the ones made by pipelines in sections 5 and 6.
  final tape = displayValue.listen((value) {
    print('  [stream] portfolio is now $value');
  });

  _banner('4. batch — atomic market tick');

  // A market tick moves prices AND adds a position at once. Without batch,
  // listeners would observe a half-applied state: new MSFT position counted
  // at price 0 before its quote lands. Inside batch, notifications are
  // deferred until all writes complete — observers fire once, with the
  // final, consistent total.
  batch(() {
    prices.update((current) => {...current, 'AAPL': 231.10, 'NVDA': 145.85});
    positions.update(
      (current) => [
        ...current,
        const Position(ticker: 'MSFT', shares: 3),
      ],
    );
    prices.update((current) => {...current, 'MSFT': 430.20});
  });

  // Yield one event-loop turn so the stream listener fires.
  await Future<void>.delayed(Duration.zero);

  _banner('5. Pipeline(restartable) — search-as-you-type');

  // The user types "n", "nv", "nvda". Each keystroke starts a lookup, but
  // only the latest one matters. restartable() marks superseded tasks
  // inactive — they check `context.isActive` and quietly drop their results.
  final searchPipeline = Pipeline(
    transformer: restartable(),
    debugLabel: 'ticker-search',
  );

  Future<void> search(String query) {
    return searchPipeline.run<void>((context) async {
      // Simulated network latency.
      await Future<void>.delayed(const Duration(milliseconds: 60));

      if (!context.isActive) {
        print('  "$query" superseded — result discarded');
        return;
      }

      final matches = _tickerUniverse
          .where((t) => t.startsWith(query.toUpperCase()))
          .join(', ');
      print('  "$query" -> ${matches.isEmpty ? 'no matches' : matches}');
    }, debugLabel: 'search:$query');
  }

  // Fire three overlapping keystrokes; only the last produces output.
  await Future.wait([
    search('n'),
    Future<void>.delayed(const Duration(milliseconds: 15), () => search('nv')),
    Future<void>.delayed(
      const Duration(milliseconds: 30),
      () => search('nvda'),
    ),
  ]);

  _banner('6. Pipeline(droppable) — refresh button mashing');

  // The opposite policy: while a refresh is in flight, extra requests are
  // dropped instead of queued. Ideal for "pull to refresh" and save buttons.
  final refreshPipeline = Pipeline(
    transformer: droppable(),
    debugLabel: 'refresh',
  );

  var refreshesPerformed = 0;
  Future<void> refresh(int attempt) {
    print('  tap #$attempt');
    return refreshPipeline.run<void>((context) async {
      await Future<void>.delayed(const Duration(milliseconds: 80));
      if (!context.isActive) {
        print('  tap #$attempt dropped — a refresh was already in flight');
        return;
      }

      refreshesPerformed++;
      // Apply fresh quotes atomically — pipelines and batch compose.
      batch(() {
        prices.update((current) => {
              for (final entry in current.entries)
                entry.key: entry.value * 1.001, // tiny uptick
            });
      });
      print('  tap #$attempt applied fresh quotes');
    });
  }

  // Three rapid taps: the first wins, the rest are dropped while it runs.
  await Future.wait([refresh(1), refresh(2), refresh(3)]);
  await Future<void>.delayed(Duration.zero);
  print('Refreshes that actually ran: $refreshesPerformed of 3');

  _banner('7. Teardown — leave nothing running');

  print('Final portfolio value: ${displayValue.value}');
  await tape.cancel();

  // dispose() without force waits for in-flight tasks to finish gracefully.
  await searchPipeline.dispose();
  await refreshPipeline.dispose();

  positions.dispose();
  prices.dispose();
  currency.dispose();
  eurRate.dispose();
  portfolioValueUsd.dispose();
  displayValue.dispose();

  print('All resources released.');
}

/// One immutable position in the portfolio.
class Position {
  const Position({required this.ticker, required this.shares});

  final String ticker;
  final int shares;
}

/// Which currency the dashboard renders in.
enum DisplayCurrency { usd, eur }

/// Tickers the search box can find.
const _tickerUniverse = <String>['AAPL', 'MSFT', 'NVDA', 'NFLX', 'TSLA'];

/// Shallow map equality so rebuilding an identical quote map stays silent.
bool _mapEquals(Map<String, double> a, Map<String, double> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (final entry in a.entries) {
    if (b[entry.key] != entry.value) return false;
  }
  return true;
}

void _banner(String title) {
  print('\n=== $title ===');
}
