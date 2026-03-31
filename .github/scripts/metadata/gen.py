#!/usr/bin/env python3
import json, sys

if len(sys.argv) < 4:
    print("Usage: gen.py <image-name> <digest> <tags>")
    sys.exit(1)

name = sys.argv[1]
digest = sys.argv[2]
raw_tags = sys.argv[3]
tags = raw_tags.splitlines()

preferred = next((t for t in tags if t.endswith(":latest")), tags[0] if tags else "")

metadata = {
    "name": name,
    "digest": digest,
    "tags": tags,
    "preferred_tag": preferred,
    "image": f"ghcr.io/cloud-neutral-toolkit/{name}",
    "image_with_digest": f"ghcr.io/cloud-neutral-toolkit/{name}@{digest}",
}

outfile = f"image-metadata-{name}.json"
with open(outfile, "w", encoding="utf-8") as f:
    json.dump(metadata, f, indent=2)

print(f"[metadata] Wrote: {outfile}")
