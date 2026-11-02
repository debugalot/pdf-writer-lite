## Uses every part of PDF Writer Lite's API. The tests run it on Lite, and tools/check_upgrade.py
## runs the same file on the full PDF Writer, to show that code written for Lite keeps working
## after upgrading.


static func build() -> PdfDocument:
	var pdf := PdfDocument.new(PdfDocument.A4, 48.0)
	var _sizes := [PdfDocument.LETTER, PdfDocument.LEGAL, PdfDocument.A3, PdfDocument.A4, PdfDocument.A5, PdfDocument.VERSION, PdfDocument.DEFAULT_THEME]
	pdf.title = "API tour"
	pdf.author = "Sir Debugalot"
	pdf.subject = "Every part of the Lite API"
	pdf.keywords = "godot, pdf"
	pdf.creator = "PDF Writer Lite tests"
	pdf.margin_left = 50.0
	pdf.margin_right = 50.0
	pdf.margin_top = 56.0
	pdf.margin_bottom = 56.0
	pdf.header = "{title} · {date}"
	pdf.header_align = "right"
	pdf.footer = "Page {page} of {pages}"
	pdf.footer_align = "center"
	pdf.compress = true
	pdf.theme.text_size = 10.5
	pdf.theme.heading_color = Color(0.1, 0.2, 0.4)
	pdf.theme.paragraph_spacing = 9.0

	pdf.add_heading("API tour")
	pdf.add_heading("Flowing content", 2, {"color": Color(0.5, 0.2, 0.1)})
	pdf.add_text("A justified paragraph in bold italic, indented and spaced out, long enough to wrap over a few lines so the justification shows.",
		{"size": 12.0, "color": Color(0.2, 0.2, 0.2), "bold": true, "italic": true, "align": "justify", "line_spacing": 1.4, "indent": 12.0, "space_after": 10.0})
	pdf.add_text("Centered.", {"align": "center"})
	pdf.add_text("Right.", {"align": "right"})
	pdf.add_list(["A bullet", "Another bullet that is long enough to wrap onto a second line inside the list's hanging indent."])
	pdf.add_list(["First", "Second"], {"ordered": true})
	pdf.add_rule({"color": Color(0.6, 0.6, 0.6), "width": 1.5, "space": 6.0})
	pdf.add_space(12.0)

	var y := pdf.get_cursor_y()
	var drawn := pdf.draw_text(Vector2(pdf.margin_left, y), "Drawn text", {"size": 14.0, "bold": true})
	var measured := pdf.measure_text("Drawn text", {"size": 14.0, "bold": true})
	assert(drawn.is_equal_approx(measured))
	pdf.draw_text(Vector2(pdf.margin_left + 160.0, y), "A long line cut short with an ellipsis", {"width": 120.0, "ellipsis": true})
	pdf.draw_text(Vector2(pdf.margin_left + 300.0, y), "Wrapped and centered in a box", {"width": 120.0, "align": "center"})
	pdf.draw_line(Vector2(pdf.margin_left, y + 40.0), Vector2(pdf.margin_left + pdf.content_width(), y + 40.0), Color(0.8, 0.2, 0.2), 2.0)
	pdf.draw_rect(Rect2(pdf.margin_left, y + 50.0, 120.0, 24.0), Color(0.9, 0.9, 0.95), Color.BLACK, 0.5)
	pdf.set_cursor_y(y + 90.0)
	pdf.add_text("After the drawing.")

	pdf.add_page_break()
	pdf.add_text("Page two.")
	pdf.new_page(PdfDocument.A5)
	pdf.add_text("An A5 page.")
	var last := pdf.get_page()
	pdf.set_page(0)
	pdf.draw_text(Vector2(pdf.margin_left, 30.0), "Back on page 1", {"size": 7.0})
	pdf.set_page(last)
	assert(pdf.get_page_count() == 3)
	return pdf
