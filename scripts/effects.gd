extends Object
class_name Effects
## ステージをまたいで使う演出の部品。
##
## どのステージからも同じ動きを呼べるようにここへ集めた。
## 演出は毎フレーム進むので、待つための SceneTree が要る。
## 自前でツリーを持たない（Object を継承した素の入れ物）ため、
## 対象のノードを受け取り、そこから get_tree() をたどる形にしている。

## 加速のしかた。等速だと機械的なので、場面ごとに緩急をつける。
enum { EASE_IN, EASE_OUT }

## クリア演出で飛び散る漢字と、その色。
const BURST_CHARS := ["祝", "勝", "光", "花", "喜", "星", "楽"]
const BURST_COLORS := [
	Color("#e0b020"), Color("#3f9e44"), Color("#bb3023"), Color("#003cff"),
]

## 0〜1 の進み具合に緩急をつける。
## EASE_IN は「静→急」（止まった状態から一気に加速する）、
## EASE_OUT は「急→静」（勢いよく出て、最後に減速して止まる）。
static func ease_k(k: float, ease_type: int) -> float:
	return k * k * k if ease_type == EASE_IN else 1.0 - pow(1.0 - k, 3.0)

## ゼロから勢いよく拡大し、行き過ぎてから戻る（弾む拡大）。
static func pop_in(node: Node2D, dur: float) -> void:
	node.scale = Vector2.ZERO
	var t := 0.0
	while t < dur:
		if not is_instance_valid(node) or not node.is_inside_tree():
			return
		var tree := node.get_tree()
		t += tree.root.get_process_delta_time()
		var k: float = clampf(t / dur, 0.0, 1.0)
		## 一度 1.0 を超えてから戻ることで「ぼよん」と弾ませる。
		var e := 1.0 - pow(1.0 - k, 3.0)
		var overshoot := sin(k * PI) * 0.45
		node.scale = Vector2.ONE * (e + overshoot)
		await tree.process_frame
	if is_instance_valid(node):
		node.scale = Vector2.ONE

## 破片を飛ばして、減速しながら落として消す。
static func fly_particle(p: KanjiSprite, vel: Vector2) -> void:
	var v := vel
	var life := 1.4
	var t := 0.0
	while t < life:
		## シーンが切り替わると解放されるので、毎回確かめる。
		if not is_instance_valid(p) or not p.is_inside_tree():
			return
		var tree := p.get_tree()
		var d := tree.root.get_process_delta_time()
		t += d
		p.position += v * d
		v.y += 260.0 * d      ## 重力で落ちる
		v *= 0.985            ## 空気抵抗で減速
		p.rotation += d * 3.0
		p.scale = Vector2.ONE * clampf(1.0 - t / life, 0.0, 1.0)
		await tree.process_frame
	if is_instance_valid(p):
		p.queue_free()

## origin を中心に漢字が放射状に飛び散る。
## parent に破片をぶら下げるので、シーンが変わればまとめて消える。
static func burst(parent: Node2D, origin: Vector2) -> void:
	for i in BURST_CHARS.size():
		var p := KanjiSprite.new()
		p.text = BURST_CHARS[i]
		p.color = BURST_COLORS[i % BURST_COLORS.size()]
		p.z_index = 9
		parent.add_child(p)
		p.position = origin
		## 放射状に飛ばす。
		var ang := TAU * float(i) / float(BURST_CHARS.size())
		fly_particle(p, Vector2.RIGHT.rotated(ang) * randf_range(70.0, 130.0))

## その場で跳ねて喜ぶ。
static func cheer(node: Node2D, times: int = 2) -> void:
	var base := node.position
	for jump in times:
		var dur := 0.34
		var t := 0.0
		while t < dur:
			if not is_instance_valid(node) or not node.is_inside_tree():
				return
			t += node.get_process_delta_time()
			var k: float = clampf(t / dur, 0.0, 1.0)
			## 放物線を描いて上がって下りる。
			node.position.y = base.y - sin(k * PI) * 26.0
			await node.get_tree().process_frame
		if is_instance_valid(node):
			node.position = base

## 画面に大きな一文字を出す。
static func show_banner(parent: Node2D, text: String, color: Color,
		x: float = 0.0, y: float = 40.0) -> KanjiSprite:
	var banner := KanjiSprite.new()
	banner.text = text
	banner.color = color
	banner.font_size = 64
	banner.z_index = 11
	parent.add_child(banner)
	banner.set_scratch_pos(x, y)
	await pop_in(banner, 0.5)
	return banner

## 案内文字をゆっくり点滅させる。
## いつ止めるかは呼ぶ側の事情なので、続けてよいかを返す関数を渡してもらう。
## シーン切り替えで対象ごと解放されるため、毎回 is_instance_valid で確かめる。
static func blink(node: KanjiSprite, should_continue: Callable) -> void:
	var t := 0.0
	while is_instance_valid(node) and node.is_inside_tree() and should_continue.call():
		t = fmod(t + node.get_process_delta_time(), 1.2)
		node.modulate.a = 0.35 + 0.65 * (0.5 + 0.5 * sin(t * PI * 2.0 - PI * 0.5))
		await node.get_tree().process_frame
	if is_instance_valid(node):
		node.modulate.a = 1.0

## 残像を薄くしながら消す。
## シーンが切り替わると対象ごと解放されるので、毎回生きているか確かめる。
static func fade_trail(t: KanjiSprite, life: float = 0.18) -> void:
	var e := 0.0
	while e < life:
		## is_instance_valid だけでは足りない。木から外された直後は
		## まだ「生きている」が get_tree() は使えないため、
		## is_inside_tree() で中にいることまで確かめる。
		if not is_instance_valid(t):
			return
		if not t.is_inside_tree():
			## 木から外された。ここで捨てないと、薄くなる途中の
			## 残像がそのまま残り続けてしまう。
			t.queue_free()
			return
		var tree := t.get_tree()
		e += tree.root.get_process_delta_time()
		t.modulate.a = clampf(1.0 - e / life, 0.0, 1.0)
		await tree.process_frame
	if is_instance_valid(t):
		t.queue_free()

## 通った跡に、同じ形の文字を薄く置いてすぐ消す。動きの軌跡に見える。
static func leave_trail(parent: Node2D, src: KanjiSprite, life: float = 0.18) -> void:
	var t := KanjiSprite.new()
	t.text = src.text
	t.color = src.color
	t.vertical = src.vertical
	parent.add_child(t)
	t.position = src.position
	t.scale = src.scale
	t.modulate.a = 0.35
	fade_trail(t, life)
