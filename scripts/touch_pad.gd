extends Node2D
class_name TouchPad
## 画面に指で触れて遊ぶための操作ボタン。
##
## スマホには矢印キーもスペースもないので、盤面の下に置いた漢字のボタンを
## 押すと、キーを押したのと同じことが起きるようにしている。
##
## 押している間ずっと押されたことにする（押した瞬間だけではない）。
## ステージ 3 の弓は「押している間ためて、離すと放つ」ので、
## 離したことまで正しく伝える必要があるため。

## ボタンの見た目。
const BTN_SIZE := 44
const COL_BTN := Color("#555555")
const COL_BTN_ON := Color("#bb3023")   ## 押している間
const COL_BTN_SUB := Color("#999999") ## 遊びの操作ではないボタン
const COL_DIVIDER := Color("#aaaaaa") ## 盤面とボタンの境目
const COL_PAD_BG := Color("#f0efe9")  ## ボタンを置く帯の地色
## ボタンを置く帯の高さ。
## 十字の上下（62px 間隔 × 2）に、縁の余白を足した高さにしている。
## 詰めると下のボタンが画面の縁に貼りついて押しにくい。
const PAD_HEIGHT := 260.0

## 盤面の下に置く帯の高さ（project.godot のビューポートと合わせる）。
const PAD_TOP := 360.0

## ボタン 1 つぶんの決まり。どの見た目で、どのキーとして扱うか。
## ボタンの並び。指で押すので、間隔も当たりも広めに取っている。
const BUTTONS := [
	{"text": "上", "action": "ui_up", "x": 112.0, "y": 68.0},
	{"text": "左", "action": "ui_left", "x": 50.0, "y": 130.0},
	{"text": "右", "action": "ui_right", "x": 174.0, "y": 130.0},
	{"text": "下", "action": "ui_down", "x": 112.0, "y": 192.0},
	{"text": "押", "action": "ui_accept", "x": 422.0, "y": 130.0},
	## タイトルへ戻る。スマホには Esc が無いので、ここから戻れるようにする。
	{"text": "戻", "action": "ui_cancel", "x": 422.0, "y": 32.0},
]
## 指が当たったとみなす広さ。見た目より大きく取る。
## 隣のボタンと重ならない範囲で、できるだけ広くしてある。
const BTN_REACH := 42.0
## 「戻」の当たる広さ。間違って押さないよう狭くしている。
const BTN_REACH_SUB := 24.0

## 盤面の幅は定数なので、autoload の実体を通さず直に読む。
## `Game` と識別子で書くと、テストの --script モードでは名前が解決できず、
## このファイルに依るものすべてが読み込めなくなる。
const GameScript := preload("res://scripts/game.gd")

## 押されているボタンと、その指の id。
var _pressed := {}
var _labels := {}

## このコマで押されたボタン。場面はこれを見て「押した瞬間」を知る。
## Input.parse_input_event で送った合図は次のコマまで届かず、
## そのままだと 1 回目の押下を取りこぼすため。
static var just_pressed := {}

## この端末で操作ボタンが要るか。
## 指で触れる画面を持つ機械（スマホ・タブレット）のときだけ出す。
## パソコンはキーボードで遊べるので、盤面の邪魔をしないよう出さない。
static func needed() -> bool:
	if DisplayServer.is_touchscreen_available():
		return true
	var os := OS.get_name()
	if os == "Android" or os == "iOS":
		return true
	## Web 版だと、上の 2 つでは取りこぼす。
	## OS.get_name() は機械ではなく "Web" を返すし、
	## 触れる画面があるかの判定も、ブラウザによっては false になる。
	## そこでブラウザ自身に「指で触る機械か」を聞く。
	if os == "Web":
		return JavaScriptBridge.eval("""
			(('ontouchstart' in window) ||
			 (navigator.maxTouchPoints > 0) ||
			 /Android|iPhone|iPad|iPod|Mobile/i.test(navigator.userAgent))
		""", true) == true
	return false

## 「押した瞬間」だったかを聞く。1 度聞いたら消える。
static func take_just_pressed(action: String) -> bool:
	if just_pressed.has(action):
		just_pressed.erase(action)
		return true
	return false

func _ready() -> void:
	## 指の動きを拾うため、画面より手前に置く。
	z_index = 100
	## ボタンを置くぶんだけ画面を縦に広げる。
	## 盤面 (480x360) の中に重ねると、下の方に置いた文字が隠れてしまう。
	## パソコンでは出さないので、そのときは盤面のままで余白も出ない。
	get_window().content_scale_size = Vector2i(480, int(PAD_TOP + PAD_HEIGHT))
	_build()

func _build() -> void:
	_build_backdrop()
	_build_divider()
	for b in BUTTONS:
		var s := KanjiSprite.new()
		s.text = b["text"]
		s.color = COL_BTN
		s.font_size = BTN_SIZE
		add_child(s)
		s.position = Vector2(b["x"], PAD_TOP + b["y"])
		_labels[b["action"]] = s

	## 「押」は他より大きくして、押しやすく目立たせる。
	if _labels.has("ui_accept"):
		_labels["ui_accept"].font_size = BTN_SIZE + 16
	## 「戻」は遊びの操作ではないので、控えめにする。
	if _labels.has("ui_cancel"):
		_labels["ui_cancel"].font_size = BTN_SIZE - 14
		_labels["ui_cancel"].color = COL_BTN_SUB

