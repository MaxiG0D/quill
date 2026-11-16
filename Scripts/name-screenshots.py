"""Renames the screenshots exported from an Xcode result bundle to the names the tests gave them.

`xcresulttool export attachments` writes files with opaque names and a manifest.json
that maps them back. Usage: python3 Scripts/name-screenshots.py screenshots
"""
import json
import pathlib
import sys

root = pathlib.Path(sys.argv[1])
for manifest in root.glob("*/manifest.json"):
    folder = manifest.parent
    for test in json.loads(manifest.read_text()):
        for attachment in test.get("attachments", []):
            source = folder / attachment["exportedFileName"]
            suggested = attachment.get("suggestedHumanReadableName", source.name)
            # Names look like "inbox-light_0_<uuid>.png"; keep the part the test chose.
            name = suggested.split("_")[0] + source.suffix
            if source.exists() and not name.startswith("Screenshot"):
                source.rename(folder / name)
    manifest.unlink()
