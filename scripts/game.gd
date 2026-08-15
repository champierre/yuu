extends Node
## グローバルな状態管理（Scratch の変数に相当）。

## Scratch の座標系（中心原点・上が +Y、480x360）を扱うための定数。
const STAGE_W := 480.0
const STAGE_H := 360.0

## Scratch 変数
var scene_no: int = 1        ## シーン
var cinema_mode: bool = false ## シネマモード
var cut_count: int = 0        ## 木を切る回数
var stage_no: int = 1         ## ステージ
var tree_fell: bool = false   ## 木が倒れた
var got_axe: bool = false     ## 斧を取った

signal scene_changed(no: int)

## Scratch 座標 -> Godot 座標（左上原点・下が +Y）へ変換する。
static func to_godot(x: float, y: float) -> Vector2:
	return Vector2(x + STAGE_W * 0.5, STAGE_H * 0.5 - y)

## Godot 座標 -> Scratch 座標。
static func to_scratch(pos: Vector2) -> Vector2:
	return Vector2(pos.x - STAGE_W * 0.5, STAGE_H * 0.5 - pos.y)

func reset() -> void:
	scene_no = 1
	cinema_mode = false
	cut_count = 0
	stage_no = 1
	tree_fell = false
	got_axe = false
