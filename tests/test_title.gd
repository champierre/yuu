extends "res://tests/test_helper.gd"
## タイトル画面。ステージを選べること、選ぶ操作で始まってしまわないこと。

func run_tests() -> void:
	print("タイトル")
	change_scene_to_file("res://scenes/title.tscn")
	await wait_ms(900)
	var t := current_scene

	check_eq(t._stage_labels.size(), game().STAGE_MAX, "ステージの数だけ選べる")
	check_eq(t._sel, 1, "はじめはステージ1 が選ばれている")

	## 右キーで次のステージへ。
	key(KEY_RIGHT, true)
	await wait_ms(150)
	key(KEY_RIGHT, false)
	await wait_ms(150)
	check_eq(t._sel, 2, "右キーで選ぶステージが変わる")
	check(not t._started, "選んだだけでは始まらない")

	## 押しっぱなしでも 1 回ぶんしか進まない。
	key(KEY_RIGHT, true)
	await wait_ms(500)
	key(KEY_RIGHT, false)
	await wait_ms(150)
	check_eq(t._sel, 3, "押しっぱなしでも一気に進まない")

	## 操作ボタンの帯を触っても始まらない。
	## 指で触る機械では、タップがマウスの押し下げとしても届くため、
	## ここを守らないとステージを選ぼうとした指で始まってしまう。
	var ev := InputEventScreenTouch.new()
	ev.position = Vector2(112, 490)   ## 盤面 (高さ360) より下＝ボタンの帯
	ev.pressed = true
	ev.index = 0
	Input.parse_input_event(ev)
	await wait_ms(300)
	check(not t._started, "操作ボタンの帯を触っても始まらない")

	## 帯かどうかの見分けが正しいか（触った場所で判断している）。
	check(t._on_pad(Vector2(112, 490)), "盤面より下は操作ボタンの帯")
	check(not t._on_pad(Vector2(240, 180)), "盤面の中は帯ではない")

	## 決定キーで始まる。
	await press_accept()
	await wait_ms(400)
	check(t._started if is_instance_valid(t) else true, "決定キーで始まる")
