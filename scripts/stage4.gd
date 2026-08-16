extends StageBase
## ステージ 4「灯」。ステージ3 の蟲を倒して入った、穴の先の洞窟。
##
## 【解き方】洞窟は「闇」に閉ざされ、道も目標も見えない。
## 宝箱の弓で「燭」を射ると火が移って「灯」になり、その周りだけが明るくなる。
## 灯を点しながら明かりを伝って進み、目標へたどり着く。
##
## 洞窟の主「蝙」は明かりを嫌う。点した灯がそのまま安全地帯になるので、
## 「明るくすること」が道を作ることと身を守ることの両方を兼ねる。
##
## 火矢は勇者の向いている方へ飛ぶ（ステージ3 の矢は真上だけだった）。
## ためた分だけ遠くまで届くので、奥の燭ほどしっかり引き絞る必要がある。

const COL_DARK := Color("#1a1a2e")    ## 闇
const COL_LAMP := Color("#8a7a5a")    ## まだ点いていない燭
const COL_LIT := Color("#e8a020")     ## 点いた灯
const COL_ROCK := Color("#6a6a6a")    ## 岩
const COL_BAT := Color("#6a4a8a")     ## 蝙
const COL_BOW := Color("#66421f")     ## 弓
const COL_BOW_FULL := Color("#e8a020") ## 引き絞りきった弓（もう放てる合図）
const COL_FIRE := Color("#e85a20")    ## 火矢
const COL_HARD := Color("#a7a7a7")    ## 弾かれた印
const COL_HURT := Color("#bb3023")    ## やられた印
## 引き絞って力んでいる勇者「疲」の色（ステージ3 と揃える）。
const COL_STRAIN_LOW := Color("#e8c020")
const COL_STRAIN_MID := Color("#e87a20")
const COL_STRAIN_HIGH := Color("#d02020")

## 明かりの届く広さ。灯は広く、勇者の手持ちの火は狭い。
## 勇者のぶんを狭くしておかないと、歩くだけで洞窟が見えてしまう。
##
## ただし狭すぎてもいけない。燭が見えるより先に触れてしまう距離だと、
## 弓で射る意味が無くなる（歩いて行って手で点けるのと変わらない）。
## 「見えるけれど、まだ遠い」が成り立つ広さにしてある。
const LIGHT_R_LAMP := 100.0
const LIGHT_R_HERO := 90.0
## これ以上明るい所には蝙が入ってこない。
const LIGHT_SAFE := 0.25
## これより暗いものは見えない扱いにする（当たり判定からも外れる）。
const LIGHT_MIN := 0.06

## 闇を敷き詰める刻み幅。細かくすると数が増えて重くなる。
const DARK_STEP := 24.0

## 弓と火矢（ステージ3 から引き継ぐ手触り）。
const BOW_OFFSET := Vector2(16, -16)
const CHARGE_TIME := 0.8
const BOW_THIN := 0.55
const BOW_THICK := 1.8
const HOLD_LIMIT := 1.2
const EXHAUST_TIME := 1.4
const STRAIN_GROW := 0.5
const ARROW_SPEED_MIN := 300.0
const ARROW_SPEED_MAX := 760.0
const ARROW_RANGE_MIN := 20.0
const ARROW_RANGE_MAX := 300.0
const ARROW_LIFE := 2.0
const ARROW_MUZZLE_DIST := 18.0
const ARROW_REACH := 12.0

## 蝙の動き。
const BAT_SPEED := 42.0
const BAT_TURN := 1.4

## 置いてあるものの場所（Scratch 座標）。
const HERO_POS := Vector2(-190, -130)
## 宝箱は勇者のすぐそば。入った所が見えないと、何をすればよいか分からない。
const CHEST_POS := Vector2(-150, -120)
const GOAL_POS := Vector2(190, 130)

## 燭の場所。手前から奥へ。勇者はこれを順に点しながら進む。
## 最後の 1 つは遠いので、しっかり引き絞らないと届かない。
const LAMP_POS := [
	Vector2(-120, 10),
	Vector2(-10, -70),
	Vector2(60, 60),
	Vector2(170, 60),
]

