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

const COL_PICK := Color("#000000")   ## 選んでいるステージ
const COL_UNPICK := Color("#aaaaaa") ## 選んでいないステージ

var _started := false
var _hint: KanjiSprite
var _sel := 1                  ## 選んでいるステージ番号
var _stage_labels: Array = []  ## ステージ選択の文字（色と大きさを塗り替える）
var _lr_was_down := false      ## 左右キーの押しっぱなしを 1 回として扱うため

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

	## ステージ選択。
	_add_stage_select()

	## 操作説明。
	var keys := KanjiSprite.new()
	keys.text = "↑↓←→ で移動　スペースで調べる・アクション"
	keys.color = COL_SUB
	keys.font_size = 14
	add_child(keys)
	keys.set_scratch_pos(0, -95)

	## 点滅する案内。
	_hint = KanjiSprite.new()
	_hint.text = "スペースキーではじめる"
	_hint.color = COL_HINT
	_hint.font_size = 16
	add_child(_hint)
	_hint.set_scratch_pos(0, -135)
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

## ステージを横に並べて選べるようにする。
## 並べ方は _add_cast と同じで、全体の幅を積んでから中央に寄せる。
func _add_stage_select() -> void:
	const GAP := 28.0
	var texts: Array = []
	for i in Game.STAGE_MAX:
		texts.append("ステージ%d" % (i + 1))

	## 先に全体の幅を出しておく（KanjiSprite は作ってからでないと幅が分からないので、
	## 一度作って並べ、あとから位置を決める）。
	var total := 0.0
	for t in texts:
		var s := KanjiSprite.new()
		s.text = t
		s.font_size = 18
		add_child(s)
		_stage_labels.append(s)
		total += s.rect().size.x + GAP
	total -= GAP

	var x := -total * 0.5
	for s in _stage_labels:
		var w: float = s.rect().size.x
		s.set_scratch_pos(x + w * 0.5, -50)
		x += w + GAP

	_refresh_stage_select()

## 選んでいるステージだけ濃く・大きく見せる。
func _refresh_stage_select() -> void:
	for i in _stage_labels.size():
		var s: KanjiSprite = _stage_labels[i]
		var picked := (i + 1) == _sel
		s.color = COL_PICK if picked else COL_UNPICK
		s.scale = Vector2.ONE * (1.15 if picked else 1.0)

## 左右でステージを選ぶ。押しっぱなしで動き続けないよう、押した瞬間だけ拾う。
func _update_stage_select() -> void:
	var left := Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_LEFT)
	var right := Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_RIGHT)
	var down := left or right
	if down and not _lr_was_down:
		if left:
			_sel = maxi(1, _sel - 1)
		else:
			_sel = mini(Game.STAGE_MAX, _sel + 1)
		_refresh_stage_select()
	_lr_was_down = down

## 案内をゆっくり点滅させる。始まったら止まる。
## シーン切り替えで自分ごと解放されるので、生存確認は Effects.blink 側で行う。
func _blink() -> void:
	Effects.blink(_hint, func(): return not _started)

func _process(_delta: float) -> void:
	if _started:
		return
	_update_stage_select()
	## スペースのほか、Enter やクリックでも始められるようにする。
	## Web 版では入力割り当てが無いと ui_accept が反応しないことがあるので、
	## キーコードも直接見る。
	if Input.is_action_pressed("ui_accept") or Input.is_action_pressed("ui_select") \
			or Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_ENTER):
		_start()

func _unhandled_input(event: InputEvent) -> void:
	if _started:
		return
	if event is InputEventMouseButton and event.pressed:
		_start()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER \
				or event.keycode == KEY_KP_ENTER:
			_start()

## 本編へ移る。
func _start() -> void:
	if _started:
		return
	_started = true
	## 解放されたあとに点滅ループが _hint を触らないよう、先に処理を止める。
	set_process(false)
	## 遊び始めるので全部を初期値に戻してから、選んだステージへ移る。
	Game.reset()
	Game.goto_stage(get_tree(), _sel)
