extends Node2D
## ステージ 2「蟲」。
##
## ステージ 1 が「斧で木を切り倒し、橋にして川を渡る」＝地形をどうにかする話
## だったのに対し、こちらは行く手を塞ぐ相手そのものを射る話。
##
## 【解き方】道を塞ぐ「蟲」は、頭と節が硬くて矢が通らない。
## 矢が通るのは列のいちばん後ろの「尾」だけ。尾を射ると節が 1 つ減り、
## 新しい末尾が尾になる。頭を狙わず、尻尾を狙うのが答え。
## （別作の弾幕ゲーム第三面の主「蟲」と同じ趣向を、弓矢に置き換えたもの）

const COL_WORM := Color("#c2559b")    ## 蟲の頭（桃）
const COL_JOINT := Color("#7a4fa3")   ## 節（紫）
const COL_TAIL := Color("#3f9e44")    ## 尾（弱点なので目立たせる）
const COL_TARGET := Color("#bb3023")  ## 的
const COL_BOW := Color("#66421f")     ## 弓
const COL_ARROW := Color("#555555")   ## 矢
const COL_GOAL := Color("#000000")    ## 目標
const COL_DONE := Color("#3f9e44")    ## 達成
const COL_SUB := Color("#555555")     ## 案内文字
const COL_HARD := Color("#a7a7a7")    ## 弾かれた印

## 弓を構える位置（勇者から見て右上）。ステージ 1 の斧と同じ考え方。
const BOW_OFFSET := Vector2(16, -16)

## 加速のしかた。Effects.ease_k に渡すので、あちらの enum と並び順を合わせてある。
enum { EASE_IN, EASE_OUT }

## 弓を引き絞る時間と、引き戻す時間。
const DRAW_TIME := 0.28
const RELEASE_TIME := 0.30
## 引き絞ったときの歪み。縦に伸びて横に潰れる＝弦を引いた形。
const BOW_STRETCH_Y := 1.35
const BOW_SQUASH_X := 0.45

## 矢の速さ (px/秒) と、飛んでいられる時間。
const ARROW_SPEED := 620.0
const ARROW_LIFE := 1.2
## 矢が出る位置。勇者から、飛ぶ向きにこれだけ離れた所から出す。
const ARROW_MUZZLE_DIST := 18.0
## 矢の当たる広さ。蟲は動くので、矩形が触れるかだけでは狙いが厳しすぎる。
const ARROW_REACH := 22.0

## 蟲の節の数（頭を除く）。最後の 1 つが弱点の「尾」。
const JOINT_COUNT := 5
## 蟲が這う高さと、蛇行の幅・速さ。
## 尾は頭より遅れて動くぶん大きく振れる。振り幅を欲張ると
## 勇者（5px/コマ）では追いつけず、狙えなくなるので控えめにしている。
const WORM_Y := 40.0
const WORM_SWAY_X := 70.0
const WORM_SWAY_Y := 16.0
const WORM_SPEED := 0.55
## 節どうしの間隔（頭の通った道を、この距離ごとに刻んで並べる）。
const TRAIL_STEP := 14.0
## 節ひとつ分が何点ぶんさかのぼるか。
const TRAIL_SKIP := 2

@onready var worm_root: Node2D = $Worm
@onready var hero: KanjiSprite = $Hero
@onready var target: KanjiSprite = $Target
@onready var bow: KanjiSprite = $Bow
@onready var goal: KanjiSprite = $Goal

var _busy := false          ## 演出中は入力を無視する
var _finished := false      ## クリア後は完全に停止する
var _can_restart := false   ## クリア後、次へ進むのを受け付けるか
var _restart_hint: KanjiSprite
var _hint: KanjiSprite      ## 操作の案内
var _shoot_was_down := false ## 射撃キーの押しっぱなしを 1 回として扱うため

## 蟲の頭と、連なる節。節の最後が「尾」。
var _worm_head: KanjiSprite = null
var _joints: Array = []
## 頭の通った道。節はこの上を追いかける。
var _trail: Array = []
var _phase := 0.0

func _ready() -> void:
	## Game.reset() は stage_no を 1 に戻してしまうのでここでは呼ばない。
	Game.reset_stage()
	## エディタからこのシーンだけを実行したときのための保険。
	Game.stage_no = 2

	_setup_colors()

	## 先に場面を組んでから待つ。
	## 後から組むと、待っている間に初期配置（全員が原点にいる状態）が見えてしまう。
	start_scene1()
	_busy = true
	await get_tree().create_timer(1.0).timeout
	_busy = false

