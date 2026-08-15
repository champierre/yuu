extends Node2D
## ステージ 2「紐を射って橋を落とす」。
##
## ステージ 1 が「斧で木を切り倒して橋にする」＝手の届く所を直接どうにかする話
## だったのに対し、こちらは「遠くの紐を矢で射切る」＝離れた所に働きかける話。
## 場面の組み立て方（3 シーン・シネマモード・演出の緩急）はステージ 1 に合わせてある。

const COL_BRIDGE := Color("#9e6a3f")  ## 橋
const COL_ROPE := Color("#8c6b47")    ## 紐
const COL_TARGET := Color("#bb3023")  ## 的
const COL_BOW := Color("#66421f")     ## 弓
const COL_ARROW := Color("#555555")   ## 矢
const COL_GOAL := Color("#000000")    ## 目標
const COL_DONE := Color("#3f9e44")    ## 達成
const COL_SOIL := Color("#6a302a")    ## 土
const COL_SUB := Color("#555555")     ## 案内文字
const COL_CUT := Color("#ff7729")     ## 切

## 弓を構える位置（勇者から見て右上）。ステージ 1 の斧と同じ考え方。
const BOW_OFFSET := Vector2(16, -16)

## 加速のしかた。Effects.ease_k に渡すので、あちらの enum と並び順を合わせてある。
enum { EASE_IN, EASE_OUT }

## 弓を引き絞る時間と、引き戻す時間。
## 斧の「振りかぶり→振り抜き」と同じで、タメを長く・放つ瞬間を短くする。
const DRAW_TIME := 0.28
const RELEASE_TIME := 0.30
## 引き絞ったときの歪み。縦に伸びて横に潰れる＝弦を引いた形。
const BOW_STRETCH_Y := 1.35
const BOW_SQUASH_X := 0.45

## 矢の速さ (px/秒) と、飛んでいられる時間。
const ARROW_SPEED := 620.0
const ARROW_LIFE := 1.2
## 矢が出る位置（勇者から見た足元からの高さ）。
## 弓の位置ではなく勇者を基準にする。弓は構えの分だけ右にずれているので、
## そこから真上に射つと的の横を素通りしてしまうため。
const ARROW_MUZZLE := Vector2(0, -18)

## 橋が落ちるときの加速と、着地する高さ。
const BRIDGE_GRAVITY := 900.0
const BRIDGE_GROUND_Y := 0.0

@onready var river: Node2D = $River
@onready var hero: KanjiSprite = $Hero
@onready var bridge: KanjiSprite = $Bridge
@onready var rope: KanjiSprite = $Rope
@onready var target: KanjiSprite = $Target
@onready var bow: KanjiSprite = $Bow
@onready var goal: KanjiSprite = $Goal
@onready var soil: Node2D = $Soil

var _busy := false          ## 演出中は入力を無視する
var _finished := false      ## クリア後は完全に停止する
var _can_restart := false   ## クリア後、やり直しを受け付けるか
var _restart_hint: KanjiSprite

func _ready() -> void:
	## Game.reset() は stage_no を 1 に戻してしまうのでここでは呼ばない。
	## ステージ固有の持ち物だけを初期化する。
	Game.reset_stage()
	## エディタからこのシーンだけを実行したときのための保険。
	## タイトルや前ステージから来た場合は既に 2 が入っている。
	Game.stage_no = 2

	hero.river = river
	## シネマモード中に右端まで歩くとシーン 1 に戻る。
	hero.reached_right_edge.connect(_on_hero_reached_right_edge)
	_setup_colors()

	## 先にシーン 1 を組んでから待つ。
	## 後から組むと、待っている間に初期配置（全員が原点にいる状態）が見えてしまう。
	start_scene1()
	_busy = true                                ## 待っている間は入力を受けない
	await get_tree().create_timer(1.0).timeout
	_busy = false

func _setup_colors() -> void:
	hero.text = "勇";     hero.color = Color.BLACK
	bridge.text = "橋橋橋"; bridge.color = COL_BRIDGE
	rope.text = "紐";     rope.color = COL_ROPE
	target.text = "的";   target.color = COL_TARGET
	bow.text = "弓";      bow.color = COL_BOW
	goal.text = "目標";   goal.color = COL_GOAL

## 場面を組む前に、全部の見た目を素の状態に戻す。
## ステージ 1 では各 start_sceneN が全ノードを明示的に書いていて、
## 書き漏らすと前の場面の状態が残る作りだった。ここでは先に一度戻しておき、
## 各場面は「使うものだけ」を書けばよいようにしている。
func _reset_all_sprites() -> void:
	for s in [bridge, rope, target, bow, goal, hero]:
		s.visible = false
		s.scale = Vector2.ONE
		s.rotation = 0.0
		s.modulate.a = 1.0
		s.vertical = false
		s.pivot = Vector2(0.5, 0.5)
		s.z_index = 0

