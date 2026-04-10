#!/usr/bin/env python3
from __future__ import annotations

import argparse
import csv
import json
import math
import struct
from pathlib import Path

ZIGBEE_OTA_MAGIC = 0x0BEEF11E

def entropy(data: bytes) -> float:
    if not data:
        return 0.0
    counts = [0] * 256
    for b in data:
        counts[b] += 1
    n = len(data)
    h = 0.0
    for c in counts:
        if c:
            p = c / n
            h -= p * math.log2(p)
    return h


def classify_payload(payload: bytes, ent: float) -> str:
    if payload.startswith(b"GBL\x00") or payload.startswith(b"GBL\x01"):
        return "wrapped_gbl"
    if payload.startswith(b":"):
        return "ascii_hex_or_srec"
    if payload.startswith(b"\x7fELF"):
        return "embedded_elf"
    if ent >= 7.6:
        return "likely_encrypted_or_compressed"
    if ent >= 6.8:
        return "binary_blob_unknown_wrapping"
    return "likely_structured_plain_binary"


def parse_ota(path: Path) -> dict:
    data = path.read_bytes()
    rec: dict[str, object] = {
        "path": str(path),
        "size": len(data),
        "is_zigbee_ota": False,
    }
    if len(data) < 56:
        rec["error"] = "file too small for Zigbee OTA header"
        return rec

    (file_id, header_version, header_length, field_control, manufacturer_code, image_type,
     file_version, stack_version, header_string_raw, total_image_size) = struct.unpack_from("<IHHHHHIH32sI", data, 0)

    if file_id != ZIGBEE_OTA_MAGIC:
        rec["error"] = f"bad magic 0x{file_id:08X}"
        return rec

    rec["is_zigbee_ota"] = True
    rec["file_identifier"] = f"0x{file_id:08X}"
    rec["header_version"] = f"0x{header_version:04X}"
    rec["header_length"] = header_length
    rec["header_field_control"] = f"0x{field_control:04X}"
    rec["manufacturer_code"] = f"0x{manufacturer_code:04X}"
    rec["image_type"] = f"0x{image_type:04X}"
    rec["file_version"] = f"0x{file_version:08X}"
    rec["stack_version"] = f"0x{stack_version:04X}"
    rec["header_string"] = header_string_raw.rstrip(b"\x00").decode("ascii", errors="replace")
    rec["total_image_size"] = total_image_size
    rec["size_matches_header"] = total_image_size == len(data)

    idx = 56
    optional: dict[str, object] = {}
    if field_control & 0x01:
        optional["security_credential_version"] = data[idx]
        idx += 1
    if field_control & 0x02:
        optional["upgrade_file_destination"] = f"0x{int.from_bytes(data[idx:idx+8], 'little'):016X}"
        idx += 8
    if field_control & 0x04:
        minimum_hardware_version, maximum_hardware_version = struct.unpack_from("<HH", data, idx)
        optional["minimum_hardware_version"] = minimum_hardware_version
        optional["maximum_hardware_version"] = maximum_hardware_version
        idx += 4
    rec["optional_fields"] = optional

    payload = data[header_length:]
    ent = entropy(payload[: min(4096, len(payload))])
    rec["payload_offset"] = header_length
    rec["payload_length"] = len(payload)
    rec["payload_prefix_hex"] = payload[:32].hex()
    rec["payload_sample_entropy_bits_per_byte"] = round(ent, 4)
    rec["payload_classification"] = classify_payload(payload, ent)
    return rec


def expand_inputs(inputs: list[str]) -> list[Path]:
    out: list[Path] = []
    for raw in inputs:
        p = Path(raw)
        if p.is_file() and p.suffix.lower() == ".ota":
            out.append(p)
        elif p.is_dir():
            out.extend(sorted(p.rglob("*.ota")))
    return sorted(set(out))


def main() -> int:
    ap = argparse.ArgumentParser(description="Scan OTA corpus and emit JSON + CSV summary")
    ap.add_argument("inputs", nargs="+", help="OTA file(s) or directory roots")
    ap.add_argument("--json-out", type=Path, required=True)
    ap.add_argument("--csv-out", type=Path, required=True)
    args = ap.parse_args()

    ota_files = expand_inputs(args.inputs)
    records = [parse_ota(p) for p in ota_files]

    summary = {
        "inputs": args.inputs,
        "ota_count": len(ota_files),
        "zigbee_ota_count": sum(1 for r in records if r.get("is_zigbee_ota")),
        "manufacturer_codes": sorted({r.get("manufacturer_code") for r in records if r.get("manufacturer_code")}),
        "records": records,
    }
    args.json_out.parent.mkdir(parents=True, exist_ok=True)
    args.csv_out.parent.mkdir(parents=True, exist_ok=True)
    args.json_out.write_text(json.dumps(summary, indent=2) + "\n")

    fieldnames = [
        "path", "size", "is_zigbee_ota", "manufacturer_code", "image_type", "file_version",
        "stack_version", "header_length", "payload_length", "payload_sample_entropy_bits_per_byte",
        "payload_classification", "size_matches_header", "error"
    ]
    with args.csv_out.open("w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=fieldnames)
        w.writeheader()
        for r in records:
            w.writerow({k: r.get(k, "") for k in fieldnames})
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
