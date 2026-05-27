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

Right after `gh pr edit ... --add-reviewer @copilot`, poll the reviews API until the bot's review count increments. Run the loop via the `Monitor` tool so the next round resumes as soon as the new review lands:

```bash
start=$(gh api repos/{owner}/{repo}/pulls/{PR}/reviews \
  --jq '[.[] | select(.user.login == "copilot-pull-request-reviewer[bot]")] | length')
until cur=$(gh api repos/{owner}/{repo}/pulls/{PR}/reviews \
  --jq '[.[] | select(.user.login == "copilot-pull-request-reviewer[bot]")] | length'); \
  [ "$cur" -gt "$start" ]; do sleep 30; done
```

Typical latency 1–5 minutes; cap at ~15–20. If no review appears within the cap, escalate per the base auto skill.

### Fetch the new review's body and inline comments

```bash
LATEST_ID=$(gh api repos/{owner}/{repo}/pulls/{PR}/reviews \
  --jq '[.[] | select(.user.login == "copilot-pull-request-reviewer[bot]")] | sort_by(.submitted_at) | last | .id')
gh api repos/{owner}/{repo}/pulls/{PR}/comments \
  --jq ".[] | select(.pull_request_review_id == $LATEST_ID) | {id, path, line, body}"
```

Read the new **review body first**. If it contains the string **"generated no new comments"**, terminate the loop immediately — there is nothing to act on.

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

Reuse the same SHA across multiple accept replies when one commit resolves several threads.

**Do not pad a push-back with a "neat" SHA from a recent commit.** The reader follows the link expecting *the fix* and lands on an unrelated commit — that is a misleading signal dressed as a tidy one. The structural difference (SHA vs no SHA) correctly signals the semantic difference (commit vs no commit). Form follows substance.

### Iterate — termination is observed, not felt

Each round, after the base auto cycle finishes (replies posted, threads resolved, push completed):

- **Any fix pushed this round** → re-request review (`gh pr edit <PR> --add-reviewer @copilot`) and return to "Wait for the new review". The bot has not yet seen the new commits.
- **Zero fixes pushed this round** (every comment pushed back) → terminate. Re-requesting would not produce new comments on unchanged code.
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
| Behavioral-bug claim | "Breaks under scenario X" | Load `systematic-debugging` — start at Phase 1 (root cause), not at acceptance |

## Resolving Copilot threads

The base `receiving-code-review` resolution policy applies: Copilot is an agent author (`copilot-pull-request-reviewer[bot]`), so threads are resolved after reply via the GraphQL `resolveReviewThread` mutation — whether the comment was accepted or pushed back. Resolving a push-back signals "already discussed".

## Red Flags — STOP

These thoughts mean you're about to violate a delta. Reset.

- "I'll just drop a `/review` comment, it's faster" → that does not trigger the bot
- "All prior replies have a SHA, I'll add one to this push-back for consistency" → that misleads the reader
- "I addressed every comment Copilot posted, we're done" → the new commits haven't been seen
- "It's the third round, surely there's nothing left" → the *feeling* of completion is not the termination condition
- "I'll just `sleep 600` and check back" → poll with `Monitor` + `until`; the review may land in 1 minute or 15

## Common Mistakes

| Mistake | Result | Avoidance |
|---|---|---|
| Triggering via `/review` or `@copilot review` PR comment | Bot doesn't run; PR collects noise comments | Use `gh pr edit --add-reviewer @copilot` |
| Including a SHA in a push-back reply | Reviewer clicks a misleading link | Omit the SHA on push-backs; the structural difference is the point |
| Stopping after one round because "all comments addressed" | New commits ship unreviewed | Re-request until Copilot reports no new comments, or zero accepts this round |
| Blind `sleep N` while waiting | Either wastes time or returns before the review lands | Poll the reviews API with `Monitor` + `until` |
| Re-running `--add-reviewer` mid-round before replying/resolving | Two reviews stack; thread state gets confusing | Finish the round (commit, reply, resolve, push) before re-requesting |