# ---------------------------------------------------------------- シーン 1

## 谷の手前。川に阻まれ、向こう岸の目標へ行けない。
## 高い所に橋が吊り上がっていて、それを「紐」が支えている。
func start_scene1() -> void:
	Game.scene_no = 1
	Game.cinema_mode = false
	_busy = false
	_reset_all_sprites()

	river.build_full()
	_clear_soil()

	hero.visible = true
	hero.set_scratch_pos(0, -100)

	## 吊り上がったままの橋。まだ渡れない。
	bridge.visible = true
	bridge.set_scratch_pos(0, 70)

	## 橋を吊っている紐。これに触れると、見上げる場面（シーン 2）へ。
	rope.visible = true
	rope.set_scratch_pos(0, 30)

	## 練習用の的。弓を取ったあと、ここで一度射って操作を覚えられる。
	target.visible = true
	target.text = "中" if Game.hit_target else "的"
	target.set_scratch_pos(-60, -110)

	## 弓は落ちている。重なってスペースで拾う。
	bow.visible = true
	if Game.got_bow:
		## 拾ったあとは勇者について回る。
		_follow_bow()
	else:
		bow.set_scratch_pos(-190, -120)

	goal.visible = true
	goal.set_scratch_pos(0, 150)

# ---------------------------------------------------------------- シーン 2

## 谷を横から見た場面。シネマモードで左右のみ。
## 紐の根元に的があり、そこを射ると紐が切れる。
func start_scene2() -> void:
	Game.scene_no = 2
	Game.cinema_mode = true
	_busy = false
	_reset_all_sprites()

	## 川は地面の切れ目に流れる小川になる。
	river.build_single(-8, -160)
	_draw_soil()

	hero.visible = true
	hero.set_scratch_pos(150, -145)

	## 吊られた橋と、それを支える紐。
	bridge.visible = true
	bridge.set_scratch_pos(0, 40)

	rope.visible = true
	rope.vertical = true   ## 縦に垂らして「吊っている」形にする
	rope.set_scratch_pos(0, 5)

	## 紐の根元に的を重ねて置く。
	## 細い紐そのものは狙いにくいので、根元の的を射れば切れる、という筋にした。
	target.visible = true
	target.text = "的"
	target.set_scratch_pos(0, -20)

	bow.visible = Game.got_bow
	_follow_bow()

	## 目標はこの場面では見えない。
	goal.visible = false

## 地面の「土」を並べる。川 (x=-8) の左右に隙間を空ける。
func _draw_soil() -> void:
	_clear_soil()
	var x := -230.0
	for i in 10:
		_stamp_soil(x)
		x += 20.0
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

## 落ちた橋が川に架かり、渡って目標へ。
func start_scene3() -> void:
	Game.scene_no = 3
	Game.cinema_mode = false
	_busy = false
	_reset_all_sprites()

	river.build_gapped()
	_clear_soil()

	hero.visible = true
	hero.set_scratch_pos(0, -30)

	## 落ちた橋が川に架かる。
	## ステージ 1 の倒木は縦に積んで橋にしたが、こちらは横書きのまま架かる。
	bridge.visible = true
	bridge.set_scratch_pos(0, BRIDGE_GROUND_Y)

	bow.visible = Game.got_bow
	_follow_bow()

	goal.visible = true
	goal.set_scratch_pos(0, 150)

# ---------------------------------------------------------------- 毎フレーム処理

func _process(_delta: float) -> void:
	if _finished or _busy:
		return
	match Game.scene_no:
		1: _process_scene1()
		2: _process_scene2()
		3: _process_scene3()

func _process_scene1() -> void:
	_try_take_bow()
	_follow_bow()

	## 弓を持って的に重なりスペース → 練習で一射。
	if Game.got_bow and not Game.hit_target and target.visible \
			and hero.touching(target) and Input.is_action_pressed("ui_accept"):
		_practice_shot()
		return

	## 紐に触れたら、見上げる場面へ。
	if hero.touching(rope):
		start_scene2()

func _process_scene2() -> void:
	_follow_bow()

	## 弓を持って紐の真下でスペース → 射る。
	if Game.got_bow and Input.is_action_pressed("ui_accept"):
		_shoot_at_rope()

func _process_scene3() -> void:
	_follow_bow()

	if hero.touching(goal):
		_finish()

