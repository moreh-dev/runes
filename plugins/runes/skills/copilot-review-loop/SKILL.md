---
name: copilot-review-loop
description: Use when the user asks to run, automate, or iterate on GitHub Copilot's PR review — including phrases like "run Copilot review", "handle Copilot feedback", "Copilot loop" — on a GitHub PR.
---

# Copilot Review Loop

**REQUIRED SUB-SKILL:** Use `receiving-code-review-auto` for the per-comment verify→fix→reply→resolve cycle, including all per-comment evaluation rules inherited from `receiving-code-review`. The delta below covers only Copilot-specific mechanics: trigger, wait, reply format, and termination. Each Copilot round is one full pass of the base auto cycle; the delta adds the surrounding loop.

## Trigger via reviewer, never via comment

```
gh pr edit <PR> --add-reviewer @copilot
```

**Prohibited** (silently litters the PR; does NOT trigger the bot):
- `gh pr comment <PR> --body "/review"`
- `gh pr comment <PR> --body "@copilot review"`

If such a comment was already posted by mistake, leave it in place and surface it to the user for manual cleanup — do not auto-delete via the API. The delete call is irreversible and trivially misfires on the wrong comment ID (the endpoint deletes any issue/PR comment by numeric ID, with no scope guard for "stray Copilot triggers"). The reviewer surface is the only reliable trigger.

## Wait, then fetch

Capture the bot's review count *before* requesting; poll until it increments. Hard cap at 20 minutes (40 × 30s). On cap-elapsed, halt and report — the base auto skill's "unrecognized error" path.

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

## Reply format — SHA only when there is a SHA

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

Reuse the same SHA across accept replies only when one commit literally contains the fix for each of those threads (e.g., two comments on adjacent lines resolved by the same edit).

**Do not pad a push-back with a "neat" SHA from a recent commit.** The reader follows the link expecting *the fix* and lands on an unrelated commit — a misleading signal dressed as tidy. The structural difference (SHA vs no SHA) signals the semantic difference (commit vs no commit). Form follows substance.

## Iterate until terminated

After the base auto cycle finishes one round, re-request Copilot's review and wait again — **whether or not any fix was pushed this round**. A zero-fix round still re-requests so Copilot can confirm there's nothing new on the unchanged state.

**The only termination condition:** the new review body contains the string `"generated no new comments"`. Until then, keep looping.

Round-N's contract is not "respond to round-N's comments" — it is "iterate until Copilot has seen the final state and explicitly confirms it has nothing new to say". The pull toward "done" gets stronger each round; resist it. **Termination is observed Copilot state, not subjective completion.**

(GitHub may someday reword the termination string. If that happens, the loop will continue running until a human intervenes — the cap on re-requests is "the user pressing stop", not a built-in count.)

## Red Flags — STOP

- "I'll just drop a `/review` comment, it's faster" → that doesn't trigger the bot
- "All prior replies have a SHA, I'll add one to this push-back for consistency" → that misleads the reader
- "I addressed every comment Copilot posted, we're done" → re-request anyway; Copilot hasn't confirmed termination
- "Every comment was a push-back this round, nothing changed — surely we're done" → re-request anyway; the confirmation is observed, not inferred
- "I'll just `sleep 600` and check back" → poll the reviews API; the review may land in 1 minute or 15
