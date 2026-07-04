#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
MODULE_CACHE="${TMPDIR:-/private/tmp}/parrot-swift-module-cache"
mkdir -p "$MODULE_CACHE"

run_swift_e2e() {
  local name="$1"
  shift
  local output="${TMPDIR:-/private/tmp}/parrot-${name}"
  echo "==> ${name}"
  xcrun swiftc \
    -target arm64-apple-macosx14.0 \
    -module-cache-path "$MODULE_CACHE" \
    -parse-as-library \
    "$@" \
    -o "$output"
  "$output"
}

cd "$ROOT_DIR"

run_swift_e2e provider-endpoint-timeout-e2e \
  Parrot/App/AppLocalization.swift \
  Parrot/App/ProviderEndpoint.swift \
  Parrot/App/ProviderSettings.swift \
  Scripts/provider-endpoint-timeout-e2e.swift

run_swift_e2e i18n-localization-e2e \
  Parrot/App/AppLocalization.swift \
  Parrot/App/ProviderEndpoint.swift \
  Parrot/App/ProviderSettings.swift \
  Parrot/App/TranslationHistory.swift \
  Parrot/App/ParrotUIComponents.swift \
  Parrot/App/FloatingWindowPlacement.swift \
  Parrot/App/GlobalShortcutManager.swift \
  Parrot/App/ShortcutSettings.swift \
  Scripts/i18n-localization-e2e.swift

run_swift_e2e long-text-translation-e2e \
  Parrot/App/LongTextTranslation.swift \
  Scripts/long-text-translation-e2e.swift

run_swift_e2e translation-request-lifecycle-e2e \
  Parrot/App/AppLocalization.swift \
  Parrot/App/ProviderEndpoint.swift \
  Parrot/App/TranslationRequestLifecycle.swift \
  Parrot/App/LongTextTranslation.swift \
  Parrot/App/ProviderSettings.swift \
  Parrot/App/TranslationHistory.swift \
  Parrot/App/ParrotUIComponents.swift \
  Parrot/App/QuickTextTranslationView.swift \
  Scripts/translation-request-lifecycle-e2e.swift

run_swift_e2e history-clear-confirmation-e2e \
  Parrot/App/AppLocalization.swift \
  Parrot/App/TranslationHistory.swift \
  Parrot/App/ParrotUIComponents.swift \
  Scripts/history-clear-confirmation-e2e.swift

run_swift_e2e always-on-top-preferences-e2e \
  Parrot/App/AppLocalization.swift \
  Parrot/App/ParrotUIComponents.swift \
  Scripts/always-on-top-preferences-e2e.swift

run_swift_e2e keychain-cache-e2e \
  Parrot/App/AppLocalization.swift \
  Parrot/App/ProviderEndpoint.swift \
  Parrot/App/ProviderSettings.swift \
  Scripts/keychain-cache-e2e.swift

run_swift_e2e translation-language-controls-e2e \
  Parrot/App/AppLocalization.swift \
  Parrot/App/ProviderEndpoint.swift \
  Parrot/App/ProviderSettings.swift \
  Scripts/translation-language-controls-e2e.swift

run_swift_e2e translation-style-e2e \
  Parrot/App/AppLocalization.swift \
  Parrot/App/ProviderEndpoint.swift \
  Parrot/App/ProviderSettings.swift \
  Scripts/translation-style-e2e.swift

run_swift_e2e custom-translation-prompt-e2e \
  Parrot/App/AppLocalization.swift \
  Parrot/App/ProviderEndpoint.swift \
  Parrot/App/ProviderSettings.swift \
  Scripts/custom-translation-prompt-e2e.swift

run_swift_e2e terminology-glossary-e2e \
  Parrot/App/AppLocalization.swift \
  Parrot/App/ProviderEndpoint.swift \
  Parrot/App/ProviderSettings.swift \
  Scripts/terminology-glossary-e2e.swift

run_swift_e2e floating-window-position-preferences-e2e \
  Parrot/App/AppLocalization.swift \
  Parrot/App/FloatingWindowPlacement.swift \
  Scripts/floating-window-position-preferences-e2e.swift

run_swift_e2e ocr-source-text-editing-e2e \
  Parrot/App/AppLocalization.swift \
  Parrot/App/ProviderEndpoint.swift \
  Parrot/App/TranslationRequestLifecycle.swift \
  Parrot/App/LongTextTranslation.swift \
  Parrot/App/ProviderSettings.swift \
  Parrot/App/TranslationHistory.swift \
  Parrot/App/ParrotUIComponents.swift \
  Parrot/App/QuickTextTranslationView.swift \
  Parrot/App/ScreenshotSelectionController.swift \
  Scripts/ocr-source-text-editing-e2e.swift

echo "core e2e passed"
