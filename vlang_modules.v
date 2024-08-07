/*
This file handles modules.vlang.io

TODO:
//bugs
os not working
check for bugs in this page

//later
search bar? dont know how
ctrl f

//can we accel these bad requests
1/3 of page loading time is spent outsite the request (profiled without -prod)

//general
show millis per frame on top of screen
site search/selection menu + theme/layouts (think abt how to organize it, map[base_url][]structs))
copy url of site
save website html (be able to load it from the file rather than http request) (toggle save in settings)
customization menu (rounded, color scheme...)
break all main.v functions into smaller ones, then write tests for all of them
raw text for all pages that the parser supports
read-me to encourage to contribute/use
report flashing in gg's ui-mode
*/
import gg
import gx

const toc_w = 360
const modules_w = 200
const space_w = 30
const rect_margin = 2

struct VlangModules {
mut:
	tree     Element
	url      string
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
	id_jumps   map[string]int
	render     bool // if init in middle of rendering happens
	rounded    bool = true
}

struct Box {
mut:
	x      int
	y      int
	h      int
	w      int
	primed bool
}

struct Text {
mut:
	t     string
	h     int
	w     int
	size  u8
	href  string
	color gg.Color // replace that with an index to avoid useless redundancy?
}

fn (mut r VlangModules) init(url string, width int) {
	r.url = url
	if tree := get_tree(url) {
		r.tree = tree[0]
		r.resize(width)
	} else {
		println(err)
	}
}

fn (mut r VlangModules) resize(width int) {
	println('Resizing site')
	r.id_jumps = map[string]int{}
	r.code_boxes = []
	r.toc = []
	r.content = []
	r.modules = []
	base_txt := Text{
		size: u8(r.text_cfg.size)
		color: gx.white
	}
	println('Searching doc-content')
	content := r.tree.get(.div, 'doc-content', '') or { panic('did not find elem in page') }
	r.h = 0
	r.w = 0
	println('Processing content')
	r.process_content(content, width - (space_w * 2 + toc_w + modules_w), base_txt, false)
	r.h = 0
	r.w = 0
	println('Searching content hidden')
	modules := r.tree.get(.nav, 'content hidden', '') or { panic('did not find elem in page') }
	println('Processing modules')
	r.process_modules(modules, base_txt, false)
	r.h = 0
	r.w = 0
	println('Searching doc-toc')
	toc := r.tree.get(.div, 'doc-toc', '') or { panic('did not find elem in page') }
	println('Processing table of contents')
	r.process_toc(toc, base_txt, false)
	println('Finished processing')
}

fn (mut r VlangModules) render(mut app App) {
	r.render = true
	app.ctx.draw_rect_filled(0, 0, modules_w, app.s_size.height, gg.Color{45, 55, 72, 255})
	r.h = -app.scroll
	r.show_modules(mut app, 15)
	app.ctx.draw_rect_filled(modules_w, 0, app.s_size.width, app.s_size.height, gg.Color{26, 32, 44, 255})
	r.show_content(app, modules_w + space_w)
	r.show_toc(mut app, app.s_size.width - toc_w)
	app.ctx.draw_circle_filled(app.s_size.width - 15, app.s_size.height - 15, 10, gg.Color{100, 100, 100, 255})
	if app.clicked {
		x := app.click_x - (app.s_size.width - 15)
		y := app.click_y - (app.s_size.height - 15)
		if x * x + y * y < 100 {
			app.scroll = 0
		}
	}
}

