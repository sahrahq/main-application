import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sahra_design_system/sahra_design_system.dart';

import '../../core/error/failure.dart';
import '../../core/error/failure_mapper.dart';
import '../../localization/generated/app_localizations.dart';
import 'failure_copy.dart';

/// The four states, defined ONCE (ENGINEERING-STANDARDS §2).
///
/// This is the only file in the app allowed to unwrap an `AsyncValue`.
/// `async_view_test.dart` scans `features/**/presentation/**` and fails on a
/// raw `.when(`, a `.maybeWhen(` or a bare `CircularProgressIndicator`
/// anywhere else — because three screens writing their own loading state is
/// how a product ends up with three different empty states, one of which says
/// "No results".
///
/// Three properties of this signature carry the weight:
///
///   - **`onRetry` is non-nullable.** An error with no way forward is a dead
///     end, and a dead end is now a COMPILE ERROR instead of a review comment.
///   - **`isEmpty` is required.** Otherwise an empty list renders as content —
///     a heading with nothing under it, which reads as breakage.
///   - **Loading is skeleton-shaped.** The design system's `Skeleton` mirrors
///     the content it replaces, so the screen does not jump when data lands.
class SahraAsyncView<T> extends StatelessWidget {
  const SahraAsyncView({
    required this.value,
    required this.onRetry,
    required this.isEmpty,
    required this.empty,
    required this.loading,
    required this.content,
    this.error,
    super.key,
  });

  final AsyncValue<T> value;

  /// Required. See the class note — this is the enforcement.
  final VoidCallback onRetry;

  final bool Function(T data) isEmpty;
  final WidgetBuilder empty;

  /// Skeleton, not a spinner. Shaped like what is coming.
  final WidgetBuilder loading;

  final Widget Function(BuildContext context, T data) content;

  /// Escape hatch for a screen whose error state is genuinely different — the
  /// booking screen shows `slot_taken` with alternatives rather than a retry
  /// button. It still receives a mapped [Failure], never an exception.
  final Widget Function(BuildContext context, Failure failure)? error;

  @override
  Widget build(BuildContext context) {
    // Deliberately NOT `.when`: keeping previous data on refresh means a
    // pull-to-refresh does not blank the screen the diner is reading.
    if (value.hasError && !value.isLoading) {
      final failure = mapFailure(value.error!);
      return error?.call(context, failure) ?? SahraFailureView(failure: failure, onRetry: onRetry);
    }
    if (value.hasValue) {
      final data = value.requireValue;
      return isEmpty(data) ? empty(context) : content(context, data);
    }
    return loading(context);
  }
}

/// The default error state: what happened, in the diner's language, with a way
/// forward and the `request_id` they can quote to support (doc 06 §1).
class SahraFailureView extends StatelessWidget {
  const SahraFailureView({required this.failure, required this.onRetry, super.key});

  final Failure failure;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final sahra = Theme.of(context).sahra;

    // Scrollable, and centred only when there is room.
    //
    // At 320x568 with 200% text this Column was 80px taller than the screen —
    // an error state that itself renders broken, on the smallest phone SAHRA
    // supports, for the user who most needs to read it. `Center` alone cannot
    // give back height it does not have.
    //
    // LayoutBuilder + minHeight is the pattern: centred when it fits, scrolled
    // when it does not, and never clipped either way.
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            // `maxHeight` is INFINITE when this sits inside another scroll
            // view — which it does on the booking screen. Asking for a
            // minimum of infinity is an assertion, not a layout.
            minHeight: constraints.maxHeight.isFinite ? constraints.maxHeight : 0,
          ),
          child: Padding(
            padding: SahraSpace.all(SahraSpace.s5),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                SahraEmptyState(
                  // Offline gets its own icon because it is its own situation,
                  // not a degraded version of a server error.
                  icon: failure is OfflineFailure ? 'compass' : 'spark',
                  title: failureTitle(failure, l10n),
                  message: failureMessage(failure, l10n),
                  actionLabel: l10n.actionRetry,
                  onAction: onRetry,
                ),
                if (failure.requestId != null) ...<Widget>[
                  const SizedBox(height: SahraSpace.s4),
                  Text(
                    l10n.errorReference(failure.requestId!),
                    // `body-s` at weight 700, not the 11px overline: a coloured
                    // micro-label fails contrast at 11px and fails in Arabic
                    // first (ENGINEERING-STANDARDS, "Small COLOURED text").
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: sahra.textSoft),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
