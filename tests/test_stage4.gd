extends "res://tests/test_helper.gd"
## ステージ4「灯」。暗い洞窟で、燭に火を移して明かりを作りながら進む。
##
## 座標を書き込むだけのテストでは「そもそもそこへ行けるのか」が分からない
## （CLAUDE.md の「座標を書き込むテストだけでは足りない」）ので、
## キーで歩いて宝箱に届き、火矢で燭を点し、目標まで行けることを確かめる。

func run_tests() -> void:
	print("ステージ4「灯」")
	var g := game()
	g.debug = true
	g.stage_no = 4

	var s := await load_scene("res://scenes/stage4.tscn")
	check(s != null and s.name == "Stage4", "ステージ4 が読み込める")
	if s == null:
		return

	## 洞窟は闇に閉ざされている。遠くのものは見えない。
	check(s._darks.size() > 0, "闇が敷き詰められている")
	check(not s.goal.visible, "はじめは目標が見えない")
	check_eq(s._lit.size(), 0, "はじめは灯が 1 つも点いていない")

	## 入った所だけは見える。何をすればよいか分からなくなるため。
	check(s.chest.visible, "入口の宝箱は見えている")

	## 宝箱まで歩いて弓を取る。
	var p: Vector2 = s.chest.scratch_pos()
	check(await walk_to(s.hero, p.x, p.y), "宝箱まで歩いていける")
	await press_accept()
	check(g.got_bow, "宝箱から弓が手に入る")
	check_eq(s.chest.text, "空箱", "開けた宝箱は空箱になる")

	## 暗くて見えない燭には当たらない。
	## 「見えている所しか射てない」がこのステージの肝。
	var far: Node = s._lamps[3]
	check(not far.visible, "遠くの燭はまだ見えない")

	## 手前の燭へ歩いて近づくと、勇者の明かりで見えるようになる。
	var lamp0: Node = s._lamps[0]
	var lp: Vector2 = lamp0.scratch_pos()
	await walk_to(s.hero, lp.x, lp.y + 40.0)
	await wait_ms(200)
	check(lamp0.visible, "近づくと燭が見えるようになる")

	## 火矢を当てて点す。演出を待たず、仕掛けを直に呼んで確かめる。
	await s._light_lamp(lamp0)
	await wait_ms(200)
	check_eq(lamp0.text, "灯", "燭に火が移ると「灯」になる")
	check_eq(s._lit.size(), 1, "点いた灯が数えられている")

	## 灯の周りが明るくなる。
	check(s._light_at(lamp0.position) > 0.9, "灯のある所は明るい")
	check(s._light_at(lamp0.position + Vector2(60, 0)) > 0.0, "灯の周りも明るくなる")

	## 岩は歩いて越えられない。
	## 越えられてしまうと、道を選ばせる意味が無くなる。
	var rocks: Array = s.rock_root.get_children()
	check(rocks.size() > 0, "岩が置かれている")
	check(s.hero.blockers == s.rock_root, "岩はぶつかる相手に入っている")

	## 残りの燭も点して、明かりを作りながら奥へ進む。
	for i in range(1, s._lamps.size()):
		await s._light_lamp(s._lamps[i])
	await wait_ms(200)
	check_eq(s._lit.size(), s._lamps.size(), "燭を全部点せる")

	## 明るくなったので目標が見える。
	await wait_ms(200)
	check(s.goal.visible, "灯を点すと目標が見えるようになる")

	## 目標まで歩いてクリアする。**蝙は消さない。**
	##
	## 消して確かめると「そもそも遊べるのか」が分からなくなる。
	## 実際、蝙が目標に居座って永久に近寄れない配置になっていたことがあり、
	## 蝙を消したテストでは通ってしまっていた。
	## 目標は重なった時点でクリアになるので、中心まで歩き切る前に止まる。
	## walk_to の「中心に着いたか」では見ずに、触れたかどうかで見る。
	var q: Vector2 = s.goal.scratch_pos()
	for i in 400:
		if s._finished or s.hero.touching(s.goal):
			break
		var hp: Vector2 = s.hero.scratch_pos()
		if hp.x < q.x - 3.0: await step(KEY_RIGHT)
		elif hp.x > q.x + 3.0: await step(KEY_LEFT)
		if hp.y < q.y - 3.0: await step(KEY_UP)
		elif hp.y > q.y + 3.0: await step(KEY_DOWN)
		await process_frame
	check(s.hero.touching(s.goal) or s._finished, "目標まで歩いていける")
	await wait_ms(500)
	check(s._finished, "目標に触れるとクリアになる")

	g.debug = false
	g.stage_no = 1
