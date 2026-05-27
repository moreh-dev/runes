---
name: receiving-code-review-auto
description: Use when the user asks to handle all unresolved PR review threads end-to-end in a single unattended pass.
---

# Receiving Code Review (Auto)

**REQUIRED SUB-SKILL:** Use `receiving-code-review` for per-comment evaluation, reply, and resolution rules — including the Forbidden Responses list, which applies to every reply body this skill posts. The only delta below is minimizing human interaction: run the full loop without pausing between mechanical steps, and surface to the user only on real decisions.

## The Delta

### Don't pause for confirmation

Don't ask "should I apply this?" or "should I post the reply?" — decide using the principles skill's evaluation rules and execute.

### Execution mechanics

Not covered in the principles skill because they apply only end-to-end:

- **Precheck:** working tree must be clean — escalate if dirty.
- **Commit:** one commit per applied thread, made immediately after the change. Conventional Commits, single scope. Pick the type by change kind — `fix` (bug), `refactor` (cleanup), `docs` (docs-only), `test` (test changes), `style` (formatting-only). Scope is the top-level directory of the primary modified file (e.g., `skills`, `cmd`, `api`).
- **Reply format:** accept replies start with the 40-character commit SHA on its own line (GitHub auto-links it to the commit). Push-back replies have no SHA — there is no commit to link to, and a recent unrelated SHA misleads the reader by sending them to an irrelevant diff. When one natural edit resolves several threads (e.g., two comments on adjacent lines fixed by the same change), reuse the SHA across their accept replies — keep that as one commit by design, not by batching unrelated fixes.
- **Push:** one push after the full loop. Never force-push.

### When To Stop (Escalate)

The principles skill's *When To Push Back* list applies as-is — every reason to push back on a single thread is also a reason to halt the auto loop and surface the thread to the user. In addition, escalate on these auto-specific conditions:

- Working tree dirty at start
- Threads on the same hunk contradict each other
- Pre-commit hook fails on something the auto loop cannot resolve mechanically
- Fix would require destructive operations
- Fix touches code well outside the PR scope

Already-made commits stay; do not auto-revert. **On any failure not enumerated above — partial push rejection, mid-loop interruption, or an unrecognized error — halt and report the current state to the user without further action.**

### Final Report

```
Applied:   N — <comment-permalink> <path>:<line> — <what> (<sha>)
Rejected:  N — <comment-permalink> <path>:<line> — <reason>
Clarify:   N — <comment-permalink> <path>:<line> — <question>
Escalated: N — <comment-permalink> <path>:<line> — <reason>

Pushed:    <commit-range> to <branch>
```
