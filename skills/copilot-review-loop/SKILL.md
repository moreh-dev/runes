---
name: copilot-review-loop
description: Use when the user asks to run, automate, or iterate on GitHub Copilot's PR review — including phrases like "run Copilot review", "handle Copilot feedback", "Copilot loop" — on a GitHub PR.
---

# Copilot Review Loop

**REQUIRED SUB-SKILL:** Use `receiving-code-review-auto` for the per-comment verify→fix→reply→resolve cycle, including all per-comment evaluation rules inherited from `receiving-code-review`. The delta below covers only Copilot-specific mechanics: assess, trigger, wait, reply format, and termination. Each Copilot round is one full pass of the base auto cycle; the delta adds the surrounding loop.

## Assess before requesting — never blind-request

Many repos auto-request Copilot the moment a PR opens (a ruleset's `copilot_code_review` rule, which covers only PRs targeting the default branch and may skip drafts), so by the time this skill runs a review may already be in flight, already done with comments sitting unresolved, or already done having found nothing. Blindly requesting in that state causes the failures this skill exists to prevent:

- **Duplicate review** — you request a second review on top of the auto-triggered one, so Copilot reviews the same state twice.
- **Skipped first review** — if you then process only the review *you* triggered, the earlier review's threads are never addressed or resolved.
- **Redundant re-review** — the newest review already covers the current head and found nothing, so requesting again spends a review and its wait on a state Copilot already cleared.

So every round begins by taking stock of the PR's Copilot state, and **requests a fresh review only on a clean slate** — nothing in flight, nothing open, and the current head not yet cleared:

| State | Signal | Action |
|---|---|---|
| Review in flight | The newest Copilot `review_requested` event in the issue timeline is newer than the newest Copilot review | **Wait** for it to land — do NOT re-request |
| Open threads exist | Unresolved Copilot review threads on the PR | **Process** them first — do NOT request |
| Review failed | Newest Copilot review posted zero inline comments and its body starts with `Copilot was unable to review` | **Halt and report** the body's reason — Copilot never reviewed this state |
| Confirmed clean | Newest Copilot review's `commit_id` is the PR head SHA and that review posted zero inline comments | **Terminate** — Copilot has seen this exact state and had nothing to say |
| Out of quota | Before requesting: the requester's premium-request quota is exhausted (see below) | **Halt and report** with the reset date — do NOT request |
| Clean slate | none of the above | **Request** a fresh review, then wait |

## Copilot can fail to review — detect it, never read it as clean

Copilot code review spends the **requester's** premium requests. When they run out, Copilot still posts a review: state `COMMENTED`, `commit_id` on the head, zero inline comments, and the body `Copilot was unable to review this pull request because the user who requested the review has reached their quota limit.` Judged by comment count and SHA alone, that is indistinguishable from `Confirmed clean` — so check for the failure first. This is a match on an error marker, not on a "clean" wording; the clean decision still never reads the body.

Before requesting, check the token owner's quota so you don't spend a round on a request that cannot succeed:

```
gh api /copilot_internal/user --jq '{quota: .quota_snapshots.premium_interactions
  | {has_quota, overage_permitted, credits_used}, reset: .quota_reset_date_utc}'
```

`has_quota == false` with `overage_permitted == false` means a request will fail. Ignore `unlimited` and `percent_remaining` — they read `true` and `100.0` in the same snapshot that reports no quota. The endpoint is undocumented (Copilot's IDE plugins use it), so treat it as advisory: if the call fails or the field is missing, request anyway and rely on the post-landing body check. That check stays mandatory regardless — an auto-triggered review spends someone else's quota, which this endpoint cannot see.

On either signal, halt and tell the user: the reason from the body, and the reset date if known. Do not re-request — the same requester gets the same failure.

The work unit each round is **every unresolved Copilot thread**, not a single review's snapshot — that is what guarantees an auto-triggered review's comments get addressed instead of skipped.

## Trigger via reviewer, never via comment

When the Assess step calls for a fresh review, request it through REST with the bot's login:

```
gh api --method POST repos/{owner}/{repo}/pulls/{pr}/requested_reviewers \
  -f 'reviewers[]=copilot-pull-request-reviewer[bot]'
```

Then confirm it registered: a `review_requested` event for Copilot appears in the issue timeline within seconds.

```
gh api --paginate repos/{owner}/{repo}/issues/{pr}/timeline \
  --jq '.[] | select(.event=="review_requested") | [.created_at, (.requested_reviewer.login // "?")] | @tsv'
```

No new event means nothing was requested; do not wait on it. These look like success and are not:
- `reviewers[]=Copilot` returns 200 and silently requests nothing.
- `gh pr edit {pr} --add-reviewer @copilot` can fail with `Projects (classic) is being deprecated … (repository.pullRequest.projectCards)` and change nothing.
- The PR's `requested_reviewers` does not list Copilot even after a request registers, so it can neither confirm a request nor show one in flight.
- The event's actor is the token's owner, so an event carrying the user's login does not mean they clicked in the UI.

**Prohibited** (silently litters the PR; does NOT trigger the bot):
- `gh pr comment {pr} --body "/review"`
- `gh pr comment {pr} --body "@copilot review"`

If such a comment was already posted by mistake, leave it in place and surface it to the user for manual cleanup — do not auto-delete via the API. The delete call is irreversible and trivially misfires on the wrong comment ID (the endpoint deletes any issue/PR comment by numeric ID, with no scope guard for "stray Copilot triggers"). The reviewer surface is the only reliable trigger.

## Assess, terminate, wait, then fetch

```bash
COPILOT_BOT='select(.user.type == "Bot" and (.user.login | ascii_downcase | contains("copilot")))'
COPILOT_THREAD='select((.isResolved | not) and ((.comments.nodes[0].author.login // "") | ascii_downcase | contains("copilot")))'
UNABLE='Copilot was unable to review'

copilot_reviews() {
  gh api --paginate repos/{owner}/{repo}/pulls/{pr}/reviews \
    --jq ".[] | $COPILOT_BOT | [.submitted_at, (.id | tostring), .commit_id] | @tsv"
}

# A landed review that is a failure notice, not a review → halt with its reason
review_failed() {
  local body
  body=$(gh api repos/{owner}/{repo}/pulls/{pr}/reviews/"$1" --jq '.body')
  [ "$(gh api repos/{owner}/{repo}/pulls/{pr}/reviews/"$1"/comments --jq 'length')" -eq 0 ] \
    && [[ "$body" == "$UNABLE"* ]] && { echo "Copilot review failed — halt and report: $body" >&2; return 0; }
  return 1
}

# --- Assess BEFORE requesting ---
last_request=$(gh api --paginate repos/{owner}/{repo}/issues/{pr}/timeline \
  --jq '.[] | select(.event=="review_requested" and ((.requested_reviewer.login // "") | ascii_downcase | contains("copilot"))) | .created_at' \
  | sort | tail -1)
unresolved=$(gh api graphql -f query='
  query($owner:String!,$repo:String!,$pr:Int!){ repository(owner:$owner,name:$repo){
    pullRequest(number:$pr){ reviewThreads(first:100){ nodes{
      isResolved comments(first:1){ nodes{ author{ login } } } } } } } }' \
  -F owner={owner} -F repo={repo} -F pr={pr} \
  --jq "[.data.repository.pullRequest.reviewThreads.nodes[] | $COPILOT_THREAD] | length")
head_sha=$(gh api repos/{owner}/{repo}/pulls/{pr} --jq '.head.sha')
latest=$(copilot_reviews | sort | tail -1)
latest_id=$(printf '%s' "$latest" | cut -f2)
latest_sha=$(printf '%s' "$latest" | cut -f3)
latest_inline=$([ -n "$latest_id" ] \
  && gh api repos/{owner}/{repo}/pulls/{pr}/reviews/"$latest_id"/comments --jq 'length' || echo -1)

# --- Terminate, process, or request ---
latest_at=$(printf '%s' "$latest" | cut -f1)
if [ -n "$last_request" ] && [[ "$last_request" > "${latest_at:-}" ]]; then
  wait_for_review=1                          # review in flight (e.g. auto-triggered) → wait, don't re-request
elif [ "${unresolved:-0}" -gt 0 ]; then
  wait_for_review=0                          # completed review left open threads → process them now
elif [ -n "$latest_id" ] && review_failed "$latest_id"; then
  exit 1                                     # newest review is a failure notice (e.g. quota) — never "clean"
elif [ "$latest_sha" = "$head_sha" ] && [ "${latest_inline:-1}" -eq 0 ]; then
  echo "confirmed clean: review $latest_id covers $head_sha with zero comments — loop done"
  exit 0
else
  quota=$(gh api /copilot_internal/user \
    --jq '.quota_snapshots.premium_interactions | "\(.has_quota) \(.overage_permitted)"' 2>/dev/null)
  if [ "$quota" = "false false" ]; then      # advisory: unknown/failed lookup falls through to request
    echo "Copilot premium-request quota exhausted until $(gh api /copilot_internal/user --jq .quota_reset_date_utc) — halt and report" >&2
    exit 1
  fi
  gh api --method POST repos/{owner}/{repo}/pulls/{pr}/requested_reviewers \
    -f 'reviewers[]=copilot-pull-request-reviewer[bot]' >/dev/null   # head uncleared, nothing in flight or open → request fresh
  wait_for_review=1                          # check the timeline event before trusting this wait
fi

# --- Wait for the in-flight review to land (cap 20 min = 40 × 30s) ---
if [ "$wait_for_review" -eq 1 ]; then
  for _ in $(seq 1 40); do
    cur_id=$(copilot_reviews | sort | tail -1 | cut -f2)
    [ "${cur_id:-$latest_id}" != "$latest_id" ] && break
    sleep 30
  done
  # cap elapsed without the review landing → halt, don't fetch on stale state
  [ "${cur_id:-$latest_id}" != "$latest_id" ] || { echo "no Copilot review landed within 20 min — halt and report" >&2; exit 1; }
  review_failed "$cur_id" && exit 1          # landed, but as a failure notice — don't let next Assess call it clean
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

## Fix completely, not minimally

Each review feeds on the previous round's edits, so a sloppy patch becomes the next round's nit — you manufacture your own churn. Make each fix correct and final in one pass: spell paths and commands out in full (no ellipsis a reader can't run), and check it adds no new inconsistency and breaks no rendering. Edit as if there's no next round.

## Iterate until terminated

After the base auto cycle finishes a round, loop back to **Assess** — never skip it. Assess is the *only* place termination is decided, so the loop is always `Assess → (terminate | wait | process) → Assess`. A freshly-landed clean review leaves the thread fetch empty; the round does nothing and the next Assess terminates on it — don't bolt a second termination check onto the wait loop.

**The only termination condition** is the `Confirmed clean` row: the newest Copilot review's `commit_id` is the PR head SHA, that review posted zero inline comments, it is not a `Copilot was unable to review` notice, and no unresolved Copilot threads remain. (A failure notice or exhausted quota *halts* the loop with an error — that is not termination; the head is still unreviewed.) **Never the review body's prose** — its wording tracks review order, not content: a PR's first review says `generated no comments` and later ones say `generated no new comments`, so a string match terminates or loops on how many reviews came before.

Anything short of all three re-requests. A round that only drained pre-existing threads has not cleared the current head, and neither has a review that predates the last push — so a zero-fix round still re-requests, letting Copilot confirm the unchanged state itself.

Round-N's contract is not "respond to round-N's comments" — it is "iterate until Copilot has seen the final state and confirms it has nothing to say". The pull toward "done" gets stronger each round; resist it. **Termination is observed Copilot state, not subjective completion.**

(The cap on re-requests is "the user pressing stop", not a built-in count.)

## Red Flags — STOP

- "The request returned 200, so Copilot is requested" → read the issue timeline; `reviewers[]=Copilot` and a failed `gh pr edit` both look fine and request nothing
- "I'll just request a review to kick it off" → Assess first; an auto-triggered review may be in flight, done with open threads, or done having cleared this head — a blind request duplicates it, orphans its threads, or re-reviews a state that needed nothing.
- "I'll just drop a `/review` comment, it's faster" → that doesn't trigger the bot
- "All prior replies have a SHA, I'll add one to this push-back for consistency" → that misleads the reader
- "The review summary says it found nothing — that's my termination signal" → read the review's comment count and `commit_id`, not its prose; the wording differs between a first review and a later one, and it is not a contract
- "I addressed every comment Copilot posted, we're done" → re-request anyway; Copilot hasn't cleared the head you just pushed
- "Every comment was a push-back this round, nothing changed — surely we're done" → re-request anyway; the confirmation is observed, not inferred
- "Zero comments on the head SHA — done" → first rule out a `Copilot was unable to review` notice; a quota failure has exactly that shape
- "Quota failed, I'll just re-request" → the same requester fails the same way; halt and report the reset date
- "I'll just `sleep 600` and check back" → poll the reviews API; the review may land in 1 minute or 15
