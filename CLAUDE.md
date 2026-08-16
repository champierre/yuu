# CLAUDE.md

漢字謎解きアクション「勇」の冒険（Godot 4）の作業メモ。

コードを読めば分かることは書かない。**読んでも分からず、踏むと壊れるところ**だけを残す。

## 全体像

| ファイル | 役割 |
|---|---|
| `scripts/game.gd` | autoload `Game`。グローバル状態と座標変換、ステージ管理 |
| `scripts/kanji_sprite.gd` | `class_name KanjiSprite`。漢字1体＝スプライト |
| `scripts/effects.gd` | `class_name Effects`。ステージ共通の演出部品 |
| `scripts/touch_pad.gd` | `class_name TouchPad`。指で遊ぶための操作ボタン |
| `scripts/hero.gd` | 勇者の移動 |
| `scripts/river.gd` | 川を並べる（ステージ1 で使う） |
| `scripts/stage1.gd` | ステージ1「斧」の進行 |
| `scripts/stage2.gd` | ステージ2「鉄」の進行 |
| `scripts/stage3.gd` | ステージ3「蟲」の進行 |
| `scripts/stage4.gd` | ステージ4（作りかけ。`?debug=true` のときだけ遊べる） |
| `scripts/title.gd` | タイトルとステージ選択 |

ステージは 1 つにつき `.tscn` + `.gd` の組。`Game.STAGE_SCENES` が番号とファイルを結んでいる。
**ステージを増やすときは新しい組を作り、`STAGE_SCENES` と `STAGE_MAX` に足す。**
既存ステージのスクリプトは触らなくてよい。

## 踏みやすい落とし穴

### 1. `Game.reset()` は `stage_no` を 1 に戻す

ステージの `_ready()` で `Game.reset()` を呼ぶと、入った瞬間にステージ番号が 1 になり、
クリア後の遷移先が壊れる。ステージ側では **`Game.reset_stage()`** を使う（`stage_no` を触らない）。

`reset()` を使ってよいのは「タイトルから遊び始めるとき」だけ。

### 2. `KanjiSprite.rect()` は回転を考えない

`rect()` は `_label.size * scale` から作る AABB。`rotation` を無視する（scale は見る）。
実測で確認済み: 0度/45度/90度いずれもサイズは `(20,30)` のまま変わらない。

したがって**飛ぶもの・振るものを `rotation` で傾けてはいけない**。見た目と判定がずれる。
代わりに `vertical` を使って字の形そのものを縦長／横長にする。

- 斧: `rotation = 0` を明示し、水平に薙ぐ
- 矢: `vertical = true` で上向きの細長い形にして、真上に飛ばす

### 3. `touching()` は両方が `visible` でないと false

判定の前に、相手が表示されていることを確かめる。
「当たらない」と思ったらまず `visible` を疑う。

### 4. `set_scratch_pos()` は親が原点にある前提

`position`（ローカル座標）に代入している。親ノードを動かすと全部ずれる。
`.tscn` のルートや `River` / `Soil` は `(0,0)` のままにしておく。

例外として、画面を揺らす演出では**わざと**場面のまとめ役ごとずらしている
（`stage2.gd` の `_shake_screen`）。終わったら必ず `(0,0)` に戻すこと。

### 5. シーンとスクリプトで同じものを二重に作らない

`.tscn` に置いたノードを、スクリプトでも `new()` して足すと二重になる。
実際にステージ2 で村人が 6 人になり、位置を決めていない 3 人が画面の隅に
重なって「人」の字だけ見えていた。

**`.tscn` にあるものは `$Villager1` のように拾って使い直す。**

### 6. 場面を組むときは前の場面の状態を消す

`KanjiSprite` は `visible` / `scale` / `rotation` / `text` / `vertical` / `pivot` / `modulate` が
そのまま残る。書き漏らすと前の場面の見た目を引きずる。

どのステージも `start_scene1()` などの場面を組む関数で、使うものの見た目を
その都度書き直している。ノードが増えるほど書き漏らしが起きやすいので、
新しいステージでは「先に全部を素の状態へ戻してから、使うものだけ書く」
という組み方にしておくと安全。

### 7. 演出中は `_busy`。解除し忘れると操作不能になる

`_process` は `_busy` の間なにもしない。演出の**すべての分岐**で解除すること。
特に「当たったとき」と「外したとき」で流れが分かれる場所。

**`_busy` は 1 つしかないので、演出が重なると取り合いになる。**
ステージ3 では蟲の登場演出と射撃演出が両方 `_busy` を使うため、
射撃側は「自分で立てたときだけ下ろす」ようにしている（`during_emerge`）。
横取りして下ろすと、登場が済んだあとも操作を受け付けなくなる。

### 8. `hero.blockers` は手動で渡す

`_ready()` で `hero.blockers = 入れ物` を書く。忘れるとすり抜ける。

渡した入れ物の**子ども全部**がぶつかる相手になる
（ステージ1 は川、ステージ2 は壁と門、ステージ3 は無し）。
**門のように「あとで通れるようになるもの」も、この入れ物に入れておく。**
入れ忘れると閉じているのにすり抜けられる（実際にそうなっていた）。
通れるようにするときは、入れ物から出す。

