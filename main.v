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
	script
	a
	html
	body
	header
	section
	li
	ul
}

struct Balise { // replace with english name
mut:
	@type Variant
	attr string // inside the balise
	children []Balise
	txt string // raw text between start/end of the balise
}

fn main() {
	println(get_tree())
}

fn get_tree() []Balise {
	res := http.get("https://modules.vlang.io/os.html") or {panic("http get err: ${err}")}
	mut main_content := res.body
	mut parents := []Balise{}
	mut stack := []&Balise{}
	mut in_balise := false
	mut nb := 0
	for nb < main_content.len {
		c := main_content[nb]
		if in_balise {
			if c == `/` {
				dump("\\")
				if stack.len == 1 {
					parents << *stack.pop()
				} else {
					stack.pop()
				}
				nb += 1
				for main_content[nb] != `>` {
					nb += 1
				}
				in_balise = false
			} 
			else if c == `>` {
				dump(">")
				in_balise = false
				if stack.last().@type in [.br, .doctype, .meta, .link, .title, .path]{
					stack.pop()
				}
			} 
			else {
				dump("attr ${c.ascii_str()}|")
				//if !(c in [`\t`]) {
					stack[stack.len-1].attr += c.ascii_str()
				//}
			}
		} else {
			if c == `<` {
				dump("<")
				in_balise = true
				mut name := ""
				nb += 1
				for main_content[nb] != ` ` && main_content[nb] != `>` {
					name += main_content[nb].ascii_str()	
					nb += 1
				}
				if main_content[nb] == `>` {
					in_balise = false
				}
				if name[0] == `!` {
					if name == "!doctype" {
						name = "doctype"
					}
				} else if name[0] == `c` {
					if name == "clipPath" {
						name = "clip_path"
					}
				}
				if stack.len > 0 {
					stack[stack.len-1].children << Balise{@type:Variant.from(name) or {panic("${err} : ${name}")}}
					stack << &stack[stack.len-1].children[stack[stack.len-1].children.len-1]
				} else {
					stack << &Balise{@type:Variant.from(name) or {panic("${err} : ${name}")}}
				}
			} else {
				dump("txt ${c.ascii_str()}|")
				if !(c in [`\n`, `\t`]) {
					stack[stack.len-1].txt += c.ascii_str()
				}
			}
		}
		dump(stack)	
		$dbg
		nb += 1
	}
	return parents
}
