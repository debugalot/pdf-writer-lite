extends Node
## PDF Writer Lite's tests. Run headless:
##   godot --headless --path . res://tests/test_lite.tscn
## The exit code is 0 when every check passes. The PDFs land in tests/out/.

const Reader := preload("res://tests/pdf_reader.gd")
const Tour := preload("res://tests/api_tour.gd")
const Metrics := preload("res://addons/pdf_writer/pdf_metrics.gd")
const RunReport := preload("res://demo/run_report.gd")
const OUT := "res://tests/out/"
const LOREM := "The quick brown fox jumps over the lazy dog while the knight sharpens his sword and the bug hides under the castle bridge."

var _passed := 0
var _failed := 0


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var started := Time.get_ticks_msec()
	_structure()
	_text()
	_layout()
	_lists()
	_decorations()
	_drawing()
	_document()
	_speed()
	print("\n%d passed, %d failed (%.1f s)" % [_passed, _failed, (Time.get_ticks_msec() - started) / 1000.0])
	get_tree().quit(1 if _failed > 0 else 0)


func check(name: String, ok: bool, detail := "") -> void:
	if ok:
		_passed += 1
		print("  ok    ", name)
	else:
		_failed += 1
		print("  FAIL  ", name, ("  (" + detail + ")") if detail != "" else "")


func _read(pdf: PdfDocument, file: String) -> Reader:
	var bytes := pdf.to_bytes()
	var f := FileAccess.open(OUT + file, FileAccess.WRITE)
	f.store_buffer(bytes)
	f.close()
	return Reader.new(bytes)


## The page's text lines, without the header, footer and mark.
func _body(r: Reader, page: int, pdf: PdfDocument) -> Array:
	var out := []
	var h: float = r.pages[page].size.y
	for t in r.pages[page].texts:
		var from_top := h - float(t.y)
		if from_top > pdf.margin_top and from_top < h - pdf.margin_bottom + 0.01:
			out.append(t)
	return out


func _width(t: Dictionary) -> float:
	var codes: PackedByteArray = t.codes
	return Metrics.measure(codes, float(t.size), int(t.font) % 2 == 0) + float(t.tw) * codes.count(32)


# ------------------------------------------------------------------------------------------------

func _structure() -> void:
	print("File structure")
	var pdf: PdfDocument = Tour.build()
	var bytes := pdf.to_bytes()
	var r := Reader.new(bytes)
	check("xref, offsets, stream lengths, trailer and %%EOF", r.errors.is_empty(), ", ".join(r.errors))
	check("one page object per page", r.pages.size() == pdf.get_page_count(), "%d vs %d" % [r.pages.size(), pdf.get_page_count()])
	check("the A5 page has its own size", r.pages[2].size.is_equal_approx(PdfDocument.A5))
	var fonts := 0
	for id in r.objects:
		var d := str(r.objects[id].dict)
		if d.find("/Subtype /Type1") >= 0 and d.find("/Encoding /WinAnsiEncoding") >= 0:
			fonts += 1
	check("the four built-in Helvetica fonts, WinAnsi encoded", fonts == 4)
	check("page contents are deflated", str(r.objects[r._ref(r.pages[0].dict, "/Contents")].dict).find("/FlateDecode") >= 0)
	pdf.compress = false
	var plain := Reader.new(pdf.to_bytes())
	check("compress = false writes readable contents", plain.errors.is_empty() and str(plain.objects[plain._ref(plain.pages[0].dict, "/Contents")].dict).find("/Filter") < 0)
	check("the API tour reads back", r.all_text().find("After the drawing.") >= 0 and r.all_text().find("An A5 page.") >= 0)


