import 'package:meta/meta.dart';

/// Inline equality check for Computed values.
/// Optimized: custom equality has priority, then identical(), then ==
@internal
@pragma('vm:prefer-inline')
bool checkEquality<T>(
  T oldValue,
  T newValue,
  bool Function(T, T)? customEquality,
) {
  if (customEquality != null) {
    // Custom equality function provided - use it directly
    // User's custom equality takes priority over identical() check
    return customEquality(oldValue, newValue);
  } else {
    // Default equality: identical() first (fastest), then ==
    return identical(oldValue, newValue) || oldValue == newValue;
  }
}
