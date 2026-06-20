---
name: crucible
description: >-
  Run an independent multi-perspective review by spawning a small panel of
  local or external subagents, each with a sharp role, then synthesizing their
  findings into evidence-based decisions. Includes a portable bundled Claude
  Code CLI bridge for optional heterogeneous reviewers or explicitly scoped
  external workers when available. Invoke
  autonomously only when independent judgment is likely to materially change a
  decision before action: meaningful risk, real uncertainty, competing
  approaches, a stuck diagnosis, a plan that should be stress-tested, or an
  explicit request for fresh eyes, multiple reviewers, a devil's advocate, red
  team, jury, outside opinion, or second opinion. Do not invoke for routine
  low-risk edits, direct factual answers or commands, mechanical docs/tests,
  tasks without a reviewable artifact, or when already acting as a Crucible
  reviewer/subagent.
---

# Crucible

A crucible is a deliberately sharp review panel. Use it to expose blind spots before shipping code, committing to a plan, or making a high-impact recommendation.

Core rule: subagents are advisors, not authorities. Verify every claim against source artifacts before presenting it or acting on it.

Recursion guard: when acting as a Crucible reviewer or subagent, do not invoke Crucible or spawn additional reviewers. Run at most one Crucible panel per top-level task unless the user explicitly asks for nested review.

## Operating Model

- The main agent is the planner, integrator, and decision-maker.
- Reviewers are sidecars. They do not coordinate with each other, negotiate scope, or create new requirements.
- Reviewers may come from different harnesses when available, such as local Codex subagents and an external Claude Code CLI reviewer launched through this skill's bundled runner. Use heterogeneity to reduce correlated blind spots, not to add spectacle.
- Keep the critical path local. Do not delegate the decision itself, integration, or work whose result is needed before the next immediate local step.
- Spawn only concrete, bounded review tasks that can run independently and materially improve the outcome.
- Stop spawning once the remaining work is sequential, small, or integration-heavy. Finish locally.

## Reviewer Backends

Default to local Codex subagents when the normal subagent tools are available. Add at most one external Claude Code reviewer when a different model family or harness perspective is likely to improve the review: security/privacy scrutiny, architecture critique, plan stress testing, prompt/tool harness review, or a user request for another model's opinion.

Use the bundled Claude bridge at `scripts/claude-agent.sh`, resolved relative to this `SKILL.md`. Always pass the target workspace with `--repo "$PWD"` unless a different repository root is intentional. The skill folder is portable: copying or installing the `crucible/` directory with `SKILL.md`, `agents/openai.yaml`, and `scripts/` is enough for another repository to use the bridge, assuming the local machine has an authenticated Claude Code CLI.

For review panels, prefer artifact-only mode:

```bash
CRUCIBLE_SKILL_DIR="/path/to/crucible" # directory containing this SKILL.md
printf '%s\n' "$ARTIFACT" \
  | bash "$CRUCIBLE_SKILL_DIR/scripts/claude-agent.sh" --repo "$PWD" \
      --artifact-only --stdin \
      --task "$REVIEWER_PROMPT" --model opus --budget 6.00
```

Use `--allow-read-tools` only when the artifact intentionally references repository files that Claude must inspect, the worktree is trusted, and the user benefit justifies exposing repo read access:

```bash
CRUCIBLE_SKILL_DIR="/path/to/crucible"
printf '%s\n' "$ARTIFACT" \
  | bash "$CRUCIBLE_SKILL_DIR/scripts/claude-agent.sh" --repo "$PWD" \
      --allow-read-tools --stdin \
      --task "$REVIEWER_PROMPT" --model opus --budget 6.00
```

Use `--workspace-write` only when the user explicitly wants an external Claude worker that can modify files. Give it a narrow task and a disjoint write scope:

```bash
CRUCIBLE_SKILL_DIR="/path/to/crucible"
printf '%s\n' "$TASK" \
  | bash "$CRUCIBLE_SKILL_DIR/scripts/claude-agent.sh" --repo "$PWD" \
      --workspace-write --stdin \
      --task "$WORKER_PROMPT" --model opus --budget 10.00
```

Rules for external reviewers:

- Treat the external reviewer as another sidecar, not a higher authority.
- Send the same minimized artifact package given to local reviewers whenever possible.
- Do not send secrets, credentials, `.env*` content, unrelated private files, or unaudited untracked work.
- Prefer `--artifact-only`; never use `--include-untracked-list` or `--include-untracked-content` unless the worktree was audited and the extra context is necessary.
- If Claude Code is unavailable, unauthenticated, over budget, or times out, label that reviewer as failed/omitted and continue with available reviewers.
- Do not let an external reviewer edit files. If edits are desired, label it as an external worker, give it a scoped write set, and review its diff before integrating.
- To validate a fresh install, run `bash "$CRUCIBLE_SKILL_DIR/scripts/claude-agent-smoke.sh" --repo "$PWD"` from the target repository root. Use `--skip-write` when live write-capable testing is not appropriate.

