# PDF Writer Lite for Godot

[![ExcaliBug](https://img.shields.io/badge/Website-ExcaliBug.com-F4B544?style=flat-square)](https://excalibug.com/addons/pdf-writer/)
[![Godot 4.7](https://img.shields.io/badge/Godot-4.7-478CBF?style=flat-square&logo=godotengine&logoColor=white)](https://godotengine.org)
[![PDF Writer](https://img.shields.io/badge/itch.io-PDF%20Writer%20(full)-FA5C5C?style=flat-square&logo=itch.io&logoColor=white)](https://debugalot.itch.io/pdf-writer)
[![Ko-fi](https://img.shields.io/badge/Ko--fi-Support-FF5E5B?style=flat-square&logo=kofi&logoColor=white)](https://ko-fi.com/debugalot)
[![License: free, watermarked](https://img.shields.io/badge/License-Free%2C%20watermarked-43D1C6?style=flat-square)](LICENSE)

Write PDF files from GDScript: run reports, receipts, quest logs, save summaries, printable
anything. Pure GDScript with no plugins or binaries, so it runs everywhere Godot does, including web
exports. This is the free, watermarked edition of **[PDF Writer](https://debugalot.itch.io/pdf-writer)**,
with the same API.

```gdscript
var pdf := PdfDocument.new()
pdf.title = "Run report"
pdf.footer = "Page {page} of {pages}"
pdf.add_heading("Run 42")
pdf.add_text("Finished in 12:31 with 3 deaths.")
pdf.add_list(["Floor 1: 1:02", "Floor 2: 3:40"])
pdf.save("user://run_42.pdf")
```

- **Real layout.** Headings, paragraphs, bulleted and numbered lists and rules flow down the page and
  onto new ones by themselves. Text wraps, aligns or justifies, and headings never end a page.
- **Draw anywhere.** Text (wrapped, aligned, or cut short with "…"), lines and rectangles, at any
  position on any page.
- **Headers and footers** on every page, with `{page}`, `{pages}`, `{title}` and `{date}` filled in.
- **Real text.** It stays selectable, searchable and copyable, in the PDF's built-in Helvetica.
- **Web-ready.** `download()` hands the PDF to the browser in a web export, or opens it in the
  system's viewer on desktop.

## Lite or PDF Writer?

| | PDF Writer Lite (free) | [PDF Writer](https://debugalot.itch.io/pdf-writer) ($3) |
|---|---|---|
| Languages | Latin: English and the Western European languages (Windows-1252) | Any: also Greek, Cyrillic, Chinese, Japanese, Korean, Arabic, Hebrew, Hindi, Thai... |
| Fonts | The built-in Helvetica: regular, bold, italic | Any Godot `Font`, variable fonts, automatic fallback |
| Headings, paragraphs, lists, rules, page flow | Yes | Yes |
| Header, footer, page numbers | Yes | Yes |
| Drawing | Text, lines, rectangles | Also circles, polygons, dashes, rounded corners, see-through colours |
| Tables | | Header rows repeated on every page |
| BBCode, links, bookmarks | | Yes |
| Images | | Lossless or JPEG, with transparency |
| Page decorator (draw on every page) | | Yes |
| Watermark | On every page: a large, faint knight and "Made with PDF Writer Lite" | None |

**Upgrading** is replacing `addons/pdf_writer/` with the full version's folder: code written for Lite
keeps working. `tools/check_upgrade.py` proves it by running this repository's API tour and demo on
the full version. Don't then update Lite from the Asset Library, which would put Lite back.

## Requirements

Godot 4.7, tested on 4.7.2. It may well work on earlier 4.x versions, but they haven't been tested.

## Install

From the editor's **AssetLib** tab, search for *PDF Writer Lite*. Or copy `addons/pdf_writer/` into
your project's `addons/` folder. There is no plugin to enable: `PdfDocument` is available everywhere.

## Flowing content

Content flows from the top of the first page down and onto new pages:

| | |
|---|---|
| `add_heading(text, level := 1, style := {})` | Levels 1–4. Kept on the same page as what follows it. |
| `add_text(text, style := {})` | A paragraph. `\n` starts a new line. |
| `add_list(items, style := {})` | Bullets, or numbers with `{"ordered": true}`. |
| `add_rule(style := {})`, `add_space(points)`, `add_page_break()` | Rule style keys: `color`, `width`, `space`. |

**Text style keys:** `size` (points), `color`, `bold`, `italic`, `align` (`"left"`, `"center"`,
`"right"`, `"justify"`), `line_spacing` (times the text size, default 1.3), `indent`, `space_after`.

## Drawing

Positions are in points (1/72 inch) from the top-left corner of the page, like Godot's 2D. Drawing
goes to the current page; `set_page(index)` draws on an earlier one.

| | |
|---|---|
| `draw_text(position, text, style := {}) -> Vector2` | Text at a position (top-left of the first line). `width` wraps it (or, with `ellipsis`, cuts it to one line ending in "…"). Returns its size. |
| `measure_text(text, style := {}) -> Vector2` | How big it would be. |
| `draw_line(from, to, color, width)` | |
| `draw_rect(rect, fill, stroke, width)` | Use `Color.TRANSPARENT` to leave out the fill or the outline. |
| `get_cursor_y()`, `set_cursor_y(y)`, `content_width()` | Where flowing content continues, to mix placed and flowing content. |

## The document

| | |
|---|---|
| `PdfDocument.new(size := LETTER, margin := 54)` | Sizes: `LETTER`, `LEGAL`, `A3`, `A4`, `A5`, or any `Vector2` in points. |
| `title`, `author`, `subject`, `keywords`, `creator` | Shown in the viewer's document properties. |
| `margin_left`, `margin_top`, `margin_right`, `margin_bottom` | |
| `header`, `footer`, `header_align`, `footer_align` | Text on every page; `{page}`, `{pages}`, `{title}` and `{date}` are filled in. |
| `theme` | Sizes and colours of the flowing content; see `DEFAULT_THEME` in the script. |
| `new_page(size)` | Starts a page; the flowing content continues on it. |
| `get_page_count()`, `get_page()` | |
| `to_bytes()`, `save(path)` | The finished file. |
| `download(file_name)` | Web export: hands the PDF to the browser as a download. Elsewhere: saves it to `user://` and opens it in the system's PDF viewer. |

## The watermark

Every page carries the PDF Writer Lite watermark: the Sir Debugalot knight, large and faint (10%
opacity) across the middle of the page, over the content so the text stays readable, and "Made with
PDF Writer Lite" in the bottom margin (on the right, or on the left when the footer is
right-aligned), linking to PDF Writer. It's how this edition stays free, and the [license](LICENSE)
doesn't allow removing or changing it. For PDFs without it, get
[PDF Writer](https://debugalot.itch.io/pdf-writer): $3, same code, no watermark.

## License

Free to use in any number of your own projects, commercial ones included, and the PDFs you make are
yours to share or sell. Keep the watermark, and don't redistribute the add-on itself. The full terms
are in [LICENSE](LICENSE).

## Limits

- **Latin text only.** Characters outside Windows-1252 print as "?", and the document warns once
  in the output panel. PDF Writer prints any language.
- **Built-in fonts.** Helvetica isn't embedded; every PDF viewer has it or a metric-compatible
  stand-in (Arial, Nimbus Sans), so lines break the same everywhere but the letters may look a little
  different between viewers.
- Colours are drawn opaque. No images, tables, links or bookmarks (see the comparison above).

## Demo

`demo/demo.tscn` (the main scene): fill in a dungeon run and press **Export PDF** (Ctrl+E) for a run
report with a title band, stat bars, lists and notes. The code that builds the PDF is
`demo/run_report.gd`, and it uses only the API above.

The Godot Asset Library download and GitHub's *Download ZIP* contain only `addons/pdf_writer/`.
For the demo and the tests, clone [the repository](https://github.com/debugalot/pdf-writer-lite).

## Tests

```
godot --headless --path . res://tests/test_lite.tscn
```

67 checks: file structure (every cross-reference offset, stream length and the end-of-file marker),
text read back through the encoding (accents, quotes, dashes, €), fonts, wrapping, justification,
alignment, page breaks, headings kept with what follows, lists, headers and footers, the watermark
(on every page, on top, at 10%, with its link), drawing, document information, repeatable output, the
demo's report, and speed (300 paragraphs in well under a second). The exit code is 0 when everything passes, and the PDFs land in `tests/out/`.

With Python and `pypdf` + `pymupdf` installed:

- `python tools/validate.py` opens every test PDF in pypdf's strict mode and in MuPDF, and checks the
  Helvetica widths against MuPDF's for every character.
- `python tools/check_upgrade.py <godot> <full addons/pdf_writer>` runs the API tour and the demo on
  the full version.

## Support

If PDF Writer Lite saved you time, consider [buying me a coffee on Ko-fi](https://ko-fi.com/debugalot),
getting [PDF Writer](https://debugalot.itch.io/pdf-writer), or checking out more Godot tools on
[ExcaliBug](https://excalibug.com).

## Credits

- **Glyph widths:** from Adobe's Core 14 AFM files for Helvetica and Helvetica-Bold, copyright 1985,
  1987, 1989, 1990, 1997 Adobe Systems Incorporated. Helvetica is a trademark of Monotype Imaging Inc.
- **The mark:** the Sir Debugalot knight, rendered from the KayKit Adventurers knight by Kay Lousberg
  (CC0).