## 岩の場所。行く手を狭めて、道を選ばせる。
##
## 通り道は必ず 40px 以上空けること。勇者は 20x30 なので、
## それより狭いと入れず、遠回りもできないと詰んでしまう。
## 岩は 24px 四方に見えるが、当たり判定はもう少し大きい。
const ROCK_POS := [
	## 入口の右。下を回れば抜けられる。
	Vector2(-60, -130), Vector2(-60, -100),
	## まん中の仕切り。上下どちらからでも回り込める。
	Vector2(20, 60), Vector2(20, 30), Vector2(20, 0),
	## 奥の手前。上を回れば抜けられる。
	Vector2(110, -60), Vector2(110, -90), Vector2(110, -120),
]

## 蝙のはじめの場所。目標のそばには置かない。
## 目標に居座られると、明かりを点しても近寄れなくなってしまう。
const BAT_POS := [
	Vector2(-30, 90),
	Vector2(80, -110),
]

## 目標のまわりのこの広さには蝙を入れない。
## クリアの直前で理不尽に阻まれるのを防ぐ。
const BAT_KEEP_OUT := 70.0

@onready var hero: KanjiSprite = $Hero
@onready var chest: KanjiSprite = $Chest
@onready var bow: KanjiSprite = $Bow
@onready var goal: KanjiSprite = $Goal
@onready var dark_root: Node2D = $Dark
@onready var lamp_root: Node2D = $Lamps
@onready var rock_root: Node2D = $Rocks
@onready var bat_root: Node2D = $Bats

var _lamps: Array = []      ## 燭（点くと「灯」になる）
var _lit: Array = []        ## 点いた灯だけを集めたもの。明かりの元
var _darks: Array = []      ## 敷き詰めた闇
var _bats: Array = []       ## 蝙
var _bat_dirs: Array = []   ## 蝙の進む向き

var _charge := 0.0          ## 引き絞り具合（0〜1）
var _hold_time := 0.0       ## 引き絞りきったまま粘っている時間
var _shoot_was_down := false ## 前のコマで決定が押されていたか（弓用）
var _await_release := false  ## 一度離すまで引き絞りを始めない
var _shooting := false      ## 矢が飛んでいる最中

func _ready() -> void:
	## Game.reset() は stage_no を 1 に戻してしまうのでここでは呼ばない（落とし穴 1）。
	Game.reset_stage()
	## エディタからこのシーンだけを開いたときのための保険。
	Game.stage_no = 4

	## 岩にぶつかる。ぶつかるものを集めた入れ物を渡す（落とし穴 8）。
	hero.blockers = rock_root

	## 操作ボタンは、指で触れる機械のときだけ出す。
	## そのときは「戻」ボタンから帰れるので、Esc の案内は出さない。
	if TouchPad.needed():
		add_child(TouchPad.new())
	else:
		Effects.show_escape_hint(self)

	## 先に場面を組んでから待つ（組む前に待つと、初期配置が一瞬見えてしまう）。
	_build_scene()
	_busy = true
	if not await wait(1.0):
		return
	_busy = false

# ---------------------------------------------------------------- 場面を組む

## 使うものは全部ここで見た目を決める（落とし穴 6）。
func _build_scene() -> void:
	Game.scene_no = 1
	Game.got_bow = false
	_charge = 0.0
	_hold_time = 0.0
	_shoot_was_down = false
	_await_release = false
	_shooting = false

	hero.text = "勇"
	hero.color = Color.BLACK
	hero.vertical = false
	hero.scale = Vector2.ONE
	hero.rotation = 0.0
	hero.modulate.a = 1.0
	hero.visible = true
	hero.can_move = true
	hero.set_scratch_pos(HERO_POS.x, HERO_POS.y)

	chest.text = "宝箱"
	chest.color = COL_CHEST
	chest.scale = Vector2.ONE
	chest.visible = true
	chest.set_scratch_pos(CHEST_POS.x, CHEST_POS.y)

	## 弓は取るまで見せない。
	bow.text = "弓"
	bow.color = COL_BOW
	bow.vertical = false
	bow.rotation = 0.0
	bow.scale = Vector2(BOW_THIN, 1.0)
	bow.visible = false

	goal.text = "目標"
	goal.color = COL_GOAL
	goal.scale = Vector2.ONE
	goal.z_index = 0
	goal.visible = true
	goal.set_scratch_pos(GOAL_POS.x, GOAL_POS.y)

	_build_lamps()
	_build_rocks()
	_build_bats()
	## 闇はいちばん後に敷く。上に重ねて隠すため。
	_build_dark()

	## 組んだ直後に一度明るさを配る。
	## ここを飛ばすと、最初の 1 コマだけ洞窟が丸見えになる。
	_update_light()

