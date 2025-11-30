/// Example demonstrating Pipeline and ValueUnit usage with real-world controllers.
///
/// This example shows:
/// 1. AuthenticationController - login/logout with async operations
/// 2. GeolocationController - location tracking with reactive state
library;

import 'dart:async';
import 'dart:math';

import 'package:pureflow/pureflow.dart';

// ============================================================================
// Common Types
// ============================================================================

/// Represents an authenticated user.
class User {
  final String id;
  final String email;
  final String name;
  final DateTime loginTime;

  const User({
    required this.id,
    required this.email,
    required this.name,
    required this.loginTime,
  });

  @override
  String toString() => 'User($name, $email)';
}

/// Represents a geographic location.
class GeoLocation {
  final double latitude;
  final double longitude;
  final double? accuracy;
  final DateTime timestamp;

  const GeoLocation({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.accuracy,
  });

  @override
  String toString() =>
      'GeoLocation(${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)})';
}

// ============================================================================
// 1. Authentication Controller
// ============================================================================

/// Authentication controller using Pipeline for async operations
/// and ValueUnit for reactive state management.
///
/// Features:
/// - Login/logout with cancellation support
/// - Loading state tracking
/// - Error handling
/// - Computed properties (isAuthenticated, userDisplayName)
class AuthenticationController {
  AuthenticationController() {
    // Pipeline with restartable transformer - cancels previous login attempt
    // when a new one starts
    _pipeline = Pipeline(transformer: _restartable);
  }

  late final Pipeline _pipeline;

  // ---------------------------------------------------------------------------
  // Reactive State (ValueUnit)
  // ---------------------------------------------------------------------------

  /// Current authenticated user (null if not logged in).
  final _user = Store<User?>(null);

  /// Whether a login/logout operation is in progress.
  final _isLoading = Store<bool>(false);

  /// Last error message (null if no error).
  final Store<String?> _error = Store<String?>(null);

  // ---------------------------------------------------------------------------
  // Computed Properties (CompositeUnit)
  // ---------------------------------------------------------------------------

  /// Whether the user is currently authenticated.
  late final Computed<bool> isAuthenticated = Computed<bool>(
    () => _user.value != null,
  );

  /// Display name for UI (shows email if name is empty).
  late final userDisplayName = Computed(
    () {
      final user = _user.value;
      if (user == null) return 'Guest';
      return user.name.isNotEmpty ? user.name : user.email;
    },
  );

  /// Combined status message for UI.
  late final Computed<String> statusMessage = Computed<String>(
    () {
      if (_isLoading.value) return 'Loading...';
      if (_error.value != null) return 'Error: ${_error.value}';
      if (isAuthenticated.value) return 'Welcome, ${userDisplayName.value}!';
      return 'Please log in';
    },
  );

  // ---------------------------------------------------------------------------
  // Public Getters
  // ---------------------------------------------------------------------------

  User? get user => _user.value;
  bool get isLoading => _isLoading.value;
  String? get error => _error.value;

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  /// Attempts to log in with the given credentials.
  ///
  /// Returns the authenticated user on success.
  /// Throws on failure.
  Future<User> login(String email, String password) {
    return _pipeline.run((context) async {
      _error.value = null;
      _isLoading.value = true;

      try {
        // Simulate network delay
        await Future<void>.delayed(const Duration(seconds: 2));

        // Check if operation was cancelled (e.g., user started another login)
        if (!context.isActive) {
          throw StateError('Login cancelled');
        }

        // Simulate validation
        if (email.isEmpty || password.isEmpty) {
          throw ArgumentError('Email and password are required');
        }

        if (password.length < 6) {
          throw ArgumentError('Password must be at least 6 characters');
        }

        // Simulate API response
        final user = User(
          id: 'user_${DateTime.now().millisecondsSinceEpoch}',
          email: email,
          name: email.split('@').first,
          loginTime: DateTime.now(),
        );

        // Update state atomically using batch
        batch(() {
          _user.value = user;
          _isLoading.value = false;
        });

        return user;
      } catch (e) {
        // Only update error if still active
        if (context.isActive) {
          batch(() {
            _error.value = e.toString();
            _isLoading.value = false;
          });
        }
        rethrow;
      }
    });
  }