func _text() -> void:
	print("Text")
	var pdf := PdfDocument.new()
	pdf.add_heading("Heading")
	pdf.add_text("Café, Ærøskøbing, Straße, Ñandú, “quotes”, ‘single’ — dashes – and €5… ™ © ½ œ Ÿ")
	pdf.add_text("Bold", {"bold": true})
	pdf.add_text("Italic", {"italic": true})
	pdf.add_text("Bold italic", {"bold": true, "italic": true})
	pdf.add_text("日本語 and Ελληνικά")
	var r := _read(pdf, "text.pdf")
	var text := r.page_text(0)
	check("Western European text round-trips", text.find("Café, Ærøskøbing, Straße, Ñandú, “quotes”, ‘single’ — dashes – and €5… ™ © ½ œ Ÿ") >= 0, text)
	check("characters outside Windows-1252 print as ?", text.find("??? and ????????") >= 0)
	check("and are counted for the warning", pdf._replaced == 11, str(pdf._replaced))
	var by_text := {}
	for t in r.pages[0].texts:
		by_text[t.text] = t
	check("headings are bold (F2)", int(by_text["Heading"].font) == 2)
	check("regular F1, bold F2, italic F3, bold italic F4", int(by_text["Café, Ærøskøbing, Straße, Ñandú, “quotes”, ‘single’ — dashes – and €5… ™ © ½ œ Ÿ"].font) == 1
		and int(by_text["Bold"].font) == 2 and int(by_text["Italic"].font) == 3 and int(by_text["Bold italic"].font) == 4)
	check("heading level 1 is 24 pt", is_equal_approx(float(by_text["Heading"].size), 24.0))
	check("Helvetica widths: W 944, accented i 278, bold ß 611", Metrics.width(87, false) == 944 and Metrics.width(0xED, false) == 278 and Metrics.width(0xDF, true) == 611)
	check("accented letters are as wide as their letter: Ç 722, Ö 778, é 556, bold ü 611", Metrics.width(0xC7, false) == 722
		and Metrics.width(0xD6, false) == 778 and Metrics.width(0xE9, false) == 556 and Metrics.width(0xFC, true) == 611)
	var esc := PdfDocument.new()
	esc.add_text("Brackets (like these) and a back\\slash")
	check("brackets and backslashes are escaped", _read(esc, "escape.pdf").pages[0].texts[0].text == "Brackets (like these) and a back\\slash")


func _layout() -> void:
	print("Layout")
	var pdf := PdfDocument.new()
	for i in 30:
		pdf.add_text("%d. %s %s" % [i, LOREM, LOREM], {"align": "justify"})
	pdf.add_text("Supercalifragilisticexpialidocious".repeat(6))
	var r := _read(pdf, "layout.pdf")
	var cw := pdf.content_width()
	var widest := 0.0
	var justified_ok := true
	var last_line_ok := true
	var lines := []
	for p in r.pages.size():
		lines.append_array(_body(r, p, pdf))
	for i in lines.size():
		var t: Dictionary = lines[i]
		widest = maxf(widest, _width(t))
		var next_starts_paragraph: bool = i + 1 >= lines.size() or str(lines[i + 1].text).substr(0, 3).strip_edges().trim_suffix(".").is_valid_int()
		if str(t.text).contains("fox") or str(t.text).contains("knight") or str(t.text).contains("bridge"):
			if float(t.tw) > 0.0 and absf(_width(t) - cw) > 0.05:
				justified_ok = false
			if next_starts_paragraph and float(t.tw) != 0.0:
				last_line_ok = false
	check("no line is wider than the page's content width", widest <= cw + 0.05, "%.2f > %.2f" % [widest, cw])
	check("justified lines fill the width exactly", justified_ok)
	check("the last line of a justified paragraph isn't stretched", last_line_ok)
	check("long text flows onto new pages", r.pages.size() >= 2, str(r.pages.size()))
	var top_ok := true
	for p in range(1, r.pages.size()):
		var first: Dictionary = _body(r, p, pdf)[0]
		var line_top: float = r.pages[p].size.y - float(first.y) - (float(first.size) * 1.3 - (Metrics.ASCENT + Metrics.DESCENT) * float(first.size)) * 0.5 - Metrics.ASCENT * float(first.size)
		if absf(line_top - pdf.margin_top) > 0.05:
			top_ok = false
	check("each new page starts at the top margin", top_ok)
	var all := r.all_text()
	check("a word wider than the line is broken between letters", all.find("Supercalifragilisticexpialidocious".repeat(6)) < 0 and all.find("Supercalifragilistic") >= 0)
	var breaks := PdfDocument.new()
	breaks.add_text("Line one\nLine two\n\nAfter a blank line")
	breaks.add_text("Tab\there")
	var br := _read(breaks, "breaks.pdf")
	var texts: Array = _body(br, 0, breaks).map(func(t): return t.text)
	check("newlines start new lines", texts.slice(0, 3) == ["Line one", "Line two", "After a blank line"], str(texts))
	check("a blank line takes a line's height", absf((float(br.pages[0].texts[1].y) - float(br.pages[0].texts[2].y)) - 11.0 * 1.3 * 2.0) < 0.01)
	check("tabs become spaces", texts.has("Tab    here"))

	var align := PdfDocument.new()
	align.add_text("Centered text", {"align": "center"})
	align.add_text("Right text", {"align": "right"})
	align.add_text("Indented text", {"indent": 36.0})
	var ar := _read(align, "align.pdf")
	var c: Dictionary = ar.pages[0].texts[0]
	var rt: Dictionary = ar.pages[0].texts[1]
	check("center alignment", absf(float(c.x) + _width(c) * 0.5 - 306.0) < 0.05)
	check("right alignment", absf(float(rt.x) + _width(rt) - (612.0 - 54.0)) < 0.05)
	check("indent", is_equal_approx(float(ar.pages[0].texts[2].x), 54.0 + 36.0))

	var keep := PdfDocument.new()
	keep.set_cursor_y(792.0 - 54.0 - 40.0)
	keep.add_heading("Kept with what follows")
	keep.add_text("Body")
	var kr := _read(keep, "keep.pdf")
	check("a heading near the bottom moves to the next page", kr.pages.size() == 2 and kr.page_text(1).find("Kept with what follows") >= 0 and kr.page_text(0).find("Kept") < 0)
	var space := PdfDocument.new()
	space.add_text("Top")
	space.add_space(2000.0)
	check("add_space past the bottom starts a new page", space.get_page_count() == 2 and is_equal_approx(space.get_cursor_y(), 54.0))


