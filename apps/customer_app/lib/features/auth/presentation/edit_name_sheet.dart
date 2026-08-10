import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sahra_design_system/sahra_design_system.dart';

import '../../../core/error/failure.dart';
import '../../../localization/generated/app_localizations.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/providers/session_providers.dart';
import '../../../shared/widgets/failure_copy.dart';

part 'edit_name_sheet.g.dart';

/// Correcting the name the restaurant reads at the door.
///
/// NO REFERENCE. `ProfileScreen.jsx` draws seven rows and none of them is an
/// edit control — the design package has no profile-edit screen. Built from
/// `SahraInput` and `SahraButton` so nothing new is designed, and named as a
/// deviation in `account_screen.dart` rather than passed off as matching.
///
/// ONLY THE NAME. `PATCH /auth/me` also takes a locale, and the app
/// deliberately does not offer it: the language follows the device (main.dart),
/// and an in-app switch that disagreed with the phone's setting would be a
/// second source of truth for something the phone already knows. The field
/// exists server-side for a client that has a reason to set it.
///
/// AND NOT THE EMAIL. The endpoint refuses one with a 400 while the
/// verification flow is unbuilt, and `UpdateProfileDto` has no field to send
/// it — so this sheet cannot offer one even by mistake.
Future<void> showEditNameSheet(
  BuildContext context,
  WidgetRef ref, {
  required String currentName,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _EditNameSheet(currentName: currentName),
  );
}

/// What the rename is doing. Sealed for the same reason as the reservation
/// actions: busy, failed and idle are mutually exclusive, and three booleans
/// can express states that cannot happen.
sealed class EditNameState {
  const EditNameState();
}

class EditNameIdle extends EditNameState {
  const EditNameIdle();
}

class EditNameSaving extends EditNameState {
  const EditNameSaving();
}

class EditNameFailed extends EditNameState {
  const EditNameFailed(this.failure);
  final Failure failure;
}

@riverpod
class EditName extends _$EditName {
  @override
  EditNameState build() => const EditNameIdle();

  /// Returns whether it saved, so the sheet closes only on success.
  Future<bool> save(String fullName) async {
    if (state is EditNameSaving) return false;
    state = const EditNameSaving();

    try {
      final saved = await ref.read(authRepositoryProvider).updateName(fullName);
      // THE SESSION CARRIES THE ONLY COPY OF THE DISPLAY NAME. Updating the
      // database and not this would leave the diner reading their old name for
      // the life of a 30-day refresh token — which reads as the correction
      // having silently failed.
      //
      // Fed from the SERVER's answer, not from what was typed: if the server
      // ever trims or normalises, this shows what is actually stored.
      await ref.read(currentSessionProvider.notifier).renamedTo(saved);
      state = const EditNameIdle();
      return true;
    } on Failure catch (f) {
      state = EditNameFailed(f);
      return false;
    }
  }
}

class _EditNameSheet extends ConsumerStatefulWidget {
  const _EditNameSheet({required this.currentName});

  final String currentName;

  @override
  ConsumerState<_EditNameSheet> createState() => _EditNameSheetState();
}

class _EditNameSheetState extends ConsumerState<_EditNameSheet> {
  late final TextEditingController _name = TextEditingController(text: widget.currentName);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final s = Theme.of(context).sahra;
    final text = Theme.of(context).textTheme;
    final state = ref.watch(editNameProvider);
    final saving = state is EditNameSaving;

    // Scroll view outermost — see the note in `reservation_actions.dart`.
    // `SahraPageWidth` is an Align, and an Align on the outside makes the
    // sheet full height regardless of how little is in it.
    return SingleChildScrollView(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SahraPageWidth(
        child: Padding(
          padding: SahraSpace.all(SahraSpace.s5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: s.line,
                    borderRadius: BorderRadius.circular(SahraRadius.pill),
                  ),
                ),
              ),
              const SizedBox(height: SahraSpace.s5),
              Text(
                l10n.accountEditNameTitle,
                style: text.headlineSmall?.copyWith(color: s.textBody),
              ),
              const SizedBox(height: SahraSpace.s2),
              Text(
                l10n.accountEditNameWhy,
                style: text.bodyMedium?.copyWith(color: s.textSoft),
              ),
              const SizedBox(height: SahraSpace.s5),
              SahraInput(
                label: l10n.signInNameLabel,
                hint: l10n.signInNameHint,
                variant: SahraInputVariant.line,
                controller: _name,
              ),
              if (state is EditNameFailed) ...<Widget>[
                const SizedBox(height: SahraSpace.s4),
                Text(
                  failureMessage(state.failure, l10n),
                  style: text.bodySmall?.copyWith(color: s.error),
                ),
              ],
              const SizedBox(height: SahraSpace.s6),
              SahraButton(
                label: saving ? l10n.accountEditNameSaving : l10n.accountEditNameSave,
                onPressed: saving ? null : _save,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    final ok = await ref.read(editNameProvider.notifier).save(_name.text.trim());
    if (ok && mounted) await Navigator.of(context).maybePop();
  }
}
