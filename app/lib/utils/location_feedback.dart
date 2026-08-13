import 'package:flutter/material.dart';

import '../services/location_access.dart';

/// Shows why location was unavailable, with a button that goes where the user
/// can actually fix it.
///
/// Takes a [ScaffoldMessengerState] rather than a [BuildContext] because every
/// caller reaches this after an `await`, where the context may no longer be
/// mounted. Capturing the messenger before the await is the safe pattern.
void showLocationAccessMessage(
  ScaffoldMessengerState messenger,
  LocationAccess access, {
  LocationAccessService service = const LocationAccessService(),
}) {
  if (access.isGranted) return;
  final actionLabel = access.actionLabel;
  messenger.showSnackBar(
    SnackBar(
      content: Text(access.message),
      duration: const Duration(seconds: 6),
      action: actionLabel == null
          ? null
          : SnackBarAction(
              label: actionLabel,
              onPressed: () => service.openRecoverySettings(access),
            ),
    ),
  );
}
