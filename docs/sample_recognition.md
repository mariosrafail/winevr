# Sample-code selection

The wine catalog offers **Έχω κωδικό δείγματος**. A visitor can type a configured code, press **Enter**, or press **Άνοιγμα δείγματος**. A keyboard-emulating USB/Bluetooth reader can type into the focused field and finish with Enter. The same `client_selected` signal used by the catalog opens the matching existing wine profile.

This feature identifies a configured record. It does not identify liquid, measure composition, authenticate a physical bottle, use a camera, or perform infrared/NIR spectroscopy. It does not require a printed QR code. Optical, NFC, or spectrometer hardware would need its own explicit integration and validation.

## Bundled educational codes

| Code | Existing profile | Collection |
| --- | --- | --- |
| `WV-LIA-01` | `liatiko_dafnes_demo` | Λιάτικο · Δαφνές |
| `WV-KOT-02` | `kotsifali_crete_demo` | Κοτσιφάλι · Κρήτη |
| `WV-VID-03` | `vidiano_crete_demo` | Βιδιανό · Κρήτη |

These are educational entries, without an invented producer, measured sample, vintage, or commercial certification. Their configuration is in `data/tasting_profiles/cretan_collection.json`.

## Record and input contract

Add a `sample_codes` array of strings to a profile, for example `"sample_codes": ["WV-LIA-01"]`. Codes must be unique across every loaded record and within each record. User-provided profiles retain the existing loading precedence. A user override of a bundled profile must explicitly retain or replace its aliases.

The resolver trims leading/trailing whitespace and converts Latin letters to uppercase. It preserves internal characters: ` wv-lia-01\r\n` resolves, but `WV LIA 01` does not. Accepted canonical codes contain only `A–Z`, `0–9`, and `-`, with at most 32 characters. Raw input is limited to 64 characters before trimming; oversized input is rejected. The field's larger 128-character cap ensures a truncated oversized paste cannot become a valid short prefix.

Resolution is exact. Prefixes, partial catalog searches, URLs, Unicode lookalikes, and unknown codes do not select a record. Two matching aliases, including differences only in case or outer whitespace, return `duplicate`; no first-match fallback is used. Repeated aliases on one profile also return `duplicate` so configuration mistakes remain visible.

`WineDatabase.resolve_sample_code(raw)` returns `{ok, code, profile_id, error}` on success (`error` is empty). Failures return `{ok: false, error}` and may include the normalized code. Error values are `empty`, `too_long`, `invalid`, `unknown`, or `duplicate`. The resolver is a pure lookup: it does not change the active client, profiles, file system, or network. The UI emits selection only after a successful lookup whose profile remains enabled in its catalog; invalid input leaves the current experience unchanged.

## Verification

Run `scenes/dev/SampleCodeQA.tscn` with Godot 4.6. The checks cover every bundled alias, case/outer-whitespace handling, invalid/unknown/partial/overlong input, duplicate aliases, no mutation, the actual catalog field and Enter submission, and successful activation of the existing profile. `--sample-capture --touch-ui` also saves a 390×844 native catalog screenshot to `work/sample_code_entry.png`.
