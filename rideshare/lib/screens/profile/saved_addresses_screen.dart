import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import '../../core/services/saved_places_scope.dart';
import '../../core/services/saved_places_service.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/text_styles.dart';
import '../../l10n/l10n_extensions.dart';
import '../../models/location_model.dart';
import '../location/route_search_screen.dart';

/// Home, Work and the user's named places. They are the shortcuts the route
/// search screen lists before the user types, stored on this device per user.
class SavedAddressesScreen extends StatefulWidget {
  const SavedAddressesScreen({super.key});

  @override
  State<SavedAddressesScreen> createState() => _SavedAddressesScreenState();
}

class _SavedAddressesScreenState extends State<SavedAddressesScreen> {
  late final SavedPlacesService _store = savedPlacesFor(context);

  List<SavedPlace> _places = const [];
  bool _loading = true;

  /// True while a change is on its way to the account.
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final places = await _store.shortcuts();
    if (!mounted) return;
    setState(() {
      _places = places;
      _loading = false;
    });
  }

  SavedPlace? _ofKind(SavedPlaceKind kind) {
    for (final place in _places) {
      if (place.kind == kind) return place;
    }
    return null;
  }

  /// Search (or the map) for a point, then store it under [kind]/[label].
  Future<void> _pickAndSave(SavedPlaceKind kind, String label) async {
    final existing = kind == SavedPlaceKind.custom
        ? _places
              .where((p) => p.kind == kind && p.label == label)
              .firstOrNull
        : _ofKind(kind);
    final selection = await Navigator.push<RouteSelection>(
      context,
      MaterialPageRoute(
        builder: (_) => RouteSearchScreen.singlePoint(
          savedPlaces: _store,
          title: context.l10n.savedAddressPickTitle(label),
          initial: existing?.toLocation(),
        ),
      ),
    );
    final location = selection?.from;
    if (location == null || !mounted) return;

    await _run(
      () => _store.saveShortcut(
        kind: kind,
        label: label,
        location: location,
        secondaryText: _secondaryText(location),
      ),
    );
  }

  /// Apply a change and reload; a failure (e.g. offline) leaves the list as
  /// it was and says so.
  Future<void> _run(Future<void> Function() change) async {
    setState(() => _saving = true);
    try {
      await change();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.savedAddressSaveFailed)),
        );
      }
    }
    await _load();
    if (mounted) setState(() => _saving = false);
  }

  /// The address line under the name, without repeating the name itself.
  String _secondaryText(LocationModel location) {
    final address = location.address?.trim() ?? '';
    final name = location.name.trim();
    if (address.isEmpty || address == name) return '';
    for (final separator in ['، ', ', ']) {
      if (address.startsWith('$name$separator')) {
        return address.substring(name.length + separator.length);
      }
    }
    return address;
  }

  Future<void> _addCustom() async {
    final label = await _askName();
    if (label == null || !mounted) return;
    await _pickAndSave(SavedPlaceKind.custom, label);
  }

  Future<String?> _askName({String initial = ''}) async {
    final controller = TextEditingController(text: initial);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.savedAddressNameTitle),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 30,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            hintText: ctx.l10n.savedAddressNameHint,
          ),
          onSubmitted: (value) => Navigator.pop(ctx, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(ctx.l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: Text(ctx.l10n.save),
          ),
        ],
      ),
    );
    controller.dispose();
    final trimmed = name?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }

  Future<void> _remove(SavedPlace place) =>
      _run(() => _store.removeShortcut(place.kind, label: place.label));

  Future<void> _showActions(SavedPlace place, String label) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: T.surface(context),
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(IconsaxPlusLinear.location),
              title: Text(ctx.l10n.savedAddressChangeLocation),
              onTap: () => Navigator.pop(ctx, 'move'),
            ),
            if (place.kind == SavedPlaceKind.custom)
              ListTile(
                leading: const Icon(IconsaxPlusLinear.edit_2),
                title: Text(ctx.l10n.savedAddressRename),
                onTap: () => Navigator.pop(ctx, 'rename'),
              ),
            ListTile(
              leading: Icon(IconsaxPlusLinear.trash, color: T.error(ctx)),
              title: Text(
                ctx.l10n.delete,
                style: TextStyle(color: T.error(ctx)),
              ),
              onTap: () => Navigator.pop(ctx, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    switch (action) {
      case 'move':
        await _pickAndSave(place.kind, label);
      case 'rename':
        final name = await _askName(initial: place.label);
        if (name == null || name == place.label || !mounted) return;
        // Save under the new name first, so a failure loses nothing.
        await _run(() async {
          await _store.saveShortcut(
            kind: place.kind,
            label: name,
            location: place.toLocation(),
            secondaryText: place.secondaryText,
          );
          await _store.removeShortcut(place.kind, label: place.label);
        });
      case 'delete':
        await _remove(place);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final home = _ofKind(SavedPlaceKind.home);
    final work = _ofKind(SavedPlaceKind.work);
    final custom = _places
        .where((p) => p.kind == SavedPlaceKind.custom)
        .toList();

    return Scaffold(
      backgroundColor: T.surface(context),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: T.surface(context),
        foregroundColor: T.onSurface(context),
        title: Text(
          l10n.savedAddresses,
          style: AppTextStyles.titleMedium.copyWith(fontSize: 20),
        ),
        centerTitle: true,
        bottom: _saving
            ? const PreferredSize(
                preferredSize: Size.fromHeight(2),
                child: LinearProgressIndicator(minHeight: 2),
              )
            : null,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  l10n.savedAddressesHint,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: T.onSurfaceVariant(context),
                  ),
                ),
                const SizedBox(height: 16),
                _PlaceTile(
                  icon: IconsaxPlusLinear.home_2,
                  label: l10n.savedAddressHome,
                  place: home,
                  onTap: () => home == null
                      ? _pickAndSave(SavedPlaceKind.home, l10n.savedAddressHome)
                      : _showActions(home, l10n.savedAddressHome),
                ),
                const SizedBox(height: 12),
                _PlaceTile(
                  icon: IconsaxPlusLinear.briefcase,
                  label: l10n.savedAddressWork,
                  place: work,
                  onTap: () => work == null
                      ? _pickAndSave(SavedPlaceKind.work, l10n.savedAddressWork)
                      : _showActions(work, l10n.savedAddressWork),
                ),
                if (custom.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text(
                    l10n.savedAddressOthers,
                    style: AppTextStyles.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  for (final place in custom) ...[
                    _PlaceTile(
                      icon: IconsaxPlusLinear.star_1,
                      label: place.label,
                      place: place,
                      onTap: () => _showActions(place, place.label),
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _addCustom,
                  icon: const Icon(IconsaxPlusLinear.add),
                  label: Text(l10n.savedAddressAdd),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _PlaceTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final SavedPlace? place;
  final VoidCallback onTap;

  const _PlaceTile({
    required this.icon,
    required this.label,
    required this.place,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final place = this.place;
    final subtitle = place == null
        ? context.l10n.savedAddressNotSet
        : [
            place.name,
            place.secondaryText,
          ].where((part) => part.isNotEmpty).join('، ');

    return Material(
      color: T.surfaceVariant(context),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: T.primary(context).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: T.primary(context)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: AppTextStyles.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: place == null
                            ? T.primary(context)
                            : T.onSurfaceVariant(context),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                place == null
                    ? IconsaxPlusLinear.add_circle
                    : Icons.more_vert,
                color: T.onSurfaceVariant(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