## 燭を並べる。射ると「灯」になる。
func _build_lamps() -> void:
	_clear(lamp_root)
	_lamps.clear()
	_lit.clear()
	for p in LAMP_POS:
		var s := KanjiSprite.new()
		s.text = "燭"
		s.color = COL_LAMP
		s.font_size = 24
		lamp_root.add_child(s)
		s.set_scratch_pos(p.x, p.y)
		_lamps.append(s)

## 岩を並べる。ぶつかって通れない。
func _build_rocks() -> void:
	_clear(rock_root)
	for p in ROCK_POS:
		var s := KanjiSprite.new()
		s.text = "岩"
		s.color = COL_ROCK
		s.font_size = 24
		rock_root.add_child(s)
		s.set_scratch_pos(p.x, p.y)

## 蝙を並べる。暗い所を漂い、明かりには入ってこない。
func _build_bats() -> void:
	_clear(bat_root)
	_bats.clear()
	_bat_dirs.clear()
	for i in BAT_POS.size():
		var s := KanjiSprite.new()
		s.text = "蝙"
		s.color = COL_BAT
		s.font_size = 26
		bat_root.add_child(s)
		s.set_scratch_pos(BAT_POS[i].x, BAT_POS[i].y)
		_bats.append(s)
		## はじめの向きは散らしておく。同じ方へ動くと群れて見える。
		var ang := TAU * float(i) / float(BAT_POS.size()) + 0.7
		_bat_dirs.append(Vector2.RIGHT.rotated(ang))

## 闇を格子状に敷き詰める（river.gd が川を並べるのと同じ作り）。
func _build_dark() -> void:
	_clear(dark_root)
	_darks.clear()
	var y := -Game.STAGE_H * 0.5 + DARK_STEP * 0.5
	while y < Game.STAGE_H * 0.5:
		var x := -Game.STAGE_W * 0.5 + DARK_STEP * 0.5
		while x < Game.STAGE_W * 0.5:
			var s := KanjiSprite.new()
			s.text = "闇"
			s.color = COL_DARK
			s.font_size = 24
			## 闇はいちばん手前。ほかのものを覆い隠す。
			s.z_index = 5
			dark_root.add_child(s)
			s.set_scratch_pos(x, y)
			_darks.append(s)
			x += DARK_STEP
		y += DARK_STEP

func _clear(root: Node) -> void:
	for c in root.get_children():
		root.remove_child(c)
		c.queue_free()

# ---------------------------------------------------------------- 明かり

## その場所がどれだけ明るいか（0=真っ暗、1=明るい）。
## いちばん近い明かりからの距離で決める。中心が明るく、縁で 0 になる。
func _light_at(pos: Vector2) -> float:
	var best := 0.0
	## 点いた灯。広く照らす。
	for lamp in _lit:
		if not is_instance_valid(lamp):
			continue
		var k := 1.0 - pos.distance_to(lamp.position) / LIGHT_R_LAMP
		best = maxf(best, clampf(k, 0.0, 1.0))
	## 勇者の手元。弓を持つと、その火で少しだけ先が見えるようになる。
	var r := LIGHT_R_HERO if Game.got_bow else LIGHT_R_HERO
	var hk := 1.0 - hero.position.distance_to(pos) / r
	return maxf(best, clampf(hk, 0.0, 1.0))

