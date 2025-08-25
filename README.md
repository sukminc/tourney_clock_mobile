# Tourney Clock (Flutter)

A mobile tournament clock for poker (NLHE) with Big Blind Ante, live prize pool and payout ladder (Top 10%), and director tools. Built with Flutter + Riverpod. Runs on iOS and Android (and works on desktop/web for development).

## Features (MVP)
- Big, legible **clock** with level controls (start/pause, prev/next level, ±1 min, reset).
- **Blind schedule** with automatic breaks (sample schedule included).
- **Entries / Re-entries / Rebuys / Add-ons** tracking.
- Live **stats**: Entries, Players Remaining, Prize Pool, Average Stack.
- **Payouts panel** (Top 10%) with a top-heavy geometric split that sums exactly to the prize pool.
- **Settings** sheet to change Buy-in, Currency, Starting Stack, Level Length, and Late Registration close level.
- Wakelock to keep the screen on; optional beep at level transitions (if an asset is provided).

## Tech
- Flutter (Dart), Riverpod (StateNotifier), just_audio, wakelock_plus.

## Project Structure (key files)