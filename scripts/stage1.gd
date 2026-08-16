extends StageBase
## ゲーム全体の進行。Scratch のメッセージ (start1 / start1_2 / start1_3) を
## そのままシーン 1 / 2 / 3 として実装している。

const COL_TREE := Color("#9e6a3f")   ## 木・木木木・倒木
const COL_AXE := Color("#a7a7a7")    ## 斧
const COL_CUT := Color("#ff7729")    ## 切
const COL_SCAR := Color("#6b4423")   ## 木に残る切り込み
## 切り込みの大きさ。切った回数ぶん深く（大きく）なる。
const SCAR_SIZE := 14
const SCAR_GROW := 8

## 木の立っている場所。
const TREE_X := 30.0
## 根元の木の下端。ここに 1 つ目が立つ。
const TREE_BASE_Y := -158.0
## 切り口の高さ。木 1 つ分だけ上（ここから上の 3 つが倒れる）。
const TREE_CUT_Y := TREE_BASE_Y + 30.0
const COL_SOIL := Color("#6a302a")   ## 土

## 斧を構える位置（勇者から見て右上）。
const AXE_OFFSET := Vector2(16, -16)
## 斧を水平に右から左へ振る。x は勇者からの左右方向のずれ（+が右）。
## 振りかぶり位置（右にぐっと引く）。
const SWING_START_X := 26.0
## 木に当たる位置（左）。
const SWING_HIT_X := -20.0
## 振っている間の高さ（勇者の肩の高さで水平に薙ぐ）。
const SWING_Y := -10.0

## この速さ (px/秒) で歪みが最大になる。
const AXE_MAX_SPEED := 700.0
## 最大でどれだけ横に伸ばすか / 縦に潰すか。
const AXE_STRETCH := 1.5
const AXE_SQUASH := 0.55

## 振りかぶり・振り抜き・戻りにかける秒数。
const SWING_WINDUP_TIME := 0.22
const SWING_STRIKE_TIME := 0.09
const SWING_RETURN_TIME := 0.30

@onready var river: Node2D = $River
@onready var hero: KanjiSprite = $Hero
@onready var tree_sprite: KanjiSprite = $Tree
@onready var chest: KanjiSprite = $Chest
@onready var goal: KanjiSprite = $Goal
@onready var forest: KanjiSprite = $Forest
@onready var axe: KanjiSprite = $Axe
@onready var cut_mark: KanjiSprite = $CutMark
@onready var soil: Node2D = $Soil

var _swinging := false      ## 斧を振っている最中か
var _trail := false         ## 振り抜き中だけ残像を出す
var _axe_prev_x := 0.0      ## 歪みの計算用。直前のフレームの斧の x
var _scar: KanjiSprite = null   ## 切り口の切り込み（1 つだけ。切るほど大きくなる）
var _stump: KanjiSprite = null  ## 根元の木。倒れずに残る

func _ready() -> void:
	Game.reset()   ## 起動時だけ全変数を初期化する（斧を含む）
	hero.blockers = river
	## シネマモード中に右端 (x>230) まで歩くとシーン 1 に戻る。
	hero.reached_right_edge.connect(_on_hero_reached_right_edge)
	_setup_colors()
	## 操作ボタンは、指で触れる機械のときだけ出す。
	## そのときは「戻」ボタンから帰れるので、Esc の案内は出さない。
	if TouchPad.needed():
		add_child(TouchPad.new())
	else:
		Effects.show_escape_hint(self)
	## 先にシーン 1 を組んでから待つ。
	## 後から組むと、待っている間シーンの初期配置（全員が原点にいる状態）が
	## 見えてしまい、一瞬シーン 2 のように見えてしまう。
	start_scene1()
	_busy = true                                ## 待っている間は入力を受けない
	if not await wait(1.0):                     ## Scratch の「1秒待つ」
		return
	_busy = false

