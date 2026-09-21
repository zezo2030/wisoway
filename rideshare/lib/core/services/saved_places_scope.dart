import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
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

  return SavedPlacesService(
    userId: userId == null || userId.isEmpty ? kGuestPlacesUserId : userId,
  );
}
