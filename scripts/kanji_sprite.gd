extends Node2D
class_name KanjiSprite
## Scratch のスプライト1体に相当する。漢字をそのまま絵として表示し、
## 矩形の当たり判定を持つ。

## 表示する漢字。
@export var text: String = "勇":
	set(value):
		text = value
		_refresh()

## 文字色（Scratch のコスチュームの塗り色をそのまま使う）。
@export var color: Color = Color.BLACK:
	set(value):
		color = value
		_refresh()

## Scratch のフォントサイズ 40 を bitmapResolution 2 で描いたもの＝実質 20px。
@export var font_size: int = 20:
	set(value):
		font_size = value
		_refresh()

## true にすると文字を縦に積む（木木木 のような縦長コスチューム用）。
@export var vertical: bool = false:
	set(value):
		vertical = value
		_refresh()

## 原点を絵のどこに置くか。(0.5,0.5)=中央、(0.5,1.0)=下端中央（根元で倒れる木用）。
@export var pivot: Vector2 = Vector2(0.5, 0.5):
	set(value):
		pivot = value
		_refresh()

var _label: Label

func _ready() -> void:
	_build()

func _build() -> void:
	if _label != null:
		return
	_label = Label.new()
	add_child(_label)
	_refresh()

func _refresh() -> void:
	if _label == null:
		return
	## 縦書きは文字の間に改行を挟んで表現する。
	_label.text = "\n".join(text.split("")) if vertical else text
	_label.add_theme_color_override("font_color", color)
	_label.add_theme_font_size_override("font_size", font_size)
	_label.add_theme_constant_override("line_spacing", 0)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.reset_size()
	## Scratch の回転中心に合わせて絵をずらす。
	_label.position = -_label.size * pivot

## Scratch 座標で位置を指定する（go to x: y: に相当）。
func set_scratch_pos(x: float, y: float) -> void:
	position = Game.to_godot(x, y)

## Scratch 座標を返す。
func scratch_pos() -> Vector2:
	return Game.to_scratch(position)

## 当たり判定用の矩形（グローバル座標）。回転・拡大も考慮する。
func rect() -> Rect2:
	_build()
	var size := _label.size * scale
	return Rect2(global_position - size * pivot, size)

## 別のスプライトと重なっているか（touching に相当）。
func touching(other: KanjiSprite) -> bool:
	if other == null or not visible or not other.visible:
		return false
	return rect().intersects(other.rect())