func _setup_colors() -> void:
	hero.text = "勇";     hero.color = Color.BLACK
	target.text = "的";   target.color = COL_TARGET
	bow.text = "弓";      bow.color = COL_BOW
	goal.text = "目標";   goal.color = COL_GOAL

# ---------------------------------------------------------------- 場面

## 道を塞ぐ蟲と対峙する。倒せば目標へ進める。
func start_scene1() -> void:
	Game.scene_no = 1
	Game.cinema_mode = false
	_busy = false

	hero.visible = true
	hero.set_scratch_pos(0, -130)
	hero.can_move = true

	## 弓は落ちている。重なってスペースで拾う。
	bow.visible = true
	if Game.got_bow:
		_follow_bow()
	else:
		bow.set_scratch_pos(-190, -130)

	## 練習用の的。弓の使い方をここで覚えられる。
	target.visible = true
	target.text = "中" if Game.hit_target else "的"
	target.set_scratch_pos(170, -130)

	## 目標は横に広く取る。尾を追って左右に動いたあと、
	## 真上に歩けば辿り着けるようにするため。
	goal.visible = true
	goal.text = "目標目標目標"
	goal.set_scratch_pos(0, 155)

	_build_worm()

## 蟲を組み立てる。頭のうしろに節を連ね、いちばん後ろを尾にする。
func _build_worm() -> void:
	_clear_worm()

	_worm_head = KanjiSprite.new()
	_worm_head.text = "蟲"
	_worm_head.color = COL_WORM
	_worm_head.font_size = 32
	worm_root.add_child(_worm_head)
	_worm_head.set_scratch_pos(0, WORM_Y)

	## 軌跡をあらかじめ頭の後ろへ伸ばしておく。
	## こうしないと節が全部頭の上に重なったまま、しばらく過ぎてしまう。
	_trail.clear()
	var need := JOINT_COUNT * TRAIL_SKIP + TRAIL_SKIP + 2
	for i in need:
		_trail.append(_worm_head.position - Vector2(float(i) * TRAIL_STEP, 0.0))

	for i in JOINT_COUNT:
		var s := KanjiSprite.new()
		s.text = "節"
		s.color = COL_JOINT
		s.font_size = 26
		worm_root.add_child(s)
		var idx := (i + 1) * TRAIL_SKIP
		s.position = _trail[idx] if idx < _trail.size() else _worm_head.position
		_joints.append(s)
	_mark_tail()

## 列の末尾を「尾」にする。ここだけ矢が通る。
func _mark_tail() -> void:
	for i in _joints.size():
		var last := i == _joints.size() - 1
		var s: KanjiSprite = _joints[i]
		s.text = "尾" if last else "節"
		s.color = COL_TAIL if last else COL_JOINT
		s.font_size = 30 if last else 26

func _clear_worm() -> void:
	for c in worm_root.get_children():
		worm_root.remove_child(c)
		c.queue_free()
	_joints.clear()
	_trail.clear()
	_worm_head = null

# ---------------------------------------------------------------- 毎フレーム処理

func _process(delta: float) -> void:
	if _finished:
		return
	## 演出中でもキーの上げ下げは見ておく。
	## ここを止めると、演出が明けたときに「押しっぱなし」の記録が
	## 古いままになり、次の一射が出せなくなる。
	var shoot_down := Input.is_action_pressed("ui_accept")
	if _busy:
		_shoot_was_down = shoot_down
		return

	_move_worm(delta)

	## 弓を拾ったそのフレームで射ってしまわないようにする。
	## 同じスペース 1 回で「拾う」と「射る」が続けて起きると噛み合わない。
	var just_took := _try_take_bow()
	_follow_bow()
	if just_took:
		_shoot_was_down = true
		return

	## 弓を持ってスペース → 向いている方へ一射。
	if Game.got_bow and _shoot_pressed():
		_shoot()
		return

	## 蟲を倒しきったら、目標へ進める。
	if _worm_head == null and hero.touching(goal):
		_finish()

