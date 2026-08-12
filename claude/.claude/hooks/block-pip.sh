#!/usr/bin/env bash
# PreToolUse hook: uv 管理プロジェクト（uv.lock がある）で pip install 系コマンドが
# 実行されようとしたらブロックする。uv.lock が見つからないプロジェクトでは何もしない
# （pip 運用のプロジェクトを誤ブロックしないため）。
# 明示的に逃げたい場合は環境変数 ALLOW_PIP=1 を設定する。
#
# コマンド本体（先頭トークン）に対してのみ判定する。引数の文字列リテラル内に
# "pip install" が含まれているだけのケース（例: gh pr create --body "... pip install ..."）
# は false positive にしない。シェル連結（; && || | & ` ( )）で接続された各サブコマンドを
# 個別に判定し、sudo / nice / nohup / env / xargs などのラッパー前置や env var 代入も透過する。
set -euo pipefail

input=$(cat)

parsed=$(CLAUDE_HOOK_INPUT="$input" ALLOW_PIP="${ALLOW_PIP:-0}" python3 <<'PY'
import json, os, re, sys

try:
    d = json.loads(os.environ.get("CLAUDE_HOOK_INPUT", "") or "{}")
except Exception:
    print("")
    print("")
    print("")
    sys.exit(0)

tool = d.get("tool_name", "")
cmd = (d.get("tool_input") or {}).get("command", "") or ""
cmd_oneline = cmd.replace("\n", " ").replace("\r", " ")

if os.environ.get("ALLOW_PIP", "0") == "1":
    print(tool)
    print(cmd_oneline)
    print("0")
    sys.exit(0)

parts = re.split(r'(?:&&|\|\||;|\||&|`|\(|\))', cmd_oneline)

WRAPPERS = {"sudo", "nice", "time", "nohup", "env", "exec", "xargs"}

def find_command_start(tokens):
    """env var 代入と wrapper を読み飛ばして実コマンドの開始位置を返す。"""
    i = 0
    while i < len(tokens):
        t = tokens[i]
        if "=" in t and not t.startswith("=") and not t.startswith("-"):
            i += 1
            continue
        if t in WRAPPERS:
            i += 1
            while i < len(tokens) and tokens[i].startswith("-"):
                i += 1
            continue
        return i
    return None

blocked = False
for raw in parts:
    sub = raw.strip()
    if not sub:
        continue
    tokens = sub.split()
    start = find_command_start(tokens)
    if start is None:
        continue
    rest = tokens[start:]
    if not rest:
        continue
    head = rest[0]
    args = rest[1:]
    # pip / pip3 install のみ拒否（pip list / pip show 等は許容）
    if head in ("pip", "pip3"):
        if args and args[0] == "install":
            blocked = True
            break
    # python / python3 -m pip install
    if head in ("python", "python3"):
        i = 0
        while i < len(args) and args[i].startswith("-") and args[i] != "-m":
            i += 1
        if i + 2 < len(args) and args[i] == "-m" and args[i + 1] == "pip" and args[i + 2] == "install":
            blocked = True
            break

print(tool)
print(cmd_oneline)
print("1" if blocked else "0")
PY
)

tool_name=$(printf '%s\n' "$parsed" | sed -n '1p')
cmd=$(printf '%s\n' "$parsed" | sed -n '2p')
blocked=$(printf '%s\n' "$parsed" | sed -n '3p')

if [ "$tool_name" != "Bash" ]; then
  exit 0
fi

if [ "$blocked" != "1" ]; then
  exit 0
fi

# uv 管理プロジェクト（uv.lock がある）でのみブロックする。
# node_modules / .venv / .git 配下は探索しない。
proj_dir="${CLAUDE_PROJECT_DIR:-$PWD}"
uv_lock=$(find "$proj_dir" -maxdepth 3 \
  \( -name node_modules -o -name .venv -o -name .git \) -prune -o \
  -name uv.lock -print -quit 2>/dev/null || true)
if [ -z "$uv_lock" ]; then
  exit 0
fi

cat >&2 <<MSG
[BLOCKED] pip install 系コマンドは禁止です。

このプロジェクトは uv で管理されています（uv.lock を検出: ${uv_lock}）。
- 依存追加: cd <uv.lock のあるディレクトリ> && uv add <pkg>
- 同期:     cd <uv.lock のあるディレクトリ> && uv sync

どうしても pip を使う必要がある場合は、環境変数 ALLOW_PIP=1 を一時的に設定して再実行してください。
MSG
exit 2
