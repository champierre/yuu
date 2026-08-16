extends "res://tests/test_helper.gd"
## ステージ3 で弓を引き絞っている間の動き。
##
## まったく動けないと、毒を避けながら狙う遊びが成り立たない。
## 足が止まるのではなく、遅くなるだけにする。

## 右キーを frames コマぶん押しっぱなしにして、進んだ距離を返す。
## ヘッドレスは 1 コマが極端に短いので、実時間ではなくコマ数で測る。
func _run_right(hero: Node, frames: int) -> float:
	var x0: float = hero.scratch_pos().x
	key(KEY_RIGHT, true)
	for i in frames:
		await process_frame
	key(KEY_RIGHT, false)
	await process_frame
	return hero.scratch_pos().x - x0

func run_tests() -> void:
	print("ステージ3 の引き絞り中の動き")
	var G := game()
	var s := await load_scene("res://scenes/stage3.tscn")

	## 弓を持った状態から始める。
	G.got_bow = true
	s.start_scene1()
	await wait_ms(300)
	## 蟲と毒に邪魔されずに歩きだけを測る。
	s._clear_worm()
	## 画面の右端に当たらないよう、左寄りから測る。
	s.hero.set_scratch_pos(-150, -130)
	await wait_ms(200)

	var normal := await _run_right(s.hero, 10)
	check(normal > 0.0, "ふだんは右へ歩ける（%.1f px）" % normal)

	## 決定を押しっぱなしにして引き絞る。
	key(KEY_SPACE, true)
	await wait_ms(150)
	check(s.hero.can_move, "引き絞っていても動ける")

	var drawing := await _run_right(s.hero, 10)
	check(drawing > 0.0, "引き絞っている間も歩ける（%.1f px）" % drawing)

	if normal > 0.0:
		var ratio := drawing / normal
		check(ratio > 0.2 and ratio < 0.5,
			"引き絞り中の速さはふだんの 3 分の 1 ほど（%.2f 倍）" % ratio)

	## 放したら元の速さに戻る。
	key(KEY_SPACE, false)
	await wait_ms(800)
	var sc = s.hero.get("speed_scale")
	check(sc != null and is_equal_approx(float(sc), 1.0), "放したら速さが戻る")