## シーン 2 で画面右端まで歩いたらシーン 1 に戻る。
func _on_hero_reached_right_edge() -> void:
	if _finished or _busy:
		return
	if Game.scene_no == 2:
		start_scene1()

## 弓に重なってスペースを押したら手に入れる。
func _try_take_bow() -> void:
	if Game.got_bow or not bow.visible:
		return
	if hero.touching(bow) and Input.is_action_pressed("ui_accept"):
		Game.got_bow = true

## 弓は勇者の右上に構える。射っている最中は演出側が位置を決めるので触らない。
func _follow_bow() -> void:
	if Game.got_bow and not _busy:
		bow.visible = true
		bow.position = hero.position + BOW_OFFSET
		bow.scale = Vector2.ONE

# ---------------------------------------------------------------- 射る

## 練習の一射。的に当てて手応えを見せるだけで、場面は変わらない。
func _practice_shot() -> void:
	_busy = true
	await _draw_bow()
	var hit := await _fly_arrow([target])
	if hit:
		Game.hit_target = true
		target.text = "中"      ## 当たった証。宝箱が「空箱」に変わるのと同じ見せ方
		await _pop_hit(target)
	await _release_bow()
	_busy = false

## 紐を狙う一射。当たれば紐が切れ、橋が落ちる。
func _shoot_at_rope() -> void:
	_busy = true
	await _draw_bow()
	## 判定は的（矩形が大きい）と紐の両方で取る。
	var hit := await _fly_arrow([target, rope])
	await _release_bow()
	if hit:
		## 当たったら _busy は解除せず、そのまま橋が落ちる演出へ渡す。
		await _cut_rope()
	else:
		_busy = false

## 弦を引き絞る。縦に伸びて横に潰れる＝引かれた弓の形。
## 斧の「振りかぶり」と同じく、最後にタメが効くよう ease_out で動かす。
func _draw_bow() -> void:
	await _deform_bow(0.0, 1.0, DRAW_TIME, EASE_OUT)

## 弓を元の形に戻す。
func _release_bow() -> void:
	await _deform_bow(1.0, 0.0, RELEASE_TIME, EASE_OUT)

## 弓の歪みを k1 から k2 へ動かす。k は 0=素の形、1=引き絞った形。
func _deform_bow(k1: float, k2: float, dur: float, ease_type: int) -> void:
	if not Game.got_bow:
		return
	var t := 0.0
	while t < dur:
		t += get_process_delta_time()
		var p: float = clampf(t / dur, 0.0, 1.0)
		var k := lerpf(k1, k2, Effects.ease_k(p, ease_type))
		bow.position = hero.position + BOW_OFFSET
		bow.scale = Vector2(1.0 - k * BOW_SQUASH_X, 1.0 + k * BOW_STRETCH_Y)
		await get_tree().process_frame
	bow.scale = Vector2(1.0 - k2 * BOW_SQUASH_X, 1.0 + k2 * BOW_STRETCH_Y)

## 矢を真上へ飛ばす。targets のどれかに当たったら true。
## 矢は回転させない。KanjiSprite の当たり判定は回転を考えないため、
## 傾けると見た目と判定がずれてしまう。代わりに縦書きにして、
## 「矢」の字そのものを上向きの細長い形として使う（斧を傾けないのと同じ考え方）。
func _fly_arrow(targets: Array) -> bool:
	var a := KanjiSprite.new()
	a.text = "矢"
	a.color = COL_ARROW
	a.vertical = true
	add_child(a)
	a.position = hero.position + ARROW_MUZZLE

	var t := 0.0
	while t < ARROW_LIFE:
		var d := get_process_delta_time()
		t += d
		a.position.y -= ARROW_SPEED * d   ## 上へ（Godot は下が +y）
		Effects.leave_trail(self, a)      ## 速いので、軌跡が一本の線に見える

		for obj in targets:
			if obj != null and obj.visible and a.touching(obj):
				a.queue_free()
				return true

		## 画面の上に抜けたら外れ。
		if a.position.y < -40.0:
			break
		await get_tree().process_frame

	a.queue_free()
	return false

## 当たった相手を一瞬大きくして、手応えを出す。
func _pop_hit(node: KanjiSprite) -> void:
	var dur := 0.18
	var t := 0.0
	while t < dur:
		t += get_process_delta_time()
		var k: float = clampf(t / dur, 0.0, 1.0)
		node.scale = Vector2.ONE * (1.0 + sin(k * PI) * 0.35)
		await get_tree().process_frame
	node.scale = Vector2.ONE

# ---------------------------------------------------------------- 紐が切れて橋が落ちる

