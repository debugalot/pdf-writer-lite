@tool
@icon("res://addons/pdf_writer/icon.svg")
class_name PdfDocument
extends RefCounted
## Writes PDF files from GDScript: PDF Writer Lite, the free edition of PDF Writer for Godot.
##
## Content flows down the page and onto new pages by itself: headings, paragraphs and lists. You can
## also draw text, lines and rectangles anywhere on a page. Coordinates are in points (1/72 inch)
## from the top-left corner of the page, like Godot's 2D. Text uses the PDF's built-in Helvetica, so
## it prints Latin text (English and the Western European languages, Windows-1252); other characters
## print as "?". Every page carries the PDF Writer Lite watermark: a large, faint knight across the
## page and "Made with PDF Writer Lite" in its bottom margin. The license doesn't allow removing it.
##
## PDF Writer (https://debugalot.itch.io/pdf-writer) has this same API and adds any language, any
## font, tables, BBCode, images, links and bookmarks, with no watermark. Code written for Lite runs
## on it unchanged.
##
## [codeblock]
## var pdf := PdfDocument.new()
## pdf.title = "Run report"
## pdf.footer = "Page {page} of {pages}"
## pdf.add_heading("Run 42")
## pdf.add_text("Finished in 12:31 with 3 deaths.")
## pdf.add_list(["Floor 1: 1:02", "Floor 2: 3:40"])
## pdf.save("user://run_42.pdf")
## [/codeblock]

const VERSION := "1.0.0"

const Metrics := preload("pdf_metrics.gd")
const Watermark := preload("pdf_watermark.gd")

## Page sizes in points.
const LETTER := Vector2(612.0, 792.0)
const LEGAL := Vector2(612.0, 1008.0)
const A3 := Vector2(841.89, 1190.55)
const A4 := Vector2(595.28, 841.89)
const A5 := Vector2(419.53, 595.28)

## Defaults for every look the document uses. Change entries on [member theme] (sizes in points).
const DEFAULT_THEME := {
	"text_size": 11.0,
	"text_color": Color(0.13, 0.13, 0.14),
	"muted_color": Color(0.42, 0.42, 0.45),
	"heading_sizes": [24.0, 18.0, 14.0, 12.0],
	"heading_color": Color(0.07, 0.07, 0.08),
	"line_spacing": 1.3,
	"paragraph_spacing": 8.0,
	"list_indent": 18.0,
	"rule_color": Color(0.8, 0.8, 0.82),
	"header_footer_size": 8.5,
}

const FULL_VERSION_URL := "https://debugalot.itch.io/pdf-writer"
const MARK_TEXT := "Made with PDF Writer Lite"
const MARK_ICON := 12.0                  # points
const MARK_TEXT_SIZE := 6.5
const MARK_FROM_BOTTOM := 6.0
const WATERMARK_SIZE := 0.62             # of the page's shorter side
const WATERMARK_OPACITY := 0.1
const FONTS := ["Helvetica", "Helvetica-Bold", "Helvetica-Oblique", "Helvetica-BoldOblique"]

## Document information, shown in a viewer's document properties.
var title := ""
var author := ""
var subject := ""
var keywords := ""
var creator := "Godot Engine"

## The page size in points (see [constant LETTER], [constant A4]...). Pages already started keep theirs.
var page_size := LETTER
var margin_left := 54.0
var margin_top := 54.0
var margin_right := 54.0
var margin_bottom := 54.0

## Text at the top and bottom of every page. {page}, {pages}, {title} and {date} are filled in.
## Example: [code]footer = "Page {page} of {pages}"[/code].
var header := ""
var footer := ""
## "left", "center" or "right".
var header_align := "left"
var footer_align := "center"

## Deflate the page contents (smaller files). Off is only useful to read the raw PDF.
var compress := true
## Look of the flowing content; see [constant DEFAULT_THEME] for the entries.
var theme := DEFAULT_THEME.duplicate(true)