func _lists() -> void:
	print("Lists")
	var pdf := PdfDocument.new()
	pdf.add_list(["Short", LOREM])
	pdf.add_list(["One", "Two", "Three"], {"ordered": true})
	var r := _read(pdf, "lists.pdf")
	var texts: Array = r.pages[0].texts
	var bullets := texts.filter(func(t): return t.text == "•")
	check("bullets are •", bullets.size() == 2)
	var item_x := 54.0 + 18.0
	var hanging := texts.filter(func(t): return t.text != "•" and not str(t.text).ends_with(".") and float(t.x) > 60.0 and float(t.x) < 80.0)
	check("items and their wrapped lines hang at the list indent", hanging.size() >= 3 and hanging.all(func(t): return is_equal_approx(float(t.x), item_x)))
	check("bullets sit left of the items", float(bullets[0].x) < item_x)
	var numbers := texts.filter(func(t): return t.text in ["1.", "2.", "3."])
	check("numbered lists count 1., 2., 3.", numbers.size() == 3)
	check("markers share the baseline of their item", texts.any(func(t): return t.text == "One" and is_equal_approx(float(t.y), float(numbers[0].y))))


func _decorations() -> void:
	print("Header, footer and mark")
	var pdf := PdfDocument.new()
	pdf.title = "Quest log"
	pdf.header = "{title}"
	pdf.footer = "Page {page} of {pages}"
	for i in 3:
		pdf.add_text("Page %d" % (i + 1))
		if i < 2:
			pdf.add_page_break()
	var r := _read(pdf, "decorations.pdf")
	check("{page} and {pages} are filled in", r.page_text(1).find("Page 2 of 3") >= 0)
	check("{title} is filled in", r.page_text(0).find("Quest log") >= 0)
	var head: Dictionary = r.pages[0].texts.filter(func(t): return t.text == "Quest log")[0]
	var foot: Dictionary = r.pages[0].texts.filter(func(t): return t.text == "Page 1 of 3")[0]
	check("the header sits in the top margin", 792.0 - float(head.y) < 54.0)
	check("the footer sits in the bottom margin, centered", float(foot.y) < 54.0 and absf(float(foot.x) + _width(foot) * 0.5 - 306.0) < 0.05)
	var marks := 0
	var links := 0
	for p in r.pages:
		if (p.ops as PackedStringArray).has("q 12 0 0 12 %s 6 cm /Mark Do Q" % _num(612.0 - 54.0 - 15.0 - Metrics.measure(PdfDocument.MARK_TEXT.to_ascii_buffer(), 6.5, false))) \
				and p.texts.any(func(t): return t.text == "Made with PDF Writer Lite"):
			marks += 1
		var d := str(p.dict)
		var annot := str(r.objects[Reader.leading_int(d.substr(d.find("/Annots [") + 9))].dict) if d.find("/Annots [") >= 0 else ""
		if annot.find("/URI (https://debugalot.itch.io/pdf-writer)") >= 0:
			links += 1
	check("every page has the mark in its bottom-right corner", marks == 3, str(marks))
	check("every page's mark links to PDF Writer", links == 3, str(links))
	var mark_text: Dictionary = r.pages[0].texts.filter(func(t): return t.text == "Made with PDF Writer Lite")[0]
	check("the mark's text is 6.5 pt and muted", is_equal_approx(float(mark_text.size), 6.5) and mark_text.color.is_equal_approx(Color(0.42, 0.42, 0.45)))
	var image := -1
	for id in r.objects:
		if str(r.objects[id].dict).find("/ColorSpace /DeviceRGB") >= 0:
			image = id
	var dict := str(r.objects[image].dict) if image > 0 else ""
	var alpha := r._ref(dict, "/SMask")
	check("the mark is a 384 px image with an alpha mask", image > 0 and (r.objects[image].stream as PackedByteArray).size() == 384 * 384 * 3
		and alpha > 0 and (r.objects[alpha].stream as PackedByteArray).size() == 384 * 384)
	var big := 612.0 * PdfDocument.WATERMARK_SIZE
	var watermark := "q /Faint gs %s 0 0 %s %s %s cm /Mark Do Q" % [_num(big), _num(big), _num((612.0 - big) * 0.5), _num((792.0 - big) * 0.5)]
	check("every page has the large watermark, centered and drawn last (over everything)", r.pages.all(func(p): return (p.ops as PackedStringArray)[-1] == watermark))
	var faint := false
	for id in r.objects:
		if str(r.objects[id].dict).find("<< /Type /ExtGState /ca 0.1 /CA 0.1 >>") >= 0:
			faint = true
	check("the watermark is drawn at 10% opacity", faint and str(r.pages[0].dict).find("/ExtGState << /Faint ") >= 0)
	var cover := PdfDocument.new()
	cover.draw_rect(Rect2(0, 0, 612, 792), Color.WHITE)
	check("a full-page rectangle doesn't hide it", (_read(cover, "cover.pdf").pages[0].ops as PackedStringArray)[-1] == watermark)
	var left := PdfDocument.new()
	left.footer = "Page {page}"
	left.footer_align = "right"
	left.add_text("x")
	var lr := _read(left, "mark_left.pdf")
	check("the mark moves left when the footer is on the right", (lr.pages[0].ops as PackedStringArray).has("q 12 0 0 12 54 6 cm /Mark Do Q"))


