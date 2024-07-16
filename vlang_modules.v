/*
This file handles modules.vlang.io

TODO:
tab problem in structs (maybe a problem to solve in the parser)
click detection / jump to / other page
code box not right width
store actual url to be able to copy it
*/
import gg
import gx

const toc_w = 360
const modules_w = 200
const space_w = 30
const rect_margin = 2

struct VlangModules {
mut:
	tree     []Element
	readme   []string
	text_cfg gx.TextCfg = gx.TextCfg{
		size: 18
		color: gg.Color{255, 255, 255, 255}
	}
	h          int
	w          int
	max_w      int
	line_h     int
	content    []Text
	toc        []Text
	code_boxes []Box
	modules    []Text
}

struct Box {
mut:
	x int
	y int
	h int
	w int
}

struct Text {
mut:
	t     string
	h     int
	w     int
	size  u8
	color gg.Color // replace that with an index to avoid useless redundancy?
}

fn (mut r VlangModules) init(url string, width int) {
	r.code_boxes = []
	r.toc = []
	r.content = []
	r.modules = []
	r.tree = get_tree(url)
	base_txt := Text{
		size: u8(r.text_cfg.size)
		color: gx.white
	}
	content := r.tree[0].get(.div, 'doc-content', '') or { panic('did not find elem in page') }
	r.h = 0
	r.w = 0
	r.process_content(content, width - (space_w * 2 + toc_w + modules_w), base_txt, false)
	r.h = 0
	r.w = 0
	modules := r.tree[0].get(.nav, 'content hidden', '') or { panic('did not find elem in page') }
	r.process_modules(modules, base_txt, false)
	r.h = 0
	r.w = 0
	toc := r.tree[0].get(.div, 'doc-toc', '') or { panic('did not find elem in page') }
	r.process_toc(toc, base_txt, false)
	r.tree = []
}

fn (mut r VlangModules) render(mut app App) {
	app.ctx.draw_rect_filled(0, 0, modules_w, app.s_size.height, gg.Color{45, 55, 72, 255})
	r.h = -app.scroll
	r.show_modules(app, 15)
	app.ctx.draw_rect_filled(modules_w, 0, app.s_size.width, app.s_size.height, gg.Color{26, 32, 44, 255})
	r.show_content(app, modules_w + space_w)
	r.show_toc(mut app, app.s_size.width - toc_w)
}

fn (mut v VlangModules) show_toc(mut app App, offset int) {
	for t in v.toc {
		h := t.h - app.scroll
		if h + t.size >= 0 {
			if app.click_y >= h && app.click_y <= h + t.size {
				if app.click_x >= t.w + offset && app.click_x <= t.w + offset + t.t.len * t.size / 2 {
					app.ctx.draw_rect_filled(t.w + offset, h + t.size - 1, t.t.len * t.size / 2,
						1, t.color)
					if app.clicked {
						println('clicked toc')
						app.clicked = false
					}
				}
			}
			app.ctx.draw_text(t.w + offset, h, t.t, gx.TextCfg{ color: t.color, size: t.size })
			if h > app.s_size.height {
				break
			}
		}
	}
}

fn (v VlangModules) show_modules(app App, offset int) {
	for t in v.modules {
		h := t.h - app.scroll
		if h + t.size >= 0 {
			app.ctx.draw_text(t.w + offset, h, t.t, gx.TextCfg{ color: t.color, size: t.size })
			if h > app.s_size.height {
				break
			}
		}
	}
}

fn (v VlangModules) show_content(app App, offset int) {
	for b in v.code_boxes {
		y := b.y - app.scroll - rect_margin / 2
		if y + b.h > 0 && y < app.s_size.height {
			app.ctx.draw_rounded_rect_filled(b.x + offset - rect_margin, y, b.w + rect_margin * 2,
				b.h + rect_margin, 5, gg.Color{45, 55, 72, 255})
		}
	}
	for t in v.content {
		h := t.h - app.scroll
		if h + t.size >= 0 {
			app.ctx.draw_text(t.w + offset, h, t.t, gx.TextCfg{ color: t.color, size: t.size })
			if h > app.s_size.height {
				break
			}
		}
	}
}

fn (mut v VlangModules) process_toc(b Balise, cfg Text, w_o bool) {
	mut text := Text{
		h: v.h
		size: cfg.size
		color: gg.Color{144, 205, 244, 255}
	}
	w_offset := (b.@type == .li && !b.check_is(.li, 'open', '')) || w_o
	if w_o {
		text.w = 20
	}
	for c in b.children {
		match c {
			Balise {
				v.process_toc(c, text, w_offset)
			}
			RawText {
				for t in c.split_txt {
					if t.trim(' ') != '' {
						text.t = t
						v.toc << text
						v.line_h = (text.size * 6) / 5
						v.h += v.line_h
					}
				}
			}
		}
	}
}