## 洞窟の中身に明るさを配る。
##
## visible を落とすのが要点。touching() は両方が visible でないと false なので
## （落とし穴 3）、「見えていないものには当たらない」がこれだけで手に入る。
## 暗闇が見た目だけでなく、当たり判定としても効くようになる。
func _update_light() -> void:
	for group in [_lamps, _bats, rock_root.get_children()]:
		for n in group:
			if not is_instance_valid(n):
				continue
			_apply_light(n)
	_apply_light(chest)
	_apply_light(goal)

	## 闇は明かりの逆。明るいほど薄くなって、そこだけ見えるようになる。
	for d in _darks:
		if not is_instance_valid(d):
			continue
		d.modulate.a = clampf(1.0 - _light_at(d.position), 0.0, 1.0)

func _apply_light(n: KanjiSprite) -> void:
	var k := _light_at(n.position)
	n.modulate.a = k
	n.visible = k > LIGHT_MIN

# ---------------------------------------------------------------- 毎フレーム処理

func _process(delta: float) -> void:
	## 決定ボタンの上げ下げは毎コマ見ておく（中身は StageBase。落とし穴 12）。
	if _finished:
		update_act(true)
		update_finished_act()
		return
	update_act(_busy)

	## 明かりと蝙は演出中も動かし続ける。
	## ここを止めると、矢が飛んでいる間だけ洞窟が固まって見えてしまう。
	_update_light()
	_move_bats(delta)
	_follow_bow()

	if _busy:
		return

	_try_take_bow()
	_update_charge(delta)

	## 蝙に触れたらやり直し。
	if _touching_bat():
		_defeated()
		return

	if goal.visible and hero.touching(goal):
		_finish()

## 宝箱に重なって決定を押すと弓が手に入る。
func _try_take_bow() -> void:
	if Game.got_bow or not chest.visible:
		return
	## 「押した瞬間」だけ開ける。押しっぱなしを見てしまうと、
	## ボタンを押したまま宝箱の上を通っただけで開いてしまう
	## （スマホでは移動ボタンを押しながら歩くので、よく起きる）。
	if hero.touching(chest) and act_just_pressed():
		chest.text = "空箱"
		Game.got_bow = true
		bow.visible = true
		bow.position = hero.position + BOW_OFFSET
		bow.scale = Vector2(BOW_THIN, 1.0)
		bow.color = COL_BOW
		## 宝箱を開けた押し下げが、そのまま引き絞りに化けないようにする
		## （落とし穴 11）。一度離すまで構えを始めない。
		_await_release = true

## 弓は勇者の右上に構える。射っている最中は演出側が位置を決めるので触らない。
func _follow_bow() -> void:
	if not Game.got_bow or _shooting:
		return
	bow.position = hero.position + BOW_OFFSET
	var w := lerpf(BOW_THIN, BOW_THICK, _charge)
	## 太くなるぶん、少しだけ縦を詰めて力がこもった形にする。
	bow.scale = Vector2(w, 1.0 + _charge * 0.25)
	## 満ちきったら色を変えて「もう放てる」と分かるようにする。
	bow.color = COL_BOW_FULL if _charge >= 1.0 else COL_BOW

# ---------------------------------------------------------------- 弓

## 押している間は引き絞り、離した瞬間に放つ。
func _update_charge(delta: float) -> void:
	if not Game.got_bow:
		return
	var down := act_down()

	## 宝箱を開けた押し下げを引き継がない。離すまでは何もしない。
	if _await_release:
		if down:
			_shoot_was_down = true
			return
		_await_release = false
		_shoot_was_down = false

	if down:
		_charge = minf(_charge + delta / CHARGE_TIME, 1.0)
		## 引き絞っている間は足を止める。狙いを定める動作なので、
		## 歩きながら撃てると緊張感が無くなる。
		hero.can_move = false
		_show_strain()

		## 引き絞りきったまま粘ると、腕が保たなくなる。
		## そのまま撃たずにいられると強すぎるので、限界を設けた。
		if _charge >= 1.0:
			_hold_time += delta
			if _hold_time >= HOLD_LIMIT:
				_exhaust()
				return
		else:
			_hold_time = 0.0
	elif _shoot_was_down:
		## 離した瞬間に放つ。ためた分だけ遠くまで飛ぶ。
		var k := _charge
		_charge = 0.0
		_hold_time = 0.0
		_shoot_was_down = false
		hero.can_move = true
		_rest_hero()
		_shoot(k)
		return

	_shoot_was_down = down