func _drawing() -> void:
	print("Drawing")
	var pdf := PdfDocument.new()
	var size := pdf.draw_text(Vector2(100, 100), "Hello there", {"size": 20.0})
	check("draw_text returns the size measure_text gives", size.is_equal_approx(pdf.measure_text("Hello there", {"size": 20.0})))
	check("measure_text: width from the font's metrics, height = size × line spacing", is_equal_approx(size.x, Metrics.measure("Hello there".to_ascii_buffer(), 20.0, false)) and is_equal_approx(size.y, 26.0))
	var wrapped := pdf.draw_text(Vector2(100, 200), LOREM, {"width": 150.0})
	check("draw_text wraps to a width and returns that width", is_equal_approx(wrapped.x, 150.0) and wrapped.y > 26.0)
	pdf.draw_text(Vector2(100, 300), LOREM, {"width": 150.0, "ellipsis": true})
	pdf.draw_line(Vector2(10, 10), Vector2(200, 10), Color(1, 0, 0), 2.0)
	pdf.draw_rect(Rect2(10, 20, 50, 30), Color(0, 0, 1))
	pdf.draw_rect(Rect2(10, 60, 50, 30), Color.TRANSPARENT, Color(0, 1, 0), 3.0)
	pdf.draw_rect(Rect2(10, 100, 50, 30), Color(1, 1, 0), Color.BLACK, 1.0)
	pdf.draw_rect(Rect2(10, 140, 50, 30), Color.TRANSPARENT, Color.TRANSPARENT)
	pdf.new_page()
	pdf.set_page(0)
	pdf.draw_text(Vector2(300, 700), "Back on page one")
	var r := _read(pdf, "drawing.pdf")
	var ops: PackedStringArray = r.pages[0].ops
	var cut: Array = r.pages[0].texts.filter(func(t): return str(t.text).ends_with("…"))
	check("ellipsis cuts one line short with …", cut.size() == 1 and _width(cut[0]) <= 150.0)
	check("draw_line", ops.has("q 1 0 0 RG 2 w 10 782 m 200 782 l S Q"))
	check("draw_rect fills (y flipped to PDF space)", ops.has("q 0 0 1 rg 10 742 50 30 re f Q"))
	check("draw_rect outlines", ops.has("q 0 1 0 RG 3 w 10 702 50 30 re S Q"))
	check("draw_rect fills and outlines", ops.has("q 1 1 0 rg 0 0 0 RG 1 w 10 662 50 30 re B Q"))
	check("transparent fill and stroke draw nothing", not Array(ops).any(func(o): return str(o).contains(" 50 30 re") and str(o).contains("622")))
	check("set_page draws on an earlier page", r.page_text(0).find("Back on page one") >= 0 and r.page_text(1).find("Back on page one") < 0)


