extends Node2D
## ゲーム全体の進行。Scratch のメッセージ (start1 / start1_2 / start1_3) を
## そのままシーン 1 / 2 / 3 として実装している。

const COL_TREE := Color("#9e6a3f")   ## 木・木木木・倒木
const COL_CHEST := Color("#bb3023")  ## 宝箱
const COL_AXE := Color("#a7a7a7")    ## 斧
const COL_CUT := Color("#ff7729")    ## 切
const COL_SCAR := Color("#6b4423")   ## 木に残る切り跡
const COL_SOIL := Color("#6a302a")   ## 土
const COL_GOAL := Color("#000000")   ## 目標
const COL_DONE := Color("#3f9e44")   ## 達成
const COL_SUB := Color("#555555")    ## 案内文字

## 斧を構える位置（勇者から見て右上）。
const AXE_OFFSET := Vector2(16, -16)
## 斧を水平に右から左へ振る。x は勇者からの左右方向のずれ（+が右）。
## 振りかぶり位置（右にぐっと引く）。
const SWING_START_X := 26.0
## 木に当たる位置（左）。
const SWING_HIT_X := -20.0
## 振っている間の高さ（勇者の肩の高さで水平に薙ぐ）。
const SWING_Y := -10.0
## 加速のしかた。等速だと機械的なので、場面ごとに緩急をつける。
## 値は Effects.ease_k に渡すので、あちらの enum と並び順を合わせてある。
enum { EASE_IN, EASE_OUT }

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

var _busy := false          ## 演出中は入力を無視する
var _swinging := false      ## 斧を振っている最中か
var _trail := false         ## 振り抜き中だけ残像を出す
var _axe_prev_x := 0.0      ## 歪みの計算用。直前のフレームの斧の x
var _finished := false      ## クリア後は完全に停止する
var _can_restart := false   ## クリア後、やり直しを受け付けるか
var _can_advance := false   ## クリア後、次のステージへ進むのを受け付けるか
var _leaving := false       ## この場面を出ていく最中か（演出を止める合図）
var _scars: Array = []      ## 木に刻んだ切り跡
var _restart_hint: KanjiSprite  ## 「もう一度」の案内

func _ready() -> void:
	Game.reset()   ## 起動時だけ全変数を初期化する（斧を含む）
	hero.river = river
	## シネマモード中に右端 (x>230) まで歩くとシーン 1 に戻る。
	hero.reached_right_edge.connect(_on_hero_reached_right_edge)
	_setup_colors()
	Effects.show_escape_hint(self)   ## 左上に「Esc でタイトルに戻る」
	## 操作ボタンは、指で触れる機械のときだけ出す。
	if TouchPad.needed():
		add_child(TouchPad.new())
	## 先にシーン 1 を組んでから待つ。
	## 後から組むと、待っている間シーンの初期配置（全員が原点にいる状態）が
	## 見えてしまい、一瞬シーン 2 のように見えてしまう。
	start_scene1()
	_busy = true                                ## 待っている間は入力を受けない
	await get_tree().create_timer(1.0).timeout  ## Scratch の「1秒待つ」
	_busy = false

func _setup_colors() -> void:
	hero.text = "勇";      hero.color = Color.BLACK
	tree_sprite.text = "木"; tree_sprite.color = COL_TREE
	chest.text = "宝箱";    chest.color = COL_CHEST
	goal.text = "目標";     goal.color = COL_GOAL
	forest.text = "木木木"
	forest.color = COL_TREE
	forest.vertical = true
	forest.pivot = Vector2(0.5, 1.0)  ## 根元を軸にして倒れる
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
	axe.visible = Game.got_axe
	cut_mark.visible = false
	_clear_soil()

# ---------------------------------------------------------------- シーン 2

## start1_2: シネマモード。宝箱から斧を取り、木木木 を 3 回切って倒す。
## 木に刻んだ切り跡を消す。
func _clear_scars() -> void:
	for sc in _scars:
		if is_instance_valid(sc):
			sc.queue_free()
	_scars.clear()

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

	forest.visible = true
	forest.rotation = 0.0
	forest.set_scratch_pos(30, -158)

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
	if _finished or _busy:
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
	if Game.got_axe and hero.touching(forest) and Input.is_action_pressed("ui_accept"):
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
	if hero.touching(chest) and Input.is_action_pressed("ui_accept"):
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
	await _swing_axe(AXE_OFFSET.x, SWING_START_X, SWING_WINDUP_TIME, EASE_OUT)
	## 2. 振り抜き。止まった状態から一気に加速する（ease-in）。
	##    残像を置いて、水平に薙いだ軌跡を見せる。
	_trail = true
	await _swing_axe(SWING_START_X, SWING_HIT_X, SWING_STRIKE_TIME, EASE_IN)
	_trail = false

	## 命中の瞬間に「切」を表示する。
	cut_mark.visible = true
	## Scratch のコスチューム 1/2/3 は大きさ違い。回数に合わせて拡大する。
	var s := 0.7 + 0.35 * float(Game.cut_count - 1)
	cut_mark.scale = Vector2(s, s)

	## 3. 木に食い込んで急停止。少しめり込んで止まる。
	await get_tree().create_timer(0.14).timeout
	## 4. 引き抜いて構えに戻す。疲れた感じでゆっくり（ease-out）。
	await _swing_axe(SWING_HIT_X, AXE_OFFSET.x, SWING_RETURN_TIME, EASE_OUT)
	_swinging = false

	await get_tree().create_timer(0.6).timeout
	cut_mark.visible = false

	## 切った跡を木に残す。切るほど傷が増えて、倒れる手前だと分かる。
	_add_scar()

	if Game.cut_count > 2:
		await _fell_tree()
	else:
		_busy = false

