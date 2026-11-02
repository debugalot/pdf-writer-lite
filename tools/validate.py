"""Checks PDF Writer Lite's output with two independent readers, and its glyph widths.

Usage (needs pypdf and pymupdf): python -I tools/validate.py [pdf_dir]

- Every PDF in pdf_dir (default tests/out) must open in pypdf's strict mode and in MuPDF without
  warnings, with the same page count, and every page's text must extract.
- The Helvetica and Helvetica-Bold widths in addons/pdf_writer/pdf_metrics.gd must match MuPDF's
  built-in Helvetica for every WinAnsi character.
"""
import glob
import os
import re
import sys
import warnings

import pymupdf
import pypdf

warnings.simplefilter("ignore")
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
failed = 0


def report(ok: bool, name: str, detail: str = "") -> None:
    global failed
    failed += 0 if ok else 1
    print(("  ok    " if ok else "  FAIL  ") + name + ("" if ok or not detail else "  (" + detail + ")"))


print("PDFs")
pdf_dir = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "tests", "out")
files = sorted(glob.glob(os.path.join(pdf_dir, "*.pdf")))
for path in files:
    name = os.path.basename(path)
    try:
        reader = pypdf.PdfReader(path, strict=True)
        texts = [page.extract_text() for page in reader.pages]
        pymupdf.TOOLS.mupdf_warnings()                       # clear
        doc = pymupdf.open(path)
        mu = [page.get_text() for page in doc]
        warn = pymupdf.TOOLS.mupdf_warnings()
        same = len(reader.pages) == doc.page_count
        marked = all("Made with PDF Writer Lite" in t for t in mu)
        report(same and not warn and marked, f"{name}: {doc.page_count} pages, pypdf strict + MuPDF",
               warn or ("page counts differ" if not same else "a page has no mark"))
    except Exception as e:                                   # noqa: BLE001
        report(False, name, repr(e))

print("Glyph widths")
src = open(os.path.join(ROOT, "addons", "pdf_writer", "pdf_metrics.gd"), encoding="utf-8").read()


def array(name: str) -> list:
    body = re.search(r"const %s := \[(.*?)\]" % name, src, re.S).group(1)
    return [int(v) for v in re.findall(r"\d+", body)]


def table(name: str) -> dict:
    body = re.search(r"const %s := \{(.*?)\}" % name, src, re.S).group(1)
    return {int(k, 16): int(v) for k, v in re.findall(r"0x([0-9A-F]+): (\d+)", body)}


regular, bold, upper, upper_bold = array("REGULAR"), array("BOLD"), table("UPPER"), table("UPPER_BOLD")
accent_base = re.search(r'const ACCENT_BASE := "(.*?)"', src).group(1)


def width(c: int, b: bool) -> int:                           # mirrors Metrics.width()
    if 32 <= c <= 126:
        return (bold if b else regular)[c - 32]
    if b and c in upper_bold:
        return upper_bold[c]
    if c in upper:
        return upper[c]
    if 0xEC <= c <= 0xEF:
        return 278
    if 0xC0 <= c <= 0xFF:
        return (bold if b else regular)[ord(accent_base[c - 0xC0]) - 32]
    return 556


for b, font in ((False, pymupdf.Font("helv")), (True, pymupdf.Font("hebo"))):
    wrong = []
    checked = 0
    for c in range(32, 256):
        if c == 0x7F:                                        # DEL: never written (it prints as "?")
            continue
        try:
            ch = bytes([c]).decode("cp1252")
        except UnicodeDecodeError:
            continue
        expected = round(font.text_length(ch, fontsize=1000))
        checked += 1
        if width(c, b) != expected:
            wrong.append(f"{c:#04x} {ch!r}: {width(c, b)} vs {expected}")
    report(not wrong, f"{'Helvetica-Bold' if b else 'Helvetica'}: {checked} WinAnsi widths match MuPDF", "; ".join(wrong[:12]))

print(f"\n{'all passed' if failed == 0 else f'{failed} failed'}")
sys.exit(1 if failed else 0)
