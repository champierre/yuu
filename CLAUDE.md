# CLAUDE.md

漢字謎解きアクション「勇」の冒険（Godot 4 / Scratch 169268428 の移植）の作業メモ。

コードを読めば分かることは書かない。**読んでも分からず、踏むと壊れるところ**だけを残す。

## 全体像

| ファイル | 役割 |
|---|---|
| `scripts/game.gd` | autoload `Game`。グローバル状態と座標変換、ステージ管理 |
| `scripts/kanji_sprite.gd` | `class_name KanjiSprite`。漢字1体＝スプライト |
| `scripts/effects.gd` | `class_name Effects`。ステージ共通の演出部品 |
| `scripts/hero.gd` | 勇者の移動 |
| `scripts/river.gd` | 川を並べる |
| `scripts/main.gd` | ステージ1 の進行 |
| `scripts/stage2.gd` | ステージ2 の進行 |
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

回転対応させたくなったら `hero.gd` の川衝突も含めて全部の挙動が変わるので、慎重に。

### 3. `touching()` は両方が `visible` でないと false

判定の前に、相手が表示されていることを確かめる。
「当たらない」と思ったらまず `visible` を疑う。

### 4. `set_scratch_pos()` は親が原点にある前提

`position`（ローカル座標）に代入している。親ノードを動かすと全部ずれる。
`.tscn` のルートや `River` / `Soil` は `(0,0)` のままにしておく。

### 5. `reached_right_edge` は毎フレーム飛ぶ

`hero.gd` はシネマモード中に `x > 230` なら毎フレーム emit する。
受け側で `_finished` / `_busy` / シーン番号のガードを必ず入れる。

### 6. 場面を組むときは前の場面の状態を消す

`KanjiSprite` は `visible` / `scale` / `rotation` / `text` / `vertical` / `pivot` / `modulate` が
そのまま残る。書き漏らすと前の場面の見た目を引きずる。

- ステージ1（`main.gd`）: 各 `start_sceneN()` が**全ノードを明示的に書く**流儀
- ステージ2（`stage2.gd`）: 先頭で `_reset_all_sprites()` を呼び、**使うものだけ書く**流儀

新しいステージは後者を勧める。ノードが増えるほど書き漏らしが起きやすいため。

### 7. 演出中は `_busy`。解除し忘れると操作不能になる

`_process` は `_busy` の間なにもしない。演出の**すべての分岐**で解除すること。
特に「当たったとき」と「外したとき」で流れが分かれる場所。

当たって次の演出へ渡す場合は、あえて解除せずに渡す（渡した先が最後に解除する）。

### 8. `hero.river` は手動で渡す

`_ready()` で `hero.river = river` を書く。忘れると川をすり抜ける。

### 9. 点滅ループはシーン切り替えで宙に浮く

`await get_tree().process_frame` のループは、シーンが解放されたあとも動き続けようとする。
`Effects.blink()` は `is_instance_valid()` で守ってあるので、これを使う。
自前で書くなら同じ守りを入れること。

`title.gd` の `_start()` にある `set_process(false)` も同じ理由（解放前に処理を止める）。

### 10. `reload_current_scene()` は使わない

`current_scene` が未設定だと `Parameter "current_scene" is null` で失敗する。
`change_scene_to_file()` にファイルを名指しで渡す。

### 11. クリア後の案内は 0.5 秒待ってから受け付ける

待たないと、目標に触れた瞬間に押していたスペースをそのまま拾って即座に進んでしまう。
`_show_restart_hint()` などの `await get_tree().create_timer(0.5).timeout` は消さないこと。

### 12. Web 版は入力割り当てが要る

`project.godot` の `[input]` で `ui_accept` に Space / Enter / Kp Enter を明示している。
これが無いと Web 版でスペースが効かない。

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
- キーは `Input.parse_input_event()` で送る
- **待つときは `Time.get_ticks_msec()` で実時間を見る**。
  `await process_frame` を n 回まわす書き方だと、ヘッドレスでは 1 フレームが極端に短く、
  1 秒待ったつもりが一瞬しか経っていない
- 破片などの短命なノードを数えるときは、消える前（演出の途中）に数える

書き出しの確認:

```sh
godot --headless --export-release "Web" build/web/index.html
```

## デプロイ

`main` への push で GitHub Actions が Web 版を書き出し、GitHub Pages へ公開する。
公開先: https://champierre.github.io/yuu/
