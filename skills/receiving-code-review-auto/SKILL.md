---
name: receiving-code-review-auto
description: Use when the user asks to handle all unresolved PR review threads end-to-end in a single unattended pass.
---

# Receiving Code Review (Auto)

**REQUIRED SUB-SKILL:** Use runes:receiving-code-review for per-thread evaluation, reply, and resolution rules — including the Forbidden Responses list, which applies to every reply body this skill posts. The only delta below is minimizing human interaction: run the full loop without pausing between mechanical steps, and surface to the user only on real decisions.

## The Delta

### Don't pause for confirmation

Don't ask "should I apply this?" or "should I post the reply?" — decide using the evaluation rules in runes:receiving-code-review and execute.

### Execution mechanics

Not covered in runes:receiving-code-review because they apply only end-to-end:

- **Precheck:** working tree must be clean — escalate if dirty.
- **Commit:** one commit per applied thread, made immediately after the change. Conventional Commits, single scope. Pick the type by change kind — `fix` (bug), `refactor` (cleanup), `docs` (docs-only), `test` (test changes), `style` (formatting-only). Scope is the top-level directory of the primary modified file (e.g., `skills`, `cmd`, `api`).
- **Push:** one push after the full loop. Never force-push.
- **Order:** evaluate and commit each thread (in the Implementation Order of runes:receiving-code-review), push once, then post every reply and resolve threads. Replies cite commit SHAs, which only link to the fix once pushed. If the run halts before the push, no reply claims a fix the PR doesn't have yet.

### Reject, Escalate, or Halt

Every thread ends as applied, rejected, clarify, or escalated. Only a halt stops the run.

- **Rejected:** a *When To Push Back* reason from runes:receiving-code-review that you can settle with technical evidence. Examples: the change breaks existing functionality, it violates YAGNI, it's incorrect for this stack, legacy or compatibility constraints apply, or the reviewer lacks context you can cite. Post the push-back reply, apply the Resolution Policy, and continue with the next thread.
- **Escalated:** the thread needs a decision only the user can make. Don't change code or reply; leave the thread open, record it for the Final Report, and continue with the next thread.
  - It conflicts with the user's architectural decisions, or asks for an architecture change
  - Threads on the same hunk contradict each other
  - The fix would require destructive operations
  - The fix touches code well outside the PR scope
- **Halt:** stop the whole run and report the current state to the user without further action.
  - Working tree dirty at start
  - Pre-commit hook fails on something the auto loop cannot resolve mechanically
  - The push fails or is partly rejected. Post no replies.
  - Mid-loop interruption, or any error not listed here

Already-made commits stay; do not auto-revert.

### Final Report

```
Applied:   N — <comment-permalink> <path>:<line> — <what> (<sha>)
Rejected:  N — <comment-permalink> <path>:<line> — <reason>
Clarify:   N — <comment-permalink> <path>:<line> — <question>
Escalated: N — <comment-permalink> <path>:<line> — <reason>

Pushed:    <commit-range> to <branch>
```
