---
name: receiving-code-review-auto
description: Use when the user asks to handle PR review comments end-to-end without step-by-step approval - fetches unresolved threads, evaluates each per the receiving-code-review principles, applies fixes or rejects with reasoning, posts replies, and resolves agent-authored threads
---

# Receiving Code Review (Auto)

End-to-end automation for PR review thread handling. Drives the loop without pausing for permission between mechanical steps; technical judgment still applies per thread.

**The judgment lives in `receiving-code-review`. Read it first.** This skill only orchestrates.

## The Loop

```
0. PRECHECK: working tree must be clean — escalate if dirty (do not mix user WIP)
1. FETCH unresolved review threads on the PR
2. FOR EACH thread, ordered by file path then line:
   a. CLASSIFY author: agent (claude, codex, copilot, *[bot]) vs human
   b. EVALUATE per receiving-code-review
        - verify against codebase
        - YAGNI-grep if a "professional feature" suggestion
        - check for conflict with prior architectural decisions
   c. DECIDE: apply / reject / clarify / escalate
   d. EXECUTE:
        apply    → make code change, commit (one commit per thread),
                   reply with what changed + commit hash
        reject   → reply with the technical reason it does not apply
        clarify  → reply with the specific question
        escalate → stop the loop, surface to user (see "When To Stop")
   e. RESOLVE per policy below
3. PUSH new commits to the PR branch (single push, after the loop)
4. RE-REQUEST review from each agent reviewer whose thread was applied or rejected
5. REPORT final summary
```

## Resolution Policy

| Outcome             | Agent author   | Human author |
|---------------------|----------------|--------------|
| applied             | resolve        | leave open   |
| rejected            | resolve        | leave open   |
| clarify (question)  | leave open     | leave open   |
| escalate            | leave open     | leave open   |

Rationale: agents do not need a human to close the loop; humans do.

## Author Classification

Treat as **agent** when the login matches a known reviewer bot:
- `claude`, `claude[bot]`
- `codex`, `chatgpt-codex-connector[bot]`
- `copilot`, `copilot-pull-request-reviewer[bot]`
- any `*[bot]` whose recent activity is review comments

Treat anything else as **human**. When unsure, treat as human (fail-safe — leaving a thread open is recoverable; resolving a real reviewer's thread is not).

## Reply Style

Follow `receiving-code-review` reply rules:
- No "you're absolutely right", no thanks, no performative agreement
- Applied: state the fix briefly (`Fixed in <path>: <one-line what>`)
- Rejected: state the technical reason (`Current impl needs <X> because <Y>. Suggestion would <break Z>.`)
- Clarify: ask the specific question, nothing else

Replies go in the thread, not as top-level PR comments.

## Commit, Push, Re-request

**Commit:** one commit per applied thread, made immediately after the code change. Use Conventional Commits (single scope, imperative subject, no trailing period). Reference the review thread in a footer for traceability:

```
fix(<scope>): <one-line what>

Addresses-Review: <permalink-or-comment-id>
```

If a pre-commit hook fails, do **not** retry with `--no-verify`. Fix the hook failure or escalate.

**Push:** one `git push` after the loop completes (not per-commit, to avoid CI churn). Never force-push.

**Re-request review:** after pushing, re-request review from each agent reviewer whose thread was applied or rejected so they pick up the new state. Skip re-request for clarify outcomes (the ball is in the reviewer's court).

## What Auto Does NOT Do

- Does **not** force-push or rewrite history.
- Does **not** edit the PR title or description.
- Does **not** merge, close, or label the PR.
- Does **not** run destructive git operations (`reset --hard`, branch deletion, etc.).
- Does **not** start from a dirty working tree — escalates instead.

## When To Stop (Escalate)

Stop the loop and surface to the user when:
- The working tree is dirty at start (precheck)
- A suggestion conflicts with the user's prior architectural decisions
- A fix would require destructive operations (file deletion, schema drop, history rewrite)
- The reviewer references context you cannot verify (external doc, private channel, removed code)
- More than one thread on the same hunk gives contradictory guidance
- A fix touches code outside the PR's stated scope in a non-trivial way
- A pre-commit hook fails and the underlying issue is not a one-line fix

Report which thread stopped you and leave remaining threads for after the user weighs in. Already-made commits stay; do not auto-revert.

## Final Report

```
Applied:   N threads
  - <comment-id> <path>:<line> — <one-line what> (<commit-hash>)
Rejected:  N threads
  - <comment-id> <path>:<line> — <one-line reason>
Clarify:   N threads (open, awaiting reviewer)
  - <comment-id> <path>:<line> — <question>
Escalated: N threads (open, awaiting user)
  - <comment-id> <path>:<line> — <reason>

Pushed:    <commit-range> to <branch>
Re-requested review from: <reviewer-logins>
```
