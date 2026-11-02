## Builds the demo's run report. Uses only PDF Writer Lite's API, so it runs unchanged on the full
## PDF Writer too.

const INK := Color(0.12, 0.11, 0.18)
const BAND := Color(0.11, 0.09, 0.2)
const GOLD := Color(0.96, 0.71, 0.27)
const TEAL := Color(0.26, 0.82, 0.78)
const TRACK := Color(0.9, 0.9, 0.93)


## `run`: {hero, number, time, floors: Array[String], notes, stats: {name: [value, max]}, loot: Array[String]}.
static func build(run: Dictionary, paper := PdfDocument.LETTER) -> PdfDocument:
	var pdf := PdfDocument.new(paper)
	pdf.title = "Run %d: %s" % [run.number, run.hero]
	pdf.author = str(run.hero)
	pdf.subject = "Run report"
	pdf.footer = "{title}  ·  Page {page} of {pages}"
	pdf.footer_align = "left"
	pdf.theme.heading_color = INK

	# A title band across the top of the first page, drawn rather than flowed.
	var w := paper.x
	pdf.draw_rect(Rect2(0, 0, w, 118), BAND)
	pdf.draw_rect(Rect2(0, 118, w, 4), GOLD)
	pdf.draw_text(Vector2(pdf.margin_left, 34), "RUN REPORT", {"size": 9.0, "bold": true, "color": GOLD})
	pdf.draw_text(Vector2(pdf.margin_left, 48), "Run %d" % run.number, {"size": 30.0, "bold": true, "color": Color.WHITE})
	pdf.draw_text(Vector2(pdf.margin_left, 88), "%s  ·  finished in %s" % [run.hero, run.time], {"size": 12.0, "color": Color(0.85, 0.83, 0.92)})
	pdf.set_cursor_y(146)

	pdf.add_heading("Stats", 2)
	var y := pdf.get_cursor_y()
	var bar_x := pdf.margin_left + 90.0
	var bar_w := pdf.content_width() - 90.0 - 80.0
	for stat: String in run.stats:
		var value := float(run.stats[stat][0])
		var top := float(run.stats[stat][1])
		pdf.draw_text(Vector2(pdf.margin_left, y), stat, {"bold": true})
		pdf.draw_rect(Rect2(bar_x, y + 3, bar_w, 9), TRACK)
		pdf.draw_rect(Rect2(bar_x, y + 3, bar_w * clampf(value / top, 0.0, 1.0), 9), TEAL)
		pdf.draw_text(Vector2(bar_x + bar_w + 8, y), "%d / %d" % [value, top], {"color": Color(0.42, 0.42, 0.45)})
		y += 20.0
	pdf.set_cursor_y(y + 6)

	pdf.add_heading("Floors", 2)
	pdf.add_list(run.floors, {"ordered": true})
	pdf.add_heading("Notes", 2)
	pdf.add_text(str(run.notes), {"align": "justify"})
	pdf.add_heading("Loot", 2)
	pdf.add_list(run.loot)
	pdf.add_rule()
	pdf.add_text("Printed from Godot on %s." % Time.get_date_string_from_system(), {"italic": true, "size": 9.0, "color": Color(0.42, 0.42, 0.45), "align": "center"})
	return pdf


## The run the demo starts with.
static func sample() -> Dictionary:
	return {
		"hero": "Sir Debugalot",
		"number": 42,
		"time": "12:31",
		"floors": [
			"The Null Pointer Caves: 1:02, no damage taken",
			"Off-by-One Bridge: 3:40, fell once (twice?)",
			"Race Condition Rapids: 2:15",
			"The Heisenbug's Lair: 5:34, boss defeated on the third try",
		],
		"notes": "The Heisenbug vanished every time I looked at it directly, so I fought it with the debugger closed. Café break after floor two: the innkeeper's crème brûlée restores 40 HP. Next run: take the left door on the bridge, avoid the “shortcut” through the rapids, and bring more than 3 potions.",
		"stats": {"Health": [64, 100], "Gold": [1250, 2000], "Accuracy": [81, 100], "Bugs fixed": [17, 20]},
		"loot": ["Rubber Duck of Insight (legendary)", "Stack Trace Scroll ×3", "Semicolon of Closure", "Breakpoint Boots: +2 speed, -1 patience",
			"Cup of Coffee (restores 100 focus)", "Mysterious Commented-Out Code", "Unit Test Shield: blocks one regression"],
	}
