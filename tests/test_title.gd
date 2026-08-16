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

	## ここから先は「触ったら始まるか」を見る。
	##
	## ヘッドレスでは TouchPad.needed() が false（パソコン扱い）なので、
	## 盤面を触ると始まるのが正しい。指で遊ぶ機械の側の決まりは
	## タイトルの _unhandled_input を直に呼んで確かめる。
	## （needed() は機械が決めるもので、テストからは変えられない）

	## パソコンでは、盤面を押すと始まる。
	var ev3 := InputEventScreenTouch.new()
	ev3.position = Vector2(240, 180)   ## 盤面のまんなか
	ev3.pressed = true
	ev3.index = 0
	Input.parse_input_event(ev3)
	## 始まるとタイトルは解放されるので、_started は当てにしない。
	## ステージへ移ったことで確かめる。
	await wait_ms(1500)
	check(current_scene != null and current_scene.name.begins_with("Stage"),
		"パソコンでは、盤面を押すとステージへ移る")

	## 決定キーでも始まる。
	var t2 := await load_scene("res://scenes/title.tscn")
	check(not t2._started, "開いた直後は始まっていない")
	await press_accept()
	await wait_ms(1500)
	check(current_scene != null and current_scene.name.begins_with("Stage"),
		"決定キーでステージへ移る")
