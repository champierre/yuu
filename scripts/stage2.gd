extends Node2D
## ステージ 2「鉄」。Scratch 版「『勇』の冒険2」(427402420) の移植。
##
## 【解き方】漢字の足し算が答え。
## 門番は「金より鉄が貴重だ。鉄を持ってこい」と言う。
## 宝箱から出るのは「金」で、そのままでは通してもらえない。
##
## 村人は「盗人に気をつけろ」と警告してくるが、これは裏を返せば
## 「盗人に会えば金を失える」という道しるべでもある。
## わざと盗人に捕まって金を失うと、持ち物が「失」に変わる。
## その状態でもう一度宝箱を開けると「金」＋「失」＝「鉄」になる。
##
## 失うことで手に入る、という筋がそのまま字の形になっている。

const COL_WALL := Color("#7a6a55")     ## 壁
const COL_GATE := Color("#66421f")     ## 門
const COL_CHEST := Color("#bb3023")    ## 宝箱
const COL_GOLD := Color("#e0b020")     ## 金
const COL_LOST := Color("#8a8a8a")     ## 失
const COL_IRON := Color("#5a7a8a")     ## 鉄
const COL_KEEPER := Color("#33339e")   ## 門番
const COL_VILLAGER := Color("#3f9e44") ## 村人
const COL_THIEF := Color("#7a3f7a")    ## 盗人
const COL_GOAL := Color("#000000")     ## 目標
const COL_DONE := Color("#3f9e44")     ## 達成
const COL_SUB := Color("#555555")      ## 案内文字
const COL_SHOCK := Color("#3a5a9e")    ## 悲しみ（青。赤だと怒りに見えるため）

## 壁の高さ。ここから上（目標側）へは門を通らないと行けない。
const WALL_Y := 75.0
## 壁を並べる刻み幅。
const WALL_STEP := 20.0
## 門のある隙間（この 2 マスだけ壁が無い）。
const GATE1_X := 0.0
const GATE2_X := -20.0

## 村人と盗人がうろつく速さ（秒あたりの歩数）と、1 歩の幅。
const WANDER_INTERVAL := 0.9
const WANDER_STEP := 20.0
## 村人が下の街から出ないための上下の限り。
const WANDER_TOP := 10.0
const WANDER_BOTTOM := -140.0
## 盗人はこれより右へは来ない（左手に居着いている）。
const THIEF_RIGHT_LIMIT := -20.0

## 話しかけられたときの間合い。
const TALK_REACH := 26.0

## 加速のしかた。Effects.ease_k に渡すので、あちらの enum と並び順を合わせてある。
enum { EASE_IN, EASE_OUT }

@onready var wall_root: Node2D = $Wall
@onready var hero: KanjiSprite = $Hero
@onready var chest: KanjiSprite = $Chest
@onready var item: KanjiSprite = $Item
@onready var gate1: KanjiSprite = $Gate1
@onready var gate2: KanjiSprite = $Gate2
@onready var keeper: KanjiSprite = $Keeper
@onready var thief: KanjiSprite = $Thief
@onready var goal: KanjiSprite = $Goal

var _villagers: Array = []
var _villager_lines := {}    ## 村人ごとに、どちらのセリフを言うか
var _busy := false           ## 演出中は入力を無視する
var _finished := false
var _can_restart := false
var _restart_hint: KanjiSprite
var _talk: KanjiSprite       ## 今出ているセリフ
var _talk_until := 0.0       ## セリフを消す時刻
var _wander_timer := 0.0
var _act_was_down := false   ## 調べるキーの押しっぱなしを 1 回として扱う
var _thief_gone := false     ## 盗人は金を奪うと去る

func _ready() -> void:
	## Game.reset() は stage_no を 1 に戻してしまうのでここでは呼ばない。
	Game.reset_stage()
	Game.stage_no = 2

	_setup_colors()
	Effects.show_escape_hint(self)   ## 左上に「Esc でタイトルに戻る」
	start_scene1()
	_busy = true
	await get_tree().create_timer(1.0).timeout
	_busy = false

