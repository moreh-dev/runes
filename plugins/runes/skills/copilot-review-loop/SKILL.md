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
| Review in flight | Copilot appears in `requested_reviewers` (hasn't submitted yet) | **Wait** for it to land — do NOT re-request |
| Open threads exist | Unresolved Copilot review threads on the PR | **Process** them first — do NOT request |
| Clean slate | neither of the above | **Request** a fresh review, then wait |

The work unit each round is **every unresolved Copilot thread**, not a single review's snapshot — that is what guarantees an auto-triggered review's comments get addressed instead of skipped.

## Trigger via reviewer, never via comment

When the Assess step calls for a fresh review:

```
gh pr edit {pr} --add-reviewer @copilot
```

**Prohibited** (silently litters the PR; does NOT trigger the bot):
- `gh pr comment {pr} --body "/review"`
- `gh pr comment {pr} --body "@copilot review"`

If such a comment was already posted by mistake, leave it in place and surface it to the user for manual cleanup — do not auto-delete via the API. The delete call is irreversible and trivially misfires on the wrong comment ID (the endpoint deletes any issue/PR comment by numeric ID, with no scope guard for "stray Copilot triggers"). The reviewer surface is the only reliable trigger.

## Assess, wait, then fetch

```bash
COPILOT_BOT='select(.user.type == "Bot" and (.user.login | ascii_downcase | contains("copilot")))'
COPILOT_THREAD='select((.isResolved | not) and ((.comments.nodes[0].author.login // "") | ascii_downcase | contains("copilot")))'

# --- Assess BEFORE requesting ---
pending=$(gh api repos/{owner}/{repo}/pulls/{pr} \
  --jq '[.requested_reviewers[]? | select(.login | ascii_downcase | contains("copilot"))] | length')
unresolved=$(gh api graphql -f query='
  query($owner:String!,$repo:String!,$pr:Int!){ repository(owner:$owner,name:$repo){
    pullRequest(number:$pr){ reviewThreads(first:100){ nodes{
      isResolved comments(first:1){ nodes{ author{ login } } } } } } } }' \
  -F owner={owner} -F repo={repo} -F pr={pr} \
  --jq "[.data.repository.pullRequest.reviewThreads.nodes[] | $COPILOT_THREAD] | length")
start=$(gh api repos/{owner}/{repo}/pulls/{pr}/reviews --jq "[.[] | $COPILOT_BOT] | length")

# --- Request only on a clean slate ---
if [ "${pending:-0}" -gt 0 ]; then
  wait_for_review=1                          # review in flight (e.g. auto-triggered) → wait, don't re-request
elif [ "${unresolved:-0}" -gt 0 ]; then
  wait_for_review=0                          # completed review left open threads → process them now
else
  gh pr edit {pr} --add-reviewer @copilot    # nothing in flight, nothing open → request fresh
  wait_for_review=1
fi

# --- Wait for the in-flight review to land (cap 20 min = 40 × 30s) ---
if [ "$wait_for_review" -eq 1 ]; then
  for _ in $(seq 1 40); do
    cur=$(gh api repos/{owner}/{repo}/pulls/{pr}/reviews --jq "[.[] | $COPILOT_BOT] | length")
    [ "${cur:-0}" -gt "${start:-0}" ] && break
    sleep 30
  done
  # cap elapsed without the review landing → halt, don't fetch on stale state
  [ "${cur:-0}" -gt "${start:-0}" ] || { echo "no Copilot review landed within 20 min — halt and report" >&2; exit 1; }
fi

# --- Fetch unresolved Copilot threads, up to the first 100 (the round's work unit) ---
gh api graphql -f query='
  query($owner:String!,$repo:String!,$pr:Int!){ repository(owner:$owner,name:$repo){
    pullRequest(number:$pr){ reviewThreads(first:100){ nodes{
      id isResolved
      comments(first:100){ nodes{ databaseId path line body author{ login } } } } } } } }' \
  -F owner={owner} -F repo={repo} -F pr={pr} \
  --jq ".data.repository.pullRequest.reviewThreads.nodes[] | $COPILOT_THREAD
        | {threadId: .id, comments: [.comments.nodes[] | {id: .databaseId, path, line, body}]}"
```

On cap-elapsed with no review landed, halt and report — the base auto skill's "unrecognized error" path. The `threadId` feeds the base skill's GraphQL `resolveReviewThread`; the `contains("copilot")` matcher catches both REST (`Copilot`) and GraphQL (`copilot-pull-request-reviewer[bot]`) identities. The `first:100` page size on threads and comments covers any realistic PR — it is a cap, not a guarantee of literally *all*; if a PR ever exceeds it, raise the page size or paginate rather than silently dropping threads.

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

## Triage every comment: substantive vs cosmetic

Copilot's reviews skew toward repeatable nits, so triage each comment before acting:

- **Substantive** — warrants a change: a behavior or correctness bug, a chart/API contract mismatch, a convention or security violation. Apply it, or refute it with evidence when the bot is wrong.
- **Cosmetic** — warrants none: phrasing, formatting, a path or style preference, a theoretical-only concern with no behavioral impact. Push back (`Not applied: cosmetic — no behavior/correctness impact`) instead of editing.

This call is load-bearing, so keep it honest and conservative: **cosmetic is a high bar — claim it only when you can show there's no impact; when unsure, treat it as substantive and fix it.** Give every push-back a concrete reason; never wave a batch away as "just nits".

## Fix completely, not minimally

Each review feeds on the previous round's edits, so a sloppy patch becomes the next round's nit — you manufacture your own churn. Make each fix correct and final in one pass: spell paths and commands out in full (no ellipsis a reader can't run), and check it adds no new inconsistency and breaks no rendering. Edit as if there's no next round.

## Iterate until terminated

After processing a round, decide the loop's fate from the round you just handled:

- **You applied a substantive fix** → re-request a fresh review (back to **Assess**, now a clean slate) so Copilot re-examines the new state. A later review still catches real regressions your own fix introduced — keep looping.
- **The round warranted no change** — no comments, or only cosmetic ones you triaged and pushed back — → **terminate.** Copilot has reviewed the current state and surfaced nothing worth an edit; that is the end.

So **termination is "a review of the current state warrants no change," not "Copilot fell silent."** You do not drive the bot to silence — one that keeps re-raising the same cosmetic nit never goes quiet, and chasing that silence means applying edits you don't believe in.

This is **not** a license to quit early. The discipline that used to live in "drive to literal silence" now lives in the triage call: end on a no-change round only when every outstanding comment is provably non-substantive and individually reason-declined. The moment a round warrants any change, make it and keep looping. **When unsure whether a comment is substantive, it is — address it, don't terminate.**

Make this call **autonomously — never hand the stop decision to the user.** And don't hinge termination on a specific GitHub wording, so a reworded bot message can't trap the loop.

**Anti-pattern — appeasing the bot:** applying a cosmetic nit you don't agree with just so the next review comes back clean. It lets the bot's style preferences overwrite your judgment and quietly degrades the artifact. Push it back or leave it; never edit to buy silence.

## Red Flags — STOP

- "I'll just `--add-reviewer` to kick it off" → Assess first; an auto-triggered review may already be in flight or done. A blind request duplicates it and orphans the first review's threads.
- "I'll just drop a `/review` comment, it's faster" → that doesn't trigger the bot
- "All prior replies have a SHA, I'll add one to this push-back for consistency" → that misleads the reader
- "I applied the fixes, we're done" → re-request first; Copilot must review the state your fixes produced — a later review catches regressions they introduced
- "I'll just apply this nit so the next review comes back clean" → that's appeasing the bot; if it's cosmetic, push back — never edit to buy silence
- "These are all just nits, we're done" → only after you've honestly triaged each as cosmetic and reason-declined it; when unsure, it's substantive — address it
- "I'll ask the user whether to stop here" → don't; the loop terminates on your own substantive-vs-cosmetic judgment, autonomously
- "I'll just `sleep 600` and check back" → poll the reviews API; the review may land in 1 minute or 15
