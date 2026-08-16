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
	check(now != null and now.name == "Title", "「戻」でタイトルへ戻る")

func _btn_pos(pad, action: String) -> Vector2:
	for b in pad.BUTTONS:
		if b["action"] == action:
			return Vector2(b["x"], pad.PAD_TOP + b["y"])
	return Vector2.ZERO
