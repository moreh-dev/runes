---
name: copilot-review-loop
description: Use when the user asks to run, automate, or iterate on GitHub Copilot's PR review — including phrases like "run Copilot review", "handle Copilot feedback", "Copilot loop" — on a GitHub PR.
---

# Copilot Review Loop

**REQUIRED SUB-SKILL:** Use `receiving-code-review-auto` for the per-comment verify→fix→reply→resolve cycle, including precheck, commit-per-thread, escalation rules, and final report. The delta below covers only Copilot-specific mechanics: how to *trigger* the bot, how to *wait* for its review, how to *fetch* its comments, how to *format* replies, and when to *stop iterating*. Each Copilot round is one full pass of the base auto cycle; the delta adds the surrounding loop.

## The Delta

### Trigger via reviewer, never via comment

```
gh pr edit <PR> --add-reviewer @copilot
```

**Prohibited** (silently litters the PR; does NOT trigger the bot):
- `gh pr comment <PR> --body "/review"`
- `gh pr comment <PR> --body "@copilot review"`

If you've already posted such a comment, delete it: `gh api -X DELETE repos/{owner}/{repo}/issues/comments/{ID}`.

`/review` is a Copilot Chat slash command, not a PR-review trigger. `@copilot review` as a comment body occasionally appears to work on personal repos because the bot opportunistically replies to mentions, but it is not reliable on org repos. The only reliable trigger is the **reviewer surface** — same channel humans are requested through.

### Wait for the new review with polling, not blind sleep

Capture the bot's current review count, *then* request the review, *then* poll until the count increments. Use a bounded polling loop (in Claude Code: run via the `Monitor` tool; in any harness: a backgrounded shell `for`/`until` loop with an iteration cap) so the next round resumes as soon as the new review lands:

```bash
COPILOT_BOT='select(.user.type == "Bot" and (.user.login | ascii_downcase | contains("copilot")))'

start=$(gh api repos/{owner}/{repo}/pulls/{PR}/reviews \
  --jq "[.[] | $COPILOT_BOT] | length")
gh pr edit {PR} --add-reviewer @copilot
for _ in $(seq 1 40); do  # cap ~20 minutes at sleep 30
  cur=$(gh api repos/{owner}/{repo}/pulls/{PR}/reviews \
    --jq "[.[] | $COPILOT_BOT] | length")
  [ "${cur:-0}" -gt "${start:-0}" ] && break
  sleep 30
done
```

The `COPILOT_BOT` jq predicate is defined once and reused by the fetch block below — keep both blocks in the same shell context, or inline the predicate.

The login matcher mirrors the base `receiving-code-review` rule: REST sometimes returns `Copilot`, GraphQL returns `copilot-pull-request-reviewer[bot]`, and the `type == "Bot"` + login-contains-`copilot` predicate covers both without committing to either spelling.

If the cap elapses without the count incrementing, halt the loop and report to the user (bot did not respond; suggest a manual `gh pr edit --add-reviewer @copilot` retry or skipping the round) — this is the base auto skill's "unrecognized error" path.

### Fetch the new review's body and inline comments

```bash
LATEST_ID=$(gh api repos/{owner}/{repo}/pulls/{PR}/reviews \
  --jq "[.[] | $COPILOT_BOT] | sort_by(.submitted_at) | last | .id")
gh api repos/{owner}/{repo}/pulls/{PR}/comments \
  --jq ".[] | select(.pull_request_review_id == $LATEST_ID) | {id, path, line, body}"
```

Read the new **review body first**. If it contains the string **"generated no new comments"**, terminate the loop immediately — there is nothing to act on. The exact wording is GitHub's current Copilot convention; if it ever changes, the secondary termination condition below ("zero fixes pushed this round") still bounds the loop, so the failure mode is a wasted re-request, not a runaway.

### Reply format — SHA only when there is a SHA

The 40-character commit SHA on its own line auto-links to the commit on GitHub. The format is **load-bearing**: the reader clicks the SHA to see *the fix*.

