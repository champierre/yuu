extends "res://tests/test_helper.gd"
## ステージ2 の門。壁と見分けがつく色になっているか。
##
## 門は「あとで通れるようになる場所」なので、壁に紛れてはいけない。
##
## 明るさの差だけを見てもだめ。壁の茶と門の濃い茶は、
## 成分を足し合わせた差では離れて見えるのに、並べると同じ茶にしか見えない。
## 見分けの決め手は色みそのもの（色相）なので、そこを見る。

## 色相の差。色相は輪になっているので、近いほうの回り道で測る。
func _hue_gap(a: Color, b: Color) -> float:
	var d := absf(a.h - b.h)
	return minf(d, 1.0 - d)

func run_tests() -> void:
	print("ステージ2 の門の色")
	var s := await load_scene("res://scenes/stage2.tscn")

	## 並んでいる壁から 1 つ借りて、その色と比べる。
	## 型注釈は付けない（--script では class_name が解決されないことがある）。
	var wall = null
	for c in s.wall_root.get_children():
		if c != s.gate1 and c != s.gate2:
			wall = c
			break
	check(wall != null, "壁が並んでいる")
	if wall == null:
		return

	## 0.15 は色の輪でおよそ 54 度。茶と茶の違い（0.02 ほど）では届かず、
	## 系統の違う色にして初めて通る。
	var gap := _hue_gap(s.gate1.color, wall.color)
	check(gap > 0.15, "門は壁と別系統の色みになっている（色相差 %.3f）" % gap)
	check_eq(s.gate1.color, s.gate2.color, "2 つの門は同じ色")
