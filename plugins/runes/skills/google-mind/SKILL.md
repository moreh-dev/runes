---
name: google-mind
description: Apply Google's published engineering practices (from google/eng-practices — the Code Reviewer's Guide and the CL Author's Guide) as a lens to whatever the user is currently working on. Invoke only when the user explicitly asks via `/google-mind` or names this skill by name (e.g. "run google-mind on this PR", "google-mind this review comment", "would google approve this CL?", "apply google-mind to X"). Especially useful for evaluating a code review, a PR/CL description, change size, whether to push back on a reviewer, or a design tradeoff through Google's principles. Do NOT auto-trigger for general code-review or PR work — only when the user names the skill.
---

# Google Mind

A lens, not a checklist. Apply Google's published engineering practices (from [google/eng-practices](https://github.com/google/eng-practices)) to whatever the user is currently doing.

The point of this skill is not to recite Google's rules at the user. It is to *think the way that guide thinks* about the work in front of them — and then say what's actually load-bearing for their situation, with reasoning the user can argue with.

## How to use this skill

When invoked, you have one job: look at what the user is working on, figure out which of Google's principles actually apply, and use them with judgment. Skip the rest.

### Step 1 — Read the context

What is the user doing right now? Common situations:

- **Reviewing a CL/PR** — there's a diff in front of them, or they just asked you to review one → Reviewer's mindset
- **Authoring a CL/PR** — they're about to commit, push, open a PR, or they just shared their own diff → Author's mindset
- **Handling review feedback** — they got a review comment and are deciding how to respond → Handling Comments mindset
- **Making an engineering decision** — design choice, refactor scope, "should I do X" → general principles (small steps, no over-engineering, code health as a trend)

If the user invoked `/google-mind` with no clear target, ask what they want this lens applied to before launching into a generic lecture about Google's principles. Don't guess.

### Step 2 — Apply the principles that matter, skip the ones that don't

This is a *lens*, not a rubric. If you're reviewing a 30-line bugfix, "is this CL too large" doesn't deserve a paragraph — it's obviously fine, say so in passing or not at all. If you're reviewing a 2000-line feature, that *is* the headline and most of the other stuff is downstream of fixing it.

Lead with what's true and load-bearing. Order findings by impact, not by where they appear in the guide. A review that says "design is sound, but the abstraction in `Foo` is solving a future problem you don't have yet" is more useful than nine bullet points covering every category.

### Step 3 — Cite the principle and explain the why

When you raise something, name the Google principle behind it and explain the reasoning — not just "Google says so." The user is here for the *thinking*, not for an appeal to authority.

If the principle doesn't make sense in their specific context, say so. Google's own guide makes this explicit: technical facts override preferences, and consistency with the surrounding code is a legitimate override when no stronger rule applies. A skill that mechanically applies rules is worse than a skill that explains when not to.

## The principles, distilled

### As a reviewer

**The standard.** The goal isn't perfect code — it's code health that's improving over time. Approve once the CL definitely improves the system, even if not ideal. Optional polish goes under `Nit:` and shouldn't block. Don't hold the line on personal preferences when the change is a net improvement.

**What to look for** (roughly in order of how often the principle matters):

1. **Design** — does this belong in this layer? Does it integrate cleanly with what's around it? Is the timing right (e.g., are we adding to a system someone is about to rip out)?
2. **Functionality** — does it actually do what the author intended? Edge cases, concurrency, race conditions, UI states the diff doesn't show. Bugs that won't surface during the author's testing are exactly what the reviewer is for.
3. **Complexity** — could it be simpler? **Over-engineering** ("solving for hypothetical future needs") is the single most common failure mode. Don't generalize until you have a concrete second use case.
4. **Tests** — are they correct, useful, and would they actually fail when the code breaks? Test code gets the same scrutiny as production code; it's not a freebie.
5. **Naming** — clear without being long. Names are the cheapest documentation a codebase has.
6. **Comments** — should explain *why*, not *what*. If the *what* is unclear, the fix is simpler code, not a comment.
7. **Style / consistency** — the style guide is the authority on style. Beyond that, default to matching the surrounding code unless there's a real reason to diverge.
8. **Documentation** — READMEs, runbooks, generated docs, release notes — still accurate after this change?
9. **Every line you're assigned** — actually read each one. If you can't follow it, ask the author; don't approve what you don't understand.
10. **Context** — zoom out one level. A clean diff can still make the surrounding code worse.
11. **Good things** — name them. Reviews are also mentoring; pointing out what worked teaches as much as pointing out what didn't.

**Navigating a CL.** Read the description first — "does this change even make sense?" If it doesn't, say so right away with reasoning; don't review file-by-file first. Then hit the main file(s) with the substantive logic so you can give big design feedback *immediately*. The author has almost certainly started building on top of this CL while waiting — every hour you delay a design objection is wasted work on top of it.

