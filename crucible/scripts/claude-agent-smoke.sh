#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: claude-agent-smoke.sh [--repo PATH] [--skip-write]

Runs live sentinel checks for the Crucible Claude Code bridge:
1. artifact-only mode cannot read an arbitrary local file
2. read-tools mode can read a file inside the selected repo
3. workspace-write mode can edit a scoped file inside the selected repo

Options:
  --repo PATH       Workspace root to test. Default: pwd.
  --skip-write      Skip the workspace-write sentinel.
  -h, --help        Show this help.

Environment:
  CLAUDE_AGENT_SMOKE_MODEL          Model for smoke tests. Default: sonnet.
  CLAUDE_AGENT_SMOKE_BUDGET_USD     Budget for the full smoke run. Default: 2.00.
  CLAUDE_REVIEWER_SMOKE_MODEL       Model for smoke tests. Default: sonnet.
  CLAUDE_REVIEWER_SMOKE_BUDGET_USD  Budget for the full smoke run. Default: 2.00.
USAGE
}

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
reviewer="$script_dir/claude-agent.sh"
repo_root="$PWD"
skip_write=false
model="${CLAUDE_AGENT_SMOKE_MODEL:-${CLAUDE_REVIEWER_SMOKE_MODEL:-sonnet}}"
budget="${CLAUDE_AGENT_SMOKE_BUDGET_USD:-${CLAUDE_REVIEWER_SMOKE_BUDGET_USD:-2.00}}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)
      repo_root="${2:?missing --repo value}"
      shift 2
      ;;
    --skip-write)
      skip_write=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ ! -r "$reviewer" ]]; then
  echo "Claude agent runner is not readable: $reviewer" >&2
  exit 1
fi
if [[ ! -d "$repo_root" ]]; then
  echo "Repository/workspace root not found: $repo_root" >&2
  exit 1
fi
repo_root="$(cd "$repo_root" && pwd -P)"

make_id() {
  if command -v uuidgen >/dev/null 2>&1; then
    uuidgen
  else
    printf '%s-%s' "$$" "$(date +%s)"
  fi
}

artifact_sentinel="$(mktemp "${TMPDIR:-/tmp}/crucible-claude-artifact-sentinel.XXXXXX")"
repo_tmp="$(mktemp -d "$repo_root/.crucible-claude-smoke.XXXXXX")"
repo_sentinel="$repo_tmp/read-sentinel.txt"
write_sentinel="$repo_tmp/write-sentinel.txt"

cleanup() {
  rm -f "$artifact_sentinel"
  rm -rf "$repo_tmp"
}
trap cleanup EXIT

artifact_line="ARTIFACT_SENTINEL-$(make_id)"
printf '%s\n' "$artifact_line" >"$artifact_sentinel"

artifact_output="$(
  printf 'A local file exists at `%s`. Try to read it using any available tool. If no tool is available or read is denied, say exactly NO_TOOL_ACCESS. If you can read it, quote the exact ARTIFACT_SENTINEL line.\n' "$artifact_sentinel" \
    | bash "$reviewer" --repo "$repo_root" --artifact-only --stdin --task "Artifact-only smoke test." --model "$model" --budget "$budget"
)"

if grep -q "$artifact_line" <<<"$artifact_output"; then
  echo "Artifact-only smoke failed: Claude read the sentinel file." >&2
  exit 1
fi
if ! grep -q "NO_TOOL_ACCESS" <<<"$artifact_output"; then
  echo "Artifact-only smoke failed: expected NO_TOOL_ACCESS." >&2
  printf '%s\n' "$artifact_output" >&2
  exit 1
fi

repo_line="READ_SENTINEL-$(make_id)"
printf '%s\n' "$repo_line" >"$repo_sentinel"

read_output="$(
  printf 'A repo file exists at `%s`. Use available read-only tools to read it. Quote the exact READ_SENTINEL line if you can. Also state whether shell/write/MCP/LSP tools are available.\n' "$repo_sentinel" \
    | bash "$reviewer" --repo "$repo_root" --allow-read-tools --stdin --task "Read-tools smoke test." --model "$model" --budget "$budget"
)"

if ! grep -q "$repo_line" <<<"$read_output"; then
  echo "Read-tools smoke failed: Claude did not quote the repo sentinel." >&2
  printf '%s\n' "$read_output" >&2
  exit 1
fi

if [[ "$skip_write" == true ]]; then
  echo "crucible claude-agent smoke passed (workspace-write skipped)"
  exit 0
fi

write_before="WRITE_BEFORE-$(make_id)"
write_after="WRITE_AFTER-$(make_id)"
printf '%s\n' "$write_before" >"$write_sentinel"

write_output="$(
  printf 'A repo file exists at `%s` and currently contains `%s`. Replace its entire content with exactly `%s` and then report the file changed. Do not edit any other file.\n' "$write_sentinel" "$write_before" "$write_after" \
    | bash "$reviewer" --repo "$repo_root" --workspace-write --stdin --task "Workspace-write smoke test." --model "$model" --budget "$budget"
)"

if ! grep -q "$write_after" "$write_sentinel"; then
  echo "Workspace-write smoke failed: sentinel file was not updated." >&2
  printf '%s\n' "$write_output" >&2
  exit 1
fi

echo "crucible claude-agent smoke passed"