func _setup_colors() -> void:
	hero.text = "勇";     hero.color = Color.BLACK
	chest.text = "宝箱";  chest.color = COL_CHEST
	gate1.text = "門";    gate1.color = COL_GATE
	gate2.text = "門";    gate2.color = COL_GATE
	keeper.text = "門番"; keeper.color = COL_KEEPER
	thief.text = "盗人";  thief.color = COL_THIEF
	goal.text = "目標";   goal.color = COL_GOAL

# ---------------------------------------------------------------- 場面

func start_scene1() -> void:
	Game.scene_no = 1
	Game.cinema_mode = false
	_busy = false
	_thief_gone = false

	_build_wall()

	hero.visible = true
	hero.text = "勇"
	hero.color = Color.BLACK
	hero.scale = Vector2.ONE
	hero.set_scratch_pos(0, -120)
	hero.can_move = true
	## 壁と門にぶつかる。hero.gd は「川」として渡された群れを見るので、
	## ここでは壁と門をまとめて渡している。
	hero.river = wall_root

	chest.visible = true
	chest.set_scratch_pos(200, 50)

	## 持ち物。取るまでは見えない。
	item.visible = false
	item.text = "金"
	item.color = COL_GOLD

	## 門は壁と同じ入れ物に移して、開くまでは通れないようにする。
	## ここに入れ忘れると、閉じているのにすり抜けられてしまう。
	for gate in [gate1, gate2]:
		if gate.get_parent() != wall_root:
			gate.get_parent().remove_child(gate)
			wall_root.add_child(gate)
		gate.visible = true
		gate.modulate.a = 1.0
	gate1.set_scratch_pos(GATE1_X, WALL_Y)
	gate2.set_scratch_pos(GATE2_X, WALL_Y)

	keeper.visible = true
	## 壁 (y=75) と重ならないよう、少し下に立たせる。
	keeper.set_scratch_pos(40, 40)

	thief.visible = true
	thief.set_scratch_pos(-60, -20)

	goal.visible = true
	goal.text = "目標"
	goal.color = COL_GOAL
	goal.scale = Vector2.ONE
	goal.set_scratch_pos(0, 150)

	_build_villagers()

## 壁を横一列に並べる。門のある 2 マスだけ空ける。
## 門も同じ入れ物にぶら下げて、まとめて当たり判定の相手にする。
func _build_wall() -> void:
	## 門は使い回すので消さない。壁だけを作り直す。
	for c in wall_root.get_children():
		if c == gate1 or c == gate2:
			continue
		wall_root.remove_child(c)
		c.queue_free()

	var x := -240.0
	while x <= 220.0:
		## 門の場所は空けておく。
		if not is_equal_approx(x, GATE1_X) and not is_equal_approx(x, GATE2_X):
			var w := KanjiSprite.new()
			w.text = "壁"
			w.color = COL_WALL
			wall_root.add_child(w)
			w.set_scratch_pos(x, WALL_Y)
		x += WALL_STEP

## 村人を 3 人置く。街をうろついて、勇者に話しかけてくる。
## 村人はシーンに 3 人置いてある。それを並べ直して使う。
## ここで新しく作ると、シーン側の 3 人が置き場所のないまま
## 画面の隅に そのまま残ってしまう。
func _build_villagers() -> void:
	_villagers = [$Villager1, $Villager2, $Villager3]
	_villager_lines.clear()

	var spots := [Vector2(0, 0), Vector2(-100, -80), Vector2(100, -20)]
	for i in _villagers.size():
		var v: KanjiSprite = _villagers[i]
		v.text = "村人"
		v.color = COL_VILLAGER
		v.visible = true
		v.set_scratch_pos(spots[i].x, spots[i].y)

# ---------------------------------------------------------------- 毎フレーム処理

func _process(delta: float) -> void:
	if _finished:
		return
	_fade_talk(delta)
	if _busy:
		_act_was_down = Input.is_action_pressed("ui_accept")
		return

	_wander(delta)

	## 門は開いたら通れるようにする（当たり判定から外す）。
	## 宝箱・門番・盗人・村人は素通りでき、触れると話が起きるだけ。
	if _act_pressed():
		_try_chest()

	_meet_keeper()
	_meet_thief()
	_meet_villagers()

	## 持ち物は勇者について回る。
	if item.visible:
		item.position = hero.position + Vector2(18, -16)

	## 門が開いていれば、目標へ行ける。
	if Game.gate_open and hero.touching(goal):
		_finish()

