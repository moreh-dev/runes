---
name: commit-push
description: Use when the user asks to run /commit-push, commit current changes and push the branch to the remote without opening a pull request.
---

# Commit Push

Commit the current changes and push the branch to its remote, without opening a pull request.

This skill builds on `commit`: run that workflow first, then push.

## Workflow

1. Confirm the current branch and remote before doing anything else:
   - `git branch --show-current`
   - `git remote -v`
2. Follow the `commit` skill end-to-end to inspect the working tree, verify agent-instruction compliance, stage, and create one or more focused Conventional Commits.
3. Push the current branch:

   ```sh
   git push -u origin HEAD
   ```

4. Report each new commit hash, the push result, and final `git status --short`.

## Guardrails

- Inherit every guardrail from the `commit` skill.
- If no `origin` remote exists, stop before pushing and report the missing remote.
- Do not force-push unless the user explicitly asks.
- Do not create a pull request; use `commit-push-pr` when a PR is needed.
- If there are no new changes to commit but the local branch is ahead of its upstream, offer to push the existing unpushed commits instead of creating an empty commit.
