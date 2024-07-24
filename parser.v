module main

import net.http

const used_attrs = ['class', 'id', 'href']

// not tested
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

// not tested
fn is_not_closing(b Balise) bool {
	return b.@type in not_closing
}

// not tested
fn (mut p Parse) handle_end_of_not_closing_tag() {
	if !is_not_closing(p.stack.last()) {
		println('${p.stack.last().@type} seems to be a not-closing tag, please add it to the non-closing array')
	}
	p.close_tag()
	p.nb++
}

// not tested
fn (mut p Parse) handle_attr_text(c u8) {
	if c != `\t` {
		mut top := p.stack[p.stack.len - 1]

		if c == `\n` {
			top.attr += ' '
		} else {
			top.attr += c.ascii_str()
		}
	}
}

// not tested
fn is_end_of_not_closing_tag(c u8, c_1 u8) bool {
	return c == `/` && c_1 == `>`
}

// not tested
@[direct_array_access]
fn get_tree(url string) []Balise {
	println('___________________\nGetting ${url}')
	res := http.get(url) or { panic('http get err: ${err}') }
	mut p := Parse{
		main_content: res.body
	}
	for p.nb < p.main_content.len {
		c := p.main_content[p.nb]
		if p.in_balise {
			if is_end_of_not_closing_tag(c, p.main_content[p.nb + 1]) {
				p.handle_end_of_not_closing_tag()
			} else if c == `>` {
				p.close_tag()
			} else {
				p.handle_attr_text(c)
			}
		} else {
			if c == `<` {
				p.process_open_tag()
			} else {
				p.process_text_char(c)
			}
		}
		p.nb += 1
	}
	if p.parents.len == 0 {
		dump(p)
		for elem in p.stack {
			println(elem.@type)
		}
		println('p.parents is empty, see parse tree info above')
	} else {
		println('Got & parsed ${url}')
	}
	return p.parents
}

// not tested
fn (mut b Balise) ensure_last_children_is_rawtext() {
	l := b.children.len
	if l == 0 || b.children[l - 1] is Balise {
		b.children << RawText{}
	}
}

// not tested
fn (p Parse) is_actual_content(c u8) bool {
	has_page_started := p.stack.len > 0
	is_not_unwanted_tabs := c != `\t` || p.code
	return is_not_unwanted_tabs && has_page_started
}

// not tested
fn (mut p Parse) process_text_char(c u8) {
	if p.is_actual_content(c) {
		mut top := p.stack[p.stack.len - 1]
		top.ensure_last_children_is_rawtext()
		mut raw_txt := &(top.children[top.children.len - 1] as RawText)
		if c == `\t` {
			raw_txt.txt += '    '
		} else {
			raw_txt.txt += c.ascii_str()
		}
	}
}

// not tested
@[direct_array_access]
fn (mut p Parse) escape_tag() {
	p.in_balise = false
	if p.stack.len == 1 {
		p.parents << *p.stack.pop()
		if p.parents.last().@type == .code {
			p.code = false
		}
	} else {
		mut last := p.stack[p.stack.len - 1]
		last.process_attr()
		for mut last_child in last.children {
			if mut last_child is RawText {
				last_child.split_txt = last_child.txt.split('\n')
			}
		}
		p.stack.pop()
	}
	p.nb += 1
	for p.main_content[p.nb] != `>` {
		p.nb += 1
	}
}

// not tested
fn (mut b Balise) process_attr() {
	for attr_name in used_attrs {
		if i := b.attr.index(attr_name + '="') {
			start := i + attr_name.len + 2 // + '="'.len
			mut end := start + 1
			for c in b.attr[start + 1..] { // search the closing "
				if c == `"` {
					break
				}
				end += 1
			}
			attr_str := b.attr[start..end]
			match attr_name {
				'class' { b.class = attr_str }
				'id' { b.id = attr_str }
				'href' { b.href = attr_str }
				else { panic('${attr_name} attr not handled') }
			}
		}
	}
	b.attr = '' // free memory I guess
}

// not tested
fn (mut p Parse) close_tag() {
	p.in_balise = false
	mut last := p.stack[p.stack.len - 1]
	last.process_attr()
	if is_not_closing(last) {
		p.stack.pop()
	}
}

// not tested
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
				empty := last.children.len == 0
				if empty {
					last.children << RawText{}
				}
				mut child := &last.children[last.children.len - 1]
				if mut child is RawText {
					child.txt += '<' // to not lose the <
				} else {
					panic('handle not raw text ${@FILE_LINE}')
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
					last.children << Balise{
						@type: vari
					}
					p.stack << &(last.children[last.children.len - 1] as Balise)
				} else {
					p.stack << &Balise{
						@type: vari
					}
				}
				if vari == .code {
					p.code = true
				}
			} else { // does not handle all the bad cases
				println(p.main_content[p.nb - 10..p.nb + 10])
				println('${err} : `${name}` The parser wont work as intended.')
				for p.main_content[p.nb] != `>` {
					p.nb += 1
				}
				p.in_balise = false
			}
		} else {
			p.in_balise = false
			p.nb -= 1
			mut last := p.stack[p.stack.len - 1]
			mut child := &last.children[last.children.len - 1]
			if mut child is RawText {
				child.txt += '<' // to not lose the <			
			} else {
				panic('handle not rawtext ${@FILE_LINE}')
			}
		}
	}
}

fn is_valid_tag_name_char(c u8) bool {
	return (c >= `A` && c <= `Z`) || (c >= `a` && c <= `z`) || c == `!` || (c >= `0` && c <= `9`)
}