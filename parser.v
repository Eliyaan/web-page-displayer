module main

import net.http

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
@[direct_array_access]
fn get_tree(url string) []Balise {
	println('___________________\nGetting ${url}')
	res := http.get(url) or { panic('http get err: ${err}') }
	mut p := Parse{
		main_content: res.body
	}
	parse: for p.nb < p.main_content.len {
		c := p.main_content[p.nb]
		if p.in_balise {
			if c == `/` && p.main_content[p.nb + 1] == `>` {
				if is_not_closing(p.stack.last()) {
					println('if ${p.stack.last().@type} seems to be a not-closing tag, please add it to the non-closing array')
				}
				p.close_tag()
				p.nb++
			} else if c == `>` {
				p.close_tag()
			} else {
				if c != `\t` {
					mut tag := p.stack[p.stack.len - 1]

					if c == `\n` {
						tag.attr += ' '
					} else {
						tag.attr += c.ascii_str()
					}
				}
			}
		} else {
			if c == `<` {
				p.process_open_tag()
			} else {
				if (c != `\t` || p.code) && p.stack.len > 0 {
					mut last := p.stack[p.stack.len - 1]
					mut l := last.children.len
					if l == 0 || last.children[l - 1] is Balise {
						last.children << RawText{}
					} else {
					} // no problem
					l = last.children.len
					mut raw_txt := &last.children[l - 1]
					if mut raw_txt is RawText {
						if c == `\t` {
							raw_txt.txt += '    '
						} else {
							raw_txt.txt += c.ascii_str()
						}
					} else {
						panic('handle not rawtext ${@FILE_LINE}')
					}
				}
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
fn (mut last Balise) process_attr() {
	if i := last.attr.index('class=') {
		start := i + 7 // class="
		mut end := start + 1
		for c in last.attr[start + 1..] { // search the closing "
			if c == `"` {
				break
			}
			end += 1
		}
		last.class = last.attr[start..end]
	}
	if i := last.attr.index('id=') {
		start := i + 4 // id="
		mut end := start + 1
		for c in last.attr[start + 1..] {
			if c == `"` {
				break
			}
			end += 1
		}
		last.id = last.attr[start..end]
	}
	if i := last.attr.index('href=') {
		start := i + 6
		mut end := start + 1
		for c in last.attr[start + 1..] {
			if c == `"` {
				break
			}
			end += 1
		}
		last.href = last.attr[start..end]
	}
	last.attr = '' // free memory I guess
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
