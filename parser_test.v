/*
Tests to ensure the parser works as intended
*/

module main

fn test_check_is() {
	a := Balise{
		@type: .code
		class: 'a_class'
		id: 'an_id'
	}
	assert a.check_is(.code, 'a_class', 'an_id')
	assert a.check_is(.code, 'a_class', '')
	assert a.check_is(.code, '', 'an_id')
	assert a.check_is(.code, '', '')

	assert a.check_is(.code, 'a_class', 'not_the_id') == false
	assert a.check_is(.div, 'a_class', 'not_the_id') == false
	assert a.check_is(.code, 'not_the_class', 'an_id') == false
	assert a.check_is(.code, 'not_the_class', '') == false
	assert a.check_is(.code, '', 'not_the_id') == false
	assert a.check_is(.div, '', '') == false
}

fn test_is_valid_tag_name_char() {
	assert is_valid_tag_name_char(`a`)
	assert is_valid_tag_name_char(`b`)
	assert is_valid_tag_name_char(`n`)
	assert is_valid_tag_name_char(`y`)
	assert is_valid_tag_name_char(`z`)
	assert is_valid_tag_name_char(`A`)
	assert is_valid_tag_name_char(`B`)
	assert is_valid_tag_name_char(`N`)
	assert is_valid_tag_name_char(`Y`)
	assert is_valid_tag_name_char(`Z`)
	assert is_valid_tag_name_char(`0`)
	assert is_valid_tag_name_char(`2`)
	assert is_valid_tag_name_char(`5`)
	assert is_valid_tag_name_char(`9`)
	assert is_valid_tag_name_char(`!`) // for <!doctype html>
	assert is_valid_tag_name_char(`é`) == false
	assert is_valid_tag_name_char(`#`) == false
	assert is_valid_tag_name_char(`\``) == false
	assert is_valid_tag_name_char(`,`) == false
	assert is_valid_tag_name_char(`:`) == false
}

fn test_close_tag() {
	mut b := &Balise{
		@type: .html
		attr: 'href="hey" id="hello href" class="hi id"'
	}
	mut p := Parse{
		in_balise: true
		stack: [&Balise{}, b]
	}
	check_close_tag(mut p)
	assert b.attr == ''
	assert b.href == 'hey'
	assert b.id == 'hello href'
	assert b.class == 'hi id'
	mut p2 := Parse{
		in_balise: true
		stack: [&Balise{
			@type: .br
		}]
	}
	check_close_tag(mut p2)
}

fn check_close_tag(mut p Parse) {
	is_closing := !is_not_closing(p.stack[p.stack.len - 1])
	old_len := p.stack.len
	p.close_tag()
	assert p.in_balise == false
	assert is_closing || p.stack.len == old_len - 1
}

fn test_is_actual_content() {
	mut p := Parse{}
	assert p.is_actual_content(`a`) == false
	assert p.is_actual_content(`\t`) == false
	p.code = true
	assert p.is_actual_content(`\t`) == false
	p.stack << &Balise{}
	assert p.is_actual_content(`a`) == true
	assert p.is_actual_content(`\t`) == true
	p.code = false
	assert p.is_actual_content(`\t`) == false
}

fn test_sites() {
	get_tree('https://modules.vlang.io')!
	get_tree('https://modules.vlang.io/gg.html')!
	//	get_tree("https://modules.vlang.io/os.html")! //TODO FIX THIS ONE
}
