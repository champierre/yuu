# 漢字謎解きアクション「勇」の冒険

キャラクターをすべて漢字で表現した謎解きアクションゲームです。
勇者「勇」を操作して、目標を目指して進んでください。

**▶ [ブラウザで遊ぶ](https://champierre.github.io/yuu/)**

Scratch 版 [169268428](https://scratch.mit.edu/projects/169268428/)（作者: jishiha）を
Godot 4 に移植したものです。

## 遊び方

| キー | 操作 |
|---|---|
| ↑ ↓ ← → | 上下左右に移動（シーン 2 は左右のみ） |
| スペース | 宝箱を開ける・斧で木を切る |

シーン 2 では画面右端まで歩くとシーン 1 に戻れます。

## ゲームの流れ

1. **シーン 1** — 勇者「勇」は川に阻まれ、目標へ行けない。
   右下の「宝箱」に重なってスペースを押すと **斧** が手に入る。
   中央の「木」に触れると場面が変わる。
2. **シーン 2** — 木を横から見た場面。地面「土」の切れ目に小川「川」が流れている。
   斧を持って「木木木」に重なりスペースを 3 回押して木を切り倒す。
3. **シーン 3** — 倒れた木が「倒木」の橋になり、川を渡って「目標」へ。
   到達した瞬間に操作を受け付けなくなり、クリア演出が始まる
   （「達成」が弾んで出る → 漢字が四方に飛び散る → 勇者が跳ねて喜ぶ → 大きく「祝」）。

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
| `scripts/river.gd` | 川を 20px 刻みで並べる（シーン3では中央を空ける） |
| `scripts/main.gd` | 3 つのシーン進行と演出（Scratch のメッセージに対応） |
| `scenes/title.tscn` | タイトル画面のシーン |
| `scenes/main.tscn` | 全スプライトを配置したメインシーン |

## 移植のメモ

- Scratch の座標系（中心原点・上が +Y）は `Game.to_godot()` で変換している。
- スプライトの絵は SVG ではなくフォント描画で再現し、色は元のコスチュームの
  塗り色をそのまま使用（川 `#003cff`、木 `#9e6a3f`、宝箱 `#bb3023` など）。
- 「木木木」は縦長コスチュームなので縦書き＋回転中心を根元に置き、
  根元を軸に倒れるようにしている。
- 元の `broadcast and wait` による 1 秒待ちは `_busy` フラグで再現している。
- 斧を振る動作は、振りかぶり→振り抜き→食い込み→引き戻しの 4 段階。
  右から左へ水平に薙ぐ動きで、等速ではなく緩急をつけている
  （タメは減速し、振り抜きは静止から一気に加速する）。`SWING_*` 定数で調整可能。
  斧は速く動くほど「斧」の字が横に伸びて縦に潰れ、寝かせたように歪む
  （`AXE_STRETCH` / `AXE_SQUASH` / `AXE_MAX_SPEED` で調整）。
  振り抜き中は同じ歪みの残像を置いて水平の軌跡を強調している。

## ライセンス

- ソースコード: [MIT License](LICENSE)
- 同梱フォント `fonts/NotoSansJP-Regular.otf`:
  SIL Open Font License 1.1（[fonts/OFL.txt](fonts/OFL.txt)）
- 原作: [漢字謎解きアクション「勇」の冒険](https://scratch.mit.edu/projects/169268428/) by jishiha
