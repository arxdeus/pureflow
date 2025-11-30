import 'package:meta/meta.dart';

/// Extension for readable bit flag operations.
@internal
extension BitFlagExtension on int {
  @pragma('vm:prefer-inline')
  bool hasFlag(int flag) => (this & flag) != 0;

  @pragma('vm:prefer-inline')
  int setFlag(int flag) => this | flag;

  @pragma('vm:prefer-inline')
  int clearFlag(int flag) => this & ~flag;
}
