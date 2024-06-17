import net.http

enum Variant {
	doctype
	head
	meta
	link
	title
	style
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
}

struct Balise { // replace with english name
mut:
	@type    Variant
	attr     string // inside the balise
	children []Balise
	txt      string // raw text between start/end of the balise
}

fn main() {
	println(get_tree('https://modules.vlang.io/gg.html'))
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
	if p.stack.last().@type in [.br, .hr, .doctype, .meta, .link, .title, .path] {
		p.stack.pop()
	}
}

fn is_valid_tag_name_char(c u8) bool {
	return (c >= `A` && c <= `Z`) || (c >= `a` && c <= `z`) || c == `!` || (c >= `0` && c <= `9`)
}

struct Parse {
mut:
	main_content string
	parents      []Balise
	stack        []&Balise
	in_balise    bool
	nb           int
}

fn get_tree(url string) []Balise {
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
					if c == `\n` {
						p.stack[p.stack.len - 1].attr += ' '
					} else {
						p.stack[p.stack.len - 1].attr += c.ascii_str()
					}
				}
			}
		} else {
			if c == `<` {
				if !p.process_open_tag() {
					continue parse
				}
			} else {
				if c !in [`\t`] && p.stack.len > 0 {
					p.stack[p.stack.len - 1].txt += c.ascii_str()
				}
			}
		}
		p.nb += 1
	}
	return p.parents
}

fn (mut p Parse) process_open_tag() bool {
	p.in_balise = true
	mut name := ''
	p.nb += 1
	if p.main_content[p.nb] == `/` {
		p.escape_tag()
	} else {
		old_nb := p.nb
		for p.main_content[p.nb] !in [` `, `>`, `\n`] {
			if is_valid_tag_name_char(p.main_content[p.nb]) {
				name += p.main_content[p.nb].ascii_str()
				p.nb += 1
			} else {
				p.in_balise = false
				// debug println("not name ${main_content[nb].ascii_str()}  name:${name}")
				p.stack[p.stack.len - 1].txt += '<' // to not lose the <
				p.nb = old_nb
				return false // not opening a tag
			}
		}
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
				p.stack[p.stack.len - 1].children << Balise{
					@type: vari
				}
				p.stack << &p.stack[p.stack.len - 1].children[p.stack[p.stack.len - 1].children.len - 1]
			} else {
				p.stack << &Balise{
					@type: vari
				}
			}
		} else { // does not handle all the bad cases
			println('${err} : {name}. The parser wont work as intended.')
			for p.main_content[p.nb] != `>` {
				p.nb += 1
			}
			p.in_balise = false
		}
	}
	return true // tag handled
}
