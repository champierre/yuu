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
const BTN_SIZE := 34
const COL_BTN := Color("#555555")
const COL_BTN_ON := Color("#bb3023")   ## 押している間

## 盤面の下に置く帯の高さ（project.godot のビューポートと合わせる）。
const PAD_TOP := 360.0

## ボタン 1 つぶんの決まり。どの見た目で、どのキーとして扱うか。
const BUTTONS := [
	{"text": "上", "action": "ui_up", "x": 90.0, "y": 30.0},
	{"text": "左", "action": "ui_left", "x": 40.0, "y": 70.0},
	{"text": "右", "action": "ui_right", "x": 140.0, "y": 70.0},
	{"text": "下", "action": "ui_down", "x": 90.0, "y": 110.0},
	{"text": "押", "action": "ui_accept", "x": 380.0, "y": 70.0},
]

## 押されているボタンと、その指の id。
var _pressed := {}
var _labels := {}

## この端末で操作ボタンが要るか。
## 指で触れる画面を持つ機械（スマホ・タブレット）のときだけ出す。
## パソコンはキーボードで遊べるので、盤面の邪魔をしないよう出さない。
static func needed() -> bool:
	if DisplayServer.is_touchscreen_available():
		return true
	## Web 版では、触れる画面かどうかを機種名からも見ておく。
	## 触れる画面があるかの判定だけでは取りこぼす端末があるため。
	var os := OS.get_name()
	return os == "Android" or os == "iOS"

func _ready() -> void:
	## 指の動きを拾うため、画面より手前に置く。
	z_index = 100
	## ボタンを置くぶんだけ画面を縦に広げる。
	## 盤面 (480x360) の中に重ねると、下の方に置いた文字が隠れてしまう。
	## パソコンでは出さないので、そのときは盤面のままで余白も出ない。
	get_window().content_scale_size = Vector2i(480, 480)
	_build()

func _build() -> void:
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
		_labels["ui_accept"].font_size = BTN_SIZE + 10

## 指が触れた・離れた・滑ったのを見る。
func _unhandled_input(event: InputEvent) -> void:
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

## その場所にあるボタンを押す。
func _press_at(pos: Vector2, finger: int) -> void:
	for b in BUTTONS:
		var center := Vector2(b["x"], PAD_TOP + b["y"])
		## 見た目より広めに取る。指は正確に当たらないため。
		if pos.distance_to(center) > BTN_SIZE:
			continue
		_pressed[finger] = b["action"]
		_send(b["action"], true)
		if _labels.has(b["action"]):
			_labels[b["action"]].color = COL_BTN_ON
		return

## 離した指のぶんだけ、押すのをやめる。
func _release(finger: int) -> void:
	if not _pressed.has(finger):
		return
	var action: String = _pressed[finger]
	_pressed.erase(finger)
	## 同じボタンを別の指がまだ押しているなら、離さない。
	for a in _pressed.values():
		if a == action:
			return
	_send(action, false)
	if _labels.has(action):
		_labels[action].color = COL_BTN

## キーが押された（離された）ことにして、ゲーム側へ流す。
## こうしておくと、ゲーム側はキーボードと同じ書き方のままでよい。
func _send(action: String, pressed: bool) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = pressed
	## 押している間ずっと押されたことにするため、強さも渡す。
	ev.strength = 1.0 if pressed else 0.0
	Input.parse_input_event(ev)