func _setup_colors() -> void:
	hero.text = "勇";      hero.color = Color.BLACK
	tree_sprite.text = "木"; tree_sprite.color = COL_TREE
	chest.text = "宝箱";    chest.color = COL_CHEST
	goal.text = "目標";     goal.color = COL_GOAL
	## 木は縦に 4 つ。切り込みは下から 1 つ目と 2 つ目の間に入り、
	## そこから上の 3 つが倒れる。倒れる側と残る側で分けて持つ。
	forest.text = "木木木"            ## 倒れる上の 3 つ
	forest.color = COL_TREE
	forest.vertical = true
	forest.pivot = Vector2(0.5, 1.0)  ## 切り口を軸にして倒れる
	axe.text = "斧";        axe.color = COL_AXE
	cut_mark.text = "切";   cut_mark.color = COL_CUT

# ---------------------------------------------------------------- シーン 1

## start1: 川に阻まれた状態。木に触れるとシーン 2 へ。
## シーン 2 から戻ってきた場合も呼ばれる。斧を取った状態は引き継ぐ
## （元の Scratch でも start1 は「斧を取った」を初期化しない）。
func start_scene1() -> void:
	Game.scene_no = 1
	Game.cinema_mode = false
	Game.cut_count = 0
	_busy = false

	river.build_full()

	hero.visible = true
	hero.set_scratch_pos(0, -100)

	tree_sprite.visible = true
	tree_sprite.text = "木"
	tree_sprite.vertical = false
	tree_sprite.set_scratch_pos(0, -20)

	goal.visible = true
	goal.text = "目標"
	goal.color = COL_GOAL
	goal.scale = Vector2.ONE
	goal.set_scratch_pos(0, 150)

	chest.visible = true
	chest.text = "空箱" if Game.got_axe else "宝箱"
	chest.set_scratch_pos(200, -150)

	forest.visible = false
	if is_instance_valid(_stump):
		_stump.visible = false
	axe.visible = Game.got_axe
	cut_mark.visible = false
	_clear_soil()

# ---------------------------------------------------------------- シーン 2

## start1_2: シネマモード。宝箱から斧を取り、木木木 を 3 回切って倒す。
## 根元の木を 1 つ置く。切り込みより下なので、倒れずに残る。
func _build_stump() -> void:
	if _stump == null or not is_instance_valid(_stump):
		_stump = KanjiSprite.new()
		_stump.text = "木"
		_stump.color = COL_TREE
		_stump.pivot = Vector2(0.5, 1.0)
		add_child(_stump)
	_stump.visible = true
	_stump.rotation = 0.0
	_stump.set_scratch_pos(TREE_X, TREE_BASE_Y)

## 木（上の 3 つ・根元のどちらか）に触れているか。
func _touching_tree() -> bool:
	if hero.touching(forest):
		return true
	return is_instance_valid(_stump) and hero.touching(_stump)

## 木の切り込みを消す。
func _clear_scars() -> void:
	if is_instance_valid(_scar):
		_scar.queue_free()
	_scar = null

func start_scene2() -> void:
	Game.scene_no = 2
	Game.cinema_mode = true
	Game.cut_count = 0
	_busy = false
	_clear_scars()

	tree_sprite.visible = false
	goal.visible = false
	chest.visible = false   ## 宝箱はこのシーンでは隠れる

	## 川は本体 1 つだけが地面の切れ目に残り、小川になる。
	river.build_single(-8, -160)

	hero.set_scratch_pos(150, -145)

	## 上の 3 つ。切り口（下から 1 つ目と 2 つ目の境）を軸に倒れる。
	forest.visible = true
	forest.rotation = 0.0
	forest.scale = Vector2.ONE
	forest.set_scratch_pos(TREE_X, TREE_CUT_Y)

	## 根元の 1 つ。切っても残り、倒れない。
	_build_stump()

	cut_mark.visible = false
	cut_mark.set_scratch_pos(70, -130)

	## 斧は「取った」ときだけ見えるようにする。
	## ここで明示しないと、前の場面の表示状態がそのまま残ってしまう。
	axe.visible = Game.got_axe

	_draw_soil()

