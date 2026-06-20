# Crucible

Role-based review panels for Codex.

Crucible lets Codex split a hard decision across independent subagents: different roles, different goals, same artifact.

It also includes **Claude Bridge**: Codex can launch Claude Code as an external subagent from inside the same workflow. A panel can mix Codex subagents and Claude Code reviewers, so you get different perspectives, models, and harnesses in one review.

Use it for plan reviews, PR reviews, architecture critique, security/privacy checks, regression hunting, and any decision where one linear pass is not enough.

## Install

```bash
git clone https://github.com/bbssppllvv/crucible_skill.git
mkdir -p ~/.codex/skills
cp -R crucible_skill/crucible ~/.codex/skills/crucible
```

Restart Codex.

## Use

```text
Use $crucible to review this plan before implementation.
```

```text
Use $crucible. Include one external Claude Code reviewer if available.
```

```text
Use $crucible and launch Claude Code as a scoped external worker. It may edit only the files needed for this task.
```

## Claude Bridge

Requires an installed and authenticated `claude` CLI.

```bash
CRUCIBLE_SKILL_DIR="$HOME/.codex/skills/crucible"
```

Artifact-only reviewer:

```bash
printf '%s\n' "$PLAN" \
  | bash "$CRUCIBLE_SKILL_DIR/scripts/claude-agent.sh" \
      --repo "$PWD" --artifact-only --stdin \
      --task "Review this plan."
```

Read-only repo reviewer:

```bash
printf '%s\n' "$TASK" \
  | bash "$CRUCIBLE_SKILL_DIR/scripts/claude-agent.sh" \
      --repo "$PWD" --allow-read-tools --stdin \
      --task "Review the referenced files."
```

Write-capable Claude Code worker:

```bash
printf '%s\n' "$TASK" \
  | bash "$CRUCIBLE_SKILL_DIR/scripts/claude-agent.sh" \
      --repo "$PWD" --workspace-write --stdin \
      --task "Implement this scoped task. Keep the diff narrow."
```

If multiple Claude binaries are installed:

```bash
export CLAUDE_BIN="$HOME/.local/bin/claude"
```

## Safety

- Default mode is artifact-only.
- User-global MCP config is not inherited.
- `.env*`, credentials, `.claude/**`, and `.codex/**` are excluded from collected diffs.
- Untracked files are excluded unless explicitly requested.
- `--workspace-write` is explicit. Review its diff before integrating.

## Smoke Test

```bash
bash "$CRUCIBLE_SKILL_DIR/scripts/claude-agent-smoke.sh" --repo "$PWD"
```

Skip write testing:

```bash
bash "$CRUCIBLE_SKILL_DIR/scripts/claude-agent-smoke.sh" --repo "$PWD" --skip-write
```
