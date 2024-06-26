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
	h       int
	w       int
	max_w   int
	line_h  int
	content Balise
	modules Balise
}

fn (mut r VlangModules) init() {
	r.content = r.tree[0].get(.div, 'doc-content', '') or { panic('did not find elem in page') }
	r.modules = r.tree[0].get(.nav, 'content hidden', '') or { panic('did not find elem in page') }
	r.tree = []
}

fn (mut r VlangModules) render(mut app App) {
	if gg.window_size() != app.s_size {
		app.s_size = gg.window_size()
	}
	app.ctx.draw_rect_filled(300, 0, app.s_size.width, app.s_size.height, gg.Color{26, 32, 44, 255})
	app.ctx.draw_rect_filled(0, 0, 300, app.s_size.height, gg.Color{45, 55, 72, 255})
	r.h = -app.scroll
	r.show_modules(app, mut r.modules, 15, 300, r.text_cfg)
	r.h = -app.scroll
	r.show_content(app, mut r.content, 330, 1000, r.text_cfg, false)
}

fn (mut v VlangModules) show_modules(app App, mut b Balise, offset int, width int, cfg gx.TextCfg) {
	text_cfg := gx.TextCfg{
		size: cfg.size
		color: gg.Color{255, 255, 255, 255}
	}
	v.line_h = (text_cfg.size * 6) / 5
	if b.@type == .li {
		v.h += v.line_h
		if b.check_is(.li, 'open', '') {
			v.w = 0
		} else {
			v.w = 20
		}
	}
	if v.h < app.s_size.height {
		for mut c in b.children {
			match mut c {
				Balise {
					v.show_modules(app, mut c, offset, width, text_cfg)
				}
				RawText {
					for t in c.split_txt {
						if v.h >= 0 && t != '' {
							app.ctx.draw_text(v.w + offset, v.h, c.txt, text_cfg)
							v.w += (c.txt.len) * text_cfg.size / 2
						}
					}
				}
			}
		}
	}
}

fn (mut v VlangModules) show_content(app App, mut b Balise, offset int, width int, cfg gx.TextCfg, in_code bool) {
	mut code := in_code
	size := match true {
		b.check_is(.h1, '', '') { 26 }
		b.check_is(.h2, '', '') { 22 }
		else { cfg.size }
	}
	base_h := v.h
	base_w := v.w
	text_cfg := gx.TextCfg{
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
	v.line_h = (text_cfg.size * 6) / 5
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
		app.ctx.draw_rect_filled(offset + v.w, v.h, b.codebox_w, b.codebox_h, gg.Color{45, 55, 72, 255})
	}
	if v.h < app.s_size.height {
		for mut c in b.children {
			match mut c {
				Balise {
					v.show_content(app, mut c, offset, width, text_cfg, code)
				}
				RawText {
					if c.txt != linebreaks#[..c.txt.len] || in_code || code {
						for n, t in c.split_txt {
							if v.h >= 0 {
								if v.w >= 0 && v.w + t.len * text_cfg.size / 2 < width {
									app.ctx.draw_text(v.w + offset, v.h, t, text_cfg)
									v.w += (t.len) * text_cfg.size / 2
									if v.w > v.max_w {
										v.max_w = v.w
									}
								} else {
									mut i := (width - v.w) / (text_cfg.size / 2)
									for i != -1 && t[i] != ` ` {
										i -= 1
									}
									i += 1
									app.ctx.draw_text(v.w + offset, v.h, t[..i], text_cfg)
									v.h += v.line_h
									app.ctx.draw_text(offset, v.h, t[i..], text_cfg)
									v.w = t[i..].len * text_cfg.size / 2
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
		b.codebox_h = v.h - base_h + v.line_h
		b.codebox_w = v.max_w - base_w
	}
}
