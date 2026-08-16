extends Node2D
class_name StageBase
## ステージに共通する土台。3 つのステージがこれを継承する。
##
## ここに置くのは「どのステージでも同じことをする」部分だけ。
## 遊びの中身（何を置くか、何が起きるか）は各ステージが書く。
##
## 演出そのもの（弾む拡大・破片・点滅）は Effects にある。
## こちらは、それらを呼ぶ側の段取りと、場面の状態を持つ。

## どのステージでも使う色。
const COL_GOAL := Color("#000000")   ## 目標
const COL_DONE := Color("#3f9e44")   ## 達成
const COL_SUB := Color("#555555")    ## 案内文字
const COL_CHEST := Color("#bb3023")  ## 宝箱

## 場面の状態。値を変えるのは各ステージ。
var _busy := false           ## 演出中は入力を受けない
var _finished := false       ## クリアした
var _leaving := false        ## この場面を出ていく最中（演出を止める合図）
var _can_restart := false    ## クリア後、決定を受け付けるか
var _restart_hint: KanjiSprite

# ---------------------------------------------------------------- 入力

func _unhandled_input(event: InputEvent) -> void:
	## Esc（スマホでは「戻」ボタン）でいつでもタイトルへ戻れる。
	if event.is_action_pressed("ui_cancel"):
		_to_title()
		return
	if not _can_restart:
		return
	## 画面を触って進められるのは、指で遊ぶ機械ではないときだけ。
	## 指で遊ぶ機械では、すべて画面のボタンで操作する。
	## 触っただけで進むと、意図しない所で先へ行ってしまう。
	if event is InputEventMouseButton and event.pressed:
		if not TouchPad.needed():
			_confirm()
	elif event.is_action_pressed("ui_accept"):
		_confirm()

# ---------------------------------------------------------------- 場面を出る

## この場面をもう離れたか。演出は await をまたぐので、
## 続きを進める前にこれで確かめる。
func _left() -> bool:
	return _leaving or not is_inside_tree()

## タイトルへ戻る。動いている演出を止めてから抜ける。
## 止めないと、解放されたノードを触りにいって固まる。
func _to_title() -> void:
	_leaving = true
	_finished = true
	_can_restart = false
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

## クリア後の案内。点滅させ、決定で次へ進む。
func _show_end_hint(text: String) -> void:
	## 途中でタイトルへ抜けていたら、もう何もしない。
	if _left():
		return
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
