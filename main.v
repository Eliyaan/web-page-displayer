module main

import gg
import os

const basic_cfg = gg.TextCfg{
	color: gg.Color{200, 200, 200, 255}
	size: 16
}
const linebreaks = '\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n'

enum Variant {
	doctype
	head
	blockquote
	time
	meta
	link
	title
	article
	style
	main
	footer
	svg
	path
	defs
	clippath
	rect
	aside
	input
	button
	nav
	div
	br
	hr
	script
	a
	html
	body
	header
	section
	li
	ol
	ul
	span
	g
	h1
	h2
	h3
	h4
	h5
	h6
	p
	code
	strong
	em
	table
	tr
	td
	pre
	thead
	tbody
	th
	img
}

struct Balise { // replace with english name
mut:
	children  []Element
	codebox_h int
	codebox_w int
	@type     Variant
	attr      string // inside the balise
	class     string
	id        string
	href      string
}

struct RawText {
mut:
	txt       string
	split_txt []string
}

type Element = Balise | RawText

interface Render {
mut:
	render(mut app App)
	init(url string, width int)
	resize(width int)
}

struct App {
mut:
	ctx        &gg.Context = unsafe { nil }
	s_size     gg.Size     = gg.Size{1000, 700}
	render     Render
	free_frame int = 2
	scroll     int
	click_x    int
	click_y    int
	clicked    bool
}

fn main() {
	// println(get_tree('https://docs.vlang.io/')) does not work yet
	mut app := App{
		render: VlangModules{}
	}
	app.ctx = gg.new_context(
		create_window: true
		user_data: &app
		frame_fn: frame
		event_fn: event
		font_path: os.resource_abs_path('fonts/SourceCodePro-Medium.ttf')
	)
	app.render.init('https://modules.vlang.io', app.s_size.width)
	app.ctx.run()
}

fn event(e &gg.Event, mut app App) {
	app.click_x = int(e.mouse_x)
	app.click_y = int(e.mouse_y)
	match e.typ {
		.mouse_scroll {
			app.scroll -= int(e.scroll_y) * 30
			if app.scroll < 0 {
				app.scroll = 0
			}
		}
		.mouse_up {
			app.clicked = true
		}
		else {}
	}
}

fn frame(mut app App) {
	if app.free_frame == 0 {
		if gg.window_size() != app.s_size {
			app.s_size = gg.window_size()
			app.render.resize(app.s_size.width)
		}
		app.ctx.begin()
		app.render.render(mut app)
		app.ctx.end()
	} else {
		app.free_frame -= 1
		if app.free_frame == 0 {
			app.ctx.ui_mode = true
		}
	}
	app.clicked = false
}

// TODO: use for raw text rendering of unknown pages
fn organise_render(txt string, font_size int, width int) []string { // TODO split line on space if possible
	mut output := []string{}
	line_length := width / (font_size / 2)
	if line_length != 0 {
		txt_s := txt.split('\n')
		for line in txt_s {
			if line.len <= line_length {
				output << line
			} else {
				mut n := 0
				for n < line.len {
					output << line#[n..n + line_length]
					n += line_length
				}
			}
		}
	} else {
		println('line_length = 0, not normal')
	}
	return output
}

fn (e Element) raw_text() string {
	mut s := ''
	if e is RawText {
		s += e.txt
	} else if e is Balise {
		if e.@type in [.p, .pre] {
			s += '\n'
		}
		for c in e.children {
			s += c.raw_text()
		}
		if e.@type in [.p, .pre] {
			s += '\n'
		}
	}
	return s
}
