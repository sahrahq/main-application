/// Shared bilingual copy for SAHRA.
///
/// Codegen (`flutter gen-l10n`) is wired up when the first app exists; the ARB
/// files and their guarantees are here now because the error vocabulary is
/// shared and the tests that keep it honest do not need a Flutter toolchain.
library sahra_localization;

export 'src/error_codes.dart';