## Invocation Model

Use this skill based on expected value, not task labels. The question is:

> Would a few independent, role-focused reviewers likely find a real issue, missing assumption, better framing, or sharper tradeoff before I act?

If yes, use Crucible without waiting for the user to ask. Invoke it after enough inspection to provide reviewers with concrete artifacts, and before the main agent finalizes a plan, applies risky edits, presents a review, or makes a recommendation.

Strong signals:

- Consequence: a wrong answer could cause a regression, bad architecture, user harm, security/privacy risk, wasted work, data loss, or a misleading recommendation.
- Uncertainty: there are multiple plausible solutions, incomplete context, hidden assumptions, or weak confidence.
- Perspective gap: the work spans concerns one linear pass may underweight, such as correctness, simplicity, tests, product value, platform conventions, or operations.
- Commitment point: the main agent has drafted a risky or uncertain plan, review, diagnosis, or implementation and is about to act on it.
- Stuckness: debugging or planning has started to orbit one hypothesis.
- User intent: the user asks for outside opinions, fresh eyes, multiple agents, review, validation, critique, red-team thinking, or a devil's advocate.

Do not treat this as a rigid checklist. One strong signal can be enough when it implies material expected value; several weak signals can also be enough. Skip when the likely benefit is low: the task is local and obvious, the answer is a deterministic command/fact lookup, the edit is mechanical docs or low-risk test cleanup, there is no meaningful artifact to review, the added latency would dominate the work, or the review would require sharing irrelevant private context.

## Panel Size

- 1 reviewer: quick sanity check.
- 2 reviewers: focused disagreement; choose opposing roles.
- 3 reviewers: default for PR review, plan review, and architecture critique.
- 4-5 reviewers: broad review for high-risk or cross-cutting work.
- 6+ reviewers: avoid unless the user explicitly asks for a large panel.

Pick the smallest panel that covers the real risk. Role diversity matters more than headcount.

## Role Catalog

Choose roles that create useful tension. Stances are attention anchors, not fictional characters: use them to sharpen what a reviewer notices, never to encourage roleplay, jokes, lore, banter, or a different output format.

| Role | Stance | Use When |
| --- | --- | --- |
| Devil's Advocate | The Breaker | A plan needs to be broken before implementation. |
| Pragmatist | The Knife | The solution may be overbuilt, slow, too clever, or larger than the stated goal. |
| Correctness Hunter | The Invariant Keeper | Code may have edge-case bugs, broken invariants, or bad assumptions. |
| Regression Hunter | The Historian | Existing behavior must not be disturbed. |
| Security/Privacy Reviewer | The Lockpick | Secrets, permissions, automation, user data, or network calls are involved. |
| Test/QA Reviewer | The Prover | Coverage, manual QA, flaky assumptions, or release confidence matter. |
| Maintainability Reviewer | The Steward | Ownership, boundaries, naming, readability, or future changes are in play. |
| Performance/Reliability Reviewer | The Stress Tester | Latency, memory, concurrency, retries, rate limits, or failure modes matter. |
| Platform Reviewer | The Native | Native platform conventions, lifecycle, entitlements, or APIs matter. |
| Product/User Advocate | The Human | The work may miss the user's actual job, trust, or workflow. |
| UX/Accessibility Reviewer | The Door Opener | Screens, flows, interaction states, copy, or accessibility are affected. |
| Evidence Auditor | The Clerk | Findings may drift into vibes, consensus, unsupported claims, or invented context. |
| Scope Sentinel | The Gatekeeper | Reviewers may turn a bounded task into a wishlist, redesign, or speculative roadmap. |
| Domain Specialist | The Specialist | A specific domain is central, such as Swift/macOS, payments, AI agents, SEO, legal, or data systems. Name the domain in the prompt. |

Custom one-off reviewers:

- Create a custom reviewer when the catalog misses a material perspective for the artifact in front of you.
- Ask: "What failure mode or tradeoff would this reviewer uniquely catch?" If the answer is vague, use a catalog role instead.
- Define the custom reviewer before spawning: `Role`, optional `Stance`, one-sentence mandate, and explicit non-goals.
- Count custom reviewers toward the panel size limit. Prefer at most one custom reviewer; use two only when the artifact has two genuinely distinct uncataloged risks.
- Do not create custom reviewers for flavor, entertainment, duplicate coverage, or speculative future concerns.
- Keep custom roles behavior-first. A good custom role sounds like `Migration Skeptic`, `Billing Edge-Case Reviewer`, or `First-Run User`, not a fictional character biography.

Default panels:

- PR review: Correctness Hunter, Regression Hunter, Test/QA Reviewer.
- Risky PR: Correctness Hunter, Security/Privacy Reviewer, Regression Hunter, Pragmatist.
- Plan review: Devil's Advocate, Pragmatist, Scope Sentinel.
- Architecture review: Maintainability Reviewer, Performance/Reliability Reviewer, Pragmatist.
- Product/UX review: Product/User Advocate, UX/Accessibility Reviewer, Pragmatist.
- High-uncertainty diagnosis: Devil's Advocate, Evidence Auditor, Domain Specialist when a real domain is central.
- Scope-sensitive task: Pragmatist, Scope Sentinel, Product/User Advocate.