### 9. 演出は `await` をまたぐ。その間にシーンが変わると落ちる

シーンが切り替わると、ノードは解放される前にまず木から外れる。
その間 `is_instance_valid()` は true を返すのに `get_tree()` は使えない。
この食い違いが原因で、クリア演出中に Esc を押すと固まっていた。

- `Effects` の演出はすべて **`Effects.alive(node)`** を通してある。自分で書くときも同じ守りを入れる
- ステージ側は **`_left()`** を持っていて、クリア演出の段の間で確かめる
- 場面を抜けるときは `_leaving = true` を立ててから `change_scene_to_file()`

**ステージの演出で待つときは `await get_tree()` を直に書かない。**
`StageBase` の **`next_frame()`** と **`wait(秒)`** だけを使う。

```gdscript
if not await next_frame(): return   ## 次のコマまで待つ
if not await wait(0.5): return      ## 0.5 秒待つ
```

どちらも待つ前と待ったあとに場面を抜けたかを見て、抜けていたら false を返す。
`await get_tree()` を直に書くと、そのたびに守りを手で足すことになり、
**書き忘れても何も教えてくれず、遊んでいて初めて落ちる**。
実際に、蟲の登場中や斧を振っている最中に「戻」を押すと落ちていた。

抜けるときに後始末が要るものは、`return` の前に書く
（`_shake_screen` は `position` を `(0,0)` に戻す。落とし穴 4）。

**この落ち方はヘッドレスでは走り続けてしまい、テストは通ったように見える。**
`Parameter "data.tree" is null` が stderr に出るだけなので、
`run_all.sh` がそれを拾って失敗にしている。

### 10. `reload_current_scene()` は使わない

`current_scene` が未設定だと `Parameter "current_scene" is null` で失敗する。
`change_scene_to_file()` にファイルを名指しで渡す。

### 11. クリア後の案内は 0.5 秒待ってから受け付ける

待たないと、目標に触れた瞬間に押していたスペースをそのまま拾って即座に進んでしまう。
`_show_end_hint()` などの `await get_tree().create_timer(0.5).timeout` は消さないこと。

同じ理由で、**宝箱を開けた押し下げが、そのまま次の操作に化けないようにする**。
ステージ3 では `_await_release` を立てて、一度離すまで弓を引き始めない。

### 12. 「押した瞬間」と「押している間」を区別する

- 拾う・調べるは**押した瞬間**
- 弓を引き絞るのは**押している間**

**決定ボタンは `StageBase` に集めてある。ステージ側で `Input` を直に見ない。**

```gdscript
func _process(_delta: float) -> void:
	if _finished:
		update_act(true)
		update_finished_act()   ## クリア後は決定で次へ
		return
	update_act(_busy)           ## 毎コマ 1 回だけ呼ぶ
	if _busy:
		return
	...
	if act_just_pressed():      ## 使うときに聞く
		_try_chest()
```

`update_act()` を**毎コマ呼ぶ**のが要点。使う側（宝箱に重なったとき等）で
見ると、条件に合わない間は記録が更新されず、離したのを見落とす。

`_busy` の間もキーの状態だけは更新される（さもないと演出明けに
「押しっぱなし」の記録が古いままになり、次の一手が出せなくなる）。

弓の「引いて離す」だけはステージ3 が自前で持っている
（`_shoot_was_down` / `_await_release`）。押した瞬間ではなく
離した瞬間に放つので、上の仕組みとは別のものが要るため。

### 13. Web 版は入力割り当てが要る

`project.godot` の `[input]` で `ui_accept` に Space / Enter / Kp Enter を明示している。
これが無いと Web 版でスペースが効かない。

### 14. Web 版では `OS.get_name()` が "Web" を返す

機械の名前ではないので、`"Android"` や `"iOS"` との比較は効かない。
`DisplayServer.is_touchscreen_available()` もブラウザによっては false になる。

指で遊ぶ機械かどうかは **`TouchPad.needed()`** に集約してある。
Web のときは `JavaScriptBridge` でブラウザ自身に聞いている。

画面に出す案内の文言（「スペース」か「押」か）も
`TouchPad.accept_name()` / `accept_key_name()` / `move_name()` で決まる。
**文言を足すときは直書きせず、ここを通す。**

### 15. 「最後のステージ」は `Game.last_stage()` に聞く

`STAGE_MAX`（=3）は**普段遊べる最後**で、作りかけのステージはその先にある。
`?debug=true` で開いたときだけ `last_stage()` が 4 を返し、
タイトルに並ぶ数も、クリア後に「次へ」を出すかも、そこで決まる。

**`Game.STAGE_MAX` と直に比べない。** 比べると、debug のときだけ
「次のステージがあるのに『もう一度』が出る」という食い違いが起きる。

