#!/usr/bin/env bash
# PreToolUse hook: 危険な rm -rf パターン（.git / node_modules / / / $HOME 等）をブロックする。
# 誤爆すると未コミット作業や設定が失われるため、確認を促す。
#
# コマンド連結（; && || | &）された各サブコマンドを個別に判定するため、Python 側で
# シェル風の区切りで分割してから危険判定を行う。検出された危険要素は全て列挙する。
set -euo pipefail

input=$(cat)

parsed=$(CLAUDE_HOOK_INPUT="$input" ALLOW_RM_NODE_MODULES="${ALLOW_RM_NODE_MODULES:-0}" python3 <<'PY'
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

# Split by shell separators (preserve original cmd for the report)
# Treat ; && || | & ` ( ) as boundaries.
parts = re.split(r'(?:&&|\|\||;|\||&|`|\(|\))', cmd_oneline)

dangers = []
allow_node_modules = os.environ.get("ALLOW_RM_NODE_MODULES", "0") == "1"

# Pattern: rm with -r / -f / --recursive / --force somewhere in the flags
rm_pat = re.compile(r'(^|\s)rm(\s+-[a-zA-Z]*[rRfF][a-zA-Z]*|\s+--recursive|\s+--force)')

for raw in parts:
    sub = raw.strip()
    if not sub:
        continue
    if not rm_pat.search(" " + sub):
        continue
    # Find the rm token regardless of prefix (sudo / nice / time / nohup / xargs / env など
    # のコマンドラッパーや env var 代入が前置されていても引っかけるため、トークン列を走査する)
    tokens = sub.split()
    try:
        rm_idx = tokens.index("rm")
    except ValueError:
        continue
    # rm 以降のフラグ以外を引数として収集
    args = [t for t in tokens[rm_idx + 1:] if not t.startswith("-")]

    for a in args:
        # Strip surrounding quotes for matching
        u = a.strip("'\"")
        # Root path: exactly "/"
        if u == "/":
            if "ルートパス（/）" not in dangers:
                dangers.append("ルートパス（/）")
        # Home: ~, ~/, $HOME, $HOME/...
        if u == "~" or u == "$HOME" or u.startswith("~/") or u.startswith("$HOME/"):
            if "ホームディレクトリ（$HOME / ~）" not in dangers:
                dangers.append("ホームディレクトリ（$HOME / ~）")
        # .git directory (path is .git or ends with /.git, or starts with .git/)
        if u == ".git" or u.endswith("/.git") or u.startswith(".git/") or "/.git/" in u:
            if ".git ディレクトリ" not in dangers:
                dangers.append(".git ディレクトリ")
        # node_modules (anywhere in path token)
        if (u == "node_modules" or u.endswith("/node_modules") or
                u.startswith("node_modules/") or "/node_modules/" in u or
                "node_modules" == u.split("/")[-1]):
            if not allow_node_modules and "node_modules" not in dangers:
                dangers.append("node_modules")

print(tool)
print(cmd_oneline)
# Print dangers joined by tab; bash will split on tab
print("\t".join(dangers))
PY
)

tool_name=$(printf '%s\n' "$parsed" | sed -n '1p')
cmd=$(printf '%s\n' "$parsed" | sed -n '2p')
dangers_line=$(printf '%s\n' "$parsed" | sed -n '3p')

if [ "$tool_name" != "Bash" ]; then
  exit 0
fi

if [ -z "$dangers_line" ]; then
  exit 0
fi

# Convert tab-separated list into bullet lines
dangers_pretty=$(printf '%s' "$dangers_line" | tr '\t' '\n' | sed 's/^/  - /')

cat >&2 <<MSG
[BLOCKED] 危険な rm を検出しました:
$dangers_pretty

コマンド: $cmd

確認してください:
- 本当にそのパスを消して良いですか？
- 未コミット変更を先に保存していますか？
- 可能なら git clean -n などで dry-run してから実行してください

node_modules を意図的に消したい場合のみ: ALLOW_RM_NODE_MODULES=1 を設定して再実行。
MSG
exit 2
