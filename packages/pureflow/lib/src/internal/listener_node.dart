import 'package:meta/meta.dart';
import 'package:pureflow/src/interfaces.dart';

// ============================================================================
// Listener Node (Simple, for callback listeners only)
// ============================================================================

/// Simple node for callback listeners.
@internal
class ListenerNode {
  VoidCallback callback;
  ListenerNode? prev;
  ListenerNode? next;

  ListenerNode(this.callback);
}
