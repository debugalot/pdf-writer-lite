extends Control
## PDF Writer Lite demo: fill in a run and export it as a PDF report (Ctrl+E).
## On desktop the PDF opens in the system's viewer; in a web export the browser downloads it.

const RunReport := preload("res://demo/run_report.gd")
const NIGHT := Color(0.07, 0.06, 0.12)
const PANEL := Color(0.12, 0.1, 0.2)
const GOLD := Color(0.96, 0.71, 0.27)
const MUTED := Color(0.65, 0.62, 0.75)

var _hero: LineEdit
var _number: SpinBox
var _time: LineEdit
var _floors: TextEdit
var _notes: TextEdit
var _loot: TextEdit
var _paper: OptionButton
var _status: Label


func _ready() -> void:
	var run := RunReport.sample()
	var bg := ColorRect.new()
	bg.color = NIGHT
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	margin.add_child(col)

	var title := Label.new()
	title.text = "PDF Writer Lite: run report"
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", GOLD)
	col.add_child(title)
	var sub := Label.new()
	sub.text = "Fill in the run and press Export PDF (Ctrl+E). The code that builds the PDF is demo/run_report.gd."
	sub.add_theme_color_override("font_color", MUTED)
	col.add_child(sub)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	col.add_child(row)
	_hero = _line(row, "Hero", run.hero, 220)
	_number = SpinBox.new()
	_number.min_value = 1
	_number.max_value = 9999
	_number.value = run.number
	_field(row, "Run", _number, 90)
	_time = _line(row, "Time", run.time, 90)
	_paper = OptionButton.new()
	_paper.add_item("Letter")
	_paper.add_item("A4")
	_field(row, "Paper", _paper, 100)

	var boxes := HBoxContainer.new()
	boxes.size_flags_vertical = Control.SIZE_EXPAND_FILL
	boxes.add_theme_constant_override("separation", 12)
	col.add_child(boxes)
	_floors = _text(boxes, "Floors (one per line)", "\n".join(run.floors))
	_notes = _text(boxes, "Notes", run.notes)
	_loot = _text(boxes, "Loot (one per line)", "\n".join(run.loot))

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 16)
	col.add_child(bottom)
	var export := Button.new()
	export.text = "  Export PDF  "
	export.shortcut = Shortcut.new()
	var key := InputEventKey.new()
	key.keycode = KEY_E
	key.ctrl_pressed = true
	export.shortcut.events = [key]
	export.pressed.connect(_export)
	bottom.add_child(export)
	_status = Label.new()
	_status.add_theme_color_override("font_color", MUTED)
	_status.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bottom.add_child(_status)


func _export() -> void:
	var run := RunReport.sample()
	run.hero = _hero.text.strip_edges() if _hero.text.strip_edges() != "" else "Unknown hero"
	run.number = int(_number.value)
	run.time = _time.text.strip_edges()
	run.floors = _lines(_floors)
	run.notes = _notes.text.strip_edges()
	run.loot = _lines(_loot)
	var paper := PdfDocument.A4 if _paper.selected == 1 else PdfDocument.LETTER
	var started := Time.get_ticks_msec()
	var pdf := RunReport.build(run, paper)
	var file := "run_%d.pdf" % run.number
	var err := pdf.download(file)
	if err == OK:
		_status.text = "Exported %s: %d pages in %d ms." % [file, pdf.get_page_count(), Time.get_ticks_msec() - started]
	else:
		_status.text = "Couldn't save %s: %s" % [file, error_string(err)]


func _lines(edit: TextEdit) -> Array:
	return Array(edit.text.split("\n", false)).map(func(s: String) -> String: return s.strip_edges()).filter(func(s: String) -> bool: return s != "")


func _field(parent: Control, label: String, control: Control, width: float) -> void:
	var box := VBoxContainer.new()
	var l := Label.new()
	l.text = label
	l.add_theme_color_override("font_color", MUTED)
	box.add_child(l)
	control.custom_minimum_size.x = width
	box.add_child(control)
	parent.add_child(box)


func _line(parent: Control, label: String, value: String, width: float) -> LineEdit:
	var edit := LineEdit.new()
	edit.text = value
	_field(parent, label, edit, width)
	return edit


func _text(parent: Control, label: String, value: String) -> TextEdit:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var l := Label.new()
	l.text = label
	l.add_theme_color_override("font_color", MUTED)
	box.add_child(l)
	var edit := TextEdit.new()
	edit.text = value
	edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL
	style.set_content_margin_all(8)
	style.set_corner_radius_all(4)
	edit.add_theme_stylebox_override("normal", style)
	box.add_child(edit)
	parent.add_child(box)
	return edit
