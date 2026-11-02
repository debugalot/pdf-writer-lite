"""Writes addons/pdf_writer/pdf_watermark.gd: the Sir Debugalot mark as ready-made PDF image data.

Usage: python -I tools/make_watermark.py <sir_debugalot_watermark.png>

The colours and the alpha are stored as zlib streams (PDF's FlateDecode), base64 encoded, so the
add-on needs no imported texture and the watermark works the same in the editor, in exports and on
the web.
"""
import base64
import os
import sys
import zlib

from PIL import Image

PX = 384                                 # about 75 dpi drawn across the page; plenty for the corner mark

src = sys.argv[1]
mark = Image.open(src).convert("RGBA").resize((PX, PX), Image.LANCZOS)
rgb = mark.convert("RGB").tobytes()
alpha = mark.getchannel("A").tobytes()
out = os.path.join(os.path.dirname(__file__), "..", "addons", "pdf_writer", "pdf_watermark.gd")


def b64(data: bytes) -> str:
    return base64.b64encode(zlib.compress(data, 9)).decode("ascii")


with open(out, "w", encoding="utf-8", newline="\n") as f:
    f.write("## The Sir Debugalot mark printed on every page of PDF Writer Lite, as PDF image data:\n")
    f.write("## %dx%d pixels, colours (DeviceRGB) and alpha (DeviceGray), each a base64 zlib stream.\n" % (PX, PX))
    f.write("## Made by tools/make_watermark.py.\n\n")
    f.write("const SIZE := %d\n" % PX)
    f.write('const RGB := "%s"\n' % b64(rgb))
    f.write('const ALPHA := "%s"\n' % b64(alpha))
print(os.path.normpath(out), os.path.getsize(out) // 1024, "KB")
