extends "res://tests/test_helper.gd"
## 「戻」でタイトルへ帰ったあと、そのままステージが始まってしまわないか。
##
## スマホの操作ボタンで遊んでいるとき、一度も「押」を押さずに「戻」を押すと、
## 一瞬タイトルが出たあと、すぐステージ1 に戻ってしまうことがあった。

func run_tests() -> void:
	print("「戻」でタイトルへ帰る")

	## タイトルから「押」でステージ1 を始め、一度も「押」を押さずに「戻」で帰る。
	## 実際の遊びと同じ順でたどる（タイトル → ステージ1 → タイトル）。
	var t := await load_scene("res://scenes/title.tscn")
	check(t != null and t.name == "Title", "タイトルが開く")

	## タイトルの操作ボタンから「押」でステージ1 を始める。
	var pad = _find_pad(t)
	if pad == null:
		pad = load("res://scripts/touch_pad.gd").new()
		t.add_child(pad)
		await wait_ms(200)
	var acc := _btn_pos(pad, "ui_accept")
	pad._press_at(acc, 0)
	await wait_ms(200)
	## 場面が変わったあとで指を離す（実際の遊びと同じ順）。
	var up := InputEventScreenTouch.new()
	up.position = acc
	up.pressed = false
	up.index = 0
	Input.parse_input_event(up)
	await wait_ms(2500)

	var st := current_scene
	check(st != null and st.name == "Stage1", "「押」でステージ1 が始まる")

	## ステージ1 の操作ボタンで「戻」を押す。「押」は一度も押さない。
	var p2 = _find_pad(st)
	if p2 == null:
		p2 = load("res://scripts/touch_pad.gd").new()
		st.add_child(p2)
		await wait_ms(200)
	var back := _btn_pos(p2, "ui_cancel")
	p2._press_at(back, 0)
	await wait_ms(600)
	## タイトルへ帰ったあとで指を離す（実際の遊びと同じ順）。
	var ev := InputEventScreenTouch.new()
	ev.position = back
	ev.pressed = false
	ev.index = 0
	Input.parse_input_event(ev)

	## しばらく見ていて、タイトルのままでいるか。
	## ここで勝手にステージ1 へ戻ってしまうのが、この不具合。
	await wait_ms(2500)
	var now := current_scene
	check(now != null and now.name == "Title", "「戻」のあと、タイトルのままでいる")

## その場面が持っている操作ボタンを探す。
func _find_pad(scene: Node):
	for c in scene.get_children():
		if c.get_script() != null and c.get_script().resource_path.ends_with("touch_pad.gd"):
			return c
	return null

func _btn_pos(pad, action: String) -> Vector2:
	for b in pad.BUTTONS:
		if b["action"] == action:
			return Vector2(b["x"], pad.PAD_TOP + b["y"])
	return Vector2.ZERO
