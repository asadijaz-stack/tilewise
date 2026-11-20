/// Play Store update prompt.
///
/// Asks Google Play whether a newer version of TileWise is live and,
/// if so, opens Play's official update screen (the same one most
/// apps use). Silently does nothing when the app was sideloaded, is
/// a debug build, or the phone is offline — Play's in-app update
/// API only works for apps installed from the Play Store.
///
/// Note: this can only prompt users whose installed build already
/// contains this check. It first ships in v1.1.0, so it takes
/// effect from the update after that.
library;

import 'package:in_app_update/in_app_update.dart';

Future<void> checkForPlayUpdate() async {
  try {
    final info = await InAppUpdate.checkForUpdate();
    if (info.updateAvailability == UpdateAvailability.updateAvailable) {
      await InAppUpdate.performImmediateUpdate();
    }
  } catch (_) {
    // Not installed from Play / offline / Play unavailable: no prompt.
  }
}
