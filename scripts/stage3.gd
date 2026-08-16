extends Node2D
## ステージ 3「蟲」。
##
## 行く手を塞ぐ相手そのものを射て、道を開ける話。
##
## 【解き方】道を塞ぐ「蟲」は、頭と節が硬くて矢が通らない。
## 矢が通るのは列のいちばん後ろの「尾」だけ。尾を射ると節が 1 つ減り、
## 新しい末尾が尾になる。頭を狙わず、尻尾を狙うのが答え。
## （別作の弾幕ゲーム第三面の主「蟲」と同じ趣向を、弓矢に置き換えたもの）

const COL_WORM := Color("#c2559b")    ## 蟲の頭（桃）
const COL_JOINT := Color("#7a4fa3")   ## 節（紫）
const COL_TAIL := Color("#3f9e44")    ## 尾（弱点なので目立たせる）
const COL_BOW := Color("#66421f")     ## 弓
const COL_CHEST := Color("#bb3023")   ## 宝箱
const COL_BOW_FULL := Color("#c2559b") ## 引き絞りきった弓（もう放てる合図）
const COL_ARROW := Color("#555555")   ## 矢
const COL_GOAL := Color("#000000")    ## 目標
const COL_DONE := Color("#3f9e44")    ## 達成
const COL_SUB := Color("#555555")     ## 案内文字
const COL_HARD := Color("#a7a7a7")    ## 弾かれた印
const COL_HOLE := Color("#333333")   ## 穴
const COL_HURT := Color("#bb3023")   ## やられた印

## 弓を構える位置（勇者から見て右上）。ステージ 1 の斧と同じ考え方。
const BOW_OFFSET := Vector2(16, -16)

## 加速のしかた。Effects.ease_k に渡すので、あちらの enum と並び順を合わせてある。
enum { EASE_IN, EASE_OUT }

## 引き絞りきるまでの時間。押しっぱなしでこの秒数かけて満ちる。
const CHARGE_TIME := 0.8
## 引き絞ったときの太さ。押している間、細い状態からこの倍率まで太くなる。
## 力をためている様子を「字が太くなる」で表している。
const BOW_THIN := 0.55    ## 構えているだけのときの横幅
const BOW_THICK := 1.8    ## 引き絞りきったときの横幅
## 引き戻す（放したあと元の構えに戻る）時間。
const RELEASE_TIME := 0.18

## 矢の速さ (px/秒)。引き絞るほど速い。
const ARROW_SPEED_MIN := 300.0
const ARROW_SPEED_MAX := 760.0
## 矢が飛ぶ距離。引き絞った量でここが決まる。
## 浅いとほとんど飛ばず足元に落ちる。引き絞りきって、ようやく画面の端に届く。
## 距離は引き具合の 3 乗で伸ばす。half まで引いても 1/8 しか飛ばないので、
## 「しっかりためないと届かない」という手応えになる。
const ARROW_RANGE_MIN := 15.0
const ARROW_RANGE_MAX := 330.0
## 力尽きたあと、落ちきるまでの猶予。
const ARROW_LIFE := 2.0
## 矢が出る位置。勇者から、飛ぶ向きにこれだけ離れた所から出す。
const ARROW_MUZZLE_DIST := 18.0
## 矢の当たる広さ。蟲は動くので、矩形が触れるかだけでは狙いが厳しすぎる。
const ARROW_REACH := 22.0
## 残像を置く間隔 (px)。これより近い所には重ねて置かない。
const TRAIL_GAP := 12.0

## 蟲の節の数（頭を除く）。最後の 1 つが弱点の「尾」。
const JOINT_COUNT := 7
## 毒を吐く間隔（秒）と、毒の速さ・当たる広さ。
const POISON_INTERVAL := 1.6
const POISON_SPEED := 150.0
const POISON_REACH := 16.0
const COL_POISON := Color("#6aa84f")  ## 毒

