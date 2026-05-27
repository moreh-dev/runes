---
name: receiving-code-review
description: Use when walking the user through PR review feedback comment-by-comment before deciding what to apply.
---

# Code Review Reception

## Overview

Code review requires technical evaluation, not emotional performance. For each comment, surface the intent, the technical context, and the reason behind your recommendation — so the user understands what's happening, not just the resulting code change.

**Core principle:** Verify before implementing. Ask before assuming. Explain the reasoning. Technical correctness over social comfort.

## The Response Pattern

```
WHEN receiving code review feedback:

1. READ:      Unresolved feedback without reacting
2. UNDERSTAND: Restate requirement in own words (or ask)
3. VERIFY:    Check against codebase reality — cite paths/lines
4. EVALUATE:  Technically sound for THIS codebase?
5. EXPLAIN:   Surface intent, context, and reasoning per the Per-Comment Explanation template
6. RESPOND:   Technical acknowledgment or reasoned pushback
7. IMPLEMENT: One item at a time, test each
```

## Forbidden Responses

**NEVER:**
- "You're absolutely right!" (explicit CLAUDE.md violation)
- "Great point!" / "Excellent feedback!" (performative)
- "Let me implement that now" (before verification)

**INSTEAD:**
- Restate the technical requirement
- Ask clarifying questions
- Push back with technical reasoning if wrong
- Just start working (actions > words)

## Handling Unclear Feedback

```
IF any item is unclear:
  STOP - do not implement anything yet
  ASK for clarification on unclear items

WHY: Items may be related. Partial understanding = wrong implementation.
```

**Example:**
```
user: "Fix 1-6"
You understand 1,2,3,6. Unclear on 4,5.

❌ WRONG: Implement 1,2,3,6 now, ask about 4,5 later
✅ RIGHT: "I understand items 1,2,3,6. Need clarification on 4 and 5 before proceeding."
```

## Source-Specific Handling

### From the user
- **Trusted** - implement after understanding
- **Still ask** if scope unclear
- **No performative agreement**
- **Skip to action** or technical acknowledgment

### From External Reviewers
```
BEFORE implementing:
  1. Check: Technically correct for THIS codebase?
  2. Check: Breaks existing functionality?
  3. Check: Reason for current implementation?
  4. Check: Works on all platforms/versions?
  5. Check: Does reviewer understand full context?

IF suggestion seems wrong:
  Push back with technical reasoning

IF can't easily verify:
  Say so: "I can't verify this without [X]. Should I [investigate/ask/proceed]?"

IF conflicts with the user's prior decisions:
  Stop and discuss with the user first
```

**The user's rule:** "External feedback - be skeptical, but check carefully"

## Common false-positive categories from external reviewers

These patterns recur often enough across external reviewers (human contractors, bots, AI reviewers) to be worth verifying *first* before treating any of them as correct:

| Category | Example claim | Verification |
|---|---|---|
| Compilation misjudgment | "This code won't compile" / "Type error on line X" | Actually run the build/typechecker |
| Phantom symbol | "Function X is missing" / "Variable Y is undefined" | `grep` / `Read` the file(s) |
| Convention ignorance | "Use the standard fmt" / "Should be camelCase" | Compare against project AGENTS.md / CLAUDE.md / style guide |
| Already-fixed | The comment targets a stale state | `git log -p <file>` |
| Behavioral-bug claim | "Breaks under scenario X" | Apply `systematic-debugging` — reproduce the claimed scenario before accepting it |

## YAGNI Check for "Professional" Features

```
IF reviewer suggests "implementing properly":
  grep codebase for actual usage

  IF unused: "This endpoint isn't called. Remove it (YAGNI)?"
  IF used: Then implement properly
```

**The user's rule:** "You and reviewer both report to me. If we don't need this feature, don't add it."

## Per-Comment Explanation

For each review comment, cover (in this order, skipping sections that genuinely do not apply):

1. **Intent** — what the reviewer is actually asking for, in plain terms. If the comment is terse or jargon-heavy, translate it.
2. **Context** — *why* the reviewer raised this. The underlying concern: correctness bug, race, performance regression, security risk, API contract violation, convention drift, future maintenance hazard, etc. Name the category and explain the mechanism.
3. **Verification** — what you checked in the codebase (file paths, call sites, related tests, git history). Cite specifics so the user can follow.
4. **Recommendation** — apply / reject / clarify, with the technical reason. Spell out the alternative if you reject.
5. **Tradeoffs** — what each path costs (extra code, perf hit, churn, lost flexibility) when there is a real tradeoff to weigh.

Intent and Recommendation are mandatory in most cases; the others appear when they add signal. Length follows substance — a one-line typo fix or a single-sentence clarification request can drop the template structure entirely. Rule of thumb: if the only honest content of Intent and Recommendation would be a one-line echo of the comment itself, skip the structure.

## Implementation Order

