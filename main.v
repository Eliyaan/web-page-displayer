import net.http
import gg
import gx
import os

const non_closing = [Variant.br, .img, .hr, .doctype, .meta, .link, .title, .path]
const basic_cfg = gx.TextCfg{
	color: gg.Color{200, 200, 200, 255}
	size: 16
}
const linebreaks = '\n\n\n\n\n\n\n\n\n\n\n\n\n'

struct Parse {
mut:
	main_content string
	parents      []Element
	stack        []&Element
	in_balise    bool
	nb           int
}

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
	@type     Variant
	attr      string // inside the balise
	class     string
	id        string
	children  []Element
	codebox_h int
	codebox_w int
}

struct RawText {
mut:
	txt       string
	split_txt []string
}

type Element = Balise | RawText

interface Render {
mut:
	tree []Element
	render(mut app App)
	init(url string, width int)
}

struct App {
mut:
	ctx        &gg.Context = unsafe { nil }
	s_size     gg.Size
	render     Render
	free_frame int = 2
	scroll     int
}

fn main() {
	// println(get_tree('https://docs.vlang.io/introduction.html')) does not work yet
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
	app.ctx.run()
}

fn event(e &gg.Event, mut app App) {
	match e.typ {
		.mouse_scroll {
			app.scroll -= int(e.scroll_y) * 20
			if app.scroll < 0 {
				app.scroll = 0
			}
		}
		else {}
	}
}

fn frame(mut app App) {
	if app.free_frame == 0 {
		if gg.window_size() != app.s_size {
			app.s_size = gg.window_size()
			app.render.init('https://modules.vlang.io/gg.html', app.s_size.width)
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
}

// Not used
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

fn (e Element) get(v Variant, class string, id string) ?Balise {
	if e is Balise {
		if e.check_is(v, class, id) {
			return e
		} else {
			for c in e.children {
				if a := c.get(v, class, id) {
					return a
				}
			}
		}
	}
	return none
}

fn (b Balise) check_is(v Variant, class string, id string) bool {
	if b.@type == v {
		if class == '' || b.class == class {
			return id == '' || b.id == id
		}
	}
	return false
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

@[direct_array_access]
fn get_tree(url string) []Element {
	res := http.get(url) or { panic('http get err: ${err}') }
	mut p := Parse{
		main_content: res.body
	}
	parse: for p.nb < p.main_content.len {
		c := p.main_content[p.nb]
		if p.in_balise {
			if c == `/` && p.main_content[p.nb + 1] == `>` {
				p.escape_tag()
			} else if c == `>` {
				p.close_tag()
			} else {
				if c != `\t` {
					mut tag := p.stack[p.stack.len - 1]
					if mut tag is Balise {
						if c == `\n` {
							tag.attr += ' '
						} else {
							tag.attr += c.ascii_str()
						}
					} else {
						panic('handle not balise ${@FILE_LINE}')
					}
				}
			}
		} else {
			if c == `<` {
				p.process_open_tag()
			} else {
				if c != `\t` && p.stack.len > 0 { // TODO: need to find a way to handle tabs for code indentation
					mut last := p.stack[p.stack.len - 1]
					if mut last is Balise { // sure
						mut l := last.children.len
						if l == 0 || last.children[l - 1] is Balise {
							last.children << RawText{}
						} else {
						} // no problem
						l = last.children.len
						mut raw_txt := &last.children[l - 1]
						if mut raw_txt is RawText {
							raw_txt.txt += c.ascii_str()
						} else {
							panic('handle not rawtext ${@FILE_LINE}')
						}
					}
				}
			}
		}
		p.nb += 1
	}
	return p.parents
}

@[direct_array_access]
fn (mut p Parse) escape_tag() {
	p.in_balise = false
	if p.stack.len == 1 {
		p.parents << *p.stack.pop()
	} else {
		mut last := p.stack[p.stack.len - 1]
		if mut last is Balise {
			for mut last_child in last.children {
				if mut last_child is RawText {
					last_child.split_txt = last_child.txt.split('\n')
				}
			}
		}
		p.stack.pop()
	}
	p.nb += 1
	for p.main_content[p.nb] != `>` {
		p.nb += 1
	}
}

fn (mut p Parse) close_tag() {
	p.in_balise = false
	mut last := p.stack[p.stack.len - 1]
	if mut last is Balise {
		if i := last.attr.index('class=') {
			start := i + 7
			mut end := start + 1
			for c in last.attr[start + 1..] {
				if c == `"` {
					break
				}
				end += 1
			}
			last.class = last.attr[start..end]
		}
		if i := last.attr.index('id=') {
			start := i + 7
			mut end := start + 1
			for c in last.attr[start + 1..] {
				if c == `"` {
					break
				}
				end += 1
			}
			last.id = last.attr[start..end]
		}
		last.attr = '' // free memory I guess
		if last.@type in non_closing {
			p.stack.pop()
		}
	}
}

@[direct_array_access]
fn (mut p Parse) process_open_tag() {
	p.nb += 1
	if p.main_content[p.nb] == `/` {
		p.escape_tag()
	} else {
		p.in_balise = true
		mut name := ''
		old_nb := p.nb
		for p.main_content[p.nb] !in [` `, `>`, `\n`] {
			if is_valid_tag_name_char(p.main_content[p.nb]) {
				name += p.main_content[p.nb].ascii_str()
				p.nb += 1
			} else {
				p.in_balise = false
				// debug println("not name ${main_content[nb].ascii_str()}  name:${name}")
				mut last := p.stack[p.stack.len - 1]
				if mut last is Balise { // sure
					mut child := &last.children[last.children.len - 1]
					if mut child is RawText {
						child.txt += '<' // to not lose the <
					} else {
						panic('handle not raw text ${@FILE_LINE}')
					}
				} else {
					panic('handle not balise ${@FILE_LINE}')
				}
				p.nb = old_nb - 1
				return
			}
		}
		if name.len > 0 {
			name = name.to_lower()
			if name[0] == `!` {
				if name == '!doctype' {
					name = 'doctype'
				}
			}
			if vari := Variant.from(name) {
				if p.main_content[p.nb] == `>` {
					p.in_balise = false
				}
				if p.stack.len > 0 {
					mut last := p.stack[p.stack.len - 1]
					if mut last is Balise {
						last.children << Balise{
							@type: vari
						}
						p.stack << &last.children[last.children.len - 1]
					} else {
						panic('handle not balise ${@FILE_LINE}')
					}
				} else {
					p.stack << &Balise{
						@type: vari
					}
				}
			} else { // does not handle all the bad cases
				println('${err} : ${name}. The parser wont work as intended.')
				for p.main_content[p.nb] != `>` {
					p.nb += 1
				}
				p.in_balise = false
			}
		} else {
			p.in_balise = false
			p.nb -= 1
			mut last := p.stack[p.stack.len - 1]
			if mut last is RawText {
				last.txt += '<' // to not lose the <			
			} else {
				panic('handle not rawtext ${@FILE_LINE}')
			}
		}
	}
}

fn is_valid_tag_name_char(c u8) bool {
	return (c >= `A` && c <= `Z`) || (c >= `a` && c <= `z`) || c == `!` || (c >= `0` && c <= `9`)
}
