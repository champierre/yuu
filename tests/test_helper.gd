extends SceneTree
class_name TestHelper
## テストの土台。各テストはこれを継承して `run_tests()` を書く。
##
## ヘッドレスの Godot は 1 コマが実機の 1/38 ほどしかないので、
## 待つときは必ず実時間（Time.get_ticks_msec）で計ること。
## コマ数で待つと、1 秒待ったつもりが一瞬しか経っていない。

var _failed := 0
var _passed := 0

func _initialize() -> void:
	_main()

func _main() -> void:
	await run_tests()
	print("")
	if _failed > 0:
		print("結果: %d 件中 %d 件 失敗" % [_passed + _failed, _failed])
		quit(1)
	elif _passed == 0:
		## 1 件も確かめずに終わったら、それは通ったのではなく
		## 走れていない。素通りさせると、壊れていても気づけない。
		print("結果: 1 件も確かめていない（テストが走っていない）")
		quit(1)
	else:
		print("結果: %d 件すべて通った" % _passed)
		quit(0)

## 各テストが中身を書く。
func run_tests() -> void:
	pass

# ---------------------------------------------------------------- 確かめる

func check(ok: bool, what: String) -> void:
	if ok:
		_passed += 1
		print("  OK   ", what)
	else:
		_failed += 1
		print("  失敗 ", what)

func check_eq(got, want, what: String) -> void:
	check(got == want, "%s（期待 %s / 実際 %s）" % [what, want, got])

# ---------------------------------------------------------------- 待つ・動かす

## 実時間で待つ。コマ数で待ってはいけない（上の説明のとおり）。
func wait_ms(ms: int) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < ms:
		await process_frame

## 場面を読み込んで、起動の待ち（1 秒）が明けるまで待つ。
## root.add_child(instantiate()) では @onready が解決されないので、
## 必ず change_scene_to_file を使う。
func load_scene(path: String) -> Node:
	change_scene_to_file(path)
	await wait_ms(2500)
	return current_scene

## autoload は識別子で書けない（--script では解決されない）ので、木からたどる。
func game() -> Node:
	return root.get_node("Game")

func key(code: int, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = pressed
	Input.parse_input_event(ev)

## 1 コマだけ押す。これを繰り返して歩かせる。
func step(code: int) -> void:
	key(code, true)
	await process_frame
	key(code, false)
	await process_frame

## 目的地へ歩く。行き過ぎないよう、近づいたら止める。
## 「一定時間押しっぱなし」だと画面の端まで行ってしまう。
func walk_to(hero: Node, tx: float, ty: float, limit: int = 600) -> bool:
	for i in limit:
		var p: Vector2 = hero.scratch_pos()
		if absf(p.x - tx) <= 6.0 and absf(p.y - ty) <= 6.0:
			return true
		if p.x < tx - 3.0: await step(KEY_RIGHT)
		elif p.x > tx + 3.0: await step(KEY_LEFT)
		if p.y < ty - 3.0: await step(KEY_UP)
		elif p.y > ty + 3.0: await step(KEY_DOWN)
		await process_frame
	return false

## 決定キーを 1 回押して離す。
## 押しっぱなしが次の操作に化けないよう、必ず離してから間を置く。
func press_accept() -> void:
	key(KEY_SPACE, false)
	await wait_ms(60)
	key(KEY_SPACE, true)
	await wait_ms(150)
	key(KEY_SPACE, false)
	await wait_ms(150)