  /// Logs out the current user.
  Future<void> logout() {
    return _pipeline.run((context) async {
      _isLoading.value = true;

      try {
        // Simulate network delay (e.g., invalidating token on server)
        await Future<void>.delayed(const Duration(milliseconds: 500));

        if (!context.isActive) return;

        batch(() {
          _user.value = null;
          _error.value = null;
          _isLoading.value = false;
        });
      } catch (e) {
        if (context.isActive) {
          batch(() {
            _error.value = e.toString();
            _isLoading.value = false;
          });
        }
        rethrow;
      }
    });
  }

  /// Clears any error state.
  void clearError() {
    _error.value = null;
  }

  /// Disposes the controller and releases resources.
  Future<void> dispose() async {
    await _pipeline.dispose(force: true);
    _user.dispose();
    _isLoading.dispose();
    _error.dispose();
    isAuthenticated.dispose();
    userDisplayName.dispose();
    statusMessage.dispose();
  }

  /// Restartable transformer - cancels previous operation when new one starts.
  static Stream<R> _restartable<E, R>(
    Stream<E> events,
    EventMapper<E, R> mapper,
  ) {
    return events.switchMap(mapper);
  }
}

// ============================================================================
// 2. Geolocation Controller
// ============================================================================

/// Geolocation controller using Pipeline for async operations
/// and ValueUnit for reactive state management.
///
/// Features:
/// - Single location fetch
/// - Continuous location tracking
/// - Distance calculation from a target
/// - Loading and error states
class GeolocationController {
  GeolocationController() {
    // Sequential transformer - processes location requests one at a time
    _pipeline = Pipeline(transformer: _sequential);
  }

  late final Pipeline _pipeline;
  Timer? _trackingTimer;

  // ---------------------------------------------------------------------------
  // Reactive State (ValueUnit)
  // ---------------------------------------------------------------------------

  /// Current location (null if not yet determined).
  final Store<GeoLocation?> _currentLocation = Store<GeoLocation?>(null);

  /// Whether location is being fetched.
  final Store<bool> _isLoading = Store<bool>(false);

  /// Whether continuous tracking is active.
  final Store<bool> _isTracking = Store<bool>(false);

  /// Last error message.
  final Store<String?> _error = Store<String?>(null);

  /// Target location for distance calculation.
  final Store<GeoLocation?> _targetLocation = Store<GeoLocation?>(null);

  // ---------------------------------------------------------------------------
  // Computed Properties (CompositeUnit)
  // ---------------------------------------------------------------------------

  /// Whether we have a valid location.
  late final Computed<bool> hasLocation = Computed<bool>(
    () => _currentLocation.value != null,
  );

  /// Distance to target in meters (null if no target or no current location).
  late final Computed<double?> distanceToTarget = Computed<double?>(
    () {
      final current = _currentLocation.value;
      final target = _targetLocation.value;
      if (current == null || target == null) return null;
      return _calculateDistance(current, target);
    },
  );

  /// Formatted distance string for UI.
  late final Computed<String> formattedDistance = Computed<String>(
    () {
      final distance = distanceToTarget.value;
      if (distance == null) return 'No target set';
      if (distance < 1000) {
        return '${distance.toStringAsFixed(0)} m';
      }
      return '${(distance / 1000).toStringAsFixed(2)} km';
    },
  );

  /// Location status message for UI.
  late final Computed<String> locationStatus = Computed<String>(
    () {
      if (_isLoading.value) return 'Getting location...';
      if (_error.value != null) return 'Error: ${_error.value}';
      final loc = _currentLocation.value;
      if (loc == null) return 'Location unknown';
      return 'Location: ${loc.latitude.toStringAsFixed(4)}, ${loc.longitude.toStringAsFixed(4)}';
    },
  );

