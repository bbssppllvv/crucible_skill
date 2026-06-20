# Crucible

Independent review panels for Codex.

Crucible helps Codex run a small panel of focused reviewers before a risky plan, code change, architecture decision, or diagnosis. It can use local Codex subagents and, when available, a bundled Claude Code CLI bridge for a second model/harness perspective.

## Install

Global install:

```bash
git clone https://github.com/bbssppllvv/crucible_skill.git
mkdir -p ~/.codex/skills
cp -R crucible_skill/crucible ~/.codex/skills/crucible
```

Project install:

```bash
git clone https://github.com/bbssppllvv/crucible_skill.git /tmp/crucible_skill
mkdir -p .agents/skills
cp -R /tmp/crucible_skill/crucible .agents/skills/crucible
```

Restart Codex after installing the skill.

## Use In Codex

Ask Codex for a review panel:

```text
Use $crucible to review this plan before implementation.
```

Ask for a heterogeneous review with Claude Code included:

```text
Use $crucible. Include one external Claude Code reviewer if available.
```

Ask for an external Claude worker only when you want it to edit files:

```text
Use $crucible and launch Claude Code as a scoped external worker. It may edit only the files needed for this task.
```

## Claude Code Bridge

The Claude bridge is optional. It requires the local `claude` CLI to be installed and authenticated.

If several Claude CLI binaries are installed, the runner chooses a compatible one. Override it when needed:

```bash
export CLAUDE_BIN="$HOME/.local/bin/claude"
```

Artifact-only review, no repo tools:

```bash
CRUCIBLE_SKILL_DIR="$HOME/.codex/skills/crucible"
printf '%s\n' "$PLAN" \
  | bash "$CRUCIBLE_SKILL_DIR/scripts/claude-agent.sh" \
      --repo "$PWD" \
      --artifact-only \
      --stdin \
      --task "Review this plan for correctness, scope, and hidden risk."
```

Read-only repo review:

```bash
printf '%s\n' "$TASK" \
  | bash "$CRUCIBLE_SKILL_DIR/scripts/claude-agent.sh" \
      --repo "$PWD" \
      --allow-read-tools \
      --stdin \
      --task "Review the referenced files and return findings only."
```

Write-capable external worker:

```bash
printf '%s\n' "$TASK" \
  | bash "$CRUCIBLE_SKILL_DIR/scripts/claude-agent.sh" \
      --repo "$PWD" \
      --workspace-write \
      --stdin \
      --task "Implement this scoped task. Keep the diff narrow."
```

## Safety Defaults

- Artifact-only is the default posture.
- User-global MCP config is not inherited.
- `.env*`, credentials, key files, `.claude/**`, and `.codex/**` are excluded from collected diffs.
- Untracked files are not included in `--diff` unless explicitly requested.
- `--workspace-write` is explicit and should be used with a narrow task and non-overlapping write scope.
- Treat external reviewers as advisors. Verify findings before acting on them.

## Smoke Test

Run this from any target repository:

```bash
CRUCIBLE_SKILL_DIR="$HOME/.codex/skills/crucible"
bash "$CRUCIBLE_SKILL_DIR/scripts/claude-agent-smoke.sh" --repo "$PWD"
```

Skip the write-capable check:

```bash
bash "$CRUCIBLE_SKILL_DIR/scripts/claude-agent-smoke.sh" --repo "$PWD" --skip-write
```

## Package Layout

```text
crucible/
  SKILL.md
  agents/openai.yaml
  scripts/claude-agent.sh
  scripts/claude-agent-smoke.sh
```
