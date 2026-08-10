import 'package:flutter/material.dart';

import '../theme/sahra_layout.dart';

/// An `AppBar` whose CONTENTS obey [SahraLayout.maxContentWidth].
///
/// WHY THIS EXISTS. `SahraPageWidth` wraps a Scaffold's `body`, which is the
/// right place for it — the Scaffold and its background must still span the
/// window. But `Scaffold.appBar` is outside that wrapper, so on a 1440-point
/// browser window the title sat at x=72 while the content it titled sat in a
/// centred column from 439 to 1001. A heading four hundred points away from
/// its own screen reads as two unrelated things.
///
/// Found by `page_width_enforced_test.dart` on three screens at once, which is
/// the signature of a rule that was applied by hand rather than by
/// construction.
///
/// IT IS SEAMLESS, not a floating bar. `AppBarTheme.backgroundColor` and
/// `scaffoldBackgroundColor` are both `surfacePage` at elevation 0, so
/// narrowing the bar reveals more of the identical colour. If either ever
/// gains its own surface or a shadow, this needs a full-width backdrop behind
/// the constrained content — hence the note rather than a silent assumption.
class SahraAppBar extends StatelessWidget implements PreferredSizeWidget {
  const SahraAppBar({
    this.title,
    this.leading,
    this.actions,
    super.key,
  });

  final Widget? title;
  final Widget? leading;
  final List<Widget>? actions;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) => SahraPageWidth(
        child: AppBar(
          title: title,
          leading: leading,
          actions: actions,
        ),
      );
}