## 調べるキーを「押した瞬間」だけ拾う。
func _act_pressed() -> bool:
	var down := Input.is_action_pressed("ui_accept")
	var just := down and not _act_was_down
	_act_was_down = down
	return just

## 村人と盗人が街をうろつく。
func _wander(delta: float) -> void:
	_wander_timer -= delta
	if _wander_timer > 0.0:
		return
	_wander_timer = WANDER_INTERVAL

	for v in _villagers:
		if is_instance_valid(v):
			_step_wander(v, false)
	if thief.visible and not _thief_gone:
		_step_wander(thief, true)

## 1 歩ぶん、でたらめな向きへ動かす。
## 街の中（壁より下）から出ないように、上下に限りをつける。
func _step_wander(s: KanjiSprite, is_thief: bool) -> void:
	var p := s.scratch_pos()
	match randi() % 4:
		0:
			## 盗人は左手に居着いていて、右へは来ない。
			if not is_thief or p.x < THIEF_RIGHT_LIMIT:
				p.x += WANDER_STEP
		1: p.x -= WANDER_STEP
		2: if p.y < WANDER_TOP: p.y += WANDER_STEP
		3: if p.y > WANDER_BOTTOM: p.y -= WANDER_STEP
	## 画面の外へは出さない。
	p.x = clampf(p.x, -220.0, 220.0)
	s.set_scratch_pos(p.x, p.y)

# ---------------------------------------------------------------- 出会い

## 宝箱を開ける。中身は持ち物の状態で変わる。
func _try_chest() -> void:
	if not chest.visible or hero.position.distance_to(chest.position) > TALK_REACH + 12.0:
		return
	if Game.lost_gold:
		## 金を失ったあとに開けると、「金」と「失」が合わさって「鉄」になる。
		_forge_iron()
	elif not Game.got_gold:
		_take_gold()

## 宝箱から「金」を取る。
func _take_gold() -> void:
	Game.got_gold = true
	item.visible = true
	item.text = "金"
	item.color = COL_GOLD
	item.position = hero.position + Vector2(18, -16)
	_say("金を手に入れた")

## 「金」＋「失」＝「鉄」。このゲームの答え。
func _forge_iron() -> void:
	_busy = true
	hero.can_move = false

	_say("金 ＋ 失 ＝ ？", 2.0)

	## 二つの字を勇者の前に並べて見せる。
	var a := KanjiSprite.new()
	a.text = "金"
	a.color = COL_GOLD
	a.font_size = 34
	a.z_index = 10
	add_child(a)
	a.set_scratch_pos(-40, 0)

	var b := KanjiSprite.new()
	b.text = "失"
	b.color = COL_LOST
	b.font_size = 34
	b.z_index = 10
	add_child(b)
	b.set_scratch_pos(40, 0)

	item.visible = false
	await get_tree().create_timer(0.8).timeout

	## 二つが中央へ寄って重なる。
	var t := 0.0
	var dur := 0.7
	var pa := a.position
	var pb := b.position
	var mid := Game.to_godot(0, 0)
	while t < dur:
		t += get_process_delta_time()
		var k: float = clampf(t / dur, 0.0, 1.0)
		var e := Effects.ease_k(k, EASE_IN)
		a.position = pa.lerp(mid, e)
		b.position = pb.lerp(mid, e)
		await get_tree().process_frame
	a.queue_free()
	b.queue_free()

	## 重なった所から「鉄」が現れる。
	var iron := KanjiSprite.new()
	iron.text = "鉄"
	iron.color = COL_IRON
	iron.font_size = 48
	iron.z_index = 11
	add_child(iron)
	iron.position = mid
	await Effects.pop_in(iron, 0.6)
	await get_tree().create_timer(0.7).timeout
	iron.queue_free()

	## 持ち物が「鉄」になる。
	Game.got_iron = true
	Game.lost_gold = false
	item.visible = true
	item.text = "鉄"
	item.color = COL_IRON
	chest.text = "空箱"

	_say("鉄になった", 2.0)
	hero.can_move = true
	_busy = false