## 地面の「土」を並べる（Scratch のペンスタンプに相当）。
## 川 (x=-8) の左右に隙間を空けて、川と土が重ならないようにする。
func _draw_soil() -> void:
	_clear_soil()
	## 左岸: -230 から -48 まで。
	var x := -230.0
	for i in 10:
		_stamp_soil(x)
		x += 20.0
	## 右岸: 12 から。川の幅 (20px) 分だけ空ける。
	x = 12.0
	for i in 12:
		_stamp_soil(x)
		x += 20.0

func _stamp_soil(x: float) -> void:
	var s := KanjiSprite.new()
	s.text = "土"
	s.color = COL_SOIL
	soil.add_child(s)
	s.set_scratch_pos(x, -165)

func _clear_soil() -> void:
	for c in soil.get_children():
		soil.remove_child(c)
		c.queue_free()

# ---------------------------------------------------------------- シーン 3

## start1_3: 倒木が橋になり、川を渡って目標へ。
func start_scene3() -> void:
	Game.scene_no = 3
	Game.cinema_mode = false
	Game.tree_fell = true
	_busy = false

	river.build_gapped()

	forest.visible = false
	if is_instance_valid(_stump):
		_stump.visible = false
	cut_mark.visible = false
	_clear_soil()

	hero.set_scratch_pos(0, -30)

	tree_sprite.visible = true
	tree_sprite.text = "倒木"
	tree_sprite.vertical = true   ## 縦に積んで川に架かる橋にする
	tree_sprite.pivot = Vector2(0.5, 0.5)
	tree_sprite.set_scratch_pos(0, 0)

	chest.visible = true
	chest.text = "空箱" if Game.got_axe else "宝箱"
	chest.set_scratch_pos(200, -150)

	goal.visible = true
	goal.text = "目標"
	goal.color = COL_GOAL
	goal.scale = Vector2.ONE
	goal.set_scratch_pos(0, 150)

# ---------------------------------------------------------------- 毎フレーム処理

func _process(_delta: float) -> void:
	## 決定ボタンの上げ下げは毎コマ見ておく（中身は StageBase）。
	if _finished:
		update_act(true)
		update_finished_act()
		return
	update_act(_busy)
	if _busy:
		return
	match Game.scene_no:
		1: _process_scene1()
		2: _process_scene2()
		3: _process_scene3()

func _process_scene1() -> void:
	## 宝箱に重なってスペース → 斧を取る（元の Scratch では宝箱はシーン1に置かれている）。
	_try_take_axe()

	## 斧は取ったあと勇者について回る。
	_follow_axe()

	## 木に触れたらシーン 2 へ。
	if hero.touching(tree_sprite):
		start_scene2()

func _process_scene2() -> void:
	## 斧は勇者について回る。
	_follow_axe()

	## 斧を持って木木木 に近づきスペース → 1 回切る。
	## 判定は勇者基準（斧は構えの分だけ離れているため）。
	## 宝箱と同じで「押した瞬間」だけ切る。押しっぱなしを見ると、
	## ボタンを押したまま木の前を通っただけで切れてしまう。
	if Game.got_axe and _touching_tree() and act_just_pressed():
		Game.cut_count += 1
		_show_cut_mark()

func _process_scene3() -> void:
	## 斧は取ったあとずっと勇者について回る。
	_follow_axe()

	## 目標に触れたらクリア演出。
	if hero.touching(goal):
		_finish()

## シーン 2 で画面右端まで歩いたらシーン 1 に戻る。
func _on_hero_reached_right_edge() -> void:
	if _finished or _busy:
		return
	if Game.scene_no == 2:
		start_scene1()

## 宝箱に重なってスペースを押したら斧を手に入れる。
func _try_take_axe() -> void:
	if Game.got_axe or not chest.visible:
		return
	## 「押した瞬間」だけ開ける。押しっぱなしを見てしまうと、
	## ボタンを押したまま宝箱の上を通っただけで開いてしまう
	## （スマホでは移動ボタンを押しながら歩くので、よく起きる）。
	if hero.touching(chest) and act_just_pressed():
		chest.text = "空箱"
		Game.got_axe = true
		axe.visible = true

