extends "res://tests/test_helper.gd"
## ステージ3 の蟲。節が残り少なくなると攻撃が激しくなるか。
##
## 追い詰められた蟲が最後にひと暴れする。倒し際が山場になる。

## 次のひと吐きを捕まえて、そのとき出た毒を返す。
## 毒は同じコマでまとめて出るので、増えた直後に見れば一度ぶんが分かる。
func _next_volley(s: Node, ms: int) -> Array:
	s._clear_poisons()
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < ms:
		await process_frame
		if not s._poisons.is_empty():
			return s._poisons.duplicate()
	return []

## ms のあいだに吐かれた毒を数える。
## 今飛んでいる数だけを見ると、画面の外へ抜けて消えたぶんを取りこぼし、
## 間隔を変えても同じような数に見えてしまう。毎コマ見て、
## 一度でも現れたものを覚えておく。
func _count_poisons(s: Node, ms: int) -> int:
	var seen := {}
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < ms:
		for e in s._poisons:
			var p = e["node"]
			if is_instance_valid(p):
				seen[p.get_instance_id()] = true
		await process_frame
	return seen.size()

func run_tests() -> void:
	print("ステージ3 の蟲の追い込み")
	var G := game()
	var s := await load_scene("res://scenes/stage3.tscn")

	## 弓を持った状態から始める（蟲は演出なしで並ぶ）。
	G.got_bow = true
	s.start_scene1()
	await wait_ms(300)

	## 毒に当たってやり直しにならないよう、演出中と同じ状態にしておく。
	## _busy の間も蟲は動き、毒も吐かれ続ける（当たり判定だけ通らない）。
	s._busy = true
	s.hero.set_scratch_pos(0, -130)

	## まだ節がたくさんあるとき。
	var calm_volley := await _next_volley(s, 3000)
	check_eq(calm_volley.size(), 1, "ふだんの蟲は毒を 1 つずつ吐く")

	var calm := await _count_poisons(s, 3000)

	## 節を 2 つまで落とす。
	while s._joints.size() > 2:
		var j = s._joints.pop_back()
		j.queue_free()
	s._mark_tail()
	await wait_ms(100)

	var rage := await _count_poisons(s, 3000)

	check(rage >= calm * 2, "節が残り 2 つになると毒の数が増える（%d → %d）" % [calm, rage])
	## 増えるのは三方向になったぶんだけ。吐く間隔そのものは変えない。
	## 間隔まで詰めると、避ける間が無くなってしまう。
	## 測り方のぶれを見て、3 倍に少し余裕を足したところを上限にする。
	check(rage <= calm * 3 + 3,
		"吐く間隔は変えていない（三方向になったぶんだけ増える）（%d → %d）" % [calm, rage])
	check(s._worm_head != null and s._worm_head.color != s.COL_WORM,
		"荒れた蟲は色が変わって、見て分かる")

	## 荒れると、ひと吐きで三方向へまき散らす。
	var volley := await _next_volley(s, 3000)
	check_eq(volley.size(), 3, "荒れた蟲は一度に三方向へ毒を吐く")

	if volley.size() == 3:
		## 三つが違う向きに散っているか。同じ向きに重なっていては
		## 三方向にした意味がない。
		var dirs := []
		for e in volley:
			dirs.append(e["vel"].angle())
		dirs.sort()
		check(dirs[1] - dirs[0] > 0.1 and dirs[2] - dirs[1] > 0.1,
			"三つはそれぞれ違う向きへ散る（%.2f / %.2f / %.2f rad）" % dirs)

		## 飛ぶ速さは変えない。数だけ増やして、速さまで上げると
		## 避けようがなくなってしまう。
		var fastest := 0.0
		for e in volley:
			fastest = maxf(fastest, e["vel"].length())
		check(is_equal_approx(fastest, s.POISON_SPEED),
			"毒の飛ぶ速さはふだんと同じ（%.0f）" % fastest)
