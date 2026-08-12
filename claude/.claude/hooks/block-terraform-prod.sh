#!/usr/bin/env bash
# PreToolUse hook: terraform apply/destroy の prod 環境への実行をブロックする。
# plan は安全なので許可する。-auto-approve 付きの apply も無条件でブロック。
# 明示的に逃げたい場合は環境変数 ALLOW_TERRAFORM_PROD=1 を設定する。
set -euo pipefail

input=$(cat)

parsed=$(CLAUDE_HOOK_INPUT="$input" ALLOW_TERRAFORM_PROD="${ALLOW_TERRAFORM_PROD:-0}" python3 <<'PY'
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

if os.environ.get("ALLOW_TERRAFORM_PROD", "0") == "1":
    print(tool)
    print(cmd_oneline)
    print("0")
    sys.exit(0)

parts = re.split(r'(?:&&|\|\||;|\||&|`|\(|\))', cmd_oneline)

blocked = False
for raw in parts:
    sub = raw.strip()
    if not sub:
        continue
    tokens = sub.split()
    if "terraform" not in tokens:
        continue
    try:
        tf_idx = tokens.index("terraform")
    except ValueError:
        continue
    args = tokens[tf_idx + 1:]
    if not args:
        continue
    subcmd = args[0]
    # plan は安全なので許可
    if subcmd not in ("apply", "destroy"):
        continue
    rest = " ".join(args[1:])
    # -auto-approve は無条件ブロック
    if "-auto-approve" in rest:
        blocked = True
        break
    # prod を含む var-file をブロック
    if re.search(r'-var-file\s*=?\s*\S*prod\S*', rest):
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

cat >&2 <<'MSG'
[BLOCKED] terraform apply/destroy の prod 環境への実行は禁止されています。

prod 環境への terraform 操作はローカルターミナルから手動で実行してください。
どうしても必要な場合は、環境変数 ALLOW_TERRAFORM_PROD=1 を設定して再実行してください。
MSG
exit 2
