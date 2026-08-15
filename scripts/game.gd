extends Node
## グローバルな状態管理（Scratch の変数に相当）。

## Scratch の座標系（中心原点・上が +Y、480x360）を扱うための定数。
const STAGE_W := 480.0
const STAGE_H := 360.0

## ステージ番号 -> シーンファイルの対応表。
## ステージを増やすときはここに足すだけでよい（遷移する側は番号しか知らない）。
const STAGE_SCENES := {
	1: "res://scenes/main.tscn",
	2: "res://scenes/stage2.tscn",
}
## 最後のステージ番号。クリア後に「次へ」を出すか「もう一度」を出すかの判断に使う。
const STAGE_MAX := 1

## Scratch 変数
var scene_no: int = 1        ## ステージの中の場面番号（1 始まり）
var cinema_mode: bool = false ## シネマモード
var cut_count: int = 0        ## 木を切る回数（ステージ 1）
var stage_no: int = 1         ## 今どのステージ（どの .tscn）にいるか
var tree_fell: bool = false   ## 木が倒れた（ステージ 1）
var got_axe: bool = false     ## 斧を取った（ステージ 1）
var got_bow: bool = false     ## 弓を取った（ステージ 2）
var hit_target: bool = false  ## 的に当てた（ステージ 2 の練習）

signal scene_changed(no: int)

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

## 指定したステージへ移る。
## ステージ固有の状態を捨ててから読み込むので、前のステージの持ち物は残らない。
func goto_stage(tree: SceneTree, no: int) -> void:
	stage_no = no
	reset_stage()
	tree.change_scene_to_file(STAGE_SCENES[no])