## 穴（蟲のすみか。倒すと目標になる）の高さ。
const HOLE_Y := 150.0
## 蟲が這う高さと、蛇行の幅・速さ。
## 尾は頭より遅れて動くぶん大きく振れる。振り幅を欲張ると
## 勇者（5px/コマ）では追いつけず、狙えなくなるので控えめにしている。
const WORM_Y := 40.0
const WORM_SWAY_X := 80.0
const WORM_SWAY_Y := 18.0
const WORM_SPEED := 0.7
## 頭の通った道を、この距離ごとに刻んで覚える。
## 細かく刻むほど節の動きが滑らかになる（そのぶん覚える点は増える）。
const TRAIL_STEP := 3.0
## 節どうしの間隔（軌跡を何点ぶんさかのぼるか）。
## TRAIL_STEP × TRAIL_SKIP が節と節の距離になる。
const TRAIL_SKIP := 9

@onready var worm_root: Node2D = $Worm
@onready var hero: KanjiSprite = $Hero
@onready var bow: KanjiSprite = $Bow
@onready var chest: KanjiSprite = $Chest
@onready var goal: KanjiSprite = $Goal

var _busy := false          ## 演出中は入力を無視する
var _finished := false      ## クリア後は完全に停止する
var _can_restart := false   ## クリア後、次へ進むのを受け付けるか
var _restart_hint: KanjiSprite
var _shoot_was_down := false ## 前のコマでスペースが押されていたか
var _charge := 0.0          ## 引き絞り具合（0=細い 〜 1=引き絞りきった）
var _leaving := false       ## この場面を出ていく最中か（演出を止める合図）
var _shooting := false      ## 射っている最中か（弓の位置は演出側が決める）
var _worm_beaten := false   ## 蟲を倒したか（穴が目標に変わったか）

## 蟲の頭と、連なる節。節の最後が「尾」。
var _worm_head: KanjiSprite = null
var _joints: Array = []
## 頭の通った道。節はこの上を追いかける。
var _trail: Array = []
var _phase := 0.0
var _emerging := 1.0        ## 穴から出てくる途中の度合い（1=出きった）
var _emerging_now := false  ## 登場演出の最中か（頭を動かす担当を分けるため）
var _poison_timer := 0.0    ## 次に毒を吐くまで
var _poisons: Array = []    ## 飛んでいる毒

func _ready() -> void:
	## Game.reset() は stage_no を 1 に戻してしまうのでここでは呼ばない。
	Game.reset_stage()
	## エディタからこのシーンだけを実行したときのための保険。
	Game.stage_no = 3

	_setup_colors()

	## 先に場面を組んでから待つ。
	## 後から組むと、待っている間に初期配置（全員が原点にいる状態）が見えてしまう。
	start_scene1()
	_busy = true
	await get_tree().create_timer(1.0).timeout
	_busy = false

func _setup_colors() -> void:
	hero.text = "勇";     hero.color = Color.BLACK
	bow.text = "弓";      bow.color = COL_BOW
	chest.text = "宝箱";  chest.color = COL_CHEST
	goal.text = "目標";   goal.color = COL_GOAL

# ---------------------------------------------------------------- 場面

## 道を塞ぐ蟲と対峙する。倒せば目標へ進める。
func start_scene1() -> void:
	Game.scene_no = 1
	Game.cinema_mode = false
	_busy = false
	_worm_beaten = false

	hero.visible = true
	hero.set_scratch_pos(0, -130)
	hero.can_move = true

	## 宝箱。重なってスペースで開けると弓が手に入る（ステージ 1 と同じ作法）。
	chest.visible = true
	chest.text = "空箱" if Game.got_bow else "宝箱"
	chest.set_scratch_pos(-190, -130)

	## 弓は宝箱から出るまで見えない。
	bow.visible = Game.got_bow
	if Game.got_bow:
		_follow_bow()

	## 蟲のすみかの「穴」。蟲はここから這い出てくる。
	## 倒すと、この穴がそのまま「目標」に変わる。
	goal.visible = true
	goal.text = "穴"
	goal.color = COL_HOLE
	goal.modulate.a = 1.0
	goal.scale = Vector2.ONE
	goal.set_scratch_pos(0, HOLE_Y)

	## 蟲は弓を手にしてから穴を出る。
	## 丸腰のうちから襲われても、どうしようもないため。
	_clear_worm()
	if Game.got_bow:
		_build_worm()