  // ---------------------------------------------------------------------------
  // Public Getters
  // ---------------------------------------------------------------------------

  GeoLocation? get currentLocation => _currentLocation.value;
  bool get isLoading => _isLoading.value;
  bool get isTracking => _isTracking.value;
  String? get error => _error.value;

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  /// Fetches the current location once.
  Future<GeoLocation?> getCurrentLocation() {
    return _pipeline.run((context) async {
      _error.value = null;
      _isLoading.value = true;

      try {
        // Simulate getting location from GPS
        await Future<void>.delayed(const Duration(seconds: 1));

        if (!context.isActive) {
          // Silently return null when cancelled (e.g., during dispose)
          return null;
        }

        // Simulate location data (random location around San Francisco)
        final location = _simulateLocation();

        batch(() {
          _currentLocation.value = location;
          _isLoading.value = false;
        });

        return location;
      } catch (e) {
        if (context.isActive) {
          batch(() {
            _error.value = e.toString();
            _isLoading.value = false;
          });
        }
        rethrow;
      }
    });
  }

  /// Starts continuous location tracking.
  ///
  /// Updates location every [interval] (default 5 seconds).
  void startTracking({Duration interval = const Duration(seconds: 5)}) {
    if (_isTracking.value) return;
    _isTracking.value = true;

    // Get initial location
    getCurrentLocation();

    // Start periodic updates
    _trackingTimer = Timer.periodic(interval, (_) {
      if (_isTracking.value) {
        getCurrentLocation();
      }
    });
  }

  /// Stops continuous location tracking.
  void stopTracking() {
    _isTracking.value = false;
    _trackingTimer?.cancel();
    _trackingTimer = null;
  }

  /// Sets a target location for distance calculation.
  void setTarget(double latitude, double longitude) {
    _targetLocation.value = GeoLocation(
      latitude: latitude,
      longitude: longitude,
      timestamp: DateTime.now(),
    );
  }

  /// Clears the target location.
  void clearTarget() {
    _targetLocation.value = null;
  }

  /// Clears any error state.
  void clearError() {
    _error.value = null;
  }

  /// Disposes the controller and releases resources.
  Future<void> dispose() async {
    stopTracking();
    await _pipeline.dispose(force: true);
    _currentLocation.dispose();
    _isLoading.dispose();
    _isTracking.dispose();
    _error.dispose();
    _targetLocation.dispose();
    hasLocation.dispose();
    distanceToTarget.dispose();
    formattedDistance.dispose();
    locationStatus.dispose();
  }

  // ---------------------------------------------------------------------------
  // Private Helpers
  // ---------------------------------------------------------------------------

  /// Simulates getting a GPS location.
  GeoLocation _simulateLocation() {
    final random = Random();
    // Random location around San Francisco with small variations
    return GeoLocation(
      latitude: 37.7749 + (random.nextDouble() - 0.5) * 0.01,
      longitude: -122.4194 + (random.nextDouble() - 0.5) * 0.01,
      accuracy: 10 + random.nextDouble() * 50,
      timestamp: DateTime.now(),
    );
  }

