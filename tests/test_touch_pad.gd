extends "res://tests/test_helper.gd"
## 画面のボタン（スマホ用）。押した・離したが正しく届くか。

func run_tests() -> void:
	print("画面のボタン")
	var s := await load_scene("res://scenes/stage3.tscn")
	var pad = load("res://scripts/touch_pad.gd").new()
	s.add_child(pad)
	await wait_ms(200)

	## ボタンが揃っているか。
	check_eq(pad._labels.size(), 6, "ボタンが 6 つある（上下左右・押・戻）")

	## 押すと、そのキーが押されたことになる。
	for action in ["ui_up", "ui_down", "ui_left", "ui_right", "ui_accept"]:
		var pos := _btn_pos(pad, action)
		pad._press_at(pos, 0)
		await wait_ms(120)
		var on: bool = Input.is_action_pressed(action)
		pad._release(0)
		await wait_ms(120)
		var off: bool = not Input.is_action_pressed(action)
		check(on and off, "%s が押して離せる" % action)

	## 「戻」を押すとタイトルへ戻る。
	## これが効かないと、スマホでは遊びをやめられない。
	## 押した時点で場面が変わるので、離す前に確かめる。
	var back := _btn_pos(pad, "ui_cancel")
	pad._press_at(back, 0)
	await wait_ms(900)
	var now := current_scene
	check(now != null and now.name == "Title", "「戻」でタイトルへ戻る（ステージ3）")

## 3 つのステージすべてで「戻」が効くか。
## どれか 1 つで効かないと、そこから抜けられなくなる。
	for scene in ["stage1", "stage2", "stage3"]:
		var st := await load_scene("res://scenes/%s.tscn" % scene)
		var p2 = load("res://scripts/touch_pad.gd").new()
		st.add_child(p2)
		await wait_ms(200)
		p2._press_at(_btn_pos(p2, "ui_cancel"), 0)
		await wait_ms(900)
		var after := current_scene
		check(after != null and after.name == "Title", "%s で「戻」が効く" % scene)
	## 「戻」で帰ったあと、そのまま遊びが始まってしまわないか。
	## 押した指を離すと、タイトルが「画面を触った」と受け取って
	## ステージが始まってしまうことがあった。
	var st2 := await load_scene("res://scenes/stage2.tscn")
	var p3 = load("res://scripts/touch_pad.gd").new()
	st2.add_child(p3)
	await wait_ms(200)
	var bpos := _btn_pos(p3, "ui_cancel")
	p3._press_at(bpos, 0)
	await wait_ms(600)
	## タイトルへ帰ったあとで指を離す（実際の遊びと同じ順）。
	var t := current_scene
	var ev := InputEventScreenTouch.new()
	ev.position = bpos
	ev.pressed = false
	ev.index = 0
	Input.parse_input_event(ev)
	await wait_ms(800)
	var now2 := current_scene
	check(now2 != null and now2.name == "Title", "「戻」のあと、そのまま始まらない")

func _btn_pos(pad, action: String) -> Vector2:
	for b in pad.BUTTONS:
		if b["action"] == action:
			return Vector2(b["x"], pad.PAD_TOP + b["y"])
	return Vector2.ZERO