var _pages: Array = []               # [{size: Vector2, ops: Array[String]}]
var _page := -1                      # the page drawing goes to
var _y := 0.0                        # where flowing content continues on the last page (from the top)
var _replaced := 0                   # characters printed as "?"
static var _told := {}               # warnings already given this session


func _init(size: Vector2 = LETTER, margin := 54.0) -> void:
	page_size = size
	margin_left = margin
	margin_top = margin
	margin_right = margin
	margin_bottom = margin


# ------------------------------------------------------------------------------------- flowing content

## Starts a new page and continues the flowing content at its top. Returns its index (from 0).
func new_page(size: Vector2 = Vector2.ZERO) -> int:
	_pages.append({"size": size if size != Vector2.ZERO else page_size, "ops": []})
	_page = _pages.size() - 1
	_y = margin_top
	return _page


## A heading, level 1 (largest) to 4, kept on the same page as the start of what follows it.
## Style keys as add_text().
func add_heading(text: String, level := 1, style := {}) -> void:
	var sizes: Array = theme.heading_sizes
	var size := float(style.get("size", sizes[clampi(level, 1, sizes.size()) - 1]))
	var st := _style(style, {"bold": true, "size": size, "color": theme.heading_color})
	var laid := _lay(text, st, content_width(), str(st.get("align", "left")))
	_start_flow()
	if _y > margin_top + 0.5:
		_y += size * 0.7
	_ensure(float(laid.height) + float(theme.text_size) * float(theme.line_spacing) * 2.0)
	_flow(laid, margin_left)
	_y += size * 0.35


## A paragraph of text. Style keys: size, color, bold, italic, align ("left", "center", "right",
## "justify"), line_spacing (times the size), indent (points), space_after (points).
func add_text(text: String, style := {}) -> void:
	var st := _style(style)
	var indent := float(st.get("indent", 0.0))
	var laid := _lay(text, st, content_width() - indent, str(st.get("align", "left")))
	_start_flow()
	_flow(laid, margin_left + indent)
	_y += float(st.get("space_after", theme.paragraph_spacing))


## A bulleted list, or a numbered one with style [code]{"ordered": true}[/code]. Takes the same style
## keys as add_text().
func add_list(items: Array, style := {}) -> void:
	var st := _style(style)
	var indent := float(st.get("indent", 0.0)) + float(theme.list_indent)
	var ordered := bool(st.get("ordered", false))
	_start_flow()
	for i in items.size():
		var laid := _lay(str(items[i]), st, content_width() - indent, str(st.get("align", "left")))
		var marker := _lay("%d." % (i + 1) if ordered else "•", st, 0.0, "left")
		_ensure(float(laid.line_height))
		_put(marker, 0, margin_left + indent - float(marker.width) - 6.0, _y)
		_flow(laid, margin_left + indent)
		_y += float(st.get("item_spacing", 2.0))
	_y += float(st.get("space_after", theme.paragraph_spacing))


## A horizontal line across the page. Style keys: color, width (thickness), space (above and below).
func add_rule(style := {}) -> void:
	_start_flow()
	var space := float(style.get("space", 8.0))
	_ensure(space * 2.0)
	_y += space
	draw_line(Vector2(margin_left, _y), Vector2(_page_w() - margin_right, _y), style.get("color", theme.rule_color), float(style.get("width", 0.75)))
	_y += space


## Empty space, in points.
func add_space(points: float) -> void:
	_start_flow()
	_y += points
	if _y > _bottom():
		new_page()


func add_page_break() -> void:
	new_page()


# ------------------------------------------------------------------------------------- drawing

## Draws on another page (from 0); drawing goes to the last page otherwise.
func set_page(index: int) -> void:
	_page = clampi(index, 0, _pages.size() - 1)


func get_page_count() -> int:
	return _pages.size()


