"""Shows that code written for PDF Writer Lite runs unchanged on the full PDF Writer.

Usage (needs pypdf): python -I tools/check_upgrade.py <godot executable> <full version's addons/pdf_writer>

Builds a scratch project with the full add-on in addons/pdf_writer/ (an upgrade is exactly that
folder replaced), runs tests/api_tour.gd and demo/run_report.gd in it, and checks that the PDFs
open, keep their text, and no longer carry the Lite mark.
"""
import os
import shutil
import subprocess
import sys
import tempfile
import warnings

import pypdf

warnings.simplefilter("ignore")
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
godot, full = sys.argv[1], sys.argv[2]

RUNNER = """extends SceneTree
func _init() -> void:
	var tour: PdfDocument = load("res://tests/api_tour.gd").build()
	print("tour ", tour.save("res://out/tour.pdf"), " ", tour.get_page_count())
	var report = load("res://demo/run_report.gd")
	var pdf: PdfDocument = report.build(report.sample())
	print("report ", pdf.save("res://out/report.pdf"), " ", pdf.get_page_count())
	quit()
"""

with tempfile.TemporaryDirectory() as tmp:
    shutil.copytree(full, os.path.join(tmp, "addons", "pdf_writer"))
    for rel in ("tests/api_tour.gd", "demo/run_report.gd"):
        os.makedirs(os.path.join(tmp, os.path.dirname(rel)), exist_ok=True)
        shutil.copy(os.path.join(ROOT, rel), os.path.join(tmp, rel))
    os.makedirs(os.path.join(tmp, "out"))
    with open(os.path.join(tmp, "project.godot"), "w") as f:
        f.write('config_version=5\n\n[application]\n\nconfig/name="Upgrade check"\n')
    with open(os.path.join(tmp, "runner.gd"), "w", newline="\n") as f:
        f.write(RUNNER)
    subprocess.run([godot, "--headless", "--path", tmp, "--import"], capture_output=True, timeout=300)
    run = subprocess.run([godot, "--headless", "--path", tmp, "-s", "res://runner.gd"], capture_output=True, text=True, timeout=300)
    log = run.stdout + run.stderr
    errors = [l for l in log.splitlines() if "SCRIPT ERROR" in l or "Parse Error" in l or "Assertion failed" in l]
    print(log.strip().splitlines()[-2:] if log.strip() else "(no output)")
    failed = 0
    for name, needle in (("tour.pdf", "After the drawing."), ("report.pdf", "Heisenbug")):
        path = os.path.join(tmp, "out", name)
        if not os.path.exists(path):
            print("  FAIL ", name, "was not written")
            failed += 1
            continue
        text = "\n".join(p.extract_text() for p in pypdf.PdfReader(path, strict=True).pages)
        ok = needle in text and "Made with PDF Writer Lite" not in text
        failed += 0 if ok else 1
        print("  ok   " if ok else "  FAIL ", f"{name} on the full version: opens, keeps its text, no Lite mark")
    for e in errors:
        print("  FAIL ", e)
    sys.exit(1 if failed or errors else 0)