## 穴から蟲が這い出てくる。頭が出て、続いて節が 1 つずつ現れる。
## いきなり全身が並ぶと唐突なので、順に出して「出てきた」と分かるようにする。
func _emerge_worm() -> void:
	_busy = true
	_emerging_now = true   ## この間、頭を動かすのはこの関数だけ
	_clear_worm()

	var hole := Game.to_godot(0, HOLE_Y)
	_emerging = 0.0
	_phase = 0.0

	## 軌跡は穴で埋めておく。節はこの道をたどって出てくるので、
	## 頭が進んで道が伸びるまでは、みな穴の中にいることになる。
	_trail.clear()
	var need := JOINT_COUNT * TRAIL_SKIP + TRAIL_SKIP + 2
	for i in need:
		_trail.append(hole)

	## まず頭が穴からゆっくりせり出す。
	_worm_head = KanjiSprite.new()
	_worm_head.text = "蟲"
	_worm_head.color = COL_WORM
	_worm_head.font_size = 32
	_worm_head.scale = Vector2.ZERO
	worm_root.add_child(_worm_head)
	_worm_head.position = hole
	var t := 0.0
	while t < HEAD_EMERGE_TIME:
		t += get_process_delta_time()
		var k: float = clampf(t / HEAD_EMERGE_TIME, 0.0, 1.0)
		## 穴からせり上がるように、下から現れて大きくなる。
		_worm_head.scale = Vector2.ONE * k
		await get_tree().process_frame
	_worm_head.scale = Vector2.ONE

	## 頭が這い出し、そのあとを節が 1 つずつ追って出てくる。
	## 節は穴に置くだけにして、位置は軌跡に任せる。
	## 頭が進むほど道が伸びるので、後ろの節ほど遅れて穴を離れる。
	var appeared := 0
	var wait := 0.0
	while _emerging < 1.0 or appeared < JOINT_COUNT:
		var d := get_process_delta_time()
		_advance_worm_head(d)

		if appeared < JOINT_COUNT:
			wait += d
			if wait >= JOINT_EMERGE_INTERVAL:
				wait = 0.0
				var s := KanjiSprite.new()
				s.text = "節"
				s.color = COL_JOINT
				s.font_size = 26
				worm_root.add_child(s)
				s.position = hole
				_joints.append(s)
				appeared += 1
				## ここでは尾を決めない。
				## 出るたびに末尾を「尾」にすると、1 本目から尾が見えてしまう。
				## 全部出そろってから、いちばん後ろを尾にする。
		_place_joints()
		await get_tree().process_frame

	## 出そろったので、最後の 1 つを尾にする。
	_mark_tail()
	_emerging_now = false
	_busy = false

## 頭が穴からせり出すのにかける時間（秒）。
const HEAD_EMERGE_TIME := 0.7
## 節が 1 つ出てくる間隔（秒）。
const JOINT_EMERGE_INTERVAL := 0.35
## 頭が穴から定位置へ移りきるまでの時間（秒）。
## ゆっくり這い出てくるように、長めに取る。
const EMERGE_MOVE_TIME := 3.0