```
FOR multi-item feedback:
  1. Clarify anything unclear FIRST
  2. Then implement in this order:
     - Blocking issues (breaks, security)
     - Simple fixes (typos, imports)
     - Complex fixes (refactoring, logic)
  3. Test each fix individually
  4. Verify no regressions
```

## When To Push Back

Push back when:
- Suggestion breaks existing functionality
- Reviewer lacks full context
- Violates YAGNI (unused feature)
- Technically incorrect for this stack
- Legacy/compatibility reasons exist
- Conflicts with the user's architectural decisions

**How to push back:**
- Use technical reasoning, not defensiveness
- Ask specific questions
- Reference working tests/code
- Involve the user if architectural

**Signal if uncomfortable pushing back out loud:** "Strange things are afoot at the Circle K"

## Acknowledging Correct Feedback

When feedback IS correct:
```
✅ "Fixed. [Brief description of what changed]"
✅ "Good catch - [specific issue]. Fixed in [location]."
✅ [Just fix it and show in the code]

❌ "You're absolutely right!"
❌ "Great point!"
❌ "Thanks for catching that!"
❌ "Thanks for [anything]"
❌ ANY gratitude expression
```

**Why no thanks:** Actions speak. Just fix it. The code itself shows you heard the feedback.

**If you catch yourself about to write "Thanks":** DELETE IT. State the fix instead.

## Gracefully Correcting Your Pushback

If you pushed back and were wrong:
```
✅ "You were right - I checked [X] and it does [Y]. Implementing now."
✅ "Verified this and you're correct. My initial understanding was wrong because [reason]. Fixing."

❌ Long apology
❌ Defending why you pushed back
❌ Over-explaining
```

State the correction factually and move on.

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Performative agreement | State requirement or just act |
| Blind implementation | Verify against codebase first |
| Batch without testing | One at a time, test each |
| Assuming reviewer is right | Check if breaks things |
| Avoiding pushback | Technical correctness > comfort |
| Partial implementation | Clarify all items first |
| Can't verify, proceed anyway | State limitation, ask for direction |

## Real Examples

**Performative Agreement (Bad):**
```
Reviewer: "Remove legacy code"
❌ "You're absolutely right! Let me remove that..."
```

**Detailed Explanation, Reject (Good):**
```
Reviewer: "Remove legacy code"

✅ "Intent: drop the pre-iOS 13 branch in PhotoLoader.
    Context: the reviewer assumes we already require iOS 13. That's a
      correctness concern — dead code is risk surface and lies to readers.
    Verification: Podfile platform :ios, '10.15' (Podfile:3); the legacy
      branch uses PHImageManager.requestImageForAsset which is the only
      API available pre-iOS 13 — newer requestImage(for:) requires 13+.
    Recommendation: reject the removal. We still ship to 10.15, so the
      legacy branch is load-bearing. But the reviewer landed on something
      real: the legacy path uses the wrong bundle ID (PhotoLoader.legacy
      instead of PhotoLoader). I'll fix that.
    Tradeoff: keeping legacy costs ~30 lines and one extra code path. We
      lose that the day product drops iOS 12 support — worth flagging then."
```

**Detailed Explanation, YAGNI Reject (Good):**
```
Reviewer: "Implement proper metrics tracking — database persistence,
date filters, CSV export"

✅ "Intent: turn the stub /metrics endpoint into a real reporting feature.
    Context: reviewer assumes the endpoint is in use. The underlying
      concern is API quality — stubs that return fake data are a footgun.
    Verification: ripgrep '/metrics' across the repo finds only the route
      definition (routes.py:42) and one test that asserts it returns 200.
      No frontend or external consumer.
    Recommendation: reject *implementing* it; instead, remove the endpoint
      and the test (YAGNI). The reviewer's quality concern is right, but
      the cheaper fix is deletion, not implementation.
    Tradeoff: if metrics show up on the roadmap soon, we'd rewrite this
      from scratch anyway — keeping a stub buys us nothing."
```

## GitHub Thread Replies

When replying to inline review comments on GitHub, reply in the comment thread (`gh api repos/{owner}/{repo}/pulls/{pr}/comments/{id}/replies`), not as a top-level PR comment.

### Resolution Policy

After replying:
- **Agent-authored threads** — match when `user.type == "Bot"` and lowercased `user.login` contains `claude`, `codex`, or `copilot`, OR `login` matches `*[bot]`. Covers `Copilot` (REST) and `copilot-pull-request-reviewer` (GraphQL) plus conventional `*[bot]` accounts. Resolve the thread whether you applied or rejected the suggestion; use the GraphQL `resolveReviewThread` mutation — REST has no equivalent.
- **Human-authored threads**: leave open. The human decides when the conversation is done.
- **Clarifying questions**: leave open regardless of author, until answered.

## The Bottom Line

**External feedback = suggestions to evaluate, not orders to follow.**

Verify. Question. Explain. Then implement.

No performative agreement. Technical rigor always.