## 紐が切れ、橋が落ちて川に架かる。
## ステージ 1 の「木が揺れて倒れる」と同じ組み立て（揺れ → 動く → 待つ → 次の場面）。
func _cut_rope() -> void:
	## 1. 切れた印を一瞬出す。斧の「切」と同じ見せ方。
	var mark := KanjiSprite.new()
	mark.text = "切"
	mark.color = COL_CUT
	mark.z_index = 10
	add_child(mark)
	mark.position = rope.position
	await Effects.pop_in(mark, 0.22)

	## 2. 切れた紐が left/right に分かれて落ちる。
	rope.visible = false
	for dir in [-1.0, 1.0]:
		var piece := KanjiSprite.new()
		piece.text = "紐"
		piece.color = COL_ROPE
		add_child(piece)
		piece.position = rope.position
		Effects.fly_particle(piece, Vector2(60.0 * dir, -40.0))

	await get_tree().create_timer(0.25).timeout
	mark.queue_free()

	## 3. 橋が一瞬持ちこたえて揺れる。
	var base_x := bridge.position.x
	for i in 20:
		bridge.position.x = base_x + randf_range(-2.0, 2.0)
		await get_tree().process_frame
	bridge.position.x = base_x

	## 4. 落下。重力で加速させ、川の高さで確実に止める。
	await _drop_bridge()

	await get_tree().create_timer(0.8).timeout
	start_scene3()

## 橋を落として川に架ける。着地したら潰れて弾む。
func _drop_bridge() -> void:
	var ground := Game.to_godot(0, BRIDGE_GROUND_Y).y
	var v := 0.0
	while bridge.position.y < ground:
		var d := get_process_delta_time()
		v += BRIDGE_GRAVITY * d
		bridge.position.y += v * d
		await get_tree().process_frame
	bridge.position.y = ground

	## 着地の衝撃。横に伸びて縦に潰れ、元に戻る。
	var dur := 0.24
	var t := 0.0
	while t < dur:
		t += get_process_delta_time()
		var k: float = clampf(t / dur, 0.0, 1.0)
		var squash := sin(k * PI) * 0.3
		bridge.scale = Vector2(1.0 + squash, 1.0 - squash)
		await get_tree().process_frame
	bridge.scale = Vector2.ONE

# ---------------------------------------------------------------- クリア

## 目標に到達。ステージ 1 と同じ流れで締める。
func _finish() -> void:
	_finished = true
	hero.can_move = false

	await get_tree().create_timer(0.12).timeout

	goal.text = "達成"
	goal.color = COL_DONE
	goal.z_index = 10
	await Effects.pop_in(goal, 0.45)

	Effects.burst(self, goal.position)
	await Effects.cheer(hero)
	await Effects.show_banner(self, "祝", COL_DONE)

	## 次のステージがあればそちらへ誘い、無ければもう一度遊べるようにする。
	if Game.stage_no < Game.STAGE_MAX:
		_show_next_stage_hint()
	else:
		_show_restart_hint()

## クリア後の「もう一度」案内。
func _show_restart_hint() -> void:
	_restart_hint = _make_hint("スペースキーでもう一度")
	## この瞬間に押していたキーを拾わないよう、少し待ってから受け付ける。
	await get_tree().create_timer(0.5).timeout
	_can_restart = true
	Effects.blink(_restart_hint, func(): return _can_restart)

## クリア後の「次のステージへ」案内。
func _show_next_stage_hint() -> void:
	_restart_hint = _make_hint("スペースキーで次のステージへ")
	await get_tree().create_timer(0.5).timeout
	_can_restart = true
	Effects.blink(_restart_hint, func(): return _can_restart)

func _make_hint(text: String) -> KanjiSprite:
	var h := KanjiSprite.new()
	h.text = text
	h.color = COL_SUB
	h.font_size = 16
	h.z_index = 11
	add_child(h)
	h.set_scratch_pos(0, -60)
	return h

## 決定キー。次のステージがあれば進み、無ければ最初からやり直す。
func _confirm() -> void:
	if not _can_restart:
		return
	_can_restart = false
	if Game.stage_no < Game.STAGE_MAX:
		Game.goto_stage(get_tree(), Game.stage_no + 1)
	else:
		## 最初のステージからやり直す。
		Game.reset()
		get_tree().change_scene_to_file(Game.STAGE_SCENES[1])

func _unhandled_input(event: InputEvent) -> void:
	if not _can_restart:
		return
	if event is InputEventMouseButton and event.pressed:
		_confirm()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER \
				or event.keycode == KEY_KP_ENTER:
			_confirm()
