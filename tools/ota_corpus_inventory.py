#!/usr/bin/env python3
"""Inventory Zigbee OTA artifacts with Sengled-first prioritization."""
from __future__ import annotations

import argparse
import hashlib
import json
import struct
from pathlib import Path

MAGIC = 0x0BEEF11E


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def parse_zigbee_ota(path: Path) -> dict:
    data = path.read_bytes()
    out = {
        "path": str(path),
        "size": len(data),
        "sha256": sha256(path),
        "valid_zigbee_ota": False,
    }

    if len(data) < 56:
        out["error"] = "file shorter than Zigbee OTA minimum header"
        return out

    (
        file_id,
        header_version,
        header_length,
        field_control,
        manufacturer_code,
        image_type,
        file_version,
        stack_version,
        header_string_raw,
        total_image_size,
    ) = struct.unpack_from("<IHHHHHIH32sI", data, 0)

    if file_id != MAGIC:
        out["error"] = f"unexpected magic 0x{file_id:08X}"
        return out

    idx = 56
    sec_cred = None
    upgrade_dest = None
    min_hw = None
    max_hw = None

    if field_control & 0x01:
        sec_cred = data[idx]
        idx += 1
    if field_control & 0x02:
        upgrade_dest = f"0x{int.from_bytes(data[idx:idx + 8], 'little'):016X}"
        idx += 8
    if field_control & 0x04:
        min_hw, max_hw = struct.unpack_from("<HH", data, idx)
        idx += 4

    out.update(
        {
            "valid_zigbee_ota": True,
            "file_identifier": f"0x{file_id:08X}",
            "header_version": f"0x{header_version:04X}",
            "header_length": header_length,
            "field_control": f"0x{field_control:04X}",
            "manufacturer_code": f"0x{manufacturer_code:04X}",
            "image_type": f"0x{image_type:04X}",
            "file_version": f"0x{file_version:08X}",
            "stack_version": f"0x{stack_version:04X}",
            "header_string": header_string_raw.rstrip(b"\x00").decode("ascii", errors="replace"),
            "total_image_size": total_image_size,
            "size_matches_header": total_image_size == len(data),
            "payload_offset": header_length,
            "payload_length": max(0, len(data) - header_length),
            "payload_prefix_hex": data[header_length : header_length + 24].hex(),
            "optional_fields": {
                "security_credential_version": sec_cred,
                "upgrade_file_destination": upgrade_dest,
                "minimum_hardware_version": min_hw,
                "maximum_hardware_version": max_hw,
            },
        }
    )

    if out["payload_prefix_hex"].startswith("0000"):
        out["payload_classification"] = "possible wrapped/encrypted EBL"
    else:
        out["payload_classification"] = "unknown"

    return out


def gather_candidates(root: Path) -> tuple[list[Path], list[str]]:
    notes: list[str] = []
    candidates: list[Path] = []

    primary = root / "zigbee-OTA" / "images"
    if primary.exists():
        candidates.extend(sorted(primary.rglob("*.ota")))
    else:
        notes.append("Primary path missing: zigbee-OTA/images")

    secondary_roots = [
        root / "EM3555-osram-rgbw-flex" / "docs",
        root / "zigbee-herdsman-converters" / "test" / "stub",
    ]
    for sr in secondary_roots:
        if sr.exists():
            candidates.extend(sorted(sr.rglob("*.ota")))

    deduped: list[Path] = []
    seen: set[Path] = set()
    for p in candidates:
        rp = p.resolve()
        if rp not in seen:
            deduped.append(p)
            seen.add(rp)

    return deduped, notes


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", type=Path, default=Path("."))
    ap.add_argument("-o", "--output", type=Path, required=True)
    args = ap.parse_args()

    root = args.root.resolve()
    candidates, notes = gather_candidates(root)
    parsed = [parse_zigbee_ota(p) for p in candidates]

    sengled = [x for x in parsed if "sengled" in x["path"].lower()]

    result = {
        "root": str(root),
        "notes": notes,
        "total_ota_files": len(parsed),
        "sengled_candidates": len(sengled),
        "artifacts": parsed,
    }

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2) + "\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
