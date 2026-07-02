---
name: building-dev-images
description: Use when building, tagging, or deploying development or iteration container images to Kubernetes or a shared node — especially with imagePullPolicy: Always and reused or commit-SHA image tags — to avoid orphaned image layers filling node disk
---

# Building Dev Images

## Overview

An image tag is a mutable pointer, not the image itself. When you push new content to a tag you have already used and the node re-pulls it (`imagePullPolicy: Always`), the layers the node had cached under that tag are no longer referenced by any tag — they become **orphaned layers**. Nothing deletes them promptly, so they accumulate and fill the node's disk.

**Core principle:** New content deserves a new tag. Reusing a tag for different content is what silently orphans layers.

**Announce at start:** "I'm using the building-dev-images skill to avoid orphaning image layers."

## When to Use

- Building or pushing an image for a dev/test/iteration deploy (not a released artifact).
- A Deployment/Pod uses `imagePullPolicy: Always` (`:latest` implies it).
- You tag by a fixed dev tag (`myapp:dev`) or a commit SHA and iterate quickly.
- Symptoms: node disk filling, many `<none>:<none>` (dangling) images, `ImageGCFailed`, `no space left on device` on a node.

**Not for:** immutable released images pushed once under a versioned tag.

## Why Layers Orphan (the trap)

Tag `myapp:dev` → digest A on the node. You rebuild, push new content to `myapp:dev` → digest B. The node pulls B; A's layers stay on disk but are now referenced by no tag. Repeat daily → dozens of orphaned image trees.

Two patterns trigger it:

1. **Reused fixed tag.** `myapp:dev` (or `:latest`) rebuilt with new content every time — same tag, different digest, every push.
2. **Commit-SHA tag without a commit.** `myapp:$(git rev-parse --short HEAD)` *looks* unique, but building with **uncommitted** changes leaves the SHA unchanged while the content differs — so you overwrite the same SHA tag with new content. The uniqueness is a mirage.

## Prevention Checklist

- [ ] **Give each build a unique, immutable tag** — timestamp, CI build number, or a content hash. New content ⇒ new tag ⇒ no orphaning. With unique tags you can also drop to `imagePullPolicy: IfNotPresent`. *(Root-cause fix — do this first.)*
- [ ] **If you tag by commit SHA, refuse to build a dirty tree.** Check `git status --porcelain`; if it is non-empty, commit first or append a marker (e.g. `-dirty`) so uncommitted content never reuses a clean SHA tag. *(Kills pattern 2.)*
- [ ] **Pin consumers by digest when content must be exact** — reference `myapp@sha256:…` instead of a tag; the digest changes when the content changes, by definition.
- [ ] **Keep a node safety net** — configure kubelet image GC (`--image-gc-high-threshold` / `--image-gc-low-threshold`) and/or periodically prune dangling images on dev nodes. This is a backstop for when tag reuse is unavoidable, *not* a substitute for unique tags.

## Quick Reference

| Need | How |
|------|-----|
| Is the working tree dirty? | `git status --porcelain` (non-empty = dirty) |
| Unique tag (timestamp) | `TAG=$(date +%Y%m%d-%H%M%S)` |
| Unique tag (clean SHA only) | `[ -z "$(git status --porcelain)" ] && TAG=$(git rev-parse --short HEAD)` |
| Dangling images on a node | `crictl images` (dangling show as `<none>`) · `docker images -f dangling=true` |
| Prune orphaned layers on a node | `crictl rmi --prune` · `docker image prune -f` |
| Pin by digest | reference `image@sha256:<digest>` instead of `image:tag` |

## Common Mistakes

- **"The tag is a commit SHA, so it's unique."** Only if the tree is committed. Uncommitted changes reuse the SHA — check `git status` first.
- **"`imagePullPolicy: Always` guarantees fresh content."** It does — and that is the problem: it re-pulls new content onto a reused tag and orphans the old layers.
- **"Pruning fixes it."** Pruning cleans up after the fact; it does not stop the orphaning. Unique tags stop it at the source.
- **"`:latest` is fine for dev."** `:latest` is the most-reused tag of all and forces `Always`. It is the worst case of pattern 1.
