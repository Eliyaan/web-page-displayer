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

fn test_sites() {
	get_tree("https://modules.vlang.io")!
	get_tree("https://modules.vlang.io/gg.html")!
//	get_tree("https://modules.vlang.io/os.html")! //TODO FIX THIS ONE
}