## 引き絞っている間、勇者が「疲」に変わる。
## 力んでいる様子を字そのもので見せる（ステージ3 と同じ手）。
func _show_strain() -> void:
	hero.text = "疲"
	if _charge < 0.5:
		hero.color = COL_STRAIN_LOW.lerp(COL_STRAIN_MID, _charge / 0.5)
	else:
		hero.color = COL_STRAIN_MID.lerp(COL_STRAIN_HIGH, (_charge - 0.5) / 0.5)
	var grow := 1.0 + _charge * STRAIN_GROW
	var shake := 0.0
	if _charge >= 1.0:
		## 限界が近いことを、小刻みな震えで知らせる。
		shake = sin(Time.get_ticks_msec() * 0.05) * 0.04
	hero.scale = Vector2.ONE * (grow + shake)

## 引き絞りをやめて、元の「勇」に戻す。
func _rest_hero() -> void:
	hero.text = "勇"
	hero.color = Color.BLACK
	hero.scale = Vector2.ONE

## 引き絞りきったまま粘りすぎた。弓が戻り、しばらく動けなくなる。
## 矢は出ない。ため得にならないようにするための仕掛け。
func _exhaust() -> void:
	_busy = true
	_charge = 0.0
	_hold_time = 0.0
	_shoot_was_down = true   ## 離すまで次の構えを始めない
	_await_release = true
	hero.can_move = false

	hero.text = "疲"
	hero.color = COL_STRAIN_HIGH
	hero.scale = Vector2.ONE * (1.0 + STRAIN_GROW)

	var t := 0.0
	while t < EXHAUST_TIME:
		t += get_process_delta_time()
		## 肩で息をするように、ゆっくり大きく揺れる。
		var breathe := sin(t * 8.0) * 0.05
		hero.scale = Vector2.ONE * (1.0 + STRAIN_GROW + breathe)
		if not await next_frame():
			return

	_rest_hero()
	hero.can_move = true
	_busy = false

## 火矢を放つ。勇者の向いている方へ飛ぶ。
func _shoot(k: float) -> void:
	_busy = true
	_shooting = true

	## 燭と岩のどちらに当たったかを見る。
	var targets: Array = []
	for lamp in _lamps:
		if is_instance_valid(lamp) and not _is_lit(lamp):
			targets.append(lamp)
	for rock in rock_root.get_children():
		if rock is KanjiSprite:
			targets.append(rock)

	## ステージ3 の矢は真上だけだったが、こちらは向いた方へ飛ぶ。
	var dir: Vector2 = hero.facing
	var struck = await _fly_arrow(targets, dir, k)

	_shooting = false
	hero.can_move = true

	if struck != null and is_instance_valid(struck):
		if struck in _lamps:
			await _light_lamp(struck)
		else:
			## 岩には火が移らない。弾かれるだけ。
			_bounce_off(struck)

	_busy = false

## 燭に火が移って「灯」になる。ここから周りが明るくなる。
func _light_lamp(lamp: KanjiSprite) -> void:
	lamp.text = "灯"
	lamp.color = COL_LIT
	lamp.font_size = 28
	_lit.append(lamp)
	## 火が点った手応えとして、弾んで大きくなる。
	await Effects.pop_in(lamp, 0.35)

func _is_lit(lamp: KanjiSprite) -> bool:
	return lamp in _lit

