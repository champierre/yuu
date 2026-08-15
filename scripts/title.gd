extends Node2D
## タイトル画面。漢字だけで構成した本編に合わせ、文字を組んで見せる。

const COL_TREE := Color("#9e6a3f")
const COL_RIVER := Color("#003cff")
const COL_HERO := Color("#000000")
const COL_SUB := Color("#555555")
const COL_HINT := Color("#888888")

## タイトルの上段「漢字謎解きアクション」と下段「「勇」の冒険」。
const SUB_TEXT := "漢字謎解きアクション"
const MAIN_TEXT := "「勇」の冒険"

var _started := false
var _hint: KanjiSprite

func _ready() -> void:
	_build()

func _build() -> void:
	## 上段（小さめの副題）。
	var sub := KanjiSprite.new()
	sub.text = SUB_TEXT
	sub.color = COL_SUB
	sub.font_size = 20
	add_child(sub)
	sub.set_scratch_pos(0, 95)

	## 下段（大きな主題）。
	var main_title := KanjiSprite.new()
	main_title.text = MAIN_TEXT
	main_title.color = COL_HERO
	main_title.font_size = 48
	add_child(main_title)
	main_title.set_scratch_pos(0, 40)

	## タイトルの下に、本編に出てくる漢字を一列に並べて世界観を見せる。
	_add_cast()

	## 操作説明。
	var keys := KanjiSprite.new()
	keys.text = "↑↓←→ で移動　スペースで調べる・切る"
	keys.color = COL_SUB
	keys.font_size = 14
	add_child(keys)
	keys.set_scratch_pos(0, -90)

	## 点滅する案内。
	_hint = KanjiSprite.new()
	_hint.text = "スペースキーではじめる"
	_hint.color = COL_HINT
	_hint.font_size = 16
	add_child(_hint)
	_hint.set_scratch_pos(0, -130)
	_blink()

## 本編の登場人物（漢字）を横に並べる。
func _add_cast() -> void:
	var cast := [
		{"t": "勇", "c": COL_HERO},
		{"t": "川", "c": COL_RIVER},
		{"t": "木", "c": COL_TREE},
		{"t": "斧", "c": Color("#a7a7a7")},
		{"t": "宝箱", "c": Color("#bb3023")},
		{"t": "目標", "c": COL_HERO},
	]
	## 文字数ぶんの幅を積み上げ、全体が中央に来るよう配置する。
	const CHAR_W := 24.0   ## 1 文字の幅
	const GAP := 22.0      ## 語と語の間隔
	var total := 0.0
	for c in cast:
		total += float(c["t"].length()) * CHAR_W + GAP
	total -= GAP
	var x := -total * 0.5
	for c in cast:
		var w := float(c["t"].length()) * CHAR_W
		var s := KanjiSprite.new()
		s.text = c["t"]
		s.color = c["c"]
		s.font_size = 22
		add_child(s)
		s.set_scratch_pos(x + w * 0.5, -30)
		x += w + GAP

## 案内をゆっくり点滅させる。
func _blink() -> void:
	while not _started:
		var t := 0.0
		while t < 1.2:
			t += get_process_delta_time()
			## sin で滑らかに明滅させる。
			_hint.modulate.a = 0.35 + 0.65 * (0.5 + 0.5 * sin(t * PI * 2.0 - PI * 0.5))
			await get_tree().process_frame
	_hint.modulate.a = 1.0

func _process(_delta: float) -> void:
	if _started:
		return
	## スペースのほか、Enter やクリックでも始められるようにする。
	if Input.is_action_pressed("ui_accept") or Input.is_action_pressed("ui_select"):
		_start()

func _unhandled_input(event: InputEvent) -> void:
	if _started:
		return
	if event is InputEventMouseButton and event.pressed:
		_start()

## 本編へ移る。
func _start() -> void:
	_started = true
	get_tree().change_scene_to_file("res://scenes/main.tscn")
