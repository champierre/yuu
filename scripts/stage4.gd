extends StageBase
## ステージ4（作りかけ）。
##
## アドレスに ?debug=true を付けたときだけタイトルに並ぶ、次のステージの土台。
## 謎解きの中身はまだ無い。ここにあるのは、どのステージにも共通する骨組み——
## 「宝箱を開けて、目標に触れるとクリアになる」だけ。
##
## 新しい謎解きを作るときは、この上に場面を足していく。
## 置くものが増えたら、_build_scene() に見た目を書き足すこと
## （前の場面の見た目を引きずらないため。落とし穴 6）。

const COL_NOTE := Color("#aaaaaa")   ## まだ作りかけだと知らせる文字

## 置いてあるものの場所（Scratch 座標）。
const HERO_POS := Vector2(0, -110)
const CHEST_POS := Vector2(150, -120)
const GOAL_POS := Vector2(0, 140)
const NOTE_POS := Vector2(0, 165)

@onready var hero: KanjiSprite = $Hero
@onready var chest: KanjiSprite = $Chest
@onready var goal: KanjiSprite = $Goal
@onready var note: KanjiSprite = $Note

var _opened := false   ## 宝箱を開けたか

func _ready() -> void:
	## Game.reset() は stage_no を 1 に戻してしまうのでここでは呼ばない（落とし穴 1）。
	Game.reset_stage()
	## 行く手を塞ぐものはまだ無い。置いたら、その入れ物をここで渡す（落とし穴 8）。
	hero.blockers = null
	## 操作ボタンは、指で触れる機械のときだけ出す。
	## そのときは「戻」ボタンから帰れるので、Esc の案内は出さない。
	if TouchPad.needed():
		add_child(TouchPad.new())
	else:
		Effects.show_escape_hint(self)
	## 先に場面を組んでから待つ（組む前に待つと、初期配置が一瞬見えてしまう）。
	_build_scene()
	_busy = true
	if not await wait(1.0):
		return
	_busy = false

## 場面を組む。使うものは全部ここで見た目を決める。
func _build_scene() -> void:
	Game.scene_no = 1
	_opened = false

	hero.text = "勇"
	hero.color = Color.BLACK
	hero.vertical = false
	hero.scale = Vector2.ONE
	hero.rotation = 0.0
	hero.visible = true
	hero.can_move = true
	hero.set_scratch_pos(HERO_POS.x, HERO_POS.y)

	chest.text = "宝箱"
	chest.color = COL_CHEST
	chest.scale = Vector2.ONE
	chest.visible = true
	chest.set_scratch_pos(CHEST_POS.x, CHEST_POS.y)

	## 目標は宝箱を開けるまで出さない。
	goal.text = "目標"
	goal.color = COL_GOAL
	goal.scale = Vector2.ONE
	goal.z_index = 0
	goal.visible = false
	goal.set_scratch_pos(GOAL_POS.x, GOAL_POS.y)

	note.text = "ステージ4 は作りかけ"
	note.color = COL_NOTE
	note.font_size = 14
	note.visible = true
	note.set_scratch_pos(NOTE_POS.x, NOTE_POS.y)

# ---------------------------------------------------------------- 毎フレーム処理

func _process(_delta: float) -> void:
	## 決定ボタンの上げ下げは毎コマ見ておく（中身は StageBase。落とし穴 12）。
	if _finished:
		update_act(true)
		update_finished_act()
		return
	update_act(_busy)
	if _busy:
		return

	_try_chest()

	if goal.visible and hero.touching(goal):
		_finish()

## 宝箱に重なって決定を押したら開く。開けると目標が現れる。
## 「押した瞬間」だけ開ける。押しっぱなしを見ると、
## ボタンを押したまま宝箱の上を通っただけで開いてしまう。
func _try_chest() -> void:
	if _opened:
		return
	if hero.touching(chest) and act_just_pressed():
		_opened = true
		chest.text = "空箱"
		goal.visible = true
		Effects.pop_in(goal, 0.3)

## 目標に到達。その瞬間に勇者を止めてクリア演出に入る。
func _finish() -> void:
	_finished = true
	hero.can_move = false

	if not await wait(0.12):
		return

	if _left():
		return
	goal.text = "達成"
	goal.color = COL_DONE
	goal.z_index = 10
	await Effects.pop_in(goal, 0.45)
	if _left():
		return

	Effects.burst(self, goal.position)
	await Effects.cheer(hero)
	await Effects.show_banner(self, "祝", COL_DONE)

	## 次のステージがあればそちらへ誘い、無ければもう一度遊べるようにする。
	if Game.stage_no < Game.last_stage():
		_show_end_hint("%sで次のステージへ" % TouchPad.accept_key_name())
	else:
		_show_end_hint("%sでもう一度" % TouchPad.accept_key_name())
