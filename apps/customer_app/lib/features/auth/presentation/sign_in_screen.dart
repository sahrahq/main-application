import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sahra_design_system/sahra_design_system.dart';

import '../../../config/env/env.dart';
import '../../../localization/generated/app_localizations.dart';
import '../../../shared/widgets/failure_copy.dart';
import '../../reservations/presentation/pending_booking.dart';
import '../../reservations/presentation/reservation_copy.dart';
import 'sign_in_notifier.dart';

/// `docs/design/ui_kits/app/SignInScreen.jsx`.
///
/// ─────────────────────────────────────────────────────────────────────────
/// WHERE THIS SCREEN AND ITS REFERENCE DISAGREE, AND WHY
/// ─────────────────────────────────────────────────────────────────────────
///
/// The reference draws a SIGN IN / SIGN UP tab pair, a password field, a
/// "Forgot password?" link, and Facebook + Google buttons. None of the four is
/// here, and none of them is an omission by oversight:
///
///   - **The tabs.** The API has no "do you already have an account" question
///     to ask. `request-otp` signs in a known number, `register` creates one,
///     and the repository picks between them from the server's answer. Asking
///     a returning diner to self-classify is a question we can answer for
///     them, and the one time they answer it wrong they end up stuck on a tab
///     that will not let them in.
///   - **The password field.** There is no password. Doc 06 §2 as implemented
///     is passwordless OTP for diners; `POST /auth/login` exists for owner and
///     staff accounts, which sign in through the management app. A password
///     box here would have nothing to submit to.
///   - **"Forgot password?"** follows the password. AUTH-2 (reset) is an open
///     gap, and it is a gap for a flow diners are not in.
///   - **Facebook and Google.** AUTH-1. There is no social endpoint at all, so
///     a button here would be decoration that fails on tap. Absent beats
///     disabled beats broken.
///
/// What IS kept from the reference: the layout skeleton — brand mark and close
/// control on one row, the three-line display headline in terracotta, a single
/// full-width primary action at the bottom, the mashrabiya wash behind it all,
/// and `variant: line` inputs.
///
/// The reference's headline copy ("Find / the vibe / for tonight") is
/// onboarding copy — it sells the product to someone deciding whether to use
/// it. A diner reaches THIS screen mid-booking, having already decided. So the
/// headline says what the sign-in is for, and when a slot is pending it says
/// which table is waiting.
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({
    this.pendingRestaurantId,
    this.onClose,
    this.onSignedIn,
    super.key,
  });

  /// The venue whose slot is waiting, if the diner arrived here from a booking
  /// attempt. Display only — the selection itself never travels in a URL
  /// (see [PendingSelection]).
  final String? pendingRestaurantId;

  /// Backing out. Null on a sign-in the diner started themselves, where there
  /// is nothing to back out to.
  final VoidCallback? onClose;

  /// They got in. Supplied by the route — see `routes.dart`.
  final VoidCallback? onSignedIn;

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _code = TextEditingController();

  @override
  void dispose() {
    _phone.dispose();
    _name.dispose();
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).sahra;
    final state = ref.watch(signInProvider);

    // LISTENED FOR, not checked after `verify()` returns. The notifier owns the
    // side effect of storing the session; this screen owns only the fact that
    // the screen is finished. Awaiting the call instead would put a
    // `BuildContext` across an await, which is the lint the split exists to
    // make unnecessary.
    ref.listen(signInProvider, (_, next) {
      if (next is SignInDone) widget.onSignedIn?.call();
    });

    final pending = widget.pendingRestaurantId == null
        ? null
        : ref.watch(pendingBookingProvider(widget.pendingRestaurantId!));

    return Scaffold(
      body: SahraPageWidth(
        child: SafeArea(
          child: Stack(
            children: <Widget>[
              Positioned.fill(
                child: SahraMashrabiya(
                  color: s.textBody,
                  opacity: Theme.of(context).brightness == Brightness.dark ? 0.05 : 0.035,
                  tile: 46,
                  fade: true,
                ),
              ),
              // Scrolled rather than laid out to fit. At 320x568 with 200% text
              // the headline alone is most of the viewport, and the code step
              // adds a field plus two links under it.
              SingleChildScrollView(
                padding: SahraSpace.inset(
                  start: SahraSpace.s5,
                  end: SahraSpace.s5,
                  top: SahraSpace.s5,
                  bottom: SahraSpace.s6,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _Header(onClose: widget.onClose),
                    const SizedBox(height: SahraSpace.s6),
                    _Headline(state: state),
                    if (pending != null) ...<Widget>[
                      const SizedBox(height: SahraSpace.s4),
                      _PendingSlotNote(selection: pending),
                    ],
                    const SizedBox(height: SahraSpace.s6),
                    switch (state) {
                      SignInPhone() ||
                      SignInSending() =>
                        _PhoneStep(phone: _phone, name: _name, state: state),
                      SignInCode() ||
                      SignInVerifying() ||
                      SignInDone() =>
                        _CodeStep(code: _code, state: state),
                    },
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onClose});

  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final s = Theme.of(context).sahra;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        // The wordmark. There is no logo asset in the repo (the reference
        // points at `../../assets/logo.png`, which the design package ships and
        // this app does not), so the brand appears as its name in the display
        // face — the same substitution the splash uses.
        Text(
          'SAHRA',
          style: SahraTypography.numeric(
            Theme.of(context).textTheme.titleMedium!.copyWith(
                  color: s.accentOnSurface,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                ),
          ),
        ),
        if (onClose != null)
          SahraButton(
            label: l10n.signInCancel,
            iconOnly: true,
            icon: const SahraIcon('x', size: 20),
            variant: SahraButtonVariant.ghost,
            size: SahraButtonSize.sm,
            onPressed: onClose,
          ),
      ],
    );
  }
}

class _Headline extends StatelessWidget {
  const _Headline({required this.state});

  final SignInState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final s = Theme.of(context).sahra;
    final text = Theme.of(context).textTheme;

    final code = state is SignInCode || state is SignInVerifying || state is SignInDone;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          code ? l10n.signInCodeTitle : l10n.signInTitle,
          style: text.displaySmall?.copyWith(color: s.textBody),
        ),
        const SizedBox(height: SahraSpace.s2),
        Text(
          code
              // The number is Latin-digit content inside Arabic prose, which
              // is precisely the case `ltrRun` exists for — without it the
              // leading `+` lands on the wrong end and "+20 100…" reads as
              // "…100 20+".
              ? l10n.signInCodeSentTo(ltrRun(_phoneOf(state)))
              : l10n.signInWhy,
          style: text.bodyMedium?.copyWith(color: s.textSoft),
        ),
      ],
    );
  }

  String _phoneOf(SignInState state) => switch (state) {
        SignInCode(:final challenge) => challenge.phone,
        SignInVerifying(:final challenge) => challenge.phone,
        _ => '',
      };
}