## 木に切り跡を刻む。切った回数ぶん、傷が深く大きくなっていく。
func _add_scar() -> void:
	var scar := KanjiSprite.new()
	scar.text = "傷"
	scar.color = COL_SCAR
	## 回数を重ねるほど大きく、濃くする。
	scar.font_size = 14 + Game.cut_count * 4
	scar.z_index = 5
	forest.add_child(scar)
	## 木の高さの、切った回数に応じた所へ刻む。
	## 下から順に刻んでいくので、傷が積み上がって見える。
	var y := -150.0 + float(Game.cut_count - 1) * 14.0
	scar.position = Vector2(randf_range(-6.0, 6.0), y - forest.position.y)
	## 出るときに一瞬弾ませて、刻まれた感じを出す。
	Effects.pop_in(scar, 0.25)
	_scars.append(scar)

## 斧を x1 から x2 まで水平に動かす。ease で緩急を変える。
func _swing_axe(x1: float, x2: float, dur: float, ease_type: int) -> void:
	var t := 0.0
	while t < dur:
		t += get_process_delta_time()
		var k: float = clampf(t / dur, 0.0, 1.0)
		_place_swinging_axe(lerpf(x1, x2, Effects.ease_k(k, ease_type)))
		await get_tree().process_frame
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
	## 50 回小刻みに揺れる。
	for i in 50:
		forest.position.x += randf_range(-1.0, 1.0)
		await get_tree().process_frame
	## 15 度ずつ 6 回、左に倒れる。
	for i in 6:
		forest.rotation -= deg_to_rad(15.0)
		await get_tree().create_timer(0.1).timeout
	await get_tree().create_timer(1.0).timeout
	start_scene3()

## 目標に到達。その瞬間にゲームを止めてクリア演出に入る。
func _finish() -> void:
	_finished = true
	hero.can_move = false   ## 到達した瞬間に勇者を止める

	## 1. 一瞬止めて「決まった」感を作る。
	await get_tree().create_timer(0.12).timeout

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
	if Game.stage_no < Game.STAGE_MAX:
		_show_next_stage_hint()
	else:
		_show_restart_hint()

## クリア後の「もう一度」案内。点滅させ、スペースかクリックで最初から始める。
func _show_restart_hint() -> void:
	## 途中でタイトルへ抜けていたら、もう何もしない。
	if _left():
		return
	_restart_hint = KanjiSprite.new()
	_restart_hint.text = "スペースキーでもう一度"
	_restart_hint.color = COL_SUB
	_restart_hint.font_size = 16
	_restart_hint.z_index = 11
	add_child(_restart_hint)
	_restart_hint.set_scratch_pos(0, -60)

	## この瞬間に押していたキーを拾わないよう、少し待ってから受け付ける。
	await get_tree().create_timer(0.5).timeout
	_can_restart = true
	_blink_restart_hint()

## クリア後の「次のステージへ」案内。_show_restart_hint と同じ作りで文言だけ違う。
func _show_next_stage_hint() -> void:
	## 途中でタイトルへ抜けていたら、もう何もしない。
	if _left():
		return
	_restart_hint = KanjiSprite.new()
	_restart_hint.text = "スペースキーで次のステージへ"
	_restart_hint.color = COL_SUB
	_restart_hint.font_size = 16
	_restart_hint.z_index = 11
	add_child(_restart_hint)
	_restart_hint.set_scratch_pos(0, -60)

	## この瞬間に押していたキーを拾わないよう、少し待ってから受け付ける。
	await get_tree().create_timer(0.5).timeout
	_can_advance = true
	_blink_restart_hint()

## 案内をゆっくり点滅させる。やり直すか次へ進んだら止まる。
func _blink_restart_hint() -> void:
	Effects.blink(_restart_hint, func(): return _can_restart or _can_advance)

## この場面をもう離れたか。演出は await をまたぐので、
## 続きを進める前にこれで確かめる。
func _left() -> bool:
	return _leaving or not is_inside_tree()

## 最初からやり直す。Game の変数も戻すので、斧を持っていない状態から始まる。
func _restart() -> void:
	if not _can_restart:
		return
	_can_restart = false
	Game.reset()
	## reload_current_scene() は current_scene が未設定だと失敗するので、
	## 本編のシーンを名指しで読み直す。
	get_tree().change_scene_to_file("res://scenes/main.tscn")

## 次のステージへ進む。持ち物はここで捨てられる（reset_stage）。
func _advance_stage() -> void:
	if not _can_advance:
		return
	_can_advance = false
	Game.goto_stage(get_tree(), Game.stage_no + 1)

## クリア後の決定キー。次へ進めるならそちらを、無ければやり直しを行う。
func _confirm() -> void:
	if _can_advance:
		_advance_stage()
	elif _can_restart:
		_restart()

func _unhandled_input(event: InputEvent) -> void:
	## Esc はいつでもタイトルへ戻れる。
	if event is InputEventKey and event.pressed and not event.echo \
			and event.keycode == KEY_ESCAPE:
		## 動いている演出を止めてから抜ける。
		## 止めないと、解放されたノードを触りにいって固まる。
		_leaving = true
		_finished = true
		_can_restart = false
		_can_advance = false
		Game.reset()
		get_tree().change_scene_to_file("res://scenes/title.tscn")
		return
	if not _can_restart and not _can_advance:
		return
	if event is InputEventMouseButton and event.pressed:
		_confirm()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER \
				or event.keycode == KEY_KP_ENTER:
			_confirm()