## 蟲を組み立てる（やり直しのときなど、演出なしで並べる）。
func _build_worm() -> void:
	_clear_worm()
	_emerging = 1.0        ## 演出なしなので、出きった状態から始める
	_emerging_now = false

	_worm_head = KanjiSprite.new()
	_worm_head.text = "蟲"
	_worm_head.color = COL_WORM
	_worm_head.font_size = 32
	worm_root.add_child(_worm_head)
	## 穴から這い出てきた形にするため、頭は穴の位置から始める。
	_worm_head.set_scratch_pos(0, HOLE_Y)

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
	_clear_poisons()
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

	## 蟲は演出中も動かし続ける。
	## ここを止めると、矢が飛んでいる間だけ蟲が固まって見えてしまう。
	## ただし穴から出てくる間は演出側が動かすので、ここでは触らない
	## （両方から動かすと進み方が二重になり、頭が飛んで見える）。
	if not _emerging_now:
		_move_worm(delta)

	## 毒も演出中に動かし続ける。
	## 蟲と同じで、矢が飛んでいる間だけ止まると固まって見えてしまう。
	## 吐くのは登場が済んでからにする（出てくる途中に吐かれると理不尽なため）。
	if _worm_head != null and not _emerging_now:
		_spit_poison(delta)
	_move_poisons(delta)

	## 弓は演出中も勇者について回る。
	## ここを止めると、蟲の登場演出の間だけ弓が取り残されて見える。
	_follow_bow()

	if _busy:
		_shoot_was_down = shoot_down
		return

	## 弓を拾ったそのフレームで射ってしまわないようにする。
	## 同じスペース 1 回で「拾う」と「射る」が続けて起きると噛み合わない。
	var just_took := _try_take_bow()
	_follow_bow()
	if just_took:
		_shoot_was_down = true
		return

	## 蟲に触れたらやられる。やり直し。
	## 弓の処理より先に見る。あとに置くと、弓を持っている間は
	## _update_charge で return してしまい、ここまで来ない。
	if (_worm_head != null and _touched_by_worm()) or _touched_by_poison():
		_defeated()
		return

	## 蟲を倒して穴が目標に変わったら、そこへ行ける。
	## _worm_head == null だけで見ると、弓を取る前（まだ蟲が出ていない）でも
	## 通ってしまい、穴に触れるだけでクリアできてしまう。
	if _worm_beaten and hero.touching(goal):
		_finish()
		return

	## 弓を持っている間は、スペースの押し下げで引き絞り、離すと放つ。
	if Game.got_bow:
		_update_charge(delta)

## 蟲が毒を吐く。勇者のいる方へ向けて飛ばす。
func _spit_poison(delta: float) -> void:
	_poison_timer -= delta
	if _poison_timer > 0.0:
		return
	_poison_timer = POISON_INTERVAL

	var p := KanjiSprite.new()
	p.text = "毒"
	p.color = COL_POISON
	p.font_size = 20
	add_child(p)
	p.position = _worm_head.position
	## 勇者の方へ飛ばす。まっすぐ狙うと避けられないので、少しばらす。
	var dir := (hero.position - _worm_head.position).normalized()
	dir = dir.rotated(randf_range(-0.25, 0.25))
	_poisons.append({"node": p, "vel": dir * POISON_SPEED})

## 飛んでいる毒を進める。画面の外に出たら消す。
func _move_poisons(delta: float) -> void:
	var alive: Array = []
	for e in _poisons:
		var p: KanjiSprite = e["node"]
		if not is_instance_valid(p):
			continue
		p.position += e["vel"] * delta
		p.rotation += delta * 2.0
		var q := p.position
		if q.x < -30.0 or q.x > Game.STAGE_W + 30.0 \
				or q.y < -30.0 or q.y > Game.STAGE_H + 30.0:
			p.queue_free()
			continue
		alive.append(e)
	_poisons = alive

## 毒に触れたか。
func _touched_by_poison() -> bool:
	for e in _poisons:
		var p: KanjiSprite = e["node"]
		if is_instance_valid(p) and hero.position.distance_to(p.position) < POISON_REACH:
			return true
	return false

## 飛んでいる毒を全部消す。
func _clear_poisons() -> void:
	for e in _poisons:
		var p: KanjiSprite = e["node"]
		if is_instance_valid(p):
			p.queue_free()
	_poisons.clear()

## 蟲の頭か節に触れたか。
func _touched_by_worm() -> bool:
	if _worm_head != null and hero.touching(_worm_head):
		return true
	for j in _joints:
		if is_instance_valid(j) and hero.touching(j):
			return true
	return false