/// What the diner is signing in FOR, when they got here mid-booking.
///
/// Not decoration. A sign-in wall that appears without explanation reads as a
/// paywall, and the C-1.6 decision only survives contact with a real diner if
/// the thing they were doing is visibly still there waiting.
class _PendingSlotNote extends StatelessWidget {
  const _PendingSlotNote({required this.selection});

  final PendingSelection selection;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final s = Theme.of(context).sahra;
    final text = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: SahraSpace.all(SahraSpace.s4),
      // Gold BORDER on a sunken well, not gold-tinted text on a gold wash.
      // The reference's watching banner is `gold-tint` behind `gold-dark`
      // copy; there is no `premiumOnTint` token, and inventing one to sit
      // under a 28% gold wash is how the badge contrast bug happened the first
      // time. The well is a proven pair, the gold stays as border and icon —
      // both non-text channels — and the guideline can still check the words.
      decoration: BoxDecoration(
        color: s.surfaceSunken,
        border: Border.all(color: s.premium),
        borderRadius: SahraRadius.allOf(SahraRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SahraIcon('lantern', size: 18, color: s.premium),
              const SizedBox(width: SahraSpace.s2),
              Expanded(
                child: Text(
                  l10n.signInSlotHeld(
                    // ISOLATED. The venue name is very often Latin text ("Layali
                    // Lounge") sitting inside an Arabic sentence, and without an
                    // isolate the bidi algorithm drags the neighbouring comma
                    // and digits into the Latin run — the exact defect the venue
                    // screen's phone number had.
                    ltrRun(selection.venueName),
                    // "5 أغسطس", not "2026-08-05". A machine date in the middle
                    // of a sentence reads as a serial number, and this sentence
                    // exists to reassure someone mid-booking.
                    dayAndMonth(selection.date, context),
                    ltrRun(selection.slotLabel),
                    l10n.bookGuests(selection.partySize),
                  ),
                  style: text.bodySmall?.copyWith(
                    color: s.textBody,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: SahraSpace.s1),
          Text(
            l10n.signInSlotNote,
            style: text.bodySmall?.copyWith(color: s.textSoft),
          ),
        ],
      ),
    );
  }
}