Use `Domain Specialist` only when the required specialty is explicit and material. Do not use it as a generic smart reviewer.

## Workflow

1. Inspect just enough context to understand the artifact and the stakes.
2. Decide whether independent perspectives are likely to change the answer, plan, review, or implementation.
3. Define the artifact under review: diff, files, plan, logs, screenshot, design, diagnosis, or proposal.
4. Minimize context before delegation: prefer diffs, excerpts, file paths, screenshots, or logs with secrets and irrelevant private content removed. State what reviewers may inspect and what was withheld.
5. Select 1-5 catalog or custom roles based on the risks and unknowns that matter most. For each custom role, write its mandate and non-goals before spawning.
6. Choose reviewer backends. Use local Codex subagents for ordinary review. Add one external Claude Code reviewer when model/harness diversity is likely to catch a different class of issue and the artifact is safe to share. Use `--workspace-write` only for an explicit external-worker task, not for an ordinary reviewer role.
7. Spawn independent subagents. If subagent tools are not already available, make one bounded search for multi-agent tools. If using Claude Code, run this skill's `scripts/claude-agent.sh` as an external reviewer or explicitly scoped worker and capture its output as a handoff.
8. If true subagents or the external reviewer are unavailable, do not claim they ran. Either proceed with a clearly labeled partial panel or report the blocker if the user explicitly required that backend.
9. Give each reviewer the same minimized artifact package and one role-specific mandate. Do not give reviewers each other's outputs.
10. Require structured findings with evidence, confidence, and scope boundaries.
11. Synthesize after reviewers return. If some agents fail or time out, synthesize only available outputs and label the result partial. Never invent missing reviewer responses.
12. Act on the synthesis: revise the plan, implement changes, or present final review findings.

## Subagent Prompt

Use this shape and fill only the task-specific blanks:

```text
You are the [ROLE] ([STANCE, optional]) in a crucible review.

Task: [what is being reviewed and why]
Artifact: [diff/files/plan/logs/screenshot/etc.]
Allowed inspection scope: [whether the reviewer may inspect files beyond the artifact]
Role mandate: [for custom roles, state the exact perspective and non-goals; otherwise omit]

Review only from your assigned perspective. Be sharp but evidence-based.
Use the stance only as an attention lens. Do not roleplay, add personality flourishes, jokes, lore, or theatrical framing.
Do not invoke Crucible, spawn subagents, or perform a second-level panel review.
Do not expand the project scope. Do not propose optional enhancements, rewrites, redesigns, speculative future work, or nice-to-haves unless they materially affect the stated goal.

Return:
- Findings: severity, evidence, confidence, and recommended action.
- Questions or missing context that would change your conclusion.
- Scope you intentionally did not review.

Use severity Critical/High/Medium/Low. Evidence must be a file:line reference, exact artifact excerpt, command output, screenshot region, or "not evidenced." Confidence must be High/Medium/Low.
Make the handoff usable without reading your full transcript.

Prefer fewer high-signal findings over broad commentary. Skip nits unless they change correctness, user trust, maintainability, verification confidence, or delivery risk. Do not assume facts not present in the artifact.
```

## Synthesis Rules

- Treat repeated findings as stronger only after verifying the underlying evidence.
- Keep good disagreement visible; do not average it away.
- Reject findings that are vague, unsupported, out of scope, or based on invented context.
- Track each material finding as accepted, rejected, or unresolved, with a short reason.
- Accept feedback only when it is inside the original goal and materially improves correctness, risk, user value, maintainability, or verification confidence.
- Convert accepted feedback into concrete actions: code changes, plan edits, tests, QA notes, or explicit non-actions.
- Park useful but nonessential ideas as follow-up notes; do not silently expand the current task to include them.
- Do not run another panel just to arbitrate minor disagreements. The main agent decides.
- Treat Scope Sentinel feedback as a constraint on the current task, not permission to add new process or requirements.
- For code review, lead with actionable findings ordered by severity and include file/line references when available.
- For plan review, return the revised plan plus the specific risks or assumptions that changed.
- If the panel finds no material issue, say so and name the residual risk or test gap.

## Pitfalls

- Do not use a big panel to compensate for unclear goals. Clarify the goal or inspect the artifact first.
- Do not let subagents vote on truth. Evidence beats consensus.
- Do not spawn multiple agents with the same role unless the artifact is large enough to shard by area.
- Do not leak secrets, credentials, private user content, or unrelated repository context into subagent prompts.
- Do not let stance labels become theater. They should change attention, not voice.
- Do not let reviewer imagination turn into scope creep. Roles are lenses, not product requirements.
- Do not let the review become theater. A useful crucible produces decisions, not just opinions.