## 蟲にやられた。少し見せてから、この場面の最初からやり直す。
func _defeated() -> void:
	_busy = true
	hero.can_move = false

	var mark := KanjiSprite.new()
	mark.text = "痛"
	mark.color = COL_HURT
	mark.font_size = 40
	mark.z_index = 12
	add_child(mark)
	mark.position = hero.position
	await Effects.pop_in(mark, 0.3)

	## 勇者が倒れる。
	var t := 0.0
	while t < 0.5:
		t += get_process_delta_time()
		hero.modulate.a = maxf(1.0 - t / 0.5, 0.0)
		await get_tree().process_frame

	await get_tree().create_timer(0.4).timeout
	mark.queue_free()

	## 宝箱が閉じた、何も持っていない状態からやり直す。
	## 蟲も引き金（弓を取ること）から出直しになる。
	Game.got_bow = false
	hero.modulate.a = 1.0
	_shoot_was_down = false
	_charge = 0.0
	_clear_poisons()
	start_scene1()
	## start_scene1 のあとに置き直す。
	## _follow_bow などが位置を触るので、最後に決めておく。
	hero.set_scratch_pos(0, -130)
	hero.can_move = true

## 節を軌跡の上に並べる。
## 点にそのまま置くと、頭が新しい点を刻んだ瞬間に節が 1 点ぶん飛んでカクつく。
## 頭が次の点へどれだけ進んだかを見て、点と点の間を混ぜて置く。
func _place_joints() -> void:
	if _worm_head == null or _trail.is_empty():
		return
	var lead := clampf(_worm_head.position.distance_to(_trail[0]) / TRAIL_STEP, 0.0, 1.0)
	for i in _joints.size():
		var idx := (i + 1) * TRAIL_SKIP
		if idx < _trail.size() and idx >= 1:
			_joints[i].position = _trail[idx].lerp(_trail[idx - 1], lead)
		elif idx < _trail.size():
			_joints[i].position = _trail[idx]

## 頭を進める。穴から出るときと、いつもの動きの両方で使う。
## 頭は横に大きく、縦に小さく、ゆっくりうねる。
## 周期の違う波を重ねると、同じ所を往復している感じが薄れて
## 生きもののような動きに見える。
func _advance_worm_head(delta: float) -> void:
	if _worm_head == null:
		return
	_phase += delta * WORM_SPEED
	var c := Game.to_godot(0, WORM_Y)
	var target := Vector2(
		c.x + sin(_phase) * WORM_SWAY_X + sin(_phase * 0.37) * WORM_SWAY_X * 0.35,
		c.y + sin(_phase * 0.73) * WORM_SWAY_Y)

	## 穴から出てくる間は、いきなり定位置へ飛ばさず少しずつ寄せる。
	## そうしないと、穴ではなく画面の真ん中から現れたように見えてしまう。
	if _emerging < 1.0:
		_emerging = minf(_emerging + delta / EMERGE_MOVE_TIME, 1.0)
		var hole := Game.to_godot(0, HOLE_Y)
		_worm_head.position = hole.lerp(target, Effects.ease_k(_emerging, EASE_OUT))
	else:
		_worm_head.position = target
	## 軌跡を刻む。
	if _trail.is_empty() or _worm_head.position.distance_to(_trail[0]) >= TRAIL_STEP:
		_trail.push_front(_worm_head.position)
		var need := JOINT_COUNT * TRAIL_SKIP + TRAIL_SKIP + 2
		if _trail.size() > need:
			_trail.resize(need)

## 蟲は画面を横に蛇行する。節は頭の通った道を追いかける。
func _move_worm(delta: float) -> void:
	if _worm_head == null:
		return

	_advance_worm_head(delta)

	_place_joints()

	## 尾は弱点なので、脈打たせて目立たせる。
	if not _joints.is_empty():
		var tail: KanjiSprite = _joints[_joints.size() - 1]
		tail.scale = Vector2.ONE * (1.0 + 0.18 * sin(_phase * 6.0))

## 宝箱に重なってスペースを押したら弓が手に入る。手に入れたら true。
func _try_take_bow() -> bool:
	if Game.got_bow or not chest.visible:
		return false
	if hero.touching(chest) and Input.is_action_pressed("ui_accept"):
		chest.text = "空箱"
		Game.got_bow = true
		bow.visible = true
		## 取った瞬間に勇者の横へ置く。
		## このあと蟲の登場演出で _busy になり、しばらく
		## _follow_bow が働かないため、ここで位置を決めておく。
		bow.position = hero.position + BOW_OFFSET
		bow.scale = Vector2(BOW_THIN, 1.0)
		bow.color = COL_BOW
		## ここで蟲が穴から這い出てくる。
		_emerge_worm()
		return true
	return false