  /// Calculates distance between two locations using Haversine formula.
  static double _calculateDistance(GeoLocation from, GeoLocation to) {
    const earthRadius = 6371000.0; // meters

    final lat1 = from.latitude * pi / 180;
    final lat2 = to.latitude * pi / 180;
    final deltaLat = (to.latitude - from.latitude) * pi / 180;
    final deltaLon = (to.longitude - from.longitude) * pi / 180;

    final a = sin(deltaLat / 2) * sin(deltaLat / 2) +
        cos(lat1) * cos(lat2) * sin(deltaLon / 2) * sin(deltaLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  /// Sequential transformer - processes events one at a time.
  static Stream<R> _sequential<E, R>(
    Stream<E> events,
    EventMapper<E, R> mapper,
  ) {
    return events.asyncExpand(mapper);
  }
}

// ============================================================================
// Stream Extension for switchMap
// ============================================================================

extension SwitchMapExtension<T> on Stream<T> {
  /// Maps each event to a stream and switches to the latest one.
  Stream<R> switchMap<R>(Stream<R> Function(T) mapper) {
    StreamSubscription<R>? innerSubscription;

    return transform(
      StreamTransformer<T, R>.fromHandlers(
        handleData: (data, sink) {
          innerSubscription?.cancel();
          innerSubscription = mapper(data).listen(
            sink.add,
            onError: sink.addError,
          );
        },
        handleDone: (sink) async {
          await innerSubscription?.cancel();
          sink.close();
        },
      ),
    );
  }
}

// ============================================================================
// Demo / Main
// ============================================================================

Future<void> main() async {
  print('=' * 60);
  print('AUTHENTICATION CONTROLLER DEMO');
  print('=' * 60);

  final authController = AuthenticationController();

  // Listen to status changes
  authController.statusMessage.addListener(() {
    print('  [Status] ${authController.statusMessage.value}');
  });

  print('\n--- Initial State ---');
  print('  isAuthenticated: ${authController.isAuthenticated.value}');
  print('  statusMessage: ${authController.statusMessage.value}');

  print('\n--- Login Attempt (valid credentials) ---');
  try {
    final user = await authController.login('john@example.com', 'password123');
    print('  Login successful: $user');
    print('  isAuthenticated: ${authController.isAuthenticated.value}');
    print('  userDisplayName: ${authController.userDisplayName.value}');
  } catch (e) {
    print('  Login failed: $e');
  }

  print('\n--- Logout ---');
  await authController.logout();
  print('  isAuthenticated: ${authController.isAuthenticated.value}');

  print('\n--- Login Attempt (invalid password) ---');
  try {
    await authController.login('jane@example.com', '123');
  } catch (e) {
    print('  Login failed (expected): ${authController.error}');
  }

  await authController.dispose();

  print('\n');
  print('=' * 60);
  print('GEOLOCATION CONTROLLER DEMO');
  print('=' * 60);

  final geoController = GeolocationController();

  // Listen to location status changes
  geoController.locationStatus.addListener(() {
    print('  [Location] ${geoController.locationStatus.value}');
  });

  // Listen to distance changes
  geoController.formattedDistance.addListener(() {
    print('  [Distance] ${geoController.formattedDistance.value}');
  });

  print('\n--- Initial State ---');
  print('  hasLocation: ${geoController.hasLocation.value}');
  print('  locationStatus: ${geoController.locationStatus.value}');

  print('\n--- Get Current Location ---');
  try {
    final location = await geoController.getCurrentLocation();
    if (location != null) {
      print('  Got location: $location');
      print('  Accuracy: ${location.accuracy?.toStringAsFixed(1)} meters');
    } else {
      print('  Location request was cancelled');
    }
  } catch (e) {
    print('  Failed to get location: $e');
  }

  print('\n--- Set Target (Golden Gate Bridge) ---');
  geoController.setTarget(37.8199, -122.4783);
  print('  Target set');
  print('  Distance: ${geoController.formattedDistance.value}');

  print('\n--- Update Location (simulating movement) ---');
  await geoController.getCurrentLocation();
  print('  New distance: ${geoController.formattedDistance.value}');

  print('\n--- Start Tracking (3 updates) ---');
  geoController.startTracking(interval: const Duration(milliseconds: 500));
  print('  Tracking started: ${geoController.isTracking}');

  // Wait for a few updates
  await Future<void>.delayed(const Duration(seconds: 2));

  print('\n--- Stop Tracking ---');
  geoController.stopTracking();
  print('  Tracking stopped: ${!geoController.isTracking}');

  // Small delay to allow any in-flight requests to complete
  await Future<void>.delayed(const Duration(seconds: 1));

  await geoController.dispose();

  print('\n');
  print('=' * 60);
  print('DEMO COMPLETE');
  print('=' * 60);
}
