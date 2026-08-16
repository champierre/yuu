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
| `scripts/main.gd` | ステージ1「斧」の進行 |
| `scripts/stage2.gd` | ステージ2「鉄」の進行 |
| `scripts/stage3.gd` | ステージ3「蟲」の進行 |
| `scripts/title.gd` | タイトルとステージ選択 |

ステージは 1 つにつき `.tscn` + `.gd` の組。`Game.STAGE_SCENES` が番号とファイルを結んでいる。
**ステージを増やすときは新しい組を作り、`STAGE_SCENES` と `STAGE_MAX` に足す。**
既存ステージのスクリプトは触らなくてよい。

**ステージ1 だけファイル名が `main.gd` / `main.tscn`**（最初の移植のときのまま）。
番号と名前が食い違うので、直すときに取り違えないこと。

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

### 8. `hero.river` は手動で渡す

`_ready()` で `hero.river = river` を書く。忘れると川をすり抜ける。

`river` という名前だが、中身は「ぶつかる相手の群れ」。
ステージ2 では壁と門をまとめた入れ物を渡している。
**門のように「あとで通れるようになるもの」は、この入れ物に入れ忘れないこと。**
入れ忘れると閉じているのにすり抜けられる（実際にそうなっていた）。

### 9. 演出は `await` をまたぐ。その間にシーンが変わると落ちる

シーンが切り替わると、ノードは解放される前にまず木から外れる。
その間 `is_instance_valid()` は true を返すのに `get_tree()` は使えない。
この食い違いが原因で、クリア演出中に Esc を押すと固まっていた。

- `Effects` の演出はすべて **`Effects.alive(node)`** を通してある。自分で書くときも同じ守りを入れる
- ステージ側は **`_left()`** を持っていて、クリア演出の段の間で確かめる
- 場面を抜けるときは `_leaving = true` を立ててから `change_scene_to_file()`

### 10. `reload_current_scene()` は使わない

`current_scene` が未設定だと `Parameter "current_scene" is null` で失敗する。
`change_scene_to_file()` にファイルを名指しで渡す。

### 11. クリア後の案内は 0.5 秒待ってから受け付ける

待たないと、目標に触れた瞬間に押していたスペースをそのまま拾って即座に進んでしまう。
`_show_end_hint()` などの `await get_tree().create_timer(0.5).timeout` は消さないこと。

同じ理由で、**宝箱を開けた押し下げが、そのまま次の操作に化けないようにする**。
ステージ3 では `_await_release` を立てて、一度離すまで弓を引き始めない。

### 12. 「押した瞬間」と「押している間」を区別する

- 拾う・調べるは**押した瞬間**（自前でエッジを見る）
- 弓を引き絞るのは**押している間**

`_busy` で `_process` を止めるとキーの上げ下げを見逃すので、
`_busy` の間もキーの状態だけは更新しておく（さもないと演出明けに
「押しっぱなし」の記録が古いままになり、次の一手が出せなくなる）。

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

実際に `main.gd` だけ関数の定義が入らず、ステージ1 が開けなくなったことがある。
まとめて置換したあとは、**3 つのステージを実際に読み込むところまで**確かめる。

書き出しの確認:

```sh
godot --headless --export-release "Web" build/web/index.html
```

## デプロイ

`main` への push で GitHub Actions が Web 版を書き出し、GitHub Pages へ公開する。
公開先: https://champierre.github.io/yuu/

**直したつもりで直っていないときは、まず push できているかを見る。**
作業ツリーに残したままデプロイを待っていたことがある。
