---
name: copilot-review-loop
description: Use when the user asks to run, automate, or iterate on GitHub Copilot's PR review — including phrases like "run Copilot review", "handle Copilot feedback", "Copilot loop" — on a GitHub PR.
---

# Copilot Review Loop

**REQUIRED SUB-SKILL:** Use `receiving-code-review-auto` for the per-comment verify→fix→reply→resolve cycle, including all per-comment evaluation rules inherited from `receiving-code-review`. The delta below covers only Copilot-specific mechanics: assess, trigger, wait, reply format, and termination. Each Copilot round is one full pass of the base auto cycle; the delta adds the surrounding loop.

## Assess before requesting — never blind-request

Many repos auto-request Copilot the moment a PR opens, so by the time this skill runs a review may already be in flight, or already done with its comments sitting unresolved. Blindly running `--add-reviewer` in that state causes the two failures this skill exists to prevent:

- **Duplicate review** — you request a second review on top of the auto-triggered one, so Copilot reviews the same state twice.
- **Skipped first review** — if you then process only the review *you* triggered, the earlier review's threads are never addressed or resolved.

So every round begins by taking stock of the PR's Copilot state, and **requests a fresh review only on a clean slate** — nothing in flight, nothing open:

| State | Signal | Action |
|---|---|---|
| Review in flight | Copilot listed as a `requested_reviewer` (hasn't submitted yet) | **Wait** for it to land — do NOT re-request |
| Open threads exist | Unresolved Copilot review threads on the PR | **Process** them first — do NOT request |
| Clean slate | neither of the above | **Request** a fresh review, then wait |

The work unit each round is **every unresolved Copilot thread**, not a single review's snapshot — that is what guarantees an auto-triggered review's comments get addressed instead of skipped.

## Trigger via reviewer, never via comment

When the Assess step calls for a fresh review:

```
gh pr edit <PR> --add-reviewer @copilot
```

**Prohibited** (silently litters the PR; does NOT trigger the bot):
- `gh pr comment <PR> --body "/review"`
- `gh pr comment <PR> --body "@copilot review"`

If such a comment was already posted by mistake, leave it in place and surface it to the user for manual cleanup — do not auto-delete via the API. The delete call is irreversible and trivially misfires on the wrong comment ID (the endpoint deletes any issue/PR comment by numeric ID, with no scope guard for "stray Copilot triggers"). The reviewer surface is the only reliable trigger.

## Assess, wait, then fetch

```bash
COPILOT_BOT='select(.user.type == "Bot" and (.user.login | ascii_downcase | contains("copilot")))'
COPILOT_THREAD='select((.isResolved | not) and ((.comments.nodes[0].author.login // "") | ascii_downcase | contains("copilot")))'

# --- Assess BEFORE requesting ---
pending=$(gh api repos/{owner}/{repo}/pulls/{PR} \
  --jq '[.requested_reviewers[]? | select(.login | ascii_downcase | contains("copilot"))] | length')
unresolved=$(gh api graphql -f query='
  query($owner:String!,$repo:String!,$pr:Int!){ repository(owner:$owner,name:$repo){
    pullRequest(number:$pr){ reviewThreads(first:100){ nodes{
      isResolved comments(first:1){ nodes{ author{ login } } } } } } } }' \
  -F owner={owner} -F repo={repo} -F pr={PR} \
  --jq "[.data.repository.pullRequest.reviewThreads.nodes[] | $COPILOT_THREAD] | length")
start=$(gh api repos/{owner}/{repo}/pulls/{PR}/reviews --jq "[.[] | $COPILOT_BOT] | length")

# --- Request only on a clean slate ---
if [ "${pending:-0}" -gt 0 ]; then
  wait_for_review=1                          # review in flight (e.g. auto-triggered) → wait, don't re-request
elif [ "${unresolved:-0}" -gt 0 ]; then
  wait_for_review=0                          # completed review left open threads → process them now
else
  gh pr edit {PR} --add-reviewer @copilot    # nothing in flight, nothing open → request fresh
  wait_for_review=1
fi

# --- Wait for the in-flight review to land (cap 20 min = 40 × 30s) ---
if [ "$wait_for_review" -eq 1 ]; then
  for _ in $(seq 1 40); do
    cur=$(gh api repos/{owner}/{repo}/pulls/{PR}/reviews --jq "[.[] | $COPILOT_BOT] | length")
    [ "${cur:-0}" -gt "${start:-0}" ] && break
    sleep 30
  done
fi

# --- Fetch ALL unresolved Copilot threads (the round's work unit) ---
gh api graphql -f query='
  query($owner:String!,$repo:String!,$pr:Int!){ repository(owner:$owner,name:$repo){
    pullRequest(number:$pr){ reviewThreads(first:100){ nodes{
      id isResolved
      comments(first:100){ nodes{ databaseId path line body author{ login } } } } } } } }' \
  -F owner={owner} -F repo={repo} -F pr={PR} \
  --jq ".data.repository.pullRequest.reviewThreads.nodes[] | $COPILOT_THREAD
        | {threadId: .id, comments: [.comments.nodes[] | {id: .databaseId, path, line, body}]}"
```

On cap-elapsed with no review landed, halt and report — the base auto skill's "unrecognized error" path. The `threadId` feeds the base skill's GraphQL `resolveReviewThread`; the `contains("copilot")` matcher catches both REST (`Copilot`) and GraphQL (`copilot-pull-request-reviewer[bot]`) identities.

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

After the base auto cycle finishes a round, loop back to **Assess** — never skip it. The round just resolved every open Copilot thread, so the next Assess sees a clean slate and requests a fresh review, letting Copilot re-examine the new state — **whether or not any fix was pushed this round**. A zero-fix round still re-requests so Copilot can confirm there's nothing new on the unchanged state.

**The only termination condition:** a freshly-requested review lands whose body contains the string `"generated no new comments"` and the unresolved-threads fetch comes back empty. Read that body with:

```bash
gh api repos/{owner}/{repo}/pulls/{PR}/reviews --jq "[.[] | $COPILOT_BOT] | sort_by(.submitted_at) | last | .body"
```

A round that only drained pre-existing threads (an in-flight or already-completed review) does NOT terminate the loop — it must come back around to a clean-slate request so Copilot confirms the final state. Until then, keep looping.

Round-N's contract is not "respond to round-N's comments" — it is "iterate until Copilot has seen the final state and explicitly confirms it has nothing new to say". The pull toward "done" gets stronger each round; resist it. **Termination is observed Copilot state, not subjective completion.**

(GitHub may someday reword the termination string. If that happens, the loop will continue running until a human intervenes — the cap on re-requests is "the user pressing stop", not a built-in count.)

## Red Flags — STOP

- "I'll just `--add-reviewer` to kick it off" → Assess first; an auto-triggered review may already be in flight or done. A blind request duplicates it and orphans the first review's threads.
- "I'll just drop a `/review` comment, it's faster" → that doesn't trigger the bot
- "All prior replies have a SHA, I'll add one to this push-back for consistency" → that misleads the reader
- "I addressed every comment Copilot posted, we're done" → re-request anyway; Copilot hasn't confirmed termination
- "Every comment was a push-back this round, nothing changed — surely we're done" → re-request anyway; the confirmation is observed, not inferred
- "I'll just `sleep 600` and check back" → poll the reviews API; the review may land in 1 minute or 15
