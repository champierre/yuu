extends "res://tests/test_helper.gd"
## ステージ3 の宝箱も「重なって押した」ときだけ開く。
## 通りかかっただけ、押しっぱなしで通っただけでは開かない。

func run_tests() -> void:
	print("ステージ3 の宝箱")
	var G := game()
	var s := await load_scene("res://scenes/stage3.tscn")

	## 1. ボタンを押さずに重なる → 開かない
	s.hero.position = s.chest.position
	await wait_ms(400)
	check(not G.got_bow, "触れただけでは弓を取れない")

	## 2. 押しっぱなしのまま近づく → 開かない
	##    スマホでは移動ボタンを押しながら歩くので、これで開いては困る。
	s.hero.set_scratch_pos(0, -130)
	await wait_ms(200)
	key(KEY_SPACE, true)                  ## 離れた所で押し始める
	await wait_ms(200)
	s.hero.position = s.chest.position    ## 押したまま重なる
	await wait_ms(400)
	check(not G.got_bow, "押しっぱなしのまま重なっても弓を取れない")
	key(KEY_SPACE, false)
	await wait_ms(200)

	## 3. 重なってから押す → 開く
	await press_accept()
	check(G.got_bow, "重なってから押すと弓が手に入る")