## 硬い所に当たったときの反応。跳ね返って「硬」と出る。
func _bounce_off(s: KanjiSprite) -> void:
	var mark := KanjiSprite.new()
	mark.text = "硬"
	mark.color = COL_HARD
	## 読めるように大きめに出す。小さいと一瞬で消えて何か分からない。
	mark.font_size = 32
	mark.z_index = 10
	add_child(mark)
	mark.position = s.position
	await Effects.pop_in(mark, 0.2)
	if not await wait(0.9):
		return
	await Effects.fade_trail(mark, 0.4)

## 火矢を飛ばす。当たった相手を返す（当たらなければ null）。
## ステージ3 の _fly_arrow と同じ作りだが、字が「火」で、向きを選べる。
func _fly_arrow(targets: Array, dir: Vector2, k: float):
	var a := KanjiSprite.new()
	a.text = "火"
	a.color = COL_FIRE
	## 縦に飛ぶときは字も縦長にする。
	## 回転させないのは、当たり判定が回転を考えないため（落とし穴 2）。
	a.vertical = absf(dir.y) > absf(dir.x)
	a.z_index = 6   ## 闇より手前。飛んでいるのが見えるように
	add_child(a)
	a.position = hero.position + dir * ARROW_MUZZLE_DIST

	## ためた分だけ速く、そして遠くまで飛ぶ。
	var kk: float = clampf(k, 0.0, 1.0)
	var speed: float = lerpf(ARROW_SPEED_MIN, ARROW_SPEED_MAX, kk)
	## 3 乗にすることで、浅い引きでは極端に飛ばなくなる。
	var range_max: float = lerpf(ARROW_RANGE_MIN, ARROW_RANGE_MAX, kk * kk * kk)
	var start := a.position

	var t := 0.0
	while t < ARROW_LIFE:
		if _leaving or not is_instance_valid(a):
			if is_instance_valid(a):
				a.queue_free()
			return null
		var d := get_process_delta_time()
		t += d

		if start.distance_to(a.position) >= range_max:
			## 力尽きた。燃え尽きて消える。
			break
		a.position += dir * speed * d

		for obj in targets:
			if obj == null or not is_instance_valid(obj):
				continue
			## 暗くて見えない相手には当たらない。
			## 見えている所しか射てない、というのがこのステージの肝。
			if not obj.visible:
				continue
			if a.touching(obj) or a.position.distance_to(obj.position) < ARROW_REACH:
				## 当たった所まで矢を進めてから消す。
				a.position = obj.position
				if not await next_frame():
					return null
				a.queue_free()
				return obj

		## 画面の外に抜けたら外れ。
		var p := a.position
		if p.x < -40.0 or p.x > Game.STAGE_W + 40.0 \
				or p.y < -40.0 or p.y > Game.STAGE_H + 40.0:
			break
		if not await next_frame():
			return null

	if is_instance_valid(a):
		## 消えぎわに小さくしてから捨てる。ふっと消えるより自然に見える。
		await Effects.fade_trail(a, 0.2)
	return null

# ---------------------------------------------------------------- 蝙

## 蝙が漂う。明かりを嫌うので、明るい所からは逃げる。
##
## 「明るければ向きを変えるだけ」にすると、明かりに囲まれたとき
## その場でぐるぐる回り続けて動けなくなる。
## 明るい所にいるときは、いちばん暗い方へ逃がすこと。
func _move_bats(delta: float) -> void:
	for i in _bats.size():
		var b: KanjiSprite = _bats[i]
		if not is_instance_valid(b):
			continue
		var dir: Vector2 = _bat_dirs[i]

		## 今いる所が明るいなら、暗い方へ逃げる。
		if _light_at(b.position) > LIGHT_SAFE:
			dir = _darker_dir(b.position, dir)
			_bat_dirs[i] = dir
			b.position += dir * BAT_SPEED * delta
			_keep_inside(b)
			continue

		var next: Vector2 = b.position + dir * BAT_SPEED * delta
		## 進む先が明るい、または画面の外なら向きを変える。
		var turn := _light_at(next) > LIGHT_SAFE
		## 目標のまわりには入らない。
		if next.distance_to(goal.position) < BAT_KEEP_OUT:
			turn = true
		var sp := Game.to_scratch(next)
		if absf(sp.x) > Game.STAGE_W * 0.5 - 24.0 or absf(sp.y) > Game.STAGE_H * 0.5 - 24.0:
			turn = true

		if turn:
			## 少しずつ向きを変える。急に反転すると跳ねて見える。
			_bat_dirs[i] = dir.rotated(BAT_TURN * delta * 6.0)
		else:
			b.position = next
			## ふらふらと漂わせる。まっすぐ飛ぶと機械的に見える。
			_bat_dirs[i] = dir.rotated(sin(Time.get_ticks_msec() * 0.001 + i) * BAT_TURN * delta)
			_keep_inside(b)