fn (mut v VlangModules) show_toc(mut app App, offset int) {
	if v.render {
		for t in v.toc {
			h := t.h - app.scroll
			if h + t.size >= 0 {
				if app.click_y >= h && app.click_y <= h + t.size {
					if app.click_x >= t.w + offset
						&& app.click_x <= t.w + offset + t.t.len * t.size / 2 {
						app.ctx.draw_rect_filled(t.w + offset, h + t.size - 1, t.t.len * t.size / 2,
							1, t.color)
						if app.clicked {
							if t.href.len > 0 && t.href[0] == `#` {
								app.scroll = v.id_jumps[t.href[1..]]
							} else {
								println("clickable not starting with '#': `${t.href}`")
							}
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
}

fn (mut v VlangModules) show_modules(mut app App, offset int) {
	if v.render {
		for t in v.modules {
			h := t.h - app.scroll
			if h + t.size >= 0 {
				if app.click_y >= h && app.click_y <= h + t.size {
					if app.click_x >= t.w + offset
						&& app.click_x <= t.w + offset + t.t.len * t.size / 2 {
						app.ctx.draw_rect_filled(t.w + offset, h + t.size - 1, t.t.len * t.size / 2,
							1, t.color)
						if app.clicked {
							app.clicked = false
							mut href := t.href
							if href.len >= 2 && href[0..2] == './' {
								href = 'https://modules.vlang.io/${href[2..]}'
							}
							if href.len >= 4 && href[0..4] == 'http' {
								app.scroll = 0
								v.init(href, app.s_size.width)
								v.render = false
								break
							} else {
								println("clickable not starting with 'http': `${href}`")
							}
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
}

fn (v VlangModules) show_content(app App, offset int) {
	if v.render {
		for b in v.code_boxes {
			y := b.y - app.scroll - rect_margin / 2
			if y + b.h > 0 && y < app.s_size.height {
				if v.rounded {
					app.ctx.draw_rounded_rect_filled(b.x + offset - rect_margin, y, b.w +
						rect_margin * 2, b.h + rect_margin, 5, gg.Color{45, 55, 72, 255})
				} else {
					app.ctx.draw_rect_filled(b.x + offset - rect_margin, y, b.w + rect_margin * 2,
						b.h + rect_margin, gg.Color{45, 55, 72, 255})
				}
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
}

fn (mut v VlangModules) process_toc(b Balise, cfg Text, w_o bool) {
	mut text := Text{
		h: v.h
		size: cfg.size
		color: gg.Color{144, 205, 244, 255}
		href: b.href + cfg.href
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
		color: cfg.color
		href: b.href + cfg.href
	}
	is_li := b.@type == .li
	is_open_active := b.check_is(.li, 'open active', '')
	if w_o {
		text.w = 20
	}
	if is_li {
		if is_open_active || b.check_is(.li, 'active', '') {
			text.color = gg.Color{200, 200, 255, 255}
		} else {
			text.color = gg.Color{255, 255, 255, 255}
		}
	}
	w_offset := (is_li && !b.check_is(.li, 'open', '') && !is_open_active) || w_o
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
	if b.id != '' {
		v.id_jumps[b.id] = v.h
	}
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
		href: b.href + cfg.href
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
		v.max_w = -1
	}
	for c in b.children {
		match c {
			Balise {
				v.process_content(c, width, text, code)
			}
			RawText {
				if c.txt != linebreaks#[..c.txt.len] || in_code || code {
					for n, t in c.split_txt {
						space_rep := ' '.repeat(t.len)
						if (in_code || code) || t != space_rep {
							if v.w + t.len * text.size / 2 < width {
								if (in_code || code) && v.max_w == -1 {
									v.max_w = v.w
								}
								text.t = t
								text.h = v.h
								text.w = v.w
								v.content << text
								v.w += (t.len) * text.size / 2
								if v.w > v.max_w {
									v.max_w = v.w
								}
								box.primed = true
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
									if text.t != '' { // could happen if whole word/text of txt is linebreaked
										v.content << text
										v.max_w = v.w + text.t.len * (text.size / 2)
										box.primed = true
										if box.x != 0 && b.check_is(.code, '', '') { // if x == 0 just do big box
											box.h = v.h - box.y + v.line_h
											box.w = v.max_w - box.x
											v.code_boxes << box
											box.x = 0
											box.y = v.h + v.line_h
											v.max_w = 0
										}
									} else {
										if (txt.index(' ') or { txt.len }) * (text.size / 2) > width { // if the size of the text before the next space is bigger than a line we need to break it
											i = (width - v.w) / (text.size / 2)
											text.t = txt[..i] // txt is bigger than i
											v.content << text
											v.max_w = v.w + text.t.len * (text.size / 2)
											box.primed = true
										} else {
											// if the len of the text before the next space is smaller than a line it will fit on next line
										}
									}
									v.w = 0
									v.h += v.line_h
									txt = txt[i..]
								}
								// the last cut part
								if txt != '' {
									if (in_code || code) && v.max_w == -1 {
										v.max_w = v.w
									}
									text.t = txt
									text.h = v.h
									text.w = v.w
									v.content << text
									v.w = txt.len * text.size / 2
									if txt == t {
										if v.w > v.max_w {
											v.max_w = v.w
										}
										if !box.primed {
											box.x = 0
											box.y = v.h
										}
									} else {
										if box.y != v.h {
											v.max_w = width
										} else {
											v.max_w = v.w
										}
									}
									box.primed = true
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
		box.h = v.h - box.y + v.line_h
		box.w = v.max_w - box.x
		v.code_boxes << box
	}
}
