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
  if ! "$GODOT" --headless --script "$t" 2>&1 | grep -v "^Godot Engine"; then
    failed=1
  fi
  # godot はテストの結果を終了コードで返す
  status=${PIPESTATUS[0]}
  if [ "$status" -ne 0 ]; then
    failed=1
  fi
  echo ""
done

if [ "$failed" -ne 0 ]; then
  echo "テストに失敗があります"
  exit 1
fi
echo "すべて通りました"
