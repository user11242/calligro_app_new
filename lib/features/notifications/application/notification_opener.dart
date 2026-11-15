import '../domain/notification_models.dart';
import '../domain/notification_repositories.dart';

/// Every notification tap goes through here (push tapped in the tray, the app
/// opened from a push, the in-app banner, an inbox item).
///
///  * Before a dashboard is on screen (cold start, splash, sign-in) the tap is
///    KEPT and opened once a dashboard [attach]es — it used to be pushed under
///    the splash screen and lost.
///  * The same tap reported twice (tray + launch message) opens one screen.
class NotificationOpener {
  NotificationOpener({DateTime Function()? clock}) : _now = clock ?? DateTime.now;

  final DateTime Function() _now;
  NotificationNavigator? _navigator;
  NotificationTarget? _pending;
  NotificationTarget? _last;
  DateTime? _lastAt;

  static const _sameTapWindow = Duration(seconds: 3);

  NotificationTarget? get pending => _pending;

  void openData(Map<String, dynamic> data) => open(NotificationTarget.fromData(data));

  void open(NotificationTarget target) {
    final now = _now();
    if (_last == target && _lastAt != null && now.difference(_lastAt!) < _sameTapWindow) return;
    _last = target;
    _lastAt = now;
    final nav = _navigator;
    if (nav == null) {
      _pending = target;
    } else {
      nav.open(target);
    }
  }

  /// A dashboard is on screen: open what was waiting.
  void attach(NotificationNavigator navigator) {
    _navigator = navigator;
    final waiting = _pending;
    _pending = null;
    if (waiting != null) navigator.open(waiting);
  }

  void detach(NotificationNavigator navigator) {
    if (identical(_navigator, navigator)) _navigator = null;
  }
}
