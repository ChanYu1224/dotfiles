#!/usr/bin/env bash
# PreToolUse hook: git commit --no-verify / --no-gpg-sign をブロックする。
# pre-commit hook にはシークレット検出・lint 等の安全装置が含まれることがあるため、
# 不用意なスキップは事故になる。
# 明示的に逃げたい場合は環境変数 ALLOW_NO_VERIFY=1 を設定する。
#
# シェル連結された各サブコマンドの先頭が git であるかを個別に判定し、
# 引数の文字列リテラル内に "--no-verify" が含まれているだけのケース（gh pr create --body 等）
# は false positive にしない。sudo / nice / env などのラッパー前置も透過する。
set -euo pipefail

input=$(cat)

parsed=$(CLAUDE_HOOK_INPUT="$input" ALLOW_NO_VERIFY="${ALLOW_NO_VERIFY:-0}" python3 <<'PY'
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

if os.environ.get("ALLOW_NO_VERIFY", "0") == "1":
    print(tool)
    print(cmd_oneline)
    print("0")
    sys.exit(0)

parts = re.split(r'(?:&&|\|\||;|\||&|`|\(|\))', cmd_oneline)

WRAPPERS = {"sudo", "nice", "time", "nohup", "env", "exec", "xargs"}
SKIP_FLAGS = {"--no-verify", "--no-gpg-sign"}

def find_command_start(tokens):
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
    if not rest or rest[0] != "git":
        continue
    for arg in rest[1:]:
        if arg in SKIP_FLAGS or arg == "commit.gpgsign=false":
            blocked = True
            break
    if blocked:
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

cat >&2 <<'MSG'
[BLOCKED] git の --no-verify / --no-gpg-sign は原則禁止です。

pre-commit hook にはシークレット検出や lint などの安全装置が含まれていることがあります。
スキップすると問題のある変更を誤ってコミットする事故につながります。

対応:
1. hook 失敗の根本原因を調べて修正する
2. どうしても緊急で迂回したい場合のみ ALLOW_NO_VERIFY=1 を設定して再実行
   （その場合も、後で必ず根本原因を修正すること）
MSG
exit 2
