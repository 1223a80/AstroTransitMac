# Product Decisions

These decisions are intentional product constraints, not unresolved audit findings. Read this file before proposing security or persistence migrations.

## LLM API Key Storage

- The LLM API key intentionally remains in the app's existing `UserDefaults`-backed settings storage.
- Do **not** migrate it to Keychain, add Keychain compatibility code, or remove the existing persistence path unless the human explicitly reverses this decision in a future request.
- Security audits may document the trade-off, but must not classify the current storage choice as an implementation bug to be fixed.

Decision confirmed by the project owner on 2026-07-10.
