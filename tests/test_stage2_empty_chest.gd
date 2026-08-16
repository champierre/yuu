extends "res://tests/test_helper.gd"
## ステージ2 の空箱。鉄を手にしたあと、もう一度押しても何も起きないか。
##
## 盗まれた時点で got_gold は false に戻り、鉄になると lost_gold も下りる。
## そのため何も守りを入れないと「まだ金を取っていない」と見なされ、
## 空箱からもう一度「金」が出てきて、持ち物の鉄が金に化けてしまう。

func run_tests() -> void:
	print("ステージ2 の空箱")
	var G := game()
	var s := await load_scene("res://scenes/stage2.tscn")

	## 鉄を手にしたあとの状態を作る。
	G.got_gold = false
	G.lost_gold = false
	G.got_iron = true
	s.chest.text = "空箱"
	s.item.visible = true
	s.item.text = "鉄"
	s.item.color = s.COL_IRON

	## 空箱に重なって決定を押す。
	s.hero.position = s.chest.position
	await wait_ms(200)
	await press_accept()
	await wait_ms(400)

	check(not G.got_gold, "空箱を押しても金は出てこない")
	check_eq(s.item.text, "鉄", "持ち物は鉄のまま")
	check_eq(s.chest.text, "空箱", "宝箱は空箱のまま")