## The page drawing goes to, from 0.
func get_page() -> int:
	return _page


## Where flowing content continues: the y on the last page, in points from its top.
func get_cursor_y() -> float:
	return _y


## Moves where flowing content continues on the last page (to leave room, or to go back up).
func set_cursor_y(y: float) -> void:
	_start_flow()
	_y = y


## The width between the left and right margins.
func content_width() -> float:
	return _page_w() - margin_left - margin_right


## Text at `position` (the top-left of its first line). Style keys as add_text(), plus width (wrap
## to this width; alignment works within it) and ellipsis (bool: with a width, one line cut short
## with "…" instead of wrapping). Returns the size it took.
func draw_text(position: Vector2, text: String, style := {}) -> Vector2:
	var st := _style(style)
	var width := float(st.get("width", 0.0))
	if bool(st.get("ellipsis", false)) and width > 0.0:
		text = _shorten(text, st, width)
	var laid := _lay(text, st, width, str(st.get("align", "left")))
	for i in (laid.lines as Array).size():
		_put(laid, i, position.x, position.y + i * float(laid.line_height))
	return Vector2(float(laid.width) if width <= 0.0 else width, float(laid.height))


## How big text would be: the same arguments as draw_text().
func measure_text(text: String, style := {}) -> Vector2:
	var st := _style(style)
	var laid := _lay(text, st, float(st.get("width", 0.0)), "left")
	return Vector2(float(laid.width), float(laid.height))


func draw_line(from: Vector2, to: Vector2, color := Color.BLACK, width := 1.0) -> void:
	if color.a <= 0.0 or width <= 0.0:
		return
	_op("q %s RG %s w %s m %s l S Q" % [_rgb(color), _num(width), _xy(from), _xy(to)])


## A rectangle, filled and/or outlined (a transparent color skips that part).
func draw_rect(rect: Rect2, fill := Color.BLACK, stroke := Color.TRANSPARENT, width := 1.0) -> void:
	var has_fill := fill.a > 0.0
	var has_stroke := stroke.a > 0.0 and width > 0.0
	if not has_fill and not has_stroke:
		return
	var ops := "q "
	if has_fill:
		ops += _rgb(fill) + " rg "
	if has_stroke:
		ops += "%s RG %s w " % [_rgb(stroke), _num(width)]
	ops += "%s %s %s %s re " % [_num(rect.position.x), _num(_py(rect.end.y)), _num(rect.size.x), _num(rect.size.y)]
	_op(ops + ("B" if has_fill and has_stroke else ("f" if has_fill else "S")) + " Q")


# ------------------------------------------------------------------------------------- output

