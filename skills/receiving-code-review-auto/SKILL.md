---
name: receiving-code-review-auto
description: Use when the user asks to handle PR review threads end-to-end without per-comment confirmation. Same behavior as receiving-code-review applied to every unresolved thread in one pass — evaluates, fixes, commits, pushes, replies, and resolves agent-authored threads.
---

# Receiving Code Review (Auto)

Same evaluation, reply, and resolution rules as `receiving-code-review`. The only delta is minimizing human interaction — run the full loop without pausing between mechanical steps, and surface to the user only on real decisions.

## The Delta

### Don't pause for confirmation

Don't ask "should I apply this?" or "should I post the reply?" — decide using the principles skill's evaluation rules and execute.

### Author classification fail-safe

When unsure whether a reviewer login is an agent (`claude`, `codex`, `copilot`, `*[bot]`), treat as human. Resolving a human's thread is harder to undo than leaving a bot's thread open.

### Execution mechanics

Not covered in the principles skill because they apply only end-to-end:

- **Precheck:** working tree must be clean — escalate if dirty.
- **Commit:** one commit per applied thread, made immediately after the change. Conventional Commits, single scope, with a footer:

  ```
  Addresses-Review: <permalink-or-comment-id>
  ```

- **Push:** one push after the full loop. Never force-push.

### When To Stop (Escalate)

- Working tree dirty at start
- Suggestion conflicts with prior architectural decisions
- Fix would require destructive operations
- Reviewer references context you cannot verify
- Threads on the same hunk contradict each other
- Fix touches code well outside the PR scope
- Pre-commit hook fails on something non-trivial

Already-made commits stay; do not auto-revert.

### Final Report

```
Applied:   N — <comment-id> <path>:<line> — <what> (<sha>)
Rejected:  N — <comment-id> <path>:<line> — <reason>
Clarify:   N — <comment-id> <path>:<line> — <question>
Escalated: N — <comment-id> <path>:<line> — <reason>

Pushed:    <commit-range> to <branch>
```