## 弓は勇者の右上に構える。射っている最中は演出側が位置を決めるので触らない。
func _follow_bow() -> void:
	if not Game.got_bow:
		return
	bow.visible = true
	## 位置はいつでも勇者について回る。
	## 射っている間だけ止めると、矢が飛んでいるあいだに勇者が動いたとき
	## 弓だけがその場に取り残されて見える。
	bow.position = hero.position + BOW_OFFSET
	## 太さは引き具合や放った反動で決まるので、ここでは触らない
	## （毎コマ戻すと、ためている最中に細くなってしまう）。

## 押している間は引き絞り、離した瞬間に放つ。
## 引き絞りは演出を待たず毎フレーム進めるので、太くなっていく様子が見える。
func _update_charge(delta: float) -> void:
	var down := Input.is_action_pressed("ui_accept")

	if down:
		## 押している間、少しずつ満ちていく。
		_charge = minf(_charge + delta / CHARGE_TIME, 1.0)
		## 引き絞っている間は足を止める。
		## 狙いを定める動作なので、歩きながら撃てると緊張感が無くなる。
		hero.can_move = false
	elif _shoot_was_down:
		## 離した瞬間に放つ。ためた分だけ速く飛ぶ。
		var k := _charge
		_charge = 0.0
		_shoot_was_down = false
		hero.can_move = true   ## 放ったので、また動ける
		_shoot(k)
		return

	_shoot_was_down = down
	_show_bow_charge()

## 引き具合を弓の太さで見せる。細い状態から、ためるほど太くなる。
func _show_bow_charge() -> void:
	if not Game.got_bow or _busy:
		return
	bow.position = hero.position + BOW_OFFSET
	var w := lerpf(BOW_THIN, BOW_THICK, _charge)
	## 太くなるぶん、少しだけ縦を詰めて力がこもった形にする。
	bow.scale = Vector2(w, 1.0 + _charge * 0.25)
	## 満ちきったら色を変えて「もう放てる」と分かるようにする。
	bow.color = COL_BOW_FULL if _charge >= 1.0 else COL_BOW

# ---------------------------------------------------------------- 射る

## 矢を放つ。引き具合 k (0〜1) がそのまま矢の速さになる。
## 向きは常に画面の上。狙いは左右の立ち位置だけで合わせる。
## 当たった相手によって起きることが変わるので、ここで振り分ける。
func _shoot(k: float) -> void:
	_busy = true
	_shooting = true

	## 尾・節・頭・的のどれに当たったかを見る。
	var targets: Array = []
	if _worm_head != null:
		targets.append(_worm_head)
		for j in _joints:
			targets.append(j)

	var struck = await _fly_arrow(targets, Vector2.UP, k)
	await _release_bow()

	if struck == null:
		_busy = false
		return

	_shooting = false
	hero.can_move = true   ## 演出が済んだら動けるように戻す
	if _is_tail(struck):
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
	_worm_head = null      ## これ以降は動かさない
	_worm_beaten = true    ## 穴が目標に変わる

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

	## 穴が目標に変わる。蟲がいなくなって、ようやく先へ行ける。
	await _hole_becomes_goal()

	await get_tree().create_timer(0.6).timeout
	_busy = false

## 蟲がいなくなった穴が、目標に変わる。
## いったん消えてから「目標」として現れ直すことで、変わったことを見せる。
func _hole_becomes_goal() -> void:
	## 穴が閉じる。
	var dur := 0.35
	var t := 0.0
	while t < dur:
		t += get_process_delta_time()
		var k: float = clampf(t / dur, 0.0, 1.0)
		goal.scale = Vector2.ONE * (1.0 - k)
		await get_tree().process_frame
	goal.scale = Vector2.ZERO

	## 目標として現れる。
	goal.text = "目標"
	goal.color = COL_GOAL
	await Effects.pop_in(goal, 0.5)

