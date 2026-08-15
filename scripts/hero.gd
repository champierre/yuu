extends KanjiSprite
## 勇者「勇」。矢印キーで 1 フレームあたり 5px 移動し、川に触れたら押し戻す。

const SPEED := 5.0

## 川のスプライト群を持つノード（衝突判定の相手）。
var river: Node = null

## シネマモードで x>230 に到達したときに発火する（start1 に相当）。
signal reached_right_edge

## false にすると操作を受け付けなくなる（クリア演出中など）。
var can_move := true

func _process(_delta: float) -> void:
	if not can_move:
		return
	if Game.cinema_mode:
		_move_cinema()
	else:
		_move_normal()

## シネマモードでない通常の移動。画面端 (±230) と川で止まる。
func _move_normal() -> void:
	if Input.is_action_pressed("ui_right"):
		position.x += SPEED
		if _touching_river() or scratch_pos().x > 230.0:
			position.x -= SPEED
	if Input.is_action_pressed("ui_left"):
		position.x -= SPEED
		if _touching_river() or scratch_pos().x < -230.0:
			position.x += SPEED
	if Input.is_action_pressed("ui_down"):
		position.y += SPEED
		if _touching_river():
			position.y -= SPEED
	if Input.is_action_pressed("ui_up"):
		position.y -= SPEED
		if _touching_river():
			position.y += SPEED

## シネマモード中は左右のみ。右端を越えると次のシーンへ。
func _move_cinema() -> void:
	if Input.is_action_pressed("ui_right"):
		position.x += SPEED
		if _touching_river():
			position.x -= SPEED
	if Input.is_action_pressed("ui_left"):
		position.x -= SPEED
		if _touching_river():
			position.x += SPEED
	if scratch_pos().x > 230.0:
		reached_right_edge.emit()

func _touching_river() -> bool:
	if river == null:
		return false
	for part in river.get_children():
		if part is KanjiSprite and touching(part):
			return true
	return false