## 門番に話しかける。持ち物で返事が変わる。
func _meet_keeper() -> void:
	if not keeper.visible or hero.position.distance_to(keeper.position) > TALK_REACH:
		return
	if Game.gate_open:
		_say("門番「さあ、通ってよいぞ」")
	elif Game.got_iron:
		_open_gate()
	elif Game.lost_gold:
		_say("門番「なにも持っていないではないか」")
	elif Game.got_gold:
		_say("門番「ふーん、金か。興味ないな」")
	else:
		_say("門番「この街では金より鉄が貴重だ。鉄を持ってくれば門を開けてやる」", 3.0)

## 鉄を見せると門が開く。
func _open_gate() -> void:
	_busy = true
	hero.can_move = false
	_say("門番「おお、鉄だな。良かろう、門を開けよう！」", 2.5)
	await get_tree().create_timer(1.4).timeout

	## 二枚の扉が順に開く。
	await _open_door(gate2)
	await _open_door(gate1)

	Game.gate_open = true
	item.visible = false   ## 渡したので持ち物は消える
	hero.can_move = true
	_busy = false

## 扉が 1 枚、脇へ滑って消える。
func _open_door(door: KanjiSprite) -> void:
	var t := 0.0
	var dur := 0.5
	var from := door.position
	var to := from + Vector2(0, -30)
	while t < dur:
		t += get_process_delta_time()
		var k: float = clampf(t / dur, 0.0, 1.0)
		door.position = from.lerp(to, Effects.ease_k(k, EASE_OUT))
		door.modulate.a = 1.0 - k
		await get_tree().process_frame
	door.visible = false
	## 開いた門は通れるようにする。壁の入れ物から外して当たらなくする。
	if door.get_parent() == wall_root:
		wall_root.remove_child(door)
		add_child(door)

## 盗人に出会う。金を持っていれば奪われる。
func _meet_thief() -> void:
	if _thief_gone or not thief.visible:
		return
	if hero.position.distance_to(thief.position) > TALK_REACH:
		return
	if Game.got_gold and not Game.lost_gold:
		_rob()
	else:
		_say("盗人「なんだ、文無しか」")

## 金を奪われる。ここが谷であり、同時に答えへの入り口。
func _rob() -> void:
	_busy = true
	hero.can_move = false

	## 1. 一瞬止まる。何が起きたか分からない間。
	await get_tree().create_timer(0.15).timeout

	## 2. 画面が揺れて「悲」を出す。取られた気持ちを見せる。
	_shock()
	await _shake_screen(0.45, 9.0)

	_say("盗人「金はいただいていくぞ」", 2.0)

	## 3. 「金」が盗人の手へ飛んでいく。
	var gold := KanjiSprite.new()
	gold.text = "金"
	gold.color = COL_GOLD
	gold.z_index = 12
	add_child(gold)
	gold.position = item.position
	item.visible = false
	var t := 0.0
	var dur := 0.5
	var from := gold.position
	while t < dur:
		t += get_process_delta_time()
		var k: float = clampf(t / dur, 0.0, 1.0)
		gold.position = from.lerp(thief.position, Effects.ease_k(k, EASE_IN))
		gold.scale = Vector2.ONE * (1.0 - k * 0.5)
		await get_tree().process_frame
	gold.queue_free()

	## 4. 持ち物が「金」から「失」に変わる。
	Game.lost_gold = true
	Game.got_gold = false
	item.visible = true
	item.text = "失"
	item.color = COL_LOST
	await Effects.pop_in(item, 0.4)

	## 5. 勇者がうなだれる。
	await _slump_hero()

	await get_tree().create_timer(0.6).timeout

	## 盗人は左へ逃げて消える。
	_thief_gone = true
	var run := 0.0
	while run < 1.0 and thief.position.x > -60.0:
		run += get_process_delta_time()
		thief.position.x -= 220.0 * get_process_delta_time()
		await get_tree().process_frame
	thief.visible = false

	hero.can_move = true
	_busy = false