`Game.debug` は autoload の `_ready()` で一度だけ決める
（Web はアドレスの `?debug=true`、パソコンは `godot -- debug=true`）。
テストからは直に代入してよい。
**`_ready()` より前（`_initialize` の直後）はまだ false なので、
1 コマ待ってから見ること。**

作りかけのステージを足すときは `STAGE_SCENES` に番号を足し、
`DEBUG_STAGE_MAX` を伸ばす。できあがったら `STAGE_MAX` を伸ばして
普段の遊びに出す。

## 不具合を直すときは TDD で

**必ず「先に失敗するテストを書く」こと。**

1. その不具合を捉えるテストを `tests/` に足す
2. 走らせて**失敗することを確かめる**（ここを飛ばさない。
   失敗しないテストは、直っていなくても通ってしまう役に立たないテスト）
3. 直す
4. 走らせて通ることを確かめる
5. 他のテストも全部走らせ、巻き添えで壊していないか見る

順番が大事。先に直してしまうと、そのテストが本当に不具合を
捉えられているのか分からなくなる。

## テストのしかた

ブラウザ自動操作では `Input.is_action_pressed`（押しっぱなし判定）を再現できない。
`key` イベントは一瞬しか押されないので、勇者は動かない。
**動作確認はヘッドレスの GDScript で行う。**

```sh
godot --headless --script path/to/test.gd
```

書き方の要点:

- シーンは **`change_scene_to_file()` で読み、`current_scene` から取る**。
  `root.add_child(instantiate())` だと `@onready var x: KanjiSprite` が `Nil` になる
  （`--script` モードでは `class_name` の型注釈が解決されないことがある）
- autoload は `root.get_node("Game")` で取る（`Game` の識別子は解決されない）
- **ゲーム側でも、`Game` と識別子で書くとテストから読み込めなくなる。**
  定数や静的関数（`to_godot` など）は `preload("res://scripts/game.gd")` から呼ぶ。
  状態を触るとき（`reset()` など）だけ `get_tree().root.get_node_or_null("Game")` を使う。
  `class_name Game` は付けられない（autoload と名前がぶつかる）
- テストの中で `KanjiSprite.new()` もできない。既にあるノードを借りるか、
  ゲーム側の関数に作らせる
- キーは `Input.parse_input_event()` で送る
- **待つときは `Time.get_ticks_msec()` で実時間を見る**。
  `await process_frame` を n 回まわす書き方だと、ヘッドレスでは 1 コマが極端に短く
  （実測 0.00044 秒 = 実機の 1/38）、1 秒待ったつもりが一瞬しか経っていない
- 短命なノード（破片・残像）を数えるときは、消える前＝演出の途中で数える

### 座標を書き込むテストだけでは足りない

`set_scratch_pos()` で勇者を目的地に置くテストは、**川や画面端を飛び越えてしまう**。
それだと「そもそもそこへ行けるのか」を確かめられない。

実際にステージ3 では、紐を川の向こう側に置いていたため
勇者が永久に届かず、クリア不可能な状態になっていた。
座標を書き込むテストは全て通っていたので気づけなかった。

**新しい場面を作ったら、キーで歩いて通しでクリアできることを必ず確かめる。**

```gdscript
## 1 フレームだけキーを押す。これを繰り返して歩かせる
func _step(code: int) -> void:
	_key(code, true); await process_frame; _key(code, false); await process_frame

## 目的地へ向かう。行き過ぎないよう、近づいたら止める
for i in 400:
	if hero.touching(goal): break
	if hero.scratch_pos().x < target_x: await _step(KEY_RIGHT)
	await process_frame
```

「一定時間押しっぱなし」だと画面端まで行き過ぎるので、
**毎フレーム位置を見て、目的地を過ぎたら止める**書き方にする。

### 複数のファイルをまとめて書き換えたら、全部を読み込ませて確かめる

`--headless --quit-after` は**起動シーン（タイトル）しか読み込まない**。
ステージのスクリプトが壊れていても気づけない。

実際に、あるステージだけ関数の定義が入らず、開けなくなったことがある。
まとめて置換したあとは、**3 つのステージを実際に読み込むところまで**確かめる。

書き出しの確認:

```sh
godot --headless --export-release "Web" build/web/index.html
```

## 進め方

**`main` へ直接 push はできない。必ずブランチを切って PR を出す。**

```sh
git checkout -b 直すことの名前
# 直す
git push -u origin 直すことの名前
gh pr create
```

**PR を出すとテストが走る**（`deploy.yml` の `test`）。手元で毎回
`./tests/run_all.sh` を通さなくてよい。手元で走らせるのは、直している
最中に手早く確かめたいときだけでよい。

書き出しと公開が動くのは `main` に入ったときだけ。PR では走らない
（`build` と `deploy` に `if: github.event_name != 'pull_request'` がある）。

## デプロイ

`main` に入ると GitHub Actions がテストを走らせ、通れば Web 版を書き出して
GitHub Pages へ公開する。テストが落ちたら公開されない。
公開先: https://champierre.github.io/yuu/

**直したつもりで直っていないときは、まず push できているかを見る。**
作業ツリーに残したままデプロイを待っていたことがある。
