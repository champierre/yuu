#!/usr/bin/env bash
# テストを全部走らせる。1 つでも失敗したら 0 以外で終わる。
#
#   ./tests/run_all.sh
#
# godot が PATH に無いときは GODOT=/path/to/godot を渡す。
set -u

GODOT="${GODOT:-godot}"
cd "$(dirname "$0")/.."

failed=0
for t in tests/test_*.gd; do
  # 土台は単体で走らせない
  [ "$t" = "tests/test_helper.gd" ] && continue
  echo "--- $t"
  out=$("$GODOT" --headless --script "$t" 2>&1)
  status=$?
  echo "$out" | grep -v "^Godot Engine"
  # godot はテストの結果を終了コードで返す
  if [ "$status" -ne 0 ]; then
    failed=1
  fi
  # 場面を抜けたあとも演出が回っていると、解放された木を触りにいって落ちる。
  # ヘッドレスの Godot はそれでも走り続けてしまい、テストは通ったように見える。
  # 印は stderr にしか出ないので、ここで拾って失敗にする。
  #
  # 見るのはこの落ち方だけに絞る。SCRIPT ERROR 全部を失敗にすると、
  # --script モードで autoload の名前が解決できないだけの
  # 昔からの出力（kanji_sprite.gd の Game）まで拾ってしまうため。
  if echo "$out" | grep -qE 'Parameter "data.tree" is null|on a base object of type .null instance.|on a null value'; then
    echo "  失敗 場面を抜けたあとに演出が動いている（上のエラーを見ること）"
    failed=1
  fi
  echo ""
done

if [ "$failed" -ne 0 ]; then
  echo "テストに失敗があります"
  exit 1
fi
echo "すべて通りました"
