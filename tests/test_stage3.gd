extends "res://tests/test_helper.gd"
## ステージ3「蟲」。尾だけに矢が通ること、倒すと道が開くことを確かめる。

func run_tests() -> void:
	print("ステージ3「蟲」")
	var G := game()
	var s := await load_scene("res://scenes/stage3.tscn")

	## 弓を取るまで蟲は出てこない。
	check(s._worm_head == null, "はじめは蟲がいない")
	check_eq(s.goal.text, "穴", "目標の場所は「穴」になっている")

	## 蟲がいない（まだ出ていない）だけでは、穴に触れてもクリアにならない。
	s.hero.set_scratch_pos(0, 150)
	await wait_ms(400)
	check(not s._finished, "弓を取る前に穴へ行ってもクリアにならない")
	s.hero.set_scratch_pos(0, -130)
	await wait_ms(200)

	## 宝箱から弓を取ると、蟲が穴から出てくる。
	await walk_to(s.hero, -190, -130)
	await press_accept()
	check(G.got_bow, "宝箱から弓が手に入る")
	## 出そろうまで待つ。登場は 3 秒ほどかかるが、
	## 機械の速さで前後するので、数を見て待つ。
	for i in 300:
		if s._joints.size() >= s.JOINT_COUNT and not s._emerging_now:
			break
		await wait_ms(50)
	check_eq(s._joints.size(), s.JOINT_COUNT, "節が全部出そろう")

	## 出そろうと、いちばん後ろだけが「尾」。
	var last: String = s._joints[s._joints.size() - 1].text
	check_eq(last, "尾", "いちばん後ろが尾になる")
	var others_ok := true
	for i in s._joints.size() - 1:
		if s._joints[i].text != "節":
			others_ok = false
	check(others_ok, "尾より前は全部「節」")

	## 尾を落とすと 1 つ減り、新しい末尾が尾になる。
	var before: int = s._joints.size()
	s._clear_poisons()
	await s._cut_tail()
	await _wait_ms_no_poison(s, 400)
	check_eq(s._joints.size(), before - 1, "尾を落とすと節が 1 つ減る")
	if s._joints.size() > 0:
		check_eq(s._joints[s._joints.size() - 1].text, "尾", "新しい末尾が尾になる")

	## 全部落とすと蟲が倒れ、穴が目標に変わる。
	## 残りを 1 つずつ落とす。最後の 1 つで撃破の演出に入るので、
	## そこは終わりまで待つ。
	## _cut_tail を直に呼ぶので _busy は立たない。
	## 待つ目印にはできないため、字が変わるのを見る。
	##
	## ここで勇者は宝箱の前に立ったまま動かない。本当に遊ぶときは
	## 毒を避けながら射るが、このテストは避けないので、そのままだと
	## 落としきる前に必ず毒を浴びる。浴びると _defeated が割り込み、
	## start_scene1 で穴に戻ってしまう（CI がここで落ちていた）。
	## 蟲の倒し方を確かめるのが目的なので、毒は毎回掃いておく。
	while not s._joints.is_empty():
		s._clear_poisons()
		await s._cut_tail()
		await _wait_ms_no_poison(s, 300)
	check(s._worm_head == null, "節を全部落とすと蟲が倒れる")
	## 頭が落ちて、穴が目標に変わるまで待つ。
	## _busy を見るだけだと、演出の合間に一瞬 false になることがあるので、
	## 変わったかどうかを直に見る。
	## 頭が落ちて（0.8 秒）、穴が閉じて目標が現れる（約 1 秒）まで待つ。
	## 演出の合間に _busy が一瞬 false になることがあるので、
	## 目印にはせず、変わったかどうかを直に見る。
	for i in 200:
		if s.goal.text == "目標":
			break
		await _wait_ms_no_poison(s, 100)
	check_eq(s.goal.text, "目標", "穴が目標に変わる")


## 毒を掃きながら待つ。
## 待っている間に吐かれたぶんも消さないと、そこで浴びてやり直しになる。
func _wait_ms_no_poison(s: Node, ms: int) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < ms:
		s._clear_poisons()
		await process_frame