## 矢を飛ばす。当たった相手を返す（外れたら null）。
## 矢は回転させない。当たり判定が回転を考えないため、傾けるとずれてしまう。
## 代わりに縦横で字の形を変え、飛ぶ向きに沿った細長い形にする。
func _fly_arrow(targets: Array, dir: Vector2 = Vector2.UP, k: float = 1.0):
	var a := KanjiSprite.new()
	a.text = "矢"
	a.color = COL_ARROW
	## 上へ飛ぶので、縦書きにして字そのものを上向きの細長い形にする。
	## 回転させないのは、当たり判定が回転を考えないため。
	a.vertical = absf(dir.y) > absf(dir.x)
	add_child(a)
	a.position = hero.position + dir * ARROW_MUZZLE_DIST

	## ためた分だけ速く、そして遠くまで飛ぶ。
	## 引きが浅いとすぐ力尽きて落ちるので、しっかりためる意味が出る。
	var kk: float = clampf(k, 0.0, 1.0)
	var speed: float = lerpf(ARROW_SPEED_MIN, ARROW_SPEED_MAX, kk)
	## 3 乗にすることで、浅い引きでは極端に飛ばなくなる。
	var range_max: float = lerpf(ARROW_RANGE_MIN, ARROW_RANGE_MAX, kk * kk * kk)
	var start := a.position
	## 力尽きたあとの落下の速さ。
	var fall := 0.0

	var t := 0.0
	## 残像を置いた場所。近すぎる所には重ねて置かない。
	var last_trail := a.position
	while t < ARROW_LIFE:
		if _leaving or not is_instance_valid(a):
			if is_instance_valid(a):
				a.queue_free()
			return null
		var d := get_process_delta_time()
		t += d
		if start.distance_to(a.position) < range_max:
			## まだ勢いがある。まっすぐ飛ぶ。
			a.position += dir * speed * d
			## 軌跡は飛んでいる間だけ、しかも一定の間隔を空けて置く。
			## 毎コマ置くと、遅い矢ほど同じ場所に濃く積み重なり、
			## 消えるまでいつまでも残って見えてしまう。
			if last_trail.distance_to(a.position) >= TRAIL_GAP:
				last_trail = a.position
				Effects.leave_trail(self, a)
		else:
			## 力尽きた。あとは落ちるだけ。残像はもう置かない。
			fall += 900.0 * d
			a.position.y += fall * d
			a.modulate.a = maxf(a.modulate.a - d * 2.0, 0.0)
			if a.modulate.a <= 0.0:
				break

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

## 放ったあと、太くなっていた弓が細い構えに戻る。
## 勢いよく戻って少し行き過ぎる（弦が鳴る感じ）。
func _release_bow() -> void:
	if not Game.got_bow:
		return
	bow.color = COL_BOW
	var from: float = bow.scale.x
	var t := 0.0
	while t < RELEASE_TIME:
		t += get_process_delta_time()
		var p: float = clampf(t / RELEASE_TIME, 0.0, 1.0)
		var e := Effects.ease_k(p, EASE_OUT)
		## 行き過ぎてから戻ることで、放った反動に見せる。
		var overshoot := sin(p * PI) * 0.18
		bow.position = hero.position + BOW_OFFSET
		bow.scale = Vector2(lerpf(from, BOW_THIN, e) - overshoot, 1.0)
		await get_tree().process_frame
	bow.scale = Vector2(BOW_THIN, 1.0)

# ---------------------------------------------------------------- クリア

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

## タイトル画面へ戻る。
func _to_title() -> void:
	## 飛んでいる矢の演出を止める。
	## 止めないと、解放されたあとも残像を作ろうとして落ちる。
	_leaving = true
	Game.reset()
	get_tree().change_scene_to_file("res://scenes/title.tscn")

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
	## Esc はいつでもタイトルへ戻れる。
	if event is InputEventKey and event.pressed and not event.echo \
			and event.keycode == KEY_ESCAPE:
		_to_title()
		return
	if not _can_restart:
		return
	if event is InputEventMouseButton and event.pressed:
		_confirm()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER \
				or event.keycode == KEY_KP_ENTER:
			_confirm()
