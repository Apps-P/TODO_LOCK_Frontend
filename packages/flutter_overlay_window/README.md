# TodoLock local overlay fork

Based on flutter_overlay_window 0.5.0 from https://github.com/X-SLAYER/flutter_overlay_window. See LICENSE for the upstream license.

App-specific additions: native Play Billing 8.3.0, a non-exported billing host Activity, native overlay visibility restoration on payment UI departure, receipt verification, and a durable session/outcome journal shared by both Flutter engines. Existing overlay APIs are preserved. The main engine is the sole Hive writer.

Setup and limitations: ../../.codex/billing-setup.md.
