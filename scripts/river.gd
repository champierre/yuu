extends Node2D
## 川。Scratch ではクローンを横に並べて 1 本の川を作っている。
## シーン 1 は x=-240 から 20px 刻みで 24 個の帯。
## シーン 2 は本体 1 つだけが地面の切れ目 (-8,-160) に置かれる小川。
## シーン 3 は中央 (x=0 付近) を空けて左右に 11 個ずつ並べ、倒木の橋を渡らせる。

const RIVER_COLOR := Color("#003cff")
const STEP := 20.0

func _ready() -> void:
	pass

## 川を 1 つだけ置く（シーン 2 用）。地面の切れ目に流れる小川になる。
func build_single(x: float, y: float) -> void:
	_clear()
	var part := _add_part(x)
	part.set_scratch_pos(x, y)

## 途切れのない川（シーン 1・2 用）。
func build_full() -> void:
	_clear()
	var x := -240.0
	for i in 24:
		_add_part(x)
		x += STEP

## 中央が途切れた川（シーン 3 用）。橋を渡る隙間ができる。
func build_gapped() -> void:
	_clear()
	var x := -240.0
	for i in 11:
		_add_part(x)
		x += STEP
	x = 20.0
	for i in 11:
		_add_part(x)
		x += STEP

func _add_part(x: float) -> KanjiSprite:
	var part := KanjiSprite.new()
	part.text = "川"
	part.color = RIVER_COLOR
	add_child(part)
	part.set_scratch_pos(x, 0.0)
	return part

func _clear() -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