## The finished PDF file.
func to_bytes() -> PackedByteArray:
	if _pages.is_empty():
		new_page()
	var count := _pages.size()
	var objects: Array[PackedByteArray] = []
	var add := func(body: Variant) -> int:
		objects.append(body if body is PackedByteArray else str(body).to_utf8_buffer())
		return objects.size()
	var reserve := func() -> int:
		objects.append(PackedByteArray())
		return objects.size()

	var catalog: int = reserve.call()
	var pages_id: int = reserve.call()
	var font_refs := PackedStringArray()
	for i in FONTS.size():
		font_refs.append("/F%d %d 0 R" % [i + 1, add.call("<< /Type /Font /Subtype /Type1 /BaseFont /%s /Encoding /WinAnsiEncoding >>" % FONTS[i])])
	var alpha: int = add.call(_stream("/Type /XObject /Subtype /Image /Width %d /Height %d /ColorSpace /DeviceGray /BitsPerComponent 8 /Filter /FlateDecode" % [Watermark.SIZE, Watermark.SIZE], Marshalls.base64_to_raw(Watermark.ALPHA)))
	var mark: int = add.call(_stream("/Type /XObject /Subtype /Image /Width %d /Height %d /ColorSpace /DeviceRGB /BitsPerComponent 8 /SMask %d 0 R /Filter /FlateDecode" % [Watermark.SIZE, Watermark.SIZE, alpha], Marshalls.base64_to_raw(Watermark.RGB)))
	var faint: int = add.call("<< /Type /ExtGState /ca %s /CA %s >>" % [_num(WATERMARK_OPACITY), _num(WATERMARK_OPACITY)])
	var resources := "/ProcSet [/PDF /Text /ImageC] /Font << %s >> /XObject << /Mark %d 0 R >> /ExtGState << /Faint %d 0 R >>" % [" ".join(font_refs), mark, faint]

	var kids := PackedStringArray()
	var keep_page := _page
	for i in count:
		_page = i
		var size: Vector2 = _pages[i].size
		var ops: Array = (_pages[i].ops as Array).duplicate()
		var link := _decorate(ops, i + 1, count)
		var data := "\n".join(PackedStringArray(ops)).to_ascii_buffer()
		var content: int = add.call(_stream("/Filter /FlateDecode" if compress else "", data.compress(FileAccess.COMPRESSION_DEFLATE) if compress else data))
		var annot: int = add.call("<< /Type /Annot /Subtype /Link /Rect [%s %s %s %s] /Border [0 0 0] /A << /S /URI /URI (%s) >> >>" % [
			_num(link.position.x), _num(size.y - link.end.y), _num(link.end.x), _num(size.y - link.position.y), FULL_VERSION_URL])
		kids.append("%d 0 R" % add.call("<< /Type /Page /Parent %d 0 R /MediaBox [0 0 %s %s] /Resources << %s >> /Contents %d 0 R /Annots [%d 0 R] >>" % [
			pages_id, _num(size.x), _num(size.y), resources, content, annot]))
	_page = keep_page
	objects[pages_id - 1] = ("<< /Type /Pages /Kids [%s] /Count %d >>" % [" ".join(kids), count]).to_utf8_buffer()
	objects[catalog - 1] = ("<< /Type /Catalog /Pages %d 0 R >>" % pages_id).to_utf8_buffer()
	var stamp := Time.get_datetime_string_from_system(true).replace("-", "").replace(":", "").replace("T", "")
	var info := PackedStringArray(["/Producer (PDF Writer Lite for Godot %s)" % VERSION, "/CreationDate (D:%sZ)" % stamp])
	for pair in [["Title", title], ["Author", author], ["Subject", subject], ["Keywords", keywords], ["Creator", creator]]:
		if str(pair[1]) != "":
			info.append("/%s %s" % [pair[0], _text_string(str(pair[1]))])
	var info_id: int = add.call("<< %s >>" % " ".join(info))

	if _replaced > 0:
		_tell("latin", "PDF Writer Lite: %d characters outside Latin (Windows-1252) were printed as \"?\". PDF Writer prints any language in any font: %s" % [_replaced, FULL_VERSION_URL])

	var out := "%PDF-1.4\n%".to_ascii_buffer()
	out.append_array(PackedByteArray([0xE2, 0xE3, 0xCF, 0xD3, 0x0A]))   # marks the file as binary
	var offsets := PackedInt64Array()
	for i in objects.size():
		offsets.append(out.size())
		out.append_array(("%d 0 obj\n" % (i + 1)).to_ascii_buffer())
		out.append_array(objects[i])
		out.append_array("\nendobj\n".to_ascii_buffer())
	var xref := out.size()
	var table := PackedStringArray(["xref", "0 %d" % (objects.size() + 1), "0000000000 65535 f "])
	for at in offsets:
		table.append("%010d 00000 n " % at)
	out.append_array(("\n".join(table) + "\ntrailer\n<< /Size %d /Root %d 0 R /Info %d 0 R >>\nstartxref\n%d\n" % [objects.size() + 1, catalog, info_id, xref]).to_ascii_buffer())
	out.append_array("%%EOF\n".to_ascii_buffer())
	return out


