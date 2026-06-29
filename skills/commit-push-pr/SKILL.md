---
name: commit-push-pr
description: Use when the user asks to run /commit-push-pr, commit current changes, push the branch, and open a GitHub pull request from the current repository.
---

# Commit Push PR

Commit the current changes, push the branch, and create a GitHub pull request.

This skill builds on `commit-push` (which itself builds on `commit`): branch if needed, run that workflow, then open a PR.

## Workflow

1. Inspect repository state:
   - `git status --short`
   - `git branch --show-current`
   - `git remote -v`
   - `git log --oneline -10`
2. If on `main`, `master`, or `trunk`, create a new branch before committing. Use a short kebab-case branch name based on the dominant change.
3. Follow the `commit-push` skill end-to-end to verify agent-instruction compliance, create focused Conventional Commits, and push the branch.
4. Create the pull request with `gh pr create`.
   - The PR title must be a single Conventional Commit title.
   - If commit titles in the branch consistently use the same prefix, use that same prefix in the PR title.
   - For multiple commits, choose the dominant user-facing scope and type.
   - The PR body must include a short summary and a test plan.
5. Report the PR URL and final `git status --short`.

## PR Body Shape

Use this structure unless the repository has a stronger established template:

```md
## Summary
- ...
- ...

## Test Plan
- [ ] ...
```

## Guardrails

- Inherit every guardrail from the `commit` and `commit-push` skills.
- If `gh` is unavailable or unauthenticated, commit and push if possible, then report the exact blocker.
- Do not create a PR from `main`, `master`, or `trunk`; branch first.
- Do not create empty pull requests.