func _document() -> void:
	print("Document")
	var empty := Reader.new(PdfDocument.new().to_bytes())
	check("an empty document is one blank page", empty.errors.is_empty() and empty.pages.size() == 1)
	var pdf := PdfDocument.new()
	pdf.title = "Run report"
	pdf.author = "Sir Debugalot"
	pdf.add_text("x")
	var r := Reader.new(pdf.to_bytes())
	var info := str(r.objects[r._ref(r.trailer, "/Info")].dict)
	check("title, author and producer in the document information", info.find("/Title (Run report)") >= 0 and info.find("/Author (Sir Debugalot)") >= 0 and info.find("/Producer (PDF Writer Lite for Godot %s)" % PdfDocument.VERSION) >= 0)
	pdf.title = "Café 日本"
	r = Reader.new(pdf.to_bytes())
	check("a non-ASCII title is stored as UTF-16", str(r.objects[r._ref(r.trailer, "/Info")].dict).find("/Title <FEFF00430061006600E9002065E5672C>") >= 0)
	var a := _without_date(pdf.to_bytes())
	var b := _without_date(pdf.to_bytes())
	check("writing twice gives the same file", a == b)
	check("save() writes the file", pdf.save(OUT + "saved.pdf") == OK and _without_date(FileAccess.get_file_as_bytes(OUT + "saved.pdf")) == a)
	PdfDocument._told.erase("font")
	PdfDocument._told.erase("bbcode")
	var paid := PdfDocument.new()
	paid.add_text("x", {"font": SystemFont.new()})
	paid.draw_text(Vector2(10, 10), "[b]x[/b]", {"bbcode": true})
	check("full-version style keys warn once (font, bbcode)", PdfDocument._told.has("font") and PdfDocument._told.has("bbcode"))
	pdf.add_text("日本")
	pdf.to_bytes()
	check("outside-Latin characters warn once", PdfDocument._told.has("latin"))
	for paper in [PdfDocument.LETTER, PdfDocument.A4]:
		var report := RunReport.build(RunReport.sample(), paper)
		var rr := _read(report, "run_report_%s.pdf" % ("a4" if paper == PdfDocument.A4 else "letter"))
		var inside := true
		for t in rr.pages[0].texts:
			if float(t.x) + _width(t) > paper.x - report.margin_right + 0.05:
				inside = false
		check("the demo's run report (%s): all Latin, nothing past the right margin" % ("A4" if paper == PdfDocument.A4 else "Letter"),
			rr.errors.is_empty() and report._replaced == 0 and rr.all_text().find("crème brûlée") >= 0 and inside)


func _speed() -> void:
	print("Speed")
	var started := Time.get_ticks_usec()
	var pdf := PdfDocument.new()
	pdf.footer = "Page {page} of {pages}"
	for i in 300:
		if i % 25 == 0:
			pdf.add_heading("Section %d" % (i / 25 + 1), 2)
		pdf.add_text("%d. %s" % [i, LOREM], {"align": "justify" if i % 2 else "left"})
	var bytes := pdf.to_bytes()
	var ms := (Time.get_ticks_usec() - started) / 1000.0
	var r := Reader.new(bytes)
	check("300 paragraphs (%d pages) in %.0f ms, under 1.5 s" % [r.pages.size(), ms], ms < 1500.0 and r.errors.is_empty())


func _without_date(bytes: PackedByteArray) -> String:
	var s := Reader._latin1(bytes)
	var at := s.find("/CreationDate (D:")
	return s.substr(0, at) + s.substr(s.find(")", at)) if at >= 0 else s


func _num(v: float) -> String:
	return PdfDocument._num(v)
