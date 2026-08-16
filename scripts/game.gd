extends Node
## グローバルな状態管理（Scratch の変数に相当）。

## Scratch の座標系（中心原点・上が +Y、480x360）を扱うための定数。
const STAGE_W := 480.0
const STAGE_H := 360.0

## ステージ番号 -> シーンファイルの対応表。
## ステージを増やすときはここに足すだけでよい（遷移する側は番号しか知らない）。
const STAGE_SCENES := {
	1: "res://scenes/stage1.tscn",
	2: "res://scenes/stage2.tscn",
	3: "res://scenes/stage3.tscn",
	4: "res://scenes/stage4.tscn",   ## 作りかけ。debug のときだけ入れる
}
## 普段遊べる最後のステージ番号。
## ここまでが「できあがっているステージ」で、遊ぶ人にはこれしか見せない。
const STAGE_MAX := 3
## debug のときに遊べる最後のステージ番号。
## 作りかけのステージを試すための番号なので、STAGE_MAX より先まで含む。
const DEBUG_STAGE_MAX := 4

## 作りかけのステージまで見せるか。起動したときに一度だけ決める。
## テストからは直に書き換えてよい（機械の都合を持ち込まないため）。
var debug := false

## Scratch 変数
var scene_no: int = 1        ## ステージの中の場面番号（1 始まり）
var cinema_mode: bool = false ## シネマモード
var cut_count: int = 0        ## 木を切る回数（ステージ 1）
var stage_no: int = 1         ## 今どのステージ（どの .tscn）にいるか
var tree_fell: bool = false   ## 木が倒れた（ステージ 1）
var got_axe: bool = false     ## 斧を取った（ステージ 1）
var got_bow: bool = false     ## 弓を取った（ステージ 3）
var hit_target: bool = false  ## 的に当てた（ステージ 3）
## ステージ 2「鉄」の持ち物。金 → 失 → 鉄 と移り変わる。
var got_gold: bool = false    ## 宝箱から金を取った
var lost_gold: bool = false   ## 盗人に金を奪われた（持ち物が「失」）
var got_iron: bool = false    ## 金と失が合わさって鉄になった
var gate_open: bool = false   ## 門番が門を開けた

signal scene_changed(no: int)

func _ready() -> void:
	debug = _detect_debug()

## 作りかけのステージを見せてよいか、遊んでいる場所から判断する。
##
## Web 版はアドレスの後ろ（?debug=true）を見る。
## 遊ぶ人が普通に開いたときは付いていないので、作りかけは出てこない。
##
## パソコンで試すときは起動の引数で渡す:
##
##     godot -- debug=true
##
## Web かどうかは OS.get_name() で見る（落とし穴 14）。
## JavaScriptBridge はブラウザの中でしか動かないので、必ずこの中で呼ぶ。
func _detect_debug() -> bool:
	if OS.get_name() == "Web":
		return JavaScriptBridge.eval("""
			new URLSearchParams(location.search).get('debug') === 'true'
		""", true) == true
	## 引数は「--」の前後どちらに書かれても拾えるようにする。
	for a in OS.get_cmdline_args() + OS.get_cmdline_user_args():
		if a == "debug=true" or a == "--debug=true":
			return true
	return false

## いま遊べる最後のステージ番号。
## タイトルの選択肢も、クリア後に「次へ」を出すかも、すべてこれで決める。
## STAGE_MAX を直に見ると、debug のときだけ増える分を書き漏らす。
func last_stage() -> int:
	return DEBUG_STAGE_MAX if debug else STAGE_MAX

## Scratch 座標 -> Godot 座標（左上原点・下が +Y）へ変換する。
static func to_godot(x: float, y: float) -> Vector2:
	return Vector2(x + STAGE_W * 0.5, STAGE_H * 0.5 - y)

## Godot 座標 -> Scratch 座標。
static func to_scratch(pos: Vector2) -> Vector2:
	return Vector2(pos.x - STAGE_W * 0.5, STAGE_H * 0.5 - pos.y)

## 全部を初期値に戻す。タイトルから遊び始めるときに使う。
## stage_no も 1 に戻るので、ステージの途中で呼んではいけない（reset_stage を使う）。
func reset() -> void:
	scene_no = 1
	cinema_mode = false
	cut_count = 0
	stage_no = 1
	tree_fell = false
	got_axe = false
	got_bow = false
	hit_target = false
	got_gold = false
	lost_gold = false
	got_iron = false
	gate_open = false

## ステージを跨いで持ち越さないものだけを初期化する。
## reset() と違い stage_no は触らない（今から向かう先を消してしまわないように）。
## 持ち物（斧・弓）もステージごとに拾い直すので、ここで戻す。
func reset_stage() -> void:
	scene_no = 1
	cinema_mode = false
	cut_count = 0
	tree_fell = false
	got_axe = false
	got_bow = false
	hit_target = false
	got_gold = false
	lost_gold = false
	got_iron = false
	gate_open = false

## 指定したステージへ移る。
## ステージ固有の状態を捨ててから読み込むので、前のステージの持ち物は残らない。
func goto_stage(tree: SceneTree, no: int) -> void:
	## 遊べない番号（作りかけを debug 以外で指す等）は無かったことにする。
	if not STAGE_SCENES.has(no) or no > last_stage():
		return
	stage_no = no
	reset_stage()
	tree.change_scene_to_file(STAGE_SCENES[no])
