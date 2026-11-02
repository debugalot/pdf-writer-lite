## A small PDF reader for the tests: checks the file structure and reads back each page's text
## operations. It reads the files PDF Writer Lite writes, not PDFs in general.

const Metrics := preload("res://addons/pdf_writer/pdf_metrics.gd")

var errors := PackedStringArray()
var objects := {}                        # id → {dict: String, stream: PackedByteArray (decoded)}
var raw_streams := {}                    # id → the stream as stored
var pages := []                          # [{id, size: Vector2, ops: PackedStringArray, texts: [...], dict}]
var trailer := ""

var _text_re := RegEx.create_from_string("^BT /F(\\d) (\\S+) Tf (\\S+) (\\S+) (\\S+) rg (\\S+) (\\S+) Td (\\S+) Tw \\((.*)\\) Tj ET$")
var _unicode := {}                       # WinAnsi byte → Unicode code point


func _init(bytes: PackedByteArray) -> void:
	for cp in Metrics.WINANSI_EXTRA:
		_unicode[Metrics.WINANSI_EXTRA[cp]] = cp
	var text := _latin1(bytes)
	if not text.begins_with("%PDF-1.4\n"):
		errors.append("no %PDF-1.4 header")
	if not text.ends_with("%%EOF\n"):
		errors.append("no %%EOF at the end")
	var sx := text.rfind("startxref\n")
	var xref_at := text.substr(sx + 10, text.find("\n", sx + 10) - sx - 10).to_int()
	if text.substr(xref_at, 5) != "xref\n":
		errors.append("startxref doesn't point at the xref table")
		return
	var lines := text.substr(xref_at).split("\n")
	var count := lines[1].split(" ")[1].to_int()
	for i in range(1, count):
		var entry := lines[2 + i]
		if entry.length() != 19:                     # 20 bytes with the "\n"
			errors.append("xref entry %d is %d bytes" % [i, entry.length() + 1])
		var at := entry.substr(0, 10).to_int()
		var head := "%d 0 obj\n" % i
		if text.substr(at, head.length()) != head:
			errors.append("xref offset of object %d points elsewhere" % i)
			continue
		_read_object(i, bytes, text, at + head.length())
	trailer = text.substr(text.find("trailer", xref_at))
	if trailer.find("/Size %d " % count) < 0:
		errors.append("trailer /Size isn't %d" % count)
	var root := _ref(trailer, "/Root")
	var pages_id := _ref(str(objects.get(root, {}).get("dict", "")), "/Pages")
	var kids_dict := str(objects.get(pages_id, {}).get("dict", ""))
	var kids := kids_dict.substr(kids_dict.find("/Kids [") + 7)
	kids = kids.substr(0, kids.find("]"))
	for ref in kids.split(" 0 R", false):
		var id := leading_int(ref.strip_edges())
		if id == 0:
			continue
		var d := str(objects[id].dict)
		var box := d.substr(d.find("/MediaBox [") + 11)
		var nums := box.substr(0, box.find("]")).split(" ")
		var content: PackedByteArray = objects[_ref(d, "/Contents")].stream
		var ops := _latin1(content).split("\n")
		var texts := []
		for op in ops:
			var m := _text_re.search(op)
			if m:
				texts.append({"font": m.get_string(1).to_int(), "size": m.get_string(2).to_float(),
					"color": Color(m.get_string(3).to_float(), m.get_string(4).to_float(), m.get_string(5).to_float()),
					"x": m.get_string(6).to_float(), "y": m.get_string(7).to_float(), "tw": m.get_string(8).to_float(),
					"codes": _unescape(m.get_string(9))})
				texts[-1].text = _to_unicode(texts[-1].codes)
		pages.append({"id": id, "size": Vector2(nums[2].to_float(), nums[3].to_float()), "ops": ops, "texts": texts, "dict": d})


## All text of page `index`, one line per text operation.
func page_text(index: int) -> String:
	var out := PackedStringArray()
	for t in pages[index].texts:
		out.append(t.text)
	return "\n".join(out)


func all_text() -> String:
	var out := PackedStringArray()
	for i in pages.size():
		out.append(page_text(i))
	return "\n".join(out)


func _read_object(id: int, bytes: PackedByteArray, text: String, at: int) -> void:
	var end := text.find("\nendobj\n", at)
	var body := text.substr(at, end - at)
	var s := body.find(">>\nstream\n")
	if s < 0:
		objects[id] = {"dict": body, "stream": PackedByteArray()}
		return
	var dict := body.substr(0, s + 2)
	var length := leading_int(dict.substr(dict.find("/Length ") + 8))
	var data := bytes.slice(at + s + 10, at + s + 10 + length)
	if text.substr(at + s + 10 + length, 10) != "\nendstream":
		errors.append("stream length of object %d is wrong" % id)
	raw_streams[id] = data
	if dict.find("/FlateDecode") >= 0:
		data = data.decompress_dynamic(-1, FileAccess.COMPRESSION_DEFLATE)
	objects[id] = {"dict": dict, "stream": data}


func _ref(dict: String, key: String) -> int:
	var at := dict.find(key + " ")
	return leading_int(dict.substr(at + key.length() + 1)) if at >= 0 else 0


## The number at the start of `s` (String.to_int() would join every digit in the string).
static func leading_int(s: String) -> int:
	var v := 0
	for i in s.length():
		var c := s.unicode_at(i)
		if c < 48 or c > 57:
			break
		v = v * 10 + c - 48
	return v


func _unescape(s: String) -> PackedByteArray:
	var out := PackedByteArray()
	var i := 0
	while i < s.length():
		var c := s.unicode_at(i)
		if c == 92:
			var n := s.unicode_at(i + 1)
			if n >= 48 and n <= 55:
				out.append(_octal(s.substr(i + 1, 3)))
				i += 4
				continue
			out.append(n)
			i += 2
			continue
		out.append(c)
		i += 1
	return out


func _octal(s: String) -> int:
	var v := 0
	for i in s.length():
		v = v * 8 + (s.unicode_at(i) - 48)
	return v


func _to_unicode(codes: PackedByteArray) -> String:
	var out := ""
	for c in codes:
		out += String.chr(_unicode.get(c, c))
	return out


static func _latin1(bytes: PackedByteArray) -> String:
	var parts := PackedStringArray()
	parts.resize(bytes.size())
	for i in bytes.size():
		parts[i] = String.chr(bytes[i] if bytes[i] != 0 else 0x2400)     # one character per byte; NUL as ␀
	return "".join(parts)
