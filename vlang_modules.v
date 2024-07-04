/*
This file handles modules.vlang.io
*/
import gg
import gx

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

fn (mut r VlangModules) init() {
	base_txt := Text{
		size: u8(r.text_cfg.size)
		color: gx.white
	}
	content := r.tree[0].get(.div, 'doc-content', '') or { panic('did not find elem in page') }
	r.process_content(content, 1000, base_txt, false)
	r.h = 0
	modules := r.tree[0].get(.nav, 'content hidden', '') or { panic('did not find elem in page') }
	r.process_modules(modules, base_txt, false)
	r.tree = []
}

fn (mut r VlangModules) render(mut app App) {
	if gg.window_size() != app.s_size {
		app.s_size = gg.window_size()
	}
	app.ctx.draw_rect_filled(300, 0, app.s_size.width, app.s_size.height, gg.Color{26, 32, 44, 255})
	app.ctx.draw_rect_filled(0, 0, 300, app.s_size.height, gg.Color{45, 55, 72, 255})
	r.h = -app.scroll
	r.show_content(app, 330)
	r.show_modules(app, 15)
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
		y := b.y - app.scroll
		if y + b.h > 0 && y < app.s_size.height {
			app.ctx.draw_rect_filled(b.x + offset, y, b.w, b.h, gg.Color{45, 55, 72, 255})
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
							for !(v.w + txt.len * text.size / 2 < width) {
								mut i := (width - v.w) / (text.size / 2)
								for i != -1 && txt[i] != ` ` {
									i -= 1
								}
								i += 1
								text.h = v.h
								text.w = v.w
								text.t = txt[..i]
								v.content << text
								v.w = 0
								v.h += v.line_h
								txt = txt[i..]
							}
							box.x = v.w
							box.y = v.h
							text.t = txt
							text.h = v.h
							text.w = v.w
							v.content << text
							v.w = txt.len * text.size / 2
							if in_code {
								v.max_w = width
							} else {
								v.max_w = v.w
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