## 斧は勇者の右上に構える（Scratch の「勇者へ行く」を繰り返す動き）。
## 振っている最中は _place_swinging_axe が位置を決めるので触らない。
func _follow_axe() -> void:
	if Game.got_axe and not _swinging:
		axe.position = hero.position + AXE_OFFSET
		axe.rotation = 0.0
		axe.scale = Vector2.ONE

# ---------------------------------------------------------------- 演出

## 斧を右から左へ水平に振り抜き、当たった瞬間に「切」を出す。
func _show_cut_mark() -> void:
	_busy = true
	_swinging = true
	_axe_prev_x = AXE_OFFSET.x

	## 1. 振りかぶり。ゆっくり右へ引きながら、最後にタメる（ease-out）。
	await _swing_axe(AXE_OFFSET.x, SWING_START_X, SWING_WINDUP_TIME, Effects.EASE_OUT)
	## 2. 振り抜き。止まった状態から一気に加速する（ease-in）。
	##    残像を置いて、水平に薙いだ軌跡を見せる。
	_trail = true
	await _swing_axe(SWING_START_X, SWING_HIT_X, SWING_STRIKE_TIME, Effects.EASE_IN)
	_trail = false

	## 命中の瞬間に「切」を表示する。
	## 場所は決め打ち（勇者の右上）。斧の位置に出すと、
	## 振り抜いた先まで印がついてきて落ち着かないため。
	cut_mark.visible = true
	cut_mark.set_scratch_pos(70, -130)
	## Scratch のコスチューム 1/2/3 は大きさ違い。回数に合わせて拡大する。
	var s := 0.7 + 0.35 * float(Game.cut_count - 1)
	cut_mark.scale = Vector2(s, s)

	## 3. 木に食い込んで急停止。少しめり込んで止まる。
	if not await wait(0.14):
		return
	## 4. 引き抜いて構えに戻す。疲れた感じでゆっくり（ease-out）。
	await _swing_axe(SWING_HIT_X, AXE_OFFSET.x, SWING_RETURN_TIME, Effects.EASE_OUT)
	_swinging = false

	if not await wait(0.35):
		return

	## 「切」が木へ吸い込まれて、そのまま切り込みとして残る。
	await _drive_cut_into_tree()

	if Game.cut_count > 2:
		await _fell_tree()
	else:
		_busy = false

## 出ていた「切」が木へ吸い込まれ、そのまま切り込みとして残る。
## 別の字を新しく出すのではなく、振った結果の「切」がそのまま
## 傷になることで、切った跡だと分かるようにしている。
func _drive_cut_into_tree() -> void:
	## 切り口。下から 1 つ目と 2 つ目の境で、ここに切り込みが刻まれる。
	## forest は pivot が (0.5, 1.0) なので、位置がそのまま切り口にあたる。
	var target := forest.position

	var from := cut_mark.position
	var from_scale: float = cut_mark.scale.x
	var t := 0.0
	var dur := 0.25
	while t < dur:
		t += get_process_delta_time()
		var k: float = clampf(t / dur, 0.0, 1.0)
		## 勢いよく根元へ食い込む。
		var e := Effects.ease_k(k, Effects.EASE_IN)
		cut_mark.position = from.lerp(target, e)
		cut_mark.scale = Vector2.ONE * lerpf(from_scale, 0.6, e)
		if not await next_frame():
			return

	## 切り込みは 1 つだけ。増やさずに、切るたび大きくしていく。
	if _scar == null or not is_instance_valid(_scar):
		_scar = KanjiSprite.new()
		_scar.text = "切"
		_scar.color = COL_SCAR
		_scar.z_index = 5
		## 木の子にするので、倒れるときは一緒に傾く。
		forest.add_child(_scar)
		_scar.position = Vector2.ZERO   ## 根元
	## 切った回数ぶん深くなる。
	_scar.font_size = SCAR_SIZE + Game.cut_count * SCAR_GROW
	## 刻まれた手応えとして、一瞬だけ膨らませる。
	_pop_scar()

	## 元の「切」は役目を終えたので隠す。
	cut_mark.visible = false
	cut_mark.scale = Vector2.ONE

