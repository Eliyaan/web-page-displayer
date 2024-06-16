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
	clip_path
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
	println(get_tree())
}

fn escape_tag(main_content string, mut parents []Balise, mut stack []&Balise, nb_ int, in_balise_ bool) (int, bool) {
	mut nb := nb_
	in_balise := false
	if stack.len == 1 {
		dump(parents)
		parents << *stack.pop()
	} else {
		stack.pop()
	}
	nb += 1
	for main_content[nb] != `>` {
		nb += 1
	}
	return nb, in_balise
}

fn get_tree() []Balise {
	res := http.get('https://modules.vlang.io/gg.html') or { panic('http get err: ${err}') }
	mut main_content := res.body
	mut parents := []Balise{}
	mut stack := []&Balise{}
	mut in_balise := false
	mut nb := 0
	parse: for nb < main_content.len {
		c := main_content[nb]
		if in_balise {
			if c == `/` {
				if main_content[nb + 1] == `>` {
					nb, in_balise = escape_tag(main_content, mut parents, mut stack, nb,
						in_balise)
				}
			} else if c == `>` {
				in_balise = false
				if stack.last().@type in [.br, .hr, .doctype, .meta, .link, .title, .path] {
					stack.pop()
				}
			} else {
				stack[stack.len - 1].attr += c.ascii_str()
			}
		} else {
			if c == `<` {
				in_balise = true
				mut name := ''
				nb += 1
				if main_content[nb] == `/` {
					nb, in_balise = escape_tag(main_content, mut parents, mut stack, nb,
						in_balise)
				} else {
					for !(main_content[nb] in [` `, `>`, `\n`]) {
						if main_content[nb] == `<` {
							continue parse
						}
						name += main_content[nb].ascii_str()
						nb += 1
					}
					name = name.to_lower()
					if name[0] == `!` {
						if name == '!doctype' {
							name = 'doctype'
						}
					} else if name[0] == `c` {
						if name == 'clipPath' {
							name = 'clip_path'
						}
					}
					if vari := Variant.from(name) {
						if main_content[nb] == `>` {
							in_balise = false
						}
						if stack.len > 0 {
							stack[stack.len - 1].children << Balise{
								@type: vari
							}
							stack << &stack[stack.len - 1].children[stack[stack.len - 1].children.len - 1]
						} else {
							stack << &Balise{
								@type: vari
							}
						}
					} else {
						println('${err} : ${name}')
						for main_content[nb] != `>` {
							nb += 1
						}
					}
				}
			} else {
				if c !in [`\n`, `\t`] {
					stack[stack.len - 1].txt += c.ascii_str()
				}
			}
		}
		dump(stack)
		//		$dbg;
		nb += 1
	}
	return parents
}
