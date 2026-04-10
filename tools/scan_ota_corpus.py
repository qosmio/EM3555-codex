#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import math
import struct
from pathlib import Path

MAGIC = 0x0BEEF11E

EBL_TAGS = {
    0x0000: "EBLTAG_HEADER",
    0xF608: "EBLTAG_METADATA",
    0xFE01: "EBLTAG_PROG",
    0x02FE: "EBLTAG_MFGPROG",
    0xFD03: "EBLTAG_ERASEPROG",
    0xFC04: "EBLTAG_END",
    0xFB05: "EBLTAG_ENC_HEADER",
    0xFA06: "EBLTAG_ENC_INIT",
    0xF907: "EBLTAG_ENC_EBL_DATA",
    0xF709: "EBLTAG_ENC_MAC",
}


def entropy(data: bytes) -> float:
    if not data:
        return 0.0
    freq = [0] * 256
    for b in data:
        freq[b] += 1
    total = len(data)
    h = 0.0
    for c in freq:
        if c:
            p = c / total
            h -= p * math.log2(p)
    return h


def parse_ota(data: bytes) -> dict:
    if len(data) < 56:
        return {"valid_ota": False, "error": "file too small"}

    (file_id, hver, hlen, fctrl, mfg, image_type, fver, stack, hstr_raw, total) = struct.unpack_from(
        "<IHHHHHIH32sI", data, 0
    )
    if file_id != MAGIC:
        return {"valid_ota": False, "error": f"bad magic 0x{file_id:08x}"}

    opt = {}
    idx = 56
    if fctrl & 0x01:
        opt["security_credential_version"] = data[idx]
        idx += 1
    if fctrl & 0x02:
        opt["upgrade_file_destination"] = f"0x{int.from_bytes(data[idx:idx+8], 'little'):016X}"
        idx += 8
    if fctrl & 0x04:
        min_hw, max_hw = struct.unpack_from("<HH", data, idx)
        opt["minimum_hardware_version"] = min_hw
        opt["maximum_hardware_version"] = max_hw
        idx += 4

    payload = data[hlen:]
    probe = payload[:4096]

    markers = []
    for off in range(0, min(64, len(payload) - 3), 2):
        tag = int.from_bytes(payload[off : off + 2], "big")
        ln = int.from_bytes(payload[off + 2 : off + 4], "big")
        if tag in EBL_TAGS:
            markers.append({"offset": off, "tag": f"0x{tag:04X}", "tag_name": EBL_TAGS[tag], "len": ln})

    classification = "vendor-specific/unknown"
    if any(m["tag"] == "0xFB05" for m in markers):
        classification = "wrapped or encrypted EBL (contains ENC_HEADER tag)"
    elif any(m["tag"] in {"0x0000", "0xFE01", "0xFC04"} for m in markers):
        classification = "plain or wrapped EBL"
    elif entropy(probe) > 7.6:
        classification = "likely encrypted/compressed payload"

    return {
        "valid_ota": True,
        "header": {
            "header_version": f"0x{hver:04X}",
            "header_length": hlen,
            "field_control": f"0x{fctrl:04X}",
            "manufacturer_code": f"0x{mfg:04X}",
            "image_type": f"0x{image_type:04X}",
            "file_version": f"0x{fver:08X}",
            "stack_version": f"0x{stack:04X}",
            "header_string": hstr_raw.rstrip(b"\x00").decode("ascii", "replace"),
            "total_image_size": total,
            "optional_fields": opt,
        },
        "payload": {
            "offset": hlen,
            "length": len(payload),
            "prefix_hex": payload[:32].hex(),
            "probe_entropy": round(entropy(probe), 4),
            "ebl_markers": markers,
            "classification": classification,
        },
        "size_matches_header": (len(data) == total),
    }


def discover_inputs(root: Path) -> list[Path]:
    paths = []
    primary = root / "zigbee-OTA" / "images"
    if primary.exists():
        paths.extend(sorted(primary.rglob("*.ota")))

    fallback = root / "zigbee-herdsman-converters" / "test" / "stub"
    if fallback.exists():
        paths.extend(sorted(fallback.rglob("*.ota")))

    osram = root / "EM3555-osram-rgbw-flex" / "docs" / "FLEX_RGBW_IMG001E_00102428-encrypted.ota"
    if osram.exists() and osram not in paths:
        paths.append(osram)

    return paths


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", type=Path, default=Path("."))
    ap.add_argument("-o", "--output", type=Path, required=True)
    args = ap.parse_args()

    root = args.root.resolve()
    inputs = discover_inputs(root)

    report = {
        "root": str(root),
        "searched_paths": ["zigbee-OTA/images", "zigbee-herdsman-converters/test/stub", "EM3555-osram-rgbw-flex/docs"],
        "found_files": [],
        "notes": [],
    }

    if not (root / "zigbee-OTA" / "images").exists():
        report["notes"].append("Primary Sengled OTA corpus path zigbee-OTA/images is missing in this workspace snapshot.")

    for p in inputs:
        parsed = parse_ota(p.read_bytes())
        parsed["path"] = str(p.relative_to(root))
        report["found_files"].append(parsed)

    args.output.write_text(json.dumps(report, indent=2) + "\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
