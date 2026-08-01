/// The palette review page, rendered for a human to look at.
///
/// Not a regression check — a REVIEW ARTEFACT. Regenerate with
/// `flutter test --update-goldens --tags golden` and open the PNGs.
import 'package:flutter/material.dart';
import 'package:sahra_design_system/sahra_design_system.dart';

import '../support/harness.dart';

void main() {
  goldenMatrix(
    'Review/contrast-audit',
    (cell) => const ContrastAuditPage(),
    surface: const Size(760, 1180),
  );
}
