import 'package:agenda_app/models/activity.dart';

class ActivityClipboardService {
  ActivityClipboardService._();

  static Activity? _copiedActivity;

  static Activity? get copiedActivity => _copiedActivity;

  static bool get hasCopiedActivity => _copiedActivity != null;

  static void copy(Activity activity) {
    _copiedActivity = activity;
  }

  static void clear() {
    _copiedActivity = null;
  }
}