fn (mut v VlangModules) process_modules(b Balise, cfg Text, w_o bool) {
	mut text := Text{
		h: v.h
		size: cfg.size
		color: gg.Color{255, 255, 255, 255}
	}
	w_offset := (b.@type == .li && !b.check_is(.li, 'open', '')) || w_o
	if w_o {
		text.w = 20
	}
	for c in b.children {
		match c {
			Balise {
				v.process_modules(c, text, w_offset)
			}
			RawText {
				for t in c.split_txt {
					if t != '' {
						text.t = t
						v.modules << text
						v.line_h = (text.size * 6) / 5
						v.h += v.line_h
					}
				}
			}
		}
	}
}

fn (mut v VlangModules) process_content(b Balise, width int, cfg Text, in_code bool) {
	mut code := in_code
	mut box := Box{
		x: v.w
		y: v.h
	}
	size := match true {
		b.check_is(.h1, '', '') { 26 }
		b.check_is(.h2, '', '') { 22 }
		else { cfg.size }
	}
	mut text := Text{
		size: size
		color: match true {
			b.check_is(.span, 'token symbol', '') { gg.Color{237, 100, 166, 255} }
			b.check_is(.span, 'token comment', '') { gg.Color{160, 174, 192, 255} }
			b.check_is(.span, 'token builtin', '') { gg.Color{104, 211, 145, 255} }
			b.check_is(.span, 'token string', '') { gg.Color{104, 211, 145, 255} }
			b.check_is(.span, 'token punctuation', '') { gg.Color{160, 174, 192, 255} }
			b.check_is(.span, 'token operator', '') { gg.Color{166, 127, 89, 255} }
			b.check_is(.span, 'token number', '') { gg.Color{237, 100, 166, 255} }
			b.check_is(.span, 'token function', '') { gg.Color{78, 202, 191, 255} }
			b.check_is(.span, 'token keyword', '') { gg.Color{99, 179, 237, 255} }
			else { cfg.color }
		}
	}
	v.line_h = (text.size * 6) / 5
	if b.@type in [.p, .pre] {
		v.h += v.line_h
		v.w = 0
	}
	v.h += match b.@type {
		.p { v.line_h / 2 }
		else { 0 }
	}
	if b.check_is(.div, 'title', '') {
		v.h += v.line_h
		v.w = 0
	} else if b.check_is(.section, 'doc-node', '') {
		v.h += v.line_h
	} else if b.check_is(.code, '', '') {
		code = true
		v.max_w = v.w
	}
	for c in b.children {
		match c {
			Balise {
				v.process_content(c, width, text, code)
			}
			RawText {
				if c.txt != linebreaks#[..c.txt.len] || in_code || code {
					for n, t in c.split_txt {
						if t != '' {
							if v.w + t.len * text.size / 2 < width {
								text.t = t
								text.h = v.h
								text.w = v.w
								v.content << text
								v.w += (t.len) * text.size / 2
								if v.w > v.max_w {
									v.max_w = v.w
								}
							} else {
								mut txt := t
								for v.w + txt.len * (text.size / 2) > width {
									mut i := (width - v.w) / (text.size / 2)
									for i != -1 && txt[i] != ` ` {
										i -= 1
									}
									i += 1
									text.h = v.h
									text.w = v.w
									text.t = txt[..i] // txt is bigger than i
									v.w = 0
									v.h += v.line_h
									if text.t != '' { // could happen if whole word/text of txt is linebreaked
										v.content << text
									}
									txt = txt[i..]
								}
								// the last cut part
								if txt != '' {
									text.t = txt
									text.h = v.h
									text.w = v.w
									v.content << text
									v.w = txt.len * text.size / 2
									if txt == t {
										v.max_w = v.w
										box.x = v.w
										box.y = v.h
									} else {
										v.max_w = width
									}
								}
							}
						}
						if n < c.split_txt.len - 1 && c.split_txt.len > 1 {
							v.h += v.line_h
							v.w = 0
						}
					}
				}
			}
		}
	}
	if b.@type in [.p, .pre] {
		v.h += v.line_h
		v.w = 0
	}
	v.h += match b.@type {
		.p { v.line_h / 2 }
		else { 0 }
	}
	if b.check_is(.div, 'title', '') {
		v.h += v.line_h
		v.w = 0
	} else if b.check_is(.section, 'doc-node', '') {
		v.h += v.line_h
	} else if b.check_is(.code, '', '') {
		box.h = v.h - box.y + v.line_h
		box.w = v.max_w - box.x
		v.code_boxes << box
	}
}
