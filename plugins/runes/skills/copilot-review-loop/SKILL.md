---
name: copilot-review-loop
description: Use when the user asks to run, automate, or iterate on GitHub Copilot's PR review — including phrases like "run Copilot review", "handle Copilot feedback", "Copilot loop" — on a GitHub PR.
---

# Copilot Review Loop

**REQUIRED SUB-SKILL:** Use `receiving-code-review-auto` for the per-comment verify→fix→reply→resolve cycle (including reply format, commit-per-thread, escalation, final report). The delta below covers only Copilot-specific mechanics: trigger, wait, and termination. Each Copilot round is one full pass of the base auto cycle; the delta adds the surrounding loop.

## Trigger via reviewer, never via comment

```
gh pr edit <PR> --add-reviewer @copilot
```

**Prohibited** (silently litters the PR; does NOT trigger the bot):
- `gh pr comment <PR> --body "/review"`
- `gh pr comment <PR> --body "@copilot review"`

If you've already posted such a comment, delete it: `gh api -X DELETE repos/{owner}/{repo}/issues/comments/{ID}`. The reviewer surface is the only reliable trigger.

## Wait, then fetch

Capture the bot's review count *before* requesting; poll until it increments. Cap at ~20 minutes. On cap-elapsed, halt and report — the base auto skill's "unrecognized error" path.

```bash
COPILOT_BOT='select(.user.type == "Bot" and (.user.login | ascii_downcase | contains("copilot")))'

start=$(gh api repos/{owner}/{repo}/pulls/{PR}/reviews \
  --jq "[.[] | $COPILOT_BOT] | length")
gh pr edit {PR} --add-reviewer @copilot
for _ in $(seq 1 40); do
  cur=$(gh api repos/{owner}/{repo}/pulls/{PR}/reviews \
    --jq "[.[] | $COPILOT_BOT] | length")
  [ "${cur:-0}" -gt "${start:-0}" ] && break
  sleep 30
done

LATEST_ID=$(gh api repos/{owner}/{repo}/pulls/{PR}/reviews \
  --jq "[.[] | $COPILOT_BOT] | sort_by(.submitted_at) | last | .id")
gh api repos/{owner}/{repo}/pulls/{PR}/comments \
  --jq ".[] | select(.pull_request_review_id == $LATEST_ID) | {id, path, line, body}"
```

The matcher catches both REST (`Copilot`) and GraphQL (`copilot-pull-request-reviewer[bot]`).

If the review body contains "generated no new comments", terminate immediately. (GitHub may reword this; the zero-accepts fallback below still bounds the loop.)

## Iterate until terminated

After the base auto cycle finishes one round:

- **Any fix pushed this round** → re-request (`gh pr edit <PR> --add-reviewer @copilot`); the bot hasn't seen the new commits.
- **Zero fixes pushed this round** → terminate (after the base cycle has posted all push-back replies and resolved their threads).
- **Review body contained "generated no new comments"** → terminate.

Round-N's contract is not "respond to round-N's comments" — it is "iterate until Copilot has seen the final state and has nothing new to say". The new commits are themselves unreviewed diff; the pull toward "done" gets stronger each round. **Termination is observed Copilot state, not subjective completion.**

## Copilot's frequent false-positive categories

The base's verify-before-implement rule applies; Copilot specifically gets these wrong often:

| Category | Example | Verification |
|---|---|---|
| Compilation misjudgment | "This code won't compile" | Actually run the build/test |
| Phantom symbol | "Function X is missing" | `grep` / `Read` |
| Convention ignorance | "Use the standard fmt" | Compare against AGENTS.md / CLAUDE.md |
| Already-fixed | The fix landed in a prior round | `git log -p <file>` |
| Behavioral-bug claim | "Breaks under scenario X" | Apply `systematic-debugging` — Phase 1 root cause |

## Red Flags — STOP

- "I'll just drop a `/review` comment, it's faster" → that doesn't trigger the bot
- "I addressed every comment Copilot posted, we're done" → the new commits haven't been seen
- "It's the third round, surely nothing's left" → the *feeling* of completion is not the termination condition
- "I'll just `sleep 600` and check back" → poll the reviews API; the review may land in 1 minute or 15
