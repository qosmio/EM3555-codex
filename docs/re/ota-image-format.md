# P0.1 OTA Artifact Inventory and Header Characterization (Sengled-first)

## Scope

This run executes **P0 subtask 1** with a Sengled-first search order:

1. `zigbee-OTA/images/...` (primary corpus)
2. Secondary comparison corpus:
   - `EM3555-osram-rgbw-flex/docs/*.ota`
   - `zigbee-herdsman-converters/test/stub/**/*.ota`

Tool used:

- `tools/ota_corpus_inventory.py`

Generated machine output:

- `out/re/ota-image-index.json`

## Findings

### 1) Primary Sengled OTA corpus status

- `zigbee-OTA/images` is **missing** in the current workspace snapshot.
- No `.ota` path with `sengled` in filename/path was detected.

This blocks direct Sengled OTA trust-boundary characterization from the intended
primary corpus.

### 2) Secondary corpus (comparison-only) was parsed

The inventory found **13 OTA files** and parsed Zigbee OTA headers for each.

Two OSRAM/LEDVANCE comparison samples with the same manufacturer code:

| Artifact | Manufacturer | Image type | File version | Stack | Header string |
|---|---:|---:|---:|---:|---|
| `EM3555-osram-rgbw-flex/docs/FLEX_RGBW_IMG001E_00102428-encrypted.ota` | `0x1189` | `0x001E` | `0x00102428` | `0x0002` | `EBL RGBW` |
| `zigbee-herdsman-converters/test/stub/otaUpgradeImages/LEDVANCE/...3221010102432.ota` | `0x1189` | `0x008B` | `0x03177310` | `0x0002` | `A60_TW_Value_II` |

Both show payload prefixes consistent with a **wrapped/encrypted EBL-like**
container by current heuristic.

## Deliverable status for P0.1

- ✅ Parser script under `tools/`: `tools/ota_corpus_inventory.py`
- ✅ OTA structural inventory output: `out/re/ota-image-index.json`
- ✅ `docs/re/ota-image-format.md` (this file)
- ⚠️ Sengled-primary OTA characterization: **blocked by missing corpus path**

## Next concrete step for P0

To continue P0 on the intended target, populate `zigbee-OTA/images` with
Sengled OTA artifacts, then rerun:

```bash
./tools/ota_corpus_inventory.py --root . -o out/re/ota-image-index.json
```

After Sengled images are present, this file should be extended with:

- manufacturer/image-type/file-version matrix for Sengled images,
- payload type classification per image,
- trust-boundary notes tied to Sengled artifacts (not comparison-only OSRAM data).