## Writes the PDF to `path` (user://, res:// in the editor, or an absolute path).
func save(path: String) -> Error:
	var bytes := to_bytes()
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_buffer(bytes)
	f.close()
	return OK


## In a web export, hands the PDF to the browser as a download. Elsewhere, saves it to user://
## and opens it in the system's PDF viewer. Returns the error, if any.
func download(file_name := "document.pdf") -> Error:
	if OS.has_feature("web"):
		JavaScriptBridge.download_buffer(to_bytes(), file_name, "application/pdf")
		return OK
	var path := "user://" + file_name.get_file()
	var err := save(path)
	if err == OK:
		OS.shell_open(ProjectSettings.globalize_path(path))
	return err


# ------------------------------------------------------------------------------------- internals

func _page_w() -> float:
	return page_size.x if _pages.is_empty() else (_pages[-1].size as Vector2).x


func _bottom() -> float:
	return (page_size.y if _pages.is_empty() else (_pages[-1].size as Vector2).y) - margin_bottom


func _start_flow() -> void:
	if _pages.is_empty():
		new_page()
	_page = _pages.size() - 1


func _ensure(height: float) -> void:
	_start_flow()
	if _y + height > _bottom() and _y > margin_top + 0.5:
		new_page()


func _target_page() -> Dictionary:
	if _pages.is_empty():
		new_page()
	return _pages[clampi(_page, 0, _pages.size() - 1)]


func _op(op: String) -> void:
	(_target_page().ops as Array).append(op)


## y from the top of the page → PDF y (from the bottom).
func _py(y: float) -> float:
	return (_target_page().size as Vector2).y - y


func _xy(p: Vector2) -> String:
	return "%s %s" % [_num(p.x), _num(_py(p.y))]


## The full style: theme defaults, then `extra`, then what the caller passed.
func _style(style: Dictionary, extra := {}) -> Dictionary:
	var st := {"size": float(theme.text_size), "color": theme.text_color, "bold": false, "italic": false,
		"line_spacing": float(theme.line_spacing)}
	st.merge(extra, true)
	st.merge(style, true)
	if style.has("font"):
		_tell("font", "PDF Writer Lite prints in the built-in Helvetica, so the \"font\" style key is ignored. PDF Writer takes any font: %s" % FULL_VERSION_URL)
	if bool(style.get("bbcode", false)):
		_tell("bbcode", "PDF Writer Lite prints BBCode as plain text. PDF Writer formats it: %s" % FULL_VERSION_URL)
	return st