## 蟲は画面を横に蛇行する。節は頭の通った道を追いかける。
func _move_worm(delta: float) -> void:
	if _worm_head == null:
		return
	_phase += delta * WORM_SPEED

	var c := Game.to_godot(0, WORM_Y)
	_worm_head.position = Vector2(
		c.x + sin(_phase * 1.1) * WORM_SWAY_X,
		c.y + sin(_phase * 0.7) * WORM_SWAY_Y)

	## 通った道を「一定の距離ごと」に覚える。
	## コマ数で覚えると、頭の速さによって節の間隔が伸び縮みしてしまう。
	if _trail.is_empty() or _worm_head.position.distance_to(_trail[0]) >= TRAIL_STEP:
		_trail.push_front(_worm_head.position)
		var need := JOINT_COUNT * TRAIL_SKIP + TRAIL_SKIP + 2
		if _trail.size() > need:
			_trail.resize(need)

	for i in _joints.size():
		var idx := (i + 1) * TRAIL_SKIP
		if idx < _trail.size():
			_joints[i].position = _trail[idx]

	## 尾は弱点なので、脈打たせて目立たせる。
	if not _joints.is_empty():
		var tail: KanjiSprite = _joints[_joints.size() - 1]
		tail.scale = Vector2.ONE * (1.0 + 0.18 * sin(_phase * 6.0))

## 弓に重なってスペースを押したら手に入れる。拾ったら true。
func _try_take_bow() -> bool:
	if Game.got_bow or not bow.visible:
		return false
	if hero.touching(bow) and Input.is_action_pressed("ui_accept"):
		Game.got_bow = true
		_show_hint("尾だけに矢が通る")
		return true
	return false

## 弓は勇者の右上に構える。射っている最中は演出側が位置を決めるので触らない。
func _follow_bow() -> void:
	if Game.got_bow and not _busy:
		bow.visible = true
		bow.position = hero.position + BOW_OFFSET
		bow.scale = Vector2.ONE

## スペースを「押した瞬間」だけ true を返す。
## 押しっぱなしを 1 回として扱う（連射させない）。
func _shoot_pressed() -> bool:
	var down := Input.is_action_pressed("ui_accept")
	var just := down and not _shoot_was_down
	_shoot_was_down = down
	return just

# ---------------------------------------------------------------- 射る

## 勇者が向いている方へ射る。
## 当たった相手によって起きることが変わるので、ここで振り分ける。
func _shoot() -> void:
	_busy = true
	## 射る瞬間の向きを覚えておく。演出の途中で向きが変わらないように。
	var dir: Vector2 = hero.facing
	await _draw_bow()

	## 尾・節・頭・的のどれに当たったかを見る。
	var targets: Array = []
	if _worm_head != null:
		targets.append(_worm_head)
		for j in _joints:
			targets.append(j)
	targets.append(target)

	var struck = await _fly_arrow(targets, dir)
	await _release_bow()

	if struck == null:
		_busy = false
		return

	if struck == target:
		if not Game.hit_target:
			Game.hit_target = true
			target.text = "中"   ## 当たった証
			await _pop_hit(target)
		_busy = false
	elif _is_tail(struck):
		await _cut_tail()
	else:
		## 頭と節は硬い。弾かれるだけ。
		await _bounce_off(struck)
		_busy = false

## その相手が今の「尾」か。
func _is_tail(s) -> bool:
	return not _joints.is_empty() and s == _joints[_joints.size() - 1]

## 尾に当たった。節が 1 つ減り、新しい末尾が尾になる。
func _cut_tail() -> void:
	var tail: KanjiSprite = _joints.pop_back()
	var p := tail.position
	tail.queue_free()

	## 切れた所から破片を飛ばす。
	for d in [Vector2(-1, -1), Vector2(1, -1)]:
		var piece := KanjiSprite.new()
		piece.text = "節"
		piece.color = COL_TAIL
		add_child(piece)
		piece.position = p
		Effects.fly_particle(piece, d * 90.0)

	if _joints.is_empty():
		## 節を全部失ったら頭も落ちる。
		await _defeat_worm()
	else:
		_mark_tail()
		await get_tree().create_timer(0.25).timeout
		_busy = false

## 硬い所に当たったときの反応。跳ね返って「硬」と出る。
func _bounce_off(s: KanjiSprite) -> void:
	var mark := KanjiSprite.new()
	mark.text = "硬"
	mark.color = COL_HARD
	mark.font_size = 20
	mark.z_index = 10
	add_child(mark)
	mark.position = s.position
	await Effects.pop_in(mark, 0.18)
	await get_tree().create_timer(0.2).timeout
	await Effects.fade_trail(mark, 0.25)

