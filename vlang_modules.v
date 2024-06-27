import gg
import gx

struct VlangModules {
mut:
	tree   []Element
	readme []string
	text_cfg gx.TextCfg = gx.TextCfg { size: 18, color:gg.Color{255, 255, 255, 255}}
}

fn (mut r VlangModules) render(mut app App) {
	if gg.window_size() != app.s_size {
		app.s_size = gg.window_size()
		r.readme = organise_render(r.tree[0].get(.div, 'doc-content', '') or {
			panic("did not find elem in page")
		}.raw_text(), r.text_cfg.size, app.s_size.width-600)
	}
	app.ctx.draw_rect_filled(0, 0, app.s_size.width, app.s_size.height, gg.Color{26, 32, 44, 255})
	mut h := -app.scroll
	line_height :=  (r.text_cfg.size * 6)/5
	for l in r.readme {
		if l != '' {
			if h >= -line_height && h < app.s_size.height {
				app.ctx.draw_text(300, h, l, r.text_cfg)
			}
			h += line_height
		}
	}
}