## Lays out text in lines no wider than `width` (0 = no wrapping). Returns {lines: [{codes, width,
## x, tw}], width, height, line_height, baseline, size, font, color}. tw is the extra width per
## space that justifies a line.
func _lay(text: String, st: Dictionary, width: float, align: String) -> Dictionary:
	var size := float(st.size)
	var bold := bool(st.bold)
	var space := Metrics.width(32, bold) * size / 1000.0
	var lines := []
	for para in text.replace("\r", "").replace("\t", "    ").split("\n"):
		var cur := PackedByteArray()
		var cur_w := 0.0
		var spaces := 0
		var started := false
		for word in para.split(" "):
			var codes := _encode(word)
			var w := Metrics.measure(codes, size, bold)
			if width > 0.0 and started and cur_w + space + w > width + 0.01:
				lines.append({"codes": cur, "width": cur_w, "spaces": spaces, "wrapped": true})
				cur = PackedByteArray()
				cur_w = 0.0
				spaces = 0
				started = false
			if width > 0.0 and w > width + 0.01:
				# A word wider than the line: break it between letters.
				if started:
					lines.append({"codes": cur, "width": cur_w, "spaces": spaces, "wrapped": true})
				cur = PackedByteArray()
				cur_w = 0.0
				spaces = 0
				for c in codes:
					var cw := Metrics.width(c, bold) * size / 1000.0
					if cur_w + cw > width + 0.01 and not cur.is_empty():
						lines.append({"codes": cur, "width": cur_w, "spaces": 0, "wrapped": true})
						cur = PackedByteArray()
						cur_w = 0.0
					cur.append(c)
					cur_w += cw
				started = true
				continue
			if started:
				cur.append(32)
				cur_w += space
				spaces += 1
			cur.append_array(codes)
			cur_w += w
			started = true
		lines.append({"codes": cur, "width": cur_w, "spaces": spaces, "wrapped": false})
	var widest := 0.0
	for line: Dictionary in lines:
		widest = maxf(widest, float(line.width))
	var box := width if width > 0.0 else widest
	for line: Dictionary in lines:
		line.x = 0.0
		line.tw = 0.0
		match align:
			"center":
				line.x = (box - float(line.width)) * 0.5
			"right", "end":
				line.x = box - float(line.width)
			"justify", "fill":
				if bool(line.wrapped) and int(line.spaces) > 0:
					line.tw = (box - float(line.width)) / int(line.spaces)
	var line_height := size * float(st.get("line_spacing", theme.line_spacing))
	return {"lines": lines, "width": widest, "height": line_height * lines.size(), "line_height": line_height,
		"baseline": (line_height - (Metrics.ASCENT + Metrics.DESCENT) * size) * 0.5 + Metrics.ASCENT * size,
		"size": size, "font": 1 + (1 if bold else 0) + (2 if bool(st.italic) else 0), "color": st.color}


## Places laid-out lines down the flow, breaking pages between lines.
func _flow(laid: Dictionary, x: float) -> void:
	for i in (laid.lines as Array).size():
		_ensure(float(laid.line_height))
		_put(laid, i, x, _y)
		_y += float(laid.line_height)


## Line `index` of laid-out text with its top-left at (x, y).
func _put(laid: Dictionary, index: int, x: float, y: float, to: Array = [], page_h := 0.0) -> void:
	var line: Dictionary = laid.lines[index]
	if (line.codes as PackedByteArray).is_empty():
		return
	var op := "BT /F%d %s Tf %s rg %s %s Td %s Tw (%s) Tj ET" % [int(laid.font), _num(float(laid.size)), _rgb(laid.color),
		_num(x + float(line.x)), _num((page_h if page_h > 0.0 else _py(0.0)) - y - float(laid.baseline)), _num(float(line.tw)), _escape(line.codes)]
	if page_h > 0.0:
		to.append(op)
	else:
		_op(op)


## `text` cut short with "…" so it fits on one line `width` wide (unchanged if it already fits).
func _shorten(text: String, st: Dictionary, width: float) -> String:
	var one := text.replace("\n", " ")
	var bold := bool(st.bold)
	var size := float(st.size)
	if Metrics.measure(_encode(one, false), size, bold) <= width:
		return one
	var lo := 0
	var hi := one.length()
	while lo < hi:
		var mid := (lo + hi + 1) / 2
		if Metrics.measure(_encode(one.left(mid).strip_edges() + "…", false), size, bold) <= width:
			lo = mid
		else:
			hi = mid - 1
	return one.left(lo).strip_edges() + "…"


