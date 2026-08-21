# R8 / ProGuard rules for the release build.
#
# ── DELIBERATELY EMPTY, AND THAT IS THE POINT ────────────────────────────────
#
# Every rule in this file switches OFF part of the shrinking and obfuscation
# that `isMinifyEnabled = true` exists to do. A `-keep` added because a build
# went red, without knowing what it saved, is indistinguishable from turning
# minification off one class at a time — and nobody ever comes back to remove
# it, because nobody can tell what would break.
#
# So the rule for this file is:
#
#   EVERY ENTRY NAMES WHAT IT PROTECTS AND HOW THAT WAS ESTABLISHED.
#
# "The build failed without it" is not an explanation. "This class is looked up
# reflectively by <library> at <call site>, verified by <how>" is.
#
# ── WHAT R8 ACTUALLY NEEDED HERE ─────────────────────────────────────────────
#
# First release build with R8 on: 2026-08-11. Recorded so the next person knows
# the empty state was measured rather than assumed.
#
# The Flutter Gradle plugin already contributes rules for the engine, and each
# plugin ships `consumer-rules.pro` inside its own AAR — firebase_messaging,
# geolocator and url_launcher all do. Those are applied automatically and do
# NOT belong here; duplicating them is how this file grows into a list nobody
# can audit.
#
# Nothing in this app's own Dart or Kotlin is reached by reflection: the
# generated API client is plain Dart, Riverpod's providers are code-generated
# rather than mirrored, and the only platform channels are the three approved
# plugins, which carry their own rules.
#
# If you are about to add a rule, first check whether the plugin already ships
# one — `unzip -l ~/.gradle/caches/**/<plugin>.aar` and look for
# `proguard.txt`. Adding a duplicate here makes it look like this app needs
# something it does not.
