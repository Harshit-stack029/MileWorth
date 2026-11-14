import 'package:flutter/material.dart';

/// Google Play's "prominent disclosure" for background location.
///
/// Play policy requires that, immediately before the app asks for background
/// location, it shows in-app text that (1) names the data (location), (2) says
/// it is used even when the app is closed or not in use, and (3) names the
/// feature it powers. Keep this wording in sync with the Play Console
/// background-location declaration (docs/PLAY_DECLARATIONS.md).
const String kBackgroundLocationDisclosure =
    'MileWorth collects location data to detect and record your drives and '
    'calculate mileage, even when the app is closed or not in use.\n\n'
    'Your location stays on this phone. It is never sent to us, sold or shared. '
    'You can turn automatic tracking off anytime in Settings.';

/// Shows the disclosure as a dialog. Returns true only if the user agrees, so
/// the caller may then trigger the system permission prompt.
Future<bool> showBackgroundLocationDisclosure(BuildContext context) async {
  final agreed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.location_on),
      title: const Text('Use location in the background?'),
      content: const Text(kBackgroundLocationDisclosure),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('No thanks'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Continue'),
        ),
      ],
    ),
  );
  return agreed ?? false;
}
