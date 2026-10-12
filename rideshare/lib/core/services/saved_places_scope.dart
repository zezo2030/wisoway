import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import 'saved_places_remote.dart';
import 'saved_places_service.dart';

/// Anonymous bucket used before sign-in. Kept separate from every real account
/// so places picked while signed out never appear under someone's profile.
const String kGuestPlacesUserId = 'guest';

/// Resolve the saved-places store for whoever is signed in.
///
/// Lives here rather than on [SavedPlacesService] so the store itself stays
/// free of any dependency on the app's state management.
///
/// Falls back to the guest bucket when no [AuthProvider] is in scope. Saved
/// places are a convenience on top of search, so a missing provider must
/// degrade to "no shortcuts yet" rather than break the screen that uses them.
SavedPlacesService savedPlacesFor(BuildContext context) {
  String? userId;
  try {
    userId = context.read<AuthProvider>().userModel?.id;
  } on ProviderNotFoundException {
    userId = null;
  }

  final signedIn = userId != null && userId.isNotEmpty;
  return SavedPlacesService(
    userId: signedIn ? userId : kGuestPlacesUserId,
    // A signed-in user's shortcuts live on the account; a guest's stay here.
    remote: signedIn ? ApiSavedPlacesRemote() : null,
  );
}
