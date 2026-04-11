# P0.1 OTA Image Format / Trust-Boundary Inventory (Sengled-first)

## Scope and constraint handling

This run targets the **install feasibility question first** (P0), not dump normalization.
It uses local artifacts only and produces rerunnable outputs.

Primary target path from the task list:

- `zigbee-OTA/images/...` (Sengled-first)

Secondary comparison sources used when primary path was unavailable:

- `zigbee-herdsman-converters/test/stub/.../*.ota`
- `EM3555-osram-rgbw-flex/docs/FLEX_RGBW_IMG001E_00102428-encrypted.ota`

## Tooling used

- `tools/scan_ota_corpus.py` (new script in this change)
- `python` for CSV materialization
- `xxd`/`strings` spot-checks were used earlier during parser validation

## Generated artifacts

- Machine report: `out/re/ota-corpus-scan.json`
- Summary table: `out/re/ota-header-summary.csv`

## Key findings

1. The primary Sengled OTA corpus path `zigbee-OTA/images` is **missing** in this
   workspace snapshot.
2. The fallback corpus contains 13 OTA files, including two OSRAM/LEDVANCE
   manufacturer `0x1189` samples.
3. The OSRAM comparison sample
   `FLEX_RGBW_IMG001E_00102428-encrypted.ota` parses as valid Zigbee OTA with:
   - manufacturer `0x1189`
   - image type `0x001E`
   - file version `0x00102428`
   - stack version `0x0002`
   - no optional OTA header fields
   - payload markers indicating `EBLTAG_ENC_HEADER`, `EBLTAG_ENC_INIT`, and
     `EBLTAG_ENC_EBL_DATA` at early offsets, consistent with wrapped/encrypted
     EBL content.

## Parsed fields required by P0.1

For each discovered OTA file, the parser records:

- manufacturer code
- image type
- file version
- stack version
- optional fields (when present)
- payload offset/length
- payload prefix
- EBL marker candidates in early payload
- preliminary payload classification

See `out/re/ota-header-summary.csv` for compact rows and
`out/re/ota-corpus-scan.json` for detailed per-file evidence.

## Trust-boundary implications (preliminary)

- The OTA container itself is standard Zigbee OTA (`0x0BEEF11E`), but payload
  handling likely crosses into EBL parser/decryptor logic (bootloader or app
  handoff path, device-dependent).
- Presence of encrypted EBL tags in the OSRAM sample indicates that **header
  acceptance alone is insufficient** to claim install feasibility; downstream
  decrypt/integrity checks likely exist.
- A Sengled-specific claim cannot be made until `zigbee-OTA/images` or another
  Sengled OTA corpus is actually present for this workspace run.

## Next P0 step

Proceed to **P0.2** (OTA client call path) against the Sengled EM357 dump sets
once the expected `EM357/backups/20260406-*` content is confirmed present.