**Accept (a commit exists):**
```
<40-char commit SHA>
<one to three sentence summary of the change>
```

**Push back (no commit exists):**
```
Not applied: <technical reason with concrete evidence>
```

Reuse the same SHA across multiple accept replies when one *natural* edit resolves several threads (e.g., two comments on adjacent lines fixed by the same change). Do not batch unrelated fixes into one commit just to deduplicate the SHA line — the base auto skill's "one commit per applied thread" rule still governs, and this is the narrow exception where the threads converge on a single change by their own logic.

**Do not pad a push-back with a "neat" SHA from a recent commit.** The reader follows the link expecting *the fix* and lands on an unrelated commit — that is a misleading signal dressed as a tidy one. The structural difference (SHA vs no SHA) correctly signals the semantic difference (commit vs no commit). Form follows substance.

### Iterate — termination is observed, not felt

Each round, after the base auto cycle finishes (replies posted, threads resolved, push completed):

- **Any fix pushed this round** → re-request review (`gh pr edit <PR> --add-reviewer @copilot`) and return to "Wait for the new review". The bot has not yet seen the new commits.
- **Zero fixes pushed this round** (every comment pushed back) → terminate, *after* all push-back replies are posted and threads resolved per the base auto cycle. Re-requesting would not produce new comments on unchanged code.
- **Review body says "generated no new comments"** → terminate immediately.

Round-N's contract is not "respond to round-N's comments" — it is "iterate until Copilot has seen the final state and has nothing new to say". The commits you just pushed are themselves unreviewed diff; self-review of code you wrote 20 minutes ago is famously poor, which is the entire reason a second reviewer was requested. The pull toward "done" gets stronger each round. The termination condition is **observed Copilot state**, not your subjective sense of completion.

## Copilot's frequent false-positive categories

The base skill's verify-before-implement rule applies; Copilot specifically gets these wrong often, so check them first:

| Category | Example claim | Verification |
|---|---|---|
| Compilation misjudgment | "This code won't compile" | Actually run the build/test (`cargo build`, `cargo test`, `tsc --noEmit`, equivalent) |
| Phantom symbol | "Function X is missing" | `grep` / `Read` the file(s) |
| Convention ignorance | "Use the standard fmt" | Compare against project convention in AGENTS.md / CLAUDE.md |
| Already-fixed | The fix landed in a prior round | `git log -p <file>` |
| Behavioral-bug claim | "Breaks under scenario X" | Apply `systematic-debugging` — start at Phase 1 (root cause), not at acceptance |

## Red Flags — STOP

These thoughts mean you're about to violate a delta. Reset.

- "I'll just drop a `/review` comment, it's faster" → that does not trigger the bot
- "All prior replies have a SHA, I'll add one to this push-back for consistency" → that misleads the reader
- "I addressed every comment Copilot posted, we're done" → the new commits haven't been seen
- "It's the third round, surely there's nothing left" → the *feeling* of completion is not the termination condition
- "I'll just `sleep 600` and check back" → poll the reviews API; the review may land in 1 minute or 15

## Common Mistakes

| Mistake | Result | Avoidance |
|---|---|---|
| Triggering via `/review` or `@copilot review` PR comment | Bot doesn't run; PR collects noise comments | Use `gh pr edit --add-reviewer @copilot` |
| Including a SHA in a push-back reply | Reviewer clicks a misleading link | Omit the SHA on push-backs; the structural difference is the point |
| Stopping after one round because "all comments addressed" | New commits ship unreviewed | Re-request until Copilot reports no new comments, or zero accepts this round |
| Blind `sleep N` while waiting | Either wastes time or returns before the review lands | Poll the reviews API in a bounded `until`/`for` loop |
| Re-running `--add-reviewer` mid-round before replying/resolving | Two reviews stack; thread state gets confusing | Finish the round (commit, reply, resolve, push) before re-requesting |