## The header, footer and mark of page `number`, added to `ops`. Returns the mark's rectangle (for
## its link), in points from the top-left.
func _decorate(ops: Array, number: int, count: int) -> Rect2:
	var size: Vector2 = _pages[number - 1].size
	var st := _style({}, {"size": float(theme.header_footer_size), "color": theme.muted_color})
	var date := Time.get_date_string_from_system()
	var w := size.x - margin_left - margin_right
	for which in [["header", header, header_align], ["footer", footer, footer_align]]:
		var text := str(which[1])
		if text == "":
			continue
		text = text.replace("{page}", str(number)).replace("{pages}", str(count)).replace("{title}", title).replace("{date}", date)
		var laid := _lay(text, st, w, str(which[2]))
		var y := margin_top * 0.5 - float(laid.height) * 0.5 if which[0] == "header" else size.y - margin_bottom * 0.5 - float(laid.height) * 0.5
		for i in (laid.lines as Array).size():
			_put(laid, i, margin_left, y + i * float(laid.line_height), ops, size.y)
	# The mark: the knight and "Made with PDF Writer Lite", on the side the footer isn't.
	var mst := _style({}, {"size": MARK_TEXT_SIZE, "color": theme.muted_color})
	var label := _lay(MARK_TEXT, mst, 0.0, "left")
	var total := MARK_ICON + 3.0 + float(label.width)
	var x := margin_left if footer_align == "right" else size.x - margin_right - total
	var top := size.y - MARK_FROM_BOTTOM - MARK_ICON
	ops.append("q %s 0 0 %s %s %s cm /Mark Do Q" % [_num(MARK_ICON), _num(MARK_ICON), _num(x), _num(MARK_FROM_BOTTOM)])
	_put(label, 0, x + MARK_ICON + 3.0, top + (MARK_ICON - float(label.line_height)) * 0.5, ops, size.y)
	# The watermark: the knight, large and faint across the middle of the page, over the content so
	# nothing drawn on the page can cover it. PDF Writer (the full version) has none.
	var big := minf(size.x, size.y) * WATERMARK_SIZE
	ops.append("q /Faint gs %s 0 0 %s %s %s cm /Mark Do Q" % [_num(big), _num(big), _num((size.x - big) * 0.5), _num((size.y - big) * 0.5)])
	return Rect2(x, top, total, MARK_ICON)


## Unicode text as WinAnsi bytes. Characters the built-in fonts can't show become "?" (counted,
## so the document can say so once).
func _encode(text: String, count := true) -> PackedByteArray:
	var out := PackedByteArray()
	for i in text.length():
		var cp := text.unicode_at(i)
		if cp < 32:
			continue
		var c := Metrics.code(cp)
		if c < 0:
			c = 63
			if count:
				_replaced += 1
		out.append(c)
	return out


func _stream(dict: String, data: PackedByteArray) -> PackedByteArray:
	var out := ("<< %s/Length %d >>\nstream\n" % [dict + " " if dict != "" else "", data.size()]).to_ascii_buffer()
	out.append_array(data)
	out.append_array("\nendstream".to_ascii_buffer())
	return out


## WinAnsi bytes as the inside of a PDF literal string.
static func _escape(codes: PackedByteArray) -> String:
	var parts := PackedStringArray()
	for c in codes:
		if c == 40 or c == 41 or c == 92:
			parts.append("\\" + char(c))
		elif c < 32 or c > 126:
			parts.append("\\%03o" % c)
		else:
			parts.append(char(c))
	return "".join(parts)


## A string for the document information: plain if it's printable ASCII, otherwise UTF-16.
static func _text_string(text: String) -> String:
	var plain := true
	for i in text.length():
		var c := text.unicode_at(i)
		if c < 32 or c > 126:
			plain = false
			break
	if plain:
		return "(%s)" % text.replace("\\", "\\\\").replace("(", "\\(").replace(")", "\\)")
	var hex := "FEFF"
	var le := text.to_utf16_buffer()
	for i in range(0, le.size() - 1, 2):
		hex += "%02X%02X" % [le[i + 1], le[i]]
	return "<%s>" % hex


static func _num(v: float) -> String:
	var s := ("%.3f" % v).rstrip("0").rstrip(".")
	return "0" if s == "-0" or s == "" else s


static func _rgb(c: Color) -> String:
	return "%s %s %s" % [_num(c.r), _num(c.g), _num(c.b)]


static func _tell(key: String, message: String) -> void:
	if not _told.has(key):
		_told[key] = true
		push_warning(message)
