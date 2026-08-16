extends "res://tests/test_helper.gd"
## debug のときだけステージ4 を選べること。
##
## 普段（アドレスに ?debug=true が無いとき）は今までどおりステージ3 まで。
## debug のときだけ、作りかけのステージ4 が選択肢に並び、そこへ入れる。

func run_tests() -> void:
	print("debug のステージ選択")
	var g := game()

	## --- 普段 ---
	g.debug = false
	check_eq(g.last_stage(), 3, "普段は最後がステージ3")
	var t := await load_scene("res://scenes/title.tscn")
	check_eq(t._stage_labels.size(), 3, "普段はステージ3 までしか並ばない")
	## 右キーを何度押してもステージ4 には行けない。
	for i in 5:
		await tap(KEY_RIGHT)
	check_eq(t._sel, 3, "普段はステージ4 を選べない")

	## --- debug ---
	g.debug = true
	check_eq(g.last_stage(), 4, "debug では最後がステージ4")
	var t2 := await load_scene("res://scenes/title.tscn")
	check_eq(t2._stage_labels.size(), 4, "debug ではステージ4 も並ぶ")
	for i in 3:
		await tap(KEY_RIGHT)
	check_eq(t2._sel, 4, "右キーでステージ4 を選べる")

	## 選んで決定すると、ステージ4 へ入れる。
	await press_accept()
	await wait_ms(2500)
	check(current_scene != null and current_scene.name == "Stage4",
		"決定でステージ4 へ移る")
	check_eq(g.stage_no, 4, "ステージ番号が 4 になる")

	## 他のテストへ持ち越さない。
	g.debug = false

## キーを 1 回押して離す。押しっぱなしは 1 回ぶんにしかならないので、
## 選び直すたびに必ず離す。
func tap(code: int) -> void:
	key(code, true)
	await wait_ms(150)
	key(code, false)
	await wait_ms(150)
