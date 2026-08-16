# 漢字謎解きアクション「勇」の冒険

キャラクターをすべて漢字で表現した謎解きアクションゲームです。
勇者「勇」を操作して、目標を目指して進んでください。

**▶ [ブラウザで遊ぶ](https://champierre.github.io/yuu/)**

Scratch 版 [「勇」の冒険](https://scratch.mit.edu/projects/169268428/) と
[その 2](https://scratch.mit.edu/projects/427402420/)（作者: jishiha）を
Godot 4 に移植し、ステージを足したものです。

## 遊び方

| 操作 | |
|---|---|
| ↑ ↓ ← → | 上下左右に移動／タイトルでステージを選ぶ |
| スペース | 調べる・アクション |
| Esc | タイトルに戻る |

スマホやタブレットでは、画面の下にボタンが出ます。

全部で 3 ステージあります。行く手を阻むものをどうにかして「目標」を目指してください。
解き方はあえて書きません。漢字をよく見ると手がかりがあります。

## 開発

Godot 4.4 以降が必要です。エディタで `project.godot` を開くか、コマンドラインから:

```sh
godot --path .
```

Web 版を手元で書き出す場合:

```sh
godot --headless --export-release "Web" build/web/index.html
cd build/web && python3 -m http.server 8000
```

`main` ブランチへの push で GitHub Actions が Web 版を書き出し、
GitHub Pages へ自動デプロイします（`.github/workflows/deploy.yml`）。

## 構成

| ファイル | 役割 |
|---|---|
| `scripts/game.gd` | Scratch の変数に相当するグローバル状態と座標変換（autoload: `Game`） |
| `scripts/kanji_sprite.gd` | 漢字1体＝スプライト。表示・当たり判定・縦書き・回転中心 |
| `scripts/title.gd` | タイトル画面 |
| `scripts/hero.gd` | 勇者の移動と川の衝突判定 |
| `scripts/river.gd` | 川を 20px 刻みで並べる |
| `scripts/effects.gd` | ステージ共通の演出部品（弾む拡大・破片・点滅・残像など） |
| `scripts/touch_pad.gd` | スマホ・タブレット用の操作ボタン |
| `scripts/main.gd` | ステージ 1 の進行と演出 |
| `scripts/stage2.gd` | ステージ 2 の進行と演出 |
| `scripts/stage3.gd` | ステージ 3 の進行と演出 |
| `scenes/title.tscn` | タイトル画面のシーン |
| `scenes/main.tscn` | ステージ 1 のスプライトを配置したシーン |
| `scenes/stage2.tscn` | ステージ 2 のスプライトを配置したシーン |
| `scenes/stage3.tscn` | ステージ 3 のスプライトを配置したシーン |

開発時に気をつけることは [CLAUDE.md](CLAUDE.md) にまとめています。

## ライセンス

- ソースコード: 著作権は作者が保有します（All rights reserved）。
- 同梱フォント `fonts/NotoSansJP-Regular.otf`:
  SIL Open Font License 1.1（[fonts/OFL.txt](fonts/OFL.txt)）
- 原作: [漢字謎解きアクション「勇」の冒険](https://scratch.mit.edu/projects/169268428/) /
  [その 2](https://scratch.mit.edu/projects/427402420/) by jishiha
  （原作者本人による移植です）