## 切り込みが刻まれた瞬間、少しだけ膨らんで戻る。
func _pop_scar() -> void:
	var t := 0.0
	var dur := 0.22
	while t < dur and is_instance_valid(_scar):
		t += get_process_delta_time()
		var k: float = clampf(t / dur, 0.0, 1.0)
		_scar.scale = Vector2.ONE * (1.0 + sin(k * PI) * 0.35)
		if not await next_frame():
			return
	if is_instance_valid(_scar):
		_scar.scale = Vector2.ONE

## 斧を x1 から x2 まで水平に動かす。ease で緩急を変える。
func _swing_axe(x1: float, x2: float, dur: float, ease_type: int) -> void:
	var t := 0.0
	while t < dur:
		t += get_process_delta_time()
		var k: float = clampf(t / dur, 0.0, 1.0)
		_place_swinging_axe(lerpf(x1, x2, Effects.ease_k(k, ease_type)))
		if not await next_frame():
			return
	_place_swinging_axe(x2)

## 振っている最中の斧の位置と歪み。水平に薙ぐので傾けない。
## 速く動くほど「斧」の字が横に伸びて縦に潰れ、寝かせたように見える。
func _place_swinging_axe(x: float) -> void:
	axe.position = hero.position + Vector2(x, SWING_Y)
	axe.rotation = 0.0

	## 直前のフレームからの移動量＝速さ。
	var speed: float = absf(x - _axe_prev_x) / maxf(get_process_delta_time(), 0.0001)
	_axe_prev_x = x
	## 速さを 0〜1 に正規化して歪みの強さにする。
	var k: float = clampf(speed / AXE_MAX_SPEED, 0.0, 1.0)
	axe.scale = Vector2(1.0 + k * AXE_STRETCH, 1.0 - k * AXE_SQUASH)

	if _trail:
		Effects.leave_trail(self, axe)

## 木木木 が揺れて倒れ、シーン 3 へ。
func _fell_tree() -> void:
	Game.cut_count = 0
	## 50 回小刻みに揺れる。倒れるのは切り口から上だけなので、
	## 根元はその場に立ったまま動かさない。
	var base_x := forest.position.x
	for i in 50:
		forest.position.x = base_x + randf_range(-1.0, 1.0)
		if not await next_frame():
			return
	forest.position.x = base_x
	## 15 度ずつ 6 回、切り口を軸に左へ倒れる。
	for i in 6:
		forest.rotation -= deg_to_rad(15.0)
		if not await wait(0.1):
			return
	if not await wait(1.0):
		return
	start_scene3()

## 目標に到達。その瞬間にゲームを止めてクリア演出に入る。
func _finish() -> void:
	_finished = true
	hero.can_move = false   ## 到達した瞬間に勇者を止める

	## 1. 一瞬止めて「決まった」感を作る。
	if not await wait(0.12):
		return

	## 2. 目標が「達成」に変わり、勢いよく飛び出して弾む。
	if _left():
		return
	goal.text = "達成"
	goal.color = COL_DONE
	goal.z_index = 10
	await Effects.pop_in(goal, 0.45)
	if _left():
		return

	## 3. 「達成」から漢字が四方に弾ける。
	Effects.burst(self, goal.position)

	## 4. 勇者が喜んで飛び跳ねる。
	await Effects.cheer(hero)

	## 5. 最後に大きく「祝」を出す。
	await Effects.show_banner(self, "祝", COL_DONE)

	## 6. 次のステージがあればそちらへ誘い、無ければもう一度遊べるようにする。
	if Game.stage_no < Game.last_stage():
		_show_end_hint("%sで次のステージへ" % TouchPad.accept_key_name())
	else:
		_show_end_hint("%sでもう一度" % TouchPad.accept_key_name())

