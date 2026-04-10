#!/usr/bin/env python3
from __future__ import annotations

import argparse
import csv
import json
import math
import struct
from pathlib import Path

MAGIC = 0x0BEEF11E


def shannon_entropy(data: bytes) -> float:
    if not data:
        return 0.0
    counts = [0] * 256
    for b in data:
        counts[b] += 1
    n = len(data)
    ent = 0.0
    for c in counts:
        if c:
            p = c / n
            ent -= p * math.log2(p)
    return ent


def classify_payload(payload: bytes) -> str:
    if not payload:
        return "empty"
    head = payload[:64]
    if head.startswith(b"\x7fELF"):
        return "not-ebl-elf"
    if payload[:2] in (b"S0", b"S1", b"S2", b"S3"):
        return "srec-text"
    if b"EBL" in head:
        return "wrapped-ebl-likely"
    ent = shannon_entropy(payload[:2048])
    if ent > 7.6:
        return "possibly-encrypted-or-compressed"
    return "unknown-binary-container"


def parse_ota(path: Path) -> dict:
    data = path.read_bytes()
    if len(data) < 56:
        raise ValueError("file too small")

    fields = struct.unpack_from("<IHHHHHIH32sI", data, 0)
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
    ) = fields
    if file_id != MAGIC:
        raise ValueError(f"bad magic 0x{file_id:08X}")

    idx = 56
    sec = None
    dst = None
    min_hw = None
    max_hw = None
    if field_control & 0x01:
        sec = data[idx]
        idx += 1
    if field_control & 0x02:
        dst = f"0x{int.from_bytes(data[idx:idx+8], 'little'):016X}"
        idx += 8
    if field_control & 0x04:
        min_hw, max_hw = struct.unpack_from("<HH", data, idx)
        idx += 4

    payload = data[header_length:]
    return {
        "path": str(path),
        "file_size": len(data),
        "file_identifier": f"0x{file_id:08X}",
        "header_version": f"0x{header_version:04X}",
        "header_length": header_length,
        "header_field_control": f"0x{field_control:04X}",
        "manufacturer_code": f"0x{manufacturer_code:04X}",
        "image_type": f"0x{image_type:04X}",
        "file_version": f"0x{file_version:08X}",
        "stack_version": f"0x{stack_version:04X}",
        "header_string": header_string_raw.rstrip(b"\x00").decode("ascii", errors="replace"),
        "total_image_size": total_image_size,
        "size_matches_header": len(data) == total_image_size,
        "optional_fields": {
            "security_credential_version": sec,
            "upgrade_file_destination": dst,
            "minimum_hardware_version": min_hw,
            "maximum_hardware_version": max_hw,
        },
        "payload_offset": header_length,
        "payload_length": max(0, len(data) - header_length),
        "payload_prefix_hex": payload[:32].hex(),
        "payload_entropy_2k": round(shannon_entropy(payload[:2048]), 4),
        "payload_classification": classify_payload(payload),
    }


def find_ota_files(roots: list[Path]) -> list[Path]:
    out: list[Path] = []
    for root in roots:
        if root.is_file() and root.suffix.lower() == ".ota":
            out.append(root)
        elif root.exists():
            out.extend(sorted(root.rglob("*.ota")))
    return sorted(set(out))


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("roots", nargs="+", type=Path)
    ap.add_argument("--json-out", type=Path, required=True)
    ap.add_argument("--csv-out", type=Path, required=True)
    args = ap.parse_args()

    files = find_ota_files(args.roots)
    records = []
    errors = []
    for p in files:
        try:
            records.append(parse_ota(p))
        except Exception as exc:
            errors.append({"path": str(p), "error": str(exc)})

    payload = {
        "roots": [str(r) for r in args.roots],
        "ota_files_found": len(files),
        "parsed_ok": len(records),
        "errors": errors,
        "records": records,
    }
    args.json_out.write_text(json.dumps(payload, indent=2) + "\n")

    fieldnames = [
        "path",
        "manufacturer_code",
        "image_type",
        "file_version",
        "stack_version",
        "header_length",
        "payload_offset",
        "payload_length",
        "payload_entropy_2k",
        "payload_classification",
        "size_matches_header",
    ]
    with args.csv_out.open("w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=fieldnames)
        w.writeheader()
        for rec in records:
            w.writerow({k: rec.get(k) for k in fieldnames})
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
