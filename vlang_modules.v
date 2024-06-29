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
	h      int
	w      int
	line_h int
}

fn (mut r VlangModules) render(mut app App) {
	if gg.window_size() != app.s_size {
		app.s_size = gg.window_size()
	}
	app.ctx.draw_rect_filled(0, 0, app.s_size.width, app.s_size.height, gg.Color{26, 32, 44, 255})
	r.h = -app.scroll
	content := r.tree[0].get(.div, 'doc-content', '') or { panic('did not find elem in page') }
	r.show(app, content, 100, 1900, r.text_cfg)
}

fn (mut v VlangModules) show(app App, b Balise, offset int, width int, cfg gx.TextCfg) {
	size := match true {
		b.check_is(.h1, '', '') { 26 }
		b.check_is(.h2, '', '') { 22 }
		else { cfg.size }
	}
	text_cfg := gx.TextCfg{
		size: size
		color: match true {
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
	}
	if v.h < app.s_size.height {
		for c in b.children {
			match c {
				Balise {
					v.show(app, c, offset, width, text_cfg)
				}
				RawText {
					if c.txt != `\n`.repeat(c.txt.len) {
						s := c.txt.split('\n')
						for n, t in s {
							if v.h >= 0 {
								if v.w >= 0 && v.w < width {
									app.ctx.draw_text(v.w + offset, v.h, t, text_cfg)
									v.w += (t.len) * text_cfg.size / 2
								} else {
									v.h += v.line_h
									v.w = 0
									// handle line break
								}
							}
							if n < s.len - 1 && s.len > 1 {
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
	}
}