## ボタンを置く帯に、薄い地色を敷く。
## 盤面が白いので、うっすら色を変えるだけで「ここは別の場所」と分かる。
func _build_backdrop() -> void:
	var bg := ColorRect.new()
	bg.color = COL_PAD_BG
	bg.position = Vector2(0, PAD_TOP)
	bg.size = Vector2(GameScript.STAGE_W, PAD_HEIGHT)
	## 指の操作を邪魔しないようにする。
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	## 仕切りやボタンより後ろへ。
	bg.z_index = -1
	add_child(bg)

## 盤面とボタンの境目に仕切りの線を引く。
## ここから下は操作する所で、遊びの場ではないと分かるようにする。
## ここは遊びの世界の外なので、漢字ではなく普通の線でよい。
func _build_divider() -> void:
	var line := ColorRect.new()
	line.color = COL_DIVIDER
	line.position = Vector2(0, PAD_TOP - 1.0)
	line.size = Vector2(GameScript.STAGE_W, 2.0)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(line)

## 指が触れた・離れた・滑ったのを見る。
## _unhandled_input ではなく _input を使う。
## 場面側が先に受け取ってしまうと、ボタンまで届かないため。
func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_press_at(event.position, event.index)
		else:
			_release(event.index)
	elif event is InputEventScreenDrag:
		## 指を滑らせて別のボタンへ移ることもある。
		_release(event.index)
		_press_at(event.position, event.index)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		## パソコンでも試せるように、マウスでも同じことが起きるようにしておく。
		if event.pressed:
			_press_at(event.position, -1)
		else:
			_release(-1)
	elif event is InputEventMouseMotion and _pressed.has(-1):
		_release(-1)
		_press_at(event.position, -1)

## その場所にあるボタンを押す。押せたら true。
func _press_at(pos: Vector2, finger: int) -> bool:
	for b in BUTTONS:
		var center := Vector2(b["x"], PAD_TOP + b["y"])
		## 見た目より広めに取る。指は正確に当たらないため。
		## ただし「戻」だけは狭くする。間違って触るとゲームが終わってしまう。
		var reach := BTN_REACH_SUB if b["action"] == "ui_cancel" else BTN_REACH
		if pos.distance_to(center) > reach:
			continue
		_pressed[finger] = b["action"]
		if _labels.has(b["action"]):
			_labels[b["action"]].color = COL_BTN_ON
		## 「戻」はここで直に帰す。
		## 送った合図（InputEventAction）は場面の _unhandled_input まで
		## 流れないことがあり、待っていても戻れないため。
		if b["action"] == "ui_cancel":
			_go_title()
			return true
		_send(b["action"], true)
		## 押した瞬間を覚えておく。次のコマの終わりに消す。
		just_pressed[b["action"]] = true
		return true
	return false

## タイトルへ帰る。動いている演出を止めてから抜ける。
func _go_title() -> void:
	var scene := get_tree().current_scene
	## 場面が後始末の手を持っていれば、それに任せる。
	if scene != null and scene.has_method("_to_title"):
		scene._to_title()
		return
	## reset() は autoload が持つ状態を触るので、実体を木からたどる。
	## こちらは識別子で書けない（上と同じ理由）。
	var g := get_tree().root.get_node_or_null("Game")
	if g != null:
		g.reset()
	get_tree().change_scene_to_file("res://scenes/title.tscn")

## 離した指のぶんだけ、押すのをやめる。離すものがあれば true。
func _release(finger: int) -> bool:
	if not _pressed.has(finger):
		return false
	var action: String = _pressed[finger]
	_pressed.erase(finger)
	## 同じボタンを別の指がまだ押しているなら、離さない。
	for a in _pressed.values():
		if a == action:
			return true
	_send(action, false)
	if _labels.has(action):
		_labels[action].color = COL_BTN
	return true

## 場面が変わってこのボタンが消えるとき、押したままのものを全部離す。
##
## ボタンを押すと場面が切り替わることがある（タイトルの「押」、ステージの「戻」）。
## そのとき指を離す前にこのノードごと消えるので、_release が呼ばれず、
## 「押しっぱなし」の記録だけが Input に残ってしまう。
##
## 実際に、タイトルで「押」を押してステージ1 に入り、一度も「押」を
## 押さないまま「戻」で帰ると、残った ui_accept をタイトルが拾って
## すぐステージ1 が始まり直してしまっていた。
func _exit_tree() -> void:
	for action in _pressed.values():
		_send(action, false)
	_pressed.clear()
	## 「押した瞬間」の記録も持ち越さない。
	## 次の場面がこれを拾うと、押していないのに押したことになる。
	just_pressed.clear()

## キーが押された（離された）ことにして、ゲーム側へ流す。
## こうしておくと、ゲーム側はキーボードと同じ書き方のままでよい。
func _send(action: String, pressed: bool) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = pressed
	## 押している間ずっと押されたことにするため、強さも渡す。
	ev.strength = 1.0 if pressed else 0.0
	Input.parse_input_event(ev)

## 決定ボタンの呼び名。文の途中で使う（「〜で調べる」）。
## キーボードなら「スペース」、指で遊ぶなら画面の「押」ボタン。
static func accept_name() -> String:
	return "「押」" if needed() else "スペース"

## 決定ボタンの呼び名。文の頭で使う（「〜ではじめる」）。
static func accept_key_name() -> String:
	return "「押」ボタン" if needed() else "スペースキー"

## 移動の呼び名。
static func move_name() -> String:
	return "「上下左右」" if needed() else "↑↓←→"
