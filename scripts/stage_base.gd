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

## 決定ボタンの「押した瞬間」を見るための記録。
## 3 つのステージが同じことをしていたので、ここに 1 つだけ持つ。
var _act_was_down := false    ## 前のコマで押されていたか
var _act_just_pressed := false ## このコマで押された瞬間か

# ---------------------------------------------------------------- 決定ボタン

## 決定ボタンの上げ下げを見て、「押した瞬間」を記録する。
## 各ステージは _process の頭でこれを 1 回だけ呼び、
## 使うときは act_just_pressed() を聞く。
##
## 毎コマ呼ぶのが要点。使う側（宝箱に重なったとき等）で見ると、
## 条件に合わない間は記録が更新されず、離したのを見落とす。
##
## `busy` の間は「押した瞬間」にしない。そこで拾うとその 1 回が
## 使われないまま消え、遊ぶ人には「1 回目が効かなかった」と見える。
## ただし押しっぱなしの記録だけは更新する。さもないと演出明けに
## 記録が古いままになり、次の一手が出せなくなる（落とし穴 12）。
func update_act(busy: bool) -> void:
	var down := act_down()
	if busy:
		_act_was_down = down
		_act_just_pressed = false
		return
	_act_just_pressed = down and not _act_was_down
	_act_was_down = down
	## 画面のボタンから押されたぶんも拾う。
	## パッドが送る合図は次のコマまで届かないので、
	## それだけを見ていると 1 回目の押下を取りこぼす。
	if TouchPad.take_just_pressed("ui_accept"):
		_act_just_pressed = true

## いま決定ボタンが押されているか（押している間ずっと true）。
func act_down() -> bool:
	return Input.is_action_pressed("ui_accept")

## このコマで決定ボタンが押された瞬間か。
func act_just_pressed() -> bool:
	return _act_just_pressed

## クリアしたあとの決定ボタン。押されていれば次へ進める。
##
## _unhandled_input は入力があったときしか呼ばれず、
## パッドが送る合図では呼ばれないことがあるので、
## クリア後も毎コマここで見ておく。
func update_finished_act() -> void:
	if TouchPad.take_just_pressed("ui_accept"):
		_confirm()

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

## 演出の中で待つときは、この 2 つだけを使う。
##
## `await get_tree()` を直に書くと、そのたびに「場面を抜けたか」の
## 確認を手で足すことになり、書き忘れると落ちる。
## 実際に、蟲の登場中や斧を振っている最中に「戻」を押すと落ちていた。
##
## 待つ前と待ったあとの両方で確かめ、抜けていたら false を返す。
## 呼ぶ側はこう書く（これで守りを書き忘れようがなくなる）:
##
##     if not await next_frame(): return
##     if not await wait(0.5): return
##
## 待ったあとにも確かめるのが要点。待っている間に場面が変わるため。
## シーンが切り替わると、ノードは解放される前にまず木から外れる。
## その間 is_instance_valid() は true を返すのに get_tree() は使えない。

## 次のコマまで待つ。まだこの場面にいれば true。
func next_frame() -> bool:
	if _left():
		return false
	await get_tree().process_frame
	return not _left()

## 指定の秒数だけ待つ。まだこの場面にいれば true。
func wait(sec: float) -> bool:
	if _left():
		return false
	await get_tree().create_timer(sec).timeout
	return not _left()

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
