extends KanjiSprite
## 勇者「勇」。矢印キーで 1 フレームあたり 5px 移動し、
## ぶつかるものに触れたら押し戻す。

const SPEED := 5.0

## ぶつかって通れないものを集めたノード。
## その子ども全部が相手になる（ステージ1 は川、ステージ2 は壁と門）。
## 何も渡さなければ、ぶつかるものは無い。
var blockers: Node = null

## シネマモードで x>230 に到達したときに発火する（start1 に相当）。
signal reached_right_edge

## false にすると操作を受け付けなくなる（クリア演出中など）。
var can_move := true

## 移動の速さの倍率。1.0 でふだんの速さ。
## ステージ3 で弓を引き絞っている間だけ遅くしている。
## 動きを止めてしまうと毒を避けられなくなるので、止めずに重くする。
var speed_scale := 1.0

## 最後に動いた向き。矢を射る方向に使う。
## 一度も動いていないときのために、初めは上（目標のある側）を向いておく。
var facing := Vector2.UP

func _process(_delta: float) -> void:
	if not can_move:
		return
	if Game.cinema_mode:
		_move_cinema()
	else:
		_move_normal()

## 画面の内側にとどまれる範囲（Scratch 座標での中心位置の限界）。
## 文字の幅・高さの半分だけ内側に寄せて、絵が画面からはみ出さないようにする。
func _limit_x() -> float:
	return Game.STAGE_W * 0.5 - rect().size.x * 0.5

func _limit_y() -> float:
	return Game.STAGE_H * 0.5 - rect().size.y * 0.5

## シネマモードでない通常の移動。画面の四辺とぶつかるもので止まる。
func _move_normal() -> void:
	## 進む分と押し戻す分は必ず同じ値を使う。
	## 片方だけ SPEED のままにすると、遅くしたときにじわじわめり込む。
	var sp := SPEED * speed_scale
	if Input.is_action_pressed("ui_right"):
		facing = Vector2.RIGHT
		position.x += sp
		if _touching_blocker() or scratch_pos().x > _limit_x():
			position.x -= sp
	if Input.is_action_pressed("ui_left"):
		facing = Vector2.LEFT
		position.x -= sp
		if _touching_blocker() or scratch_pos().x < -_limit_x():
			position.x += sp
	## 上下も画面の外へ出ないように止める（+y が上）。
	if Input.is_action_pressed("ui_down"):
		facing = Vector2.DOWN
		position.y += sp
		if _touching_blocker() or scratch_pos().y < -_limit_y():
			position.y -= sp
	if Input.is_action_pressed("ui_up"):
		facing = Vector2.UP
		position.y -= sp
		if _touching_blocker() or scratch_pos().y > _limit_y():
			position.y += sp

## シネマモード中は左右のみ。右端を越えると次のシーンへ。
func _move_cinema() -> void:
	var sp := SPEED * speed_scale
	if Input.is_action_pressed("ui_right"):
		position.x += sp
		if _touching_blocker():
			position.x -= sp
	if Input.is_action_pressed("ui_left"):
		position.x -= sp
		## 左端では画面外に出ないように止める。
		if _touching_blocker() or scratch_pos().x < -_limit_x():
			position.x += sp
	## 右端まで歩いたら次の場面へ（ここは止めずに通す）。
	if scratch_pos().x > 230.0:
		reached_right_edge.emit()

func _touching_blocker() -> bool:
	if blockers == null:
		return false
	for part in blockers.get_children():
		if part is KanjiSprite and touching(part):
			return true
	return false