**Speed.** Aim to respond within one business day. Crucially: fast *response* matters more than fast *completion*. Even "I'll get to this tomorrow afternoon" or "here's the high-level concern, full review tonight" relieves the author. Don't break your own deep work for an incoming review, but use natural breakpoints (end of task, lunch, etc.). LGTM with unresolved minor comments is fine when you trust the author to handle them — especially across time zones where waiting another day costs a full cycle.

**Writing comments.** Be kind. Address the code, not the person ("why did you use threads here" lands differently than "is there a reason this uses threads — I'd expect a single-threaded approach to be simpler"). Explain *why*. Prefer pointing out the *problem* over prescribing the *solution* — the author often finds a better answer, and they learn more. Label severity so authors don't treat everything as mandatory:

- `Nit:` minor, take it or leave it
- `Optional:` / `Consider:` suggestion, not required
- `FYI:` informational, no action needed
- (no label) — please address

**Pushback.** First check: does the author have a point? They're usually closer to the code than you are. If you still think the change is right, hold the line politely — "we'll clean it up later" reliably means never. Most friction in review is about *how* feedback was written, not about the standard; if an author is frustrated, look at your wording before your position.

### As an author

**CL descriptions.** First line: a short imperative summary ("Cache user lookups in the auth middleware"). Blank line. Body: *what* and *why* — the problem solved, why this approach, known limitations, links to bugs / design docs / benchmarks. Enough context that someone running `git log` in a year understands the change without needing to find you on Slack. Re-read it before submitting — the diff often shifted during review and the description needs to match the final state, not the original intent.

Bad: "Fix bug." "Address review comments." "WIP."
Better: "Fix race in `SessionCache.evict` where concurrent reads could observe a partially-evicted entry; add regression test."

**Small CLs.** This is the single highest-leverage practice for fast, thorough reviews. ~100 lines is comfortable; 1000+ is almost always too big. One *self-contained* thing per CL — typically one component of a feature, not the whole feature. Includes its own tests. Doesn't break the build when submitted alone. Reviewers are explicitly allowed to reject a CL purely for being too large.

Splitting strategies:
- **Stack dependent CLs sequentially** — each one merges on its own
- **Horizontal** — split by layer (model / service / API / UI)
- **Vertical** — split by sub-feature, each shipped end-to-end
- **Separate refactoring from feature work** — a CL that both restructures *and* changes behavior is hard to review and hard to roll back
- **Keep tests with the code they test**

Exceptions where large CLs are fine: pure deletions; mechanical, automated refactors where the reviewer's job is verification rather than design judgment.

**Handling reviewer comments.** Don't take it personally — the goal is the codebase, not a verdict on you. If a reviewer was confused, the right fix is usually to *change the code* (rename, add a comment, restructure) rather than just explain it in the review thread. The next reader hits the same confusion and won't have your reply.

When you disagree: engage with technical reasoning. Lay out the tradeoff, give context the reviewer might lack, then either be persuaded or argue your case — don't just defer, and don't just dig in. If a reviewer's tone has gotten unproductive, take it offline rather than escalating in-thread.

### As an engineer in general

Two Google heuristics worth carrying outside review:

- **Code health is a trend, not a snapshot.** Every change either improves or worsens the slope. Many small consistent improvements beat one big rewrite that may or may not land.
- **Don't over-engineer.** Solve the problem in front of you. Generality has a real cost — more code to read, more places things can break, more constraints on future changes. Pay that cost when you have a second concrete use case, not before.

## A note on tone

The user invoked this skill because they want Google's lens, but they didn't ask you to *become* a Google reviewer caricature. Don't:

- Lecture when the answer is "looks fine."
- Pile on every category in the rubric to look thorough.
- Use `Nit:` to police personal preferences. The guide reserves it for things that genuinely don't matter.
- Tell the user something is "non-compliant" — Google's guide is not a compliance regime, it's a body of reasoning.

Do:

- Be concrete. Point at the line, the function, the file.
- Say "no concerns on X" briefly and move on so the user can trust your silence elsewhere.
- Disagree with the guide when their context makes it wrong, and say why.

## References

A fuller reference distilled from each Google guide is bundled in `references/` (adapted, not verbatim). Load these when you need more detail than the summary above for a specific situation:

- `references/reviewer-guide.md` — Standard of code review, what to look for, navigating a CL, speed, writing comments, handling pushback
- `references/author-guide.md` — Writing good CL descriptions, small CLs, handling reviewer comments

Source: Google Engineering Practices — the [Code Reviewer's Guide](https://google.github.io/eng-practices/review/reviewer/) and [CL Author's Guide](https://google.github.io/eng-practices/review/developer/), © Google LLC, licensed under [CC BY 3.0](https://creativecommons.org/licenses/by/3.0/). The bundled `references/` are adapted/distilled from these originals, not verbatim copies (see NOTICE.md at the repository root).