## 蟲を倒した。頭が落ちて道が開く。
func _defeat_worm() -> void:
	var head := _worm_head
	_worm_head = null   ## これ以降は動かさない

	## 揺れてから落ちる。ステージ 1 の木が倒れるのと同じ組み立て。
	var base_x := head.position.x
	for i in 20:
		head.position.x = base_x + randf_range(-3.0, 3.0)
		await get_tree().process_frame
	head.position.x = base_x

	## 落ちて消える。
	var v := 0.0
	while head.position.y < Game.STAGE_H + 60.0:
		var d := get_process_delta_time()
		v += 900.0 * d
		head.position.y += v * d
		head.rotation += d * 2.0
		await get_tree().process_frame
	head.queue_free()

	_show_hint("道が開いた")
	await get_tree().create_timer(0.6).timeout
	_busy = false

## 矢を飛ばす。当たった相手を返す（外れたら null）。
## 矢は回転させない。当たり判定が回転を考えないため、傾けるとずれてしまう。
## 代わりに縦横で字の形を変え、飛ぶ向きに沿った細長い形にする。
func _fly_arrow(targets: Array, dir: Vector2 = Vector2.UP):
	var a := KanjiSprite.new()
	a.text = "矢"
	a.color = COL_ARROW
	a.vertical = absf(dir.y) > absf(dir.x)
	add_child(a)
	a.position = hero.position + dir * ARROW_MUZZLE_DIST

	var t := 0.0
	while t < ARROW_LIFE:
		var d := get_process_delta_time()
		t += d
		a.position += dir * ARROW_SPEED * d
		Effects.leave_trail(self, a)   ## 速いので、軌跡が一本の線に見える

		for obj in targets:
			if obj == null or not is_instance_valid(obj) or not obj.visible:
				continue
			## 動く相手を狙うので、矩形が触れるかだけだと厳しすぎる。
			## 少し余裕をもたせ、かすった程度でも当たりとする。
			if a.touching(obj) \
					or a.position.distance_to(obj.position) < ARROW_REACH:
				a.queue_free()
				return obj

		## 画面の外に抜けたら外れ。
		var p := a.position
		if p.x < -40.0 or p.x > Game.STAGE_W + 40.0 \
				or p.y < -40.0 or p.y > Game.STAGE_H + 40.0:
			break
		await get_tree().process_frame

	a.queue_free()
	return null

## 弦を引き絞る。縦に伸びて横に潰れる＝引かれた弓の形。
func _draw_bow() -> void:
	await _deform_bow(0.0, 1.0, DRAW_TIME, EASE_OUT)

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

# ---------------------------------------------------------------- 案内

## 画面下に短い言葉を出す。前のものがあれば消す。
func _show_hint(text: String) -> void:
	if is_instance_valid(_hint):
		_hint.queue_free()
	_hint = KanjiSprite.new()
	_hint.text = text
	_hint.color = COL_SUB
	_hint.font_size = 14
	_hint.z_index = 11
	add_child(_hint)
	_hint.set_scratch_pos(0, -160)

# ---------------------------------------------------------------- クリア

func _finish() -> void:
	_finished = true
	hero.can_move = false

	await get_tree().create_timer(0.12).timeout

	goal.text = "達成"
	goal.color = COL_DONE
	goal.set_scratch_pos(0, 155)   ## 字数が変わるので置き直す
	goal.z_index = 10
	await Effects.pop_in(goal, 0.45)

	Effects.burst(self, goal.position)
	await Effects.cheer(hero)
	await Effects.show_banner(self, "祝", COL_DONE)

	if Game.stage_no < Game.STAGE_MAX:
		_show_end_hint("スペースキーで次のステージへ")
	else:
		_show_end_hint("スペースキーでもう一度")

func _show_end_hint(text: String) -> void:
	_restart_hint = KanjiSprite.new()
	_restart_hint.text = text
	_restart_hint.color = COL_SUB
	_restart_hint.font_size = 16
	_restart_hint.z_index = 11
	add_child(_restart_hint)
	_restart_hint.set_scratch_pos(0, -60)

	## この瞬間に押していたキーを拾わないよう、少し待ってから受け付ける。
	await get_tree().create_timer(0.5).timeout
	_can_restart = true
	Effects.blink(_restart_hint, func(): return _can_restart)

## 決定キー。次のステージがあれば進み、無ければ最初からやり直す。
func _confirm() -> void:
	if not _can_restart:
		return
	_can_restart = false
	if Game.stage_no < Game.STAGE_MAX:
		Game.goto_stage(get_tree(), Game.stage_no + 1)
	else:
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