## いちばん暗い方の向きを選ぶ。まわりを 8 方向だけ見る。
func _darker_dir(pos: Vector2, now: Vector2) -> Vector2:
	var best := now
	var best_light := 2.0
	for i in 8:
		var d := Vector2.RIGHT.rotated(TAU * float(i) / 8.0)
		var probe := pos + d * 30.0
		var sp := Game.to_scratch(probe)
		## 画面の外と、目標のまわりへは逃げない。
		if absf(sp.x) > Game.STAGE_W * 0.5 - 24.0 or absf(sp.y) > Game.STAGE_H * 0.5 - 24.0:
			continue
		if probe.distance_to(goal.position) < BAT_KEEP_OUT:
			continue
		var k := _light_at(probe)
		if k < best_light:
			best_light = k
			best = d
	return best

## 画面の中に留める。外へ出ると戻ってこられなくなる。
func _keep_inside(b: KanjiSprite) -> void:
	var sp := Game.to_scratch(b.position)
	var lx := Game.STAGE_W * 0.5 - 24.0
	var ly := Game.STAGE_H * 0.5 - 24.0
	b.set_scratch_pos(clampf(sp.x, -lx, lx), clampf(sp.y, -ly, ly))

## 蝙に触れたか。明るい所にいる蝙は見えているものだけが相手になる。
func _touching_bat() -> bool:
	for b in _bats:
		if is_instance_valid(b) and hero.touching(b):
			return true
	return false

## 蝙にやられた。少し見せてから、この場面の最初からやり直す。
## 点した灯は消さない。全部消えると理不尽になるため。
func _defeated() -> void:
	_busy = true
	hero.can_move = false
	_charge = 0.0
	_hold_time = 0.0

	var mark := KanjiSprite.new()
	mark.text = "痛"
	mark.color = COL_HURT
	mark.font_size = 40
	mark.z_index = 12
	add_child(mark)
	mark.position = hero.position
	await Effects.pop_in(mark, 0.3)

	if not await wait(0.5):
		return
	if is_instance_valid(mark):
		mark.queue_free()

	## 入口からやり直す。灯と弓はそのまま残す。
	_rest_hero()
	hero.set_scratch_pos(HERO_POS.x, HERO_POS.y)
	hero.can_move = true
	## 押していたぶんが、そのまま引き絞りに化けないようにする。
	_await_release = true
	_busy = false

# ---------------------------------------------------------------- クリア

## 目標に到達。その瞬間に勇者を止めてクリア演出に入る。
func _finish() -> void:
	_finished = true
	hero.can_move = false
	## 引き絞ったまま辿り着いた場合に備えて、姿を戻す。
	_rest_hero()
	_charge = 0.0

	if not await wait(0.12):
		return

	if _left():
		return
	goal.text = "達成"
	goal.color = COL_DONE
	goal.z_index = 10
	goal.modulate.a = 1.0
	goal.visible = true
	await Effects.pop_in(goal, 0.45)
	if _left():
		return

	Effects.burst(self, goal.position)
	await Effects.cheer(hero)
	await Effects.show_banner(self, "祝", COL_DONE)

	## 次のステージがあればそちらへ誘い、無ければもう一度遊べるようにする。
	if Game.stage_no < Game.last_stage():
		_show_end_hint("%sで次のステージへ" % TouchPad.accept_key_name())
	else:
		_show_end_hint("%sでもう一度" % TouchPad.accept_key_name())