class _PhoneStep extends ConsumerWidget {
  const _PhoneStep({required this.phone, required this.name, required this.state});

  final TextEditingController phone;
  final TextEditingController name;
  final SignInState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final sending = state is SignInSending;
    final failure = state is SignInPhone ? (state as SignInPhone).failure : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SahraInput(
          label: l10n.signInPhoneLabel,
          hint: l10n.signInPhoneHint,
          variant: SahraInputVariant.line,
          controller: phone,
          keyboardType: TextInputType.phone,
          error: failure == null ? null : failureMessage(failure, l10n),
        ),
        const SizedBox(height: SahraSpace.s5),
        // ASKED FOR UP FRONT, NOT AFTER THE CODE.
        //
        // The name is only used when the number turns out to be new, and the
        // repository does not know which it is until the server answers. The
        // alternative — ask for the code, discover it was a registration, then
        // interrupt to ask for a name — puts a second form in the middle of a
        // flow the diner thought was finishing.
        SahraInput(
          label: l10n.signInNameLabel,
          hint: l10n.signInNameHint,
          variant: SahraInputVariant.line,
          controller: name,
        ),
        const SizedBox(height: SahraSpace.s6),
        SahraButton(
          label: sending ? l10n.signInSending : l10n.signInContinue,
          onPressed: sending
              ? null
              : () => ref.read(signInProvider.notifier).requestCode(
                    phone: phone.text.trim(),
                    fullName: name.text.trim(),
                  ),
        ),
      ],
    );
  }
}

class _CodeStep extends ConsumerWidget {
  const _CodeStep({required this.code, required this.state});

  final TextEditingController code;
  final SignInState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final s = Theme.of(context).sahra;
    final text = Theme.of(context).textTheme;

    final verifying = state is SignInVerifying;
    final resending = state is SignInCode && (state as SignInCode).resending;
    final failure = state is SignInCode ? (state as SignInCode).failure : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SahraInput(
          label: l10n.signInCodeLabel,
          variant: SahraInputVariant.line,
          controller: code,
          keyboardType: TextInputType.number,
          error: failure == null ? null : failureMessage(failure, l10n),
        ),
        const SizedBox(height: SahraSpace.s6),
        SahraButton(
          label: verifying ? l10n.signInVerifying : l10n.signInVerify,
          onPressed:
              verifying ? null : () => ref.read(signInProvider.notifier).verify(code.text.trim()),
        ),
        const SizedBox(height: SahraSpace.s4),
        // A Wrap. At 200% text "Send another code" and "Use a different
        // number" together are 255px wider than the screen, and a Row cannot
        // give that back — the two are pushed onto separate lines instead.
        Wrap(
          spacing: SahraSpace.s2,
          runSpacing: SahraSpace.s1,
          children: <Widget>[
            SahraButton(
              label: resending ? l10n.signInResending : l10n.signInResend,
              variant: SahraButtonVariant.ghost,
              size: SahraButtonSize.sm,
              onPressed:
                  resending || verifying ? null : ref.read(signInProvider.notifier).resend,
            ),
            SahraButton(
              label: l10n.signInChangePhone,
              variant: SahraButtonVariant.ghost,
              size: SahraButtonSize.sm,
              onPressed: verifying
                  ? null
                  : () {
                      code.clear();
                      ref.read(signInProvider.notifier).changePhone();
                    },
            ),
          ],
        ),
        // WHERE THE CODE ACTUALLY WENT, while delivery is a stub.
        //
        // OPS-1: `LoggingOtpDelivery` writes the code to the API log and no SMS
        // is sent. Without this line the screen asks for a code that, as far as
        // the person holding the phone can tell, was never sent — and the first
        // thing they conclude is that the app is broken.
        //
        // It is behind a build flag, not a `kDebugMode` check: a debug build
        // pointed at a staging API with real delivery would show it wrongly,
        // and the flag tracks the API's behaviour rather than the client's.
        if (Env.otpDeliveryIsStubbed) ...<Widget>[
          const SizedBox(height: SahraSpace.s5),
          Text(
            l10n.signInDevHint(ltrRun('STUB DELIVERY')),
            style: text.bodySmall?.copyWith(color: s.textFaint),
          ),
        ],
      ],
    );
  }
}
