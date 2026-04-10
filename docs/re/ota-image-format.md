# OTA Image Format (P0.1): Sengled-first corpus scan + OSRAM/LEDVANCE comparison

## Scope and priority alignment

This pass follows the OTA-first priority for field-install feasibility.

- Primary target corpus requested: `zigbee-OTA/images/...` (Sengled-first)
- Secondary comparison corpus used here:
  - `EM3555-osram-rgbw-flex/docs/FLEX_RGBW_IMG001E_00102428-encrypted.ota`
  - `zigbee-herdsman-converters/test/stub/otaUpgradeImages/...`

Reproducible tooling/output in this repo:

- parser: `tools/ota_corpus_inspect.py`
- machine outputs:
  - `out/re/ota-corpus-inspection.json`
  - `out/re/ota-corpus-inspection.csv`

## Trust-boundary view of the OTA artifact

For each `.ota` file, the script extracts and records the OTA header fields that
matter for acceptance prechecks:

- manufacturer code
- image type
- file version
- stack version
- optional header fields (security credential version, destination EUI64,
  min/max hardware version)
- payload offset and payload length

This yields the first trust boundary split:

1. **Application OTA client boundary** (header metadata + transfer/state logic)
2. **Installer/bootloader boundary** (payload/EBL validation and install-time checks)

This task does not yet prove which side enforces final trust for Sengled, but
it captures the exact artifact metadata needed for that path recovery.

## Corpus coverage in current workspace snapshot

Command roots scanned:

- `zigbee-OTA/images` (requested primary corpus path)
- `zigbee-herdsman-converters/test/stub/otaUpgradeImages`
- `EM3555-osram-rgbw-flex/docs/FLEX_RGBW_IMG001E_00102428-encrypted.ota`

Observed from generated JSON:

- OTA files found: `11`
- Parsed successfully: `11`
- Parse errors: `0`
- Manufacturer `0x1047` (Sengled): **0 files in current scanned corpus**

## Secondary comparison samples (OSRAM/LEDVANCE)

### `FLEX_RGBW_IMG001E_00102428-encrypted.ota`

- manufacturer code: `0x1189`
- image type: `0x001E`
- file version: `0x00102428`
- stack version: `0x0002`
- header length: `56`
- optional fields: none (`field_control=0x0000`)
- payload classification (heuristic): `possibly-encrypted-or-compressed`

### LEDVANCE sample from local stub corpus

- path includes `A60_TW_Value_II-0x1189-0x008B-0x03177310...ota`
- manufacturer code: `0x1189`
- image type: `0x008B`
- file version: `0x03177310`
- payload classification (heuristic): `possibly-encrypted-or-compressed`

## Interpretation for P0

- The parser now gives repeatable extraction of OTA trust-boundary metadata for
  any local corpus path.
- In this workspace snapshot, the **requested Sengled-primary OTA corpus is not
  available at `zigbee-OTA/images`**, and no Sengled (`0x1047`) image appears in
  the scanned fallback OTA set.
- Therefore, Sengled-specific acceptance conclusions cannot be made yet from OTA
  artifacts alone.

## Next P0 steps (strictly Sengled-focused)

1. Add actual Sengled OTA images under `zigbee-OTA/images/...`.
2. Re-run `tools/ota_corpus_inspect.py` and isolate Sengled rows by mfg code.
3. Begin P0.2/P0.3 on the Sengled `EM357` dump set to map OTA client call path
   and acceptance branches with addresses/status-code evidence.
