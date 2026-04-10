# P0.1 OTA Artifact Inventory and Format Characterization

## Objective alignment

This pass targets the **non-invasive install feasibility** question by inventorying and structurally parsing local OTA images first, with emphasis on finding Sengled-relevant artifacts before using OSRAM/LEDVANCE as comparison.

## Tools used

- `tools/scan_ota_corpus.py` (new reusable parser/scanner)
- `python` (JSON inspection)
- `xxd` (spot-check header bytes for OSRAM sample)

## Inputs scanned

Command input roots:

- `zigbee-OTA/images` (requested primary corpus path)
- `zigbee-herdsman-converters/test/stub/otaUpgradeImages`
- `EM3555-osram-rgbw-flex/docs/FLEX_RGBW_IMG001E_00102428-encrypted.ota` (secondary comparison)

## Generated artifacts

- `out/re/ota-corpus-summary.json`
- `out/re/ota-corpus-summary.csv`

## Corpus-level findings

- Total OTA files parsed: **11**
- Zigbee OTA files recognized (`0x0BEEF11E`): **11**
- Manufacturer codes observed:
  - `0x1002`, `0x1037`, `0x1078`, `0x117C`, `0x1189`, `0x1209`, `0x122F`, `0x124F`, `0x1286`, `0xFFFF`
- **No Sengled-labeled OTA file** was found in the scanned local roots.

## Secondary comparison sample (OSRAM/LEDVANCE)

File:

- `EM3555-osram-rgbw-flex/docs/FLEX_RGBW_IMG001E_00102428-encrypted.ota`

Parsed header values:

- Manufacturer code: `0x1189`
- Image type: `0x001E`
- File version: `0x00102428`
- Stack version: `0x0002`
- Header length: `56`
- Optional fields: none (`field_control=0x0000`)
- Payload offset: `56`
- Payload length: `178852`

Payload heuristic:

- 4 KiB sample entropy: `7.9534 bits/byte`
- Classification: `likely_encrypted_or_compressed`

This supports treating the OSRAM sample as a useful comparison point for wrapped/encrypted OTA payload behavior, but not as primary evidence for Sengled acceptance logic.

## Trust-boundary notes (P0 impact)

What this step can already answer:

- Local OTA artifacts are parseable as Zigbee OTA containers.
- Key OTA metadata fields needed for acceptance gating (manufacturer/image-type/version/stack) can be extracted reproducibly.

What this step cannot answer yet:

- Sengled-specific OTA acceptance path in stock EM357 firmware.
- Whether Sengled OTA payloads are plain EBL, wrapped EBL, or encrypted EBL.
- Application-vs-bootloader enforcement split on Sengled hardware.

## Blockers for next P0 subtasks

The following expected primary inputs are not present in this workspace snapshot:

- `EM357/backups/20260406-000518/...`
- `EM357/backups/20260406-001017/...`
- `zigbee-OTA/images/...` (directory missing)

Without those, `P0.2+` can only proceed as SDK-informed hypothesis work, not Sengled-stock-evidence-backed path recovery.

## Immediate next step (when primary inputs are restored)

1. Re-run `tools/scan_ota_corpus.py` including restored `zigbee-OTA/images`.
2. Filter for Sengled manufacturer/image tuples and isolate candidate install payload formats.
3. Pivot to EM357 dump call-path recovery (`P0.2`) with address-linked evidence.