## 「悲」の字を大きく出して、すぐ消す。取られた瞬間の気持ち。
## この悲しみ（金を失うこと）が、のちに「鉄」へつながる。
func _shock() -> void:
	var mark := KanjiSprite.new()
	mark.text = "悲"
	mark.color = COL_SHOCK
	mark.font_size = 72
	mark.z_index = 15
	add_child(mark)
	mark.set_scratch_pos(0, 0)
	_fade_out(mark, 0.5)

## 画面全体を揺らす。驚きを体で感じさせるため。
## 自分（場面のまとめ役）ごとずらして、元に戻す。
func _shake_screen(dur: float, power: float) -> void:
	var t := 0.0
	while t < dur:
		t += get_process_delta_time()
		var k: float = clampf(t / dur, 0.0, 1.0)
		## だんだん収まる。
		var p := power * (1.0 - k)
		position = Vector2(randf_range(-p, p), randf_range(-p, p))
		await get_tree().process_frame
	position = Vector2.ZERO

## 勇者がうなだれる。縦に潰れてから戻る。
func _slump_hero() -> void:
	var t := 0.0
	var dur := 0.7
	while t < dur:
		t += get_process_delta_time()
		var k: float = clampf(t / dur, 0.0, 1.0)
		## 前半で沈み、後半で戻る。
		var sink := sin(k * PI)
		hero.scale = Vector2(1.0 + sink * 0.2, 1.0 - sink * 0.3)
		await get_tree().process_frame
	hero.scale = Vector2.ONE

## 文字を薄くしながら消す。
func _fade_out(node: KanjiSprite, dur: float) -> void:
	var t := 0.0
	while t < dur:
		if not is_instance_valid(node) or not node.is_inside_tree():
			return
		t += get_process_delta_time()
		node.modulate.a = clampf(1.0 - t / dur, 0.0, 1.0)
		await get_tree().process_frame
	if is_instance_valid(node):
		node.queue_free()

## 村人に出会う。金を失ったあとは言うことが変わる。
func _meet_villagers() -> void:
	for v in _villagers:
		if not is_instance_valid(v):
			continue
		if hero.position.distance_to(v.position) > TALK_REACH:
			continue
		if Game.got_iron or Game.gate_open:
			## 鉄を手にしたあとは、もう盗人の心配をする場面ではない。
			_say("村人「よくぞ鉄を見つけたな」")
		elif Game.lost_gold:
			_say("村人「かわいそうに……」")
		else:
			## どちらを言うかは村人ごとに決めておく。
			## 毎コマ選び直すと、話しかけている間ずっと文が入れ替わって
			## ちらついてしまう。
			if not _villager_lines.has(v):
				_villager_lines[v] = randi() % 2
			if _villager_lines[v] == 0:
				_say("村人「盗人（ぬすっと）には気をつけな！」")
			else:
				_say("村人「お金を盗まれてしまうぞ」")
		return

# ---------------------------------------------------------------- セリフ

## 画面の下にセリフを出す。同じものが出ている間は出し直さない。
func _say(text: String, secs: float = 1.6) -> void:
	if is_instance_valid(_talk) and _talk.text == text:
		_talk_until = secs
		return
	if is_instance_valid(_talk):
		_talk.queue_free()
	_talk = KanjiSprite.new()
	_talk.text = text
	_talk.color = COL_SUB
	_talk.font_size = 14
	_talk.z_index = 12
	add_child(_talk)
	_talk.set_scratch_pos(0, -165)
	_talk_until = secs

## 時間が来たらセリフを消す。
func _fade_talk(delta: float) -> void:
	if not is_instance_valid(_talk):
		return
	_talk_until -= delta
	if _talk_until <= 0.0:
		_talk.queue_free()

# ---------------------------------------------------------------- クリア

func _finish() -> void:
	_finished = true
	hero.can_move = false
	if is_instance_valid(_talk):
		_talk.queue_free()

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

func _confirm() -> void:
	if not _can_restart:
		return
	_can_restart = false
	if Game.stage_no < Game.STAGE_MAX:
		Game.goto_stage(get_tree(), Game.stage_no + 1)
	else:
		Game.reset()
		get_tree().change_scene_to_file(Game.STAGE_SCENES[1])

func _to_title() -> void:
	Game.reset()
	get_tree().change_scene_to_file("res://scenes/title.tscn")

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
