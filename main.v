import net.http
import gg

const non_closing = [Variant.br, .img, .hr, .doctype, .meta, .link, .title, .path]

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
	@type    Variant
	attr     string // inside the balise
	children []Element
}

struct RawText {
mut:
	txt string
}

type Element = Balise | RawText

struct App {
mut:
	ctx  &gg.Context = unsafe { nil }
	tree []Element
}

fn main() {
	// println(get_tree('https://docs.vlang.io/introduction.html')) does not work yet
	mut app := App{
		tree: get_tree('https://modules.vlang.io/gg.html')
	}
	app.ctx = gg.new_context(create_window: true, user_data: &app, frame_fn: frame, event_fn: event)
	app.ctx.run()
}

fn event(e &gg.Event, mut app App) {}

fn frame(mut app App) {
	// read_me := app.tree[0].children[1].children[1].children[1].children[0].children[0].children[0]
	mut h := 0
	// need to change the parser && change Balise when sumtype Element = Balise|RawText
}

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
					mut tag := &p.stack[p.stack.len - 1]
					if mut tag is Balise {
						if c == `\n` {
							tag.attr += ' '
						} else {
							tag.attr += c.ascii_str()
						}
					} else { panic("handle not balise ${@FILE_LINE}") }
				}
			}
		} else {
			if c == `<` {
				p.process_open_tag()
			} else {
				if c != `\t` && p.stack.len > 0 {
					mut last := &p.stack[p.stack.len - 1]
					if mut last is Balise { // sure
						mut l := last.children.len
						if last.children[l - 1] is Balise {
							last.children << RawText{}
						} else { panic("handle not balise ${@FILE_LINE}") }
						l = last.children.len
						mut raw_txt := &last.children[l - 1]
						if mut raw_txt is RawText {
							raw_txt.txt += c.ascii_str()
						} else { panic("handle not rawtext ${@FILE_LINE}") }
					}
				}
			}
		}
		p.nb += 1
	}
	return p.parents
}

fn (mut p Parse) escape_tag() {
	p.in_balise = false
	if p.stack.len == 1 {
		p.parents << *p.stack.pop()
	} else {
		p.stack.pop()
	}
	p.nb += 1
	for p.main_content[p.nb] != `>` {
		p.nb += 1
	}
}

fn (mut p Parse) close_tag() {
	p.in_balise = false
	last := p.stack.last()
	if last is Balise {
		if last.@type in non_closing {
			p.stack.pop()
		}
	}
}

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
				mut last := &p.stack[p.stack.len - 1]
				if mut last is Balise { // sure
					mut child := &last.children[last.children.len - 1]
					if mut child is RawText{
						child.txt += '<' // to not lose the <
					} else { panic("handle not raw text ${@FILE_LINE}") }
				} else { panic("handle not balise ${@FILE_LINE}") }
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
					mut last := &p.stack[p.stack.len - 1]
					if mut last is Balise {
						last.children << Balise{
							@type: vari
						}
						p.stack << &last.children[last.children.len - 1]
					} else { panic("handle not balise ${@FILE_LINE}") }
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
			mut last := &p.stack[p.stack.len-1]
			if mut last is RawText {
				last.txt += '<' // to not lose the <			
			} else { panic("handle not rawtext ${@FILE_LINE}") }
		}
	}
}

fn is_valid_tag_name_char(c u8) bool {
	return (c >= `A` && c <= `Z`) || (c >= `a` && c <= `z`) || c == `!` || (c >= `0` && c <= `9`)
}
