# LocalBiz AI

Offline, multilingual smart shop assistant for small local businesses (Android, Flutter).

**Status: v0.1.0 source complete, NOT yet compiled or run by the author.**
See `DEVELOPMENT_STATUS.md` for exactly what is implemented, what is untested and the known blockers.

## What it does
* Talk or type: "Rice price enna?", "Arisi 5 kilo add pannu", "Bill complete pannu".
* One `products` table with independent **retail** and **wholesale** prices.
  Normal price questions return only the retail price; wholesale needs the owner.
* Billing with price snapshots, stock deduction, discount, configurable tax, PDF receipts.
* Inventory, purchases, price history, stock history, sales reports, CSV export.
* Owner PIN, optional fingerprint, encrypted database (SQLCipher), roles, audit log.
* Encrypted backup / restore. Local notifications. No internet permission.

## Languages
Tamil, English, Tamil-English (Tanglish), Malayalam, Kannada, Telugu, Hindi
(commands understood in all; replies in the selected / detected language).
Speech recognition and speaking depend on the phone's installed language packs:
see Settings → Voice settings → Check support.

## Architecture
```
lib/
  core/        database, security, theme, l10n, services, utils, providers
  ai/          intent (parser, matcher, validator), conversation (engine),
               voice (STT/TTS), local_llm (model management)
  features/    onboarding, authentication, dashboard, assistant, products, pricing,
               billing, inventory, purchases, reports, history, settings
  shared/      models, repositories, widgets
test/          81 automated tests (not yet executed, see TEST_REPORT.md)
tool/          patch_android.py (adapts the generated Android scaffold)
keystore/      release signing key (keep the repo private)
```
Hybrid AI: deterministic command engine first; optional local LLM may only propose a
structured intent, which is validated and executed through the same permission-checked
services. Money is integer paise; quantities are integer milli-units; the LLM never
calculates anything.

## Build the APK
See `BUILD_INSTRUCTIONS.md` (GitHub Actions: push, wait, download the APK).
