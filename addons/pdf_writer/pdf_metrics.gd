## Text in the PDF's built-in Helvetica fonts: WinAnsi codes for Unicode text, and glyph widths
## (1/1000 em) from Adobe's AFM files for Helvetica and Helvetica-Bold. The oblique faces share the
## upright widths.

## Helvetica's ascender and descender, in em.
const ASCENT := 0.718
const DESCENT := 0.207

# Codes 32..126.
const REGULAR := [
	278, 278, 355, 556, 556, 889, 667, 191, 333, 333, 389, 584, 278, 333, 278, 278,
	556, 556, 556, 556, 556, 556, 556, 556, 556, 556, 278, 278, 584, 584, 584, 556,
	1015, 667, 667, 722, 722, 667, 611, 778, 722, 278, 500, 667, 556, 833, 722, 778,
	667, 778, 722, 667, 611, 722, 667, 944, 667, 667, 611, 278, 278, 278, 469, 556,
	333, 556, 556, 500, 556, 556, 278, 556, 556, 222, 222, 500, 222, 833, 556, 556,
	556, 556, 333, 500, 278, 556, 500, 722, 500, 500, 500, 334, 260, 334, 584,
]
const BOLD := [
	278, 333, 474, 556, 556, 889, 722, 238, 333, 333, 389, 584, 278, 333, 278, 278,
	556, 556, 556, 556, 556, 556, 556, 556, 556, 556, 333, 333, 584, 584, 584, 611,
	975, 722, 722, 722, 722, 667, 611, 778, 722, 278, 556, 722, 611, 833, 722, 778,
	667, 778, 722, 667, 611, 722, 667, 944, 667, 667, 611, 333, 278, 333, 584, 556,
	333, 556, 611, 556, 611, 556, 333, 611, 611, 278, 278, 556, 278, 889, 611, 611,
	611, 611, 389, 556, 333, 611, 556, 778, 556, 556, 500, 389, 280, 389, 584,
]
# WinAnsi codes 128..255 that aren't accented letters, in Helvetica. UPPER_BOLD has Helvetica-Bold's
# where it differs.
const UPPER := {
	0x80: 556, 0x82: 222, 0x83: 556, 0x84: 333, 0x85: 1000, 0x86: 556, 0x87: 556, 0x88: 333, 0x89: 1000,
	0x8A: 667, 0x8B: 333, 0x8C: 1000, 0x8E: 611, 0x91: 222, 0x92: 222, 0x93: 333, 0x94: 333, 0x95: 350,
	0x96: 556, 0x97: 1000, 0x98: 333, 0x99: 1000, 0x9A: 500, 0x9B: 333, 0x9C: 944, 0x9E: 500, 0x9F: 667,
	0xA0: 278, 0xA1: 333, 0xA2: 556, 0xA3: 556, 0xA4: 556, 0xA5: 556, 0xA6: 260, 0xA7: 556, 0xA8: 333,
	0xA9: 737, 0xAA: 370, 0xAB: 556, 0xAC: 584, 0xAD: 333, 0xAE: 737, 0xAF: 333, 0xB0: 400, 0xB1: 584,
	0xB2: 333, 0xB3: 333, 0xB4: 333, 0xB5: 556, 0xB6: 537, 0xB7: 278, 0xB8: 333, 0xB9: 333, 0xBA: 365,
	0xBB: 556, 0xBC: 834, 0xBD: 834, 0xBE: 834, 0xBF: 611, 0xC6: 1000, 0xD0: 722, 0xD7: 584, 0xD8: 778,
	0xDE: 667, 0xDF: 611, 0xE6: 889, 0xF0: 556, 0xF7: 584, 0xF8: 611, 0xFE: 556,
}
const UPPER_BOLD := {
	0x82: 278, 0x84: 500, 0x91: 278, 0x92: 278, 0x93: 500, 0x94: 500, 0x9A: 556, 0xA6: 280,
	0xB5: 611, 0xB6: 556, 0xF0: 611, 0xFE: 611,
}
# Unicode code points that WinAnsi places in 0x80..0x9F.
const WINANSI_EXTRA := {
	0x20AC: 0x80, 0x201A: 0x82, 0x0192: 0x83, 0x201E: 0x84, 0x2026: 0x85, 0x2020: 0x86, 0x2021: 0x87,
	0x02C6: 0x88, 0x2030: 0x89, 0x0160: 0x8A, 0x2039: 0x8B, 0x0152: 0x8C, 0x017D: 0x8E, 0x2018: 0x91,
	0x2019: 0x92, 0x201C: 0x93, 0x201D: 0x94, 0x2022: 0x95, 0x2013: 0x96, 0x2014: 0x97, 0x02DC: 0x98,
	0x2122: 0x99, 0x0161: 0x9A, 0x203A: 0x9B, 0x0153: 0x9C, 0x017E: 0x9E, 0x0178: 0x9F,
}
# For widths: the unaccented letter of each code 0xC0..0xFF (* = in UPPER instead).
const ACCENT_BASE := "AAAAAA*CEEEEIIII*NOOOOO**UUUUY**aaaaaa*ceeeeiiii*nooooo**uuuuy*y"


## The WinAnsi byte for a Unicode code point, or -1 if the built-in fonts can't show it.
static func code(cp: int) -> int:
	if cp >= 32 and cp <= 126:
		return cp
	if cp >= 0xA0 and cp <= 0xFF:
		return cp
	return WINANSI_EXTRA.get(cp, -1)


## Width of one WinAnsi code, in 1/1000 em.
static func width(c: int, bold: bool) -> int:
	if c >= 32 and c <= 126:
		return (BOLD if bold else REGULAR)[c - 32]
	if bold and UPPER_BOLD.has(c):
		return UPPER_BOLD[c]
	if UPPER.has(c):
		return UPPER[c]
	if c >= 0xEC and c <= 0xEF:          # accented i's are as wide as the dotless i, not the i
		return 278
	if c >= 0xC0 and c <= 0xFF:
		var base := ACCENT_BASE.unicode_at(c - 0xC0)
		return (BOLD if bold else REGULAR)[base - 32]
	return 556


## Width of WinAnsi bytes at `size` points.
static func measure(codes: PackedByteArray, size: float, bold: bool) -> float:
	var total := 0
	for c in codes:
		total += width(c, bold)
	return total * size / 1000.0
