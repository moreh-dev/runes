# CL Author's Guide — Full Reference

Adapted (distilled, not verbatim) from Google's CL Author's Guide — https://google.github.io/eng-practices/review/developer/ — © Google LLC, licensed under CC BY 3.0: https://creativecommons.org/licenses/by/3.0/

Read this when the SKILL.md summary doesn't have enough detail for an authoring question — particularly when the user is asking how to write a CL description for a tricky change, how to split a large CL, or how to respond to a specific piece of reviewer feedback.

## Table of contents

1. [Writing Good CL Descriptions](#1-writing-good-cl-descriptions)
2. [Small CLs](#2-small-cls)
3. [How to Handle Reviewer Comments](#3-how-to-handle-reviewer-comments)

---

## 1. Writing Good CL Descriptions

A CL description is a public record of *what* change is being made and *why* it was made. It will become a permanent part of our version control history, and will possibly be read by hundreds of people other than your reviewers over the years.

Future developers will search for your CL based on its description. Someone in the future might be looking for your change because of a faint memory of its relevance but without the specifics handy. If all the important information is in the code and not the description, it's going to be a lot harder for them to locate your CL.

### First Line

- Short summary of what is being done.
- Complete sentence, written as though it was an order.
- Followed by an empty line.

The **first line** of a CL description should be a short summary of *specifically* what is being done by the CL, followed by a blank line. This is what most future code searchers will see when they are browsing through a list of CLs, so the first line should be informative enough that they don't have to read your CL or its whole description to understand what your CL actually *did* or how it differs from other CLs. By tradition, the first line of a CL description is a complete sentence, written as though it were an order (an imperative sentence). For example, say `"Delete the FizzBuzz RPC and replace it with the new system."` instead of `"Deleting the FizzBuzz RPC and replacing it with the new system."` You don't have to write the rest of the description as an imperative sentence, though.

### Body is Informative

The rest of the description should be informative. It might include a brief description of the problem that's being solved, and why this is the best approach. If there are any shortcomings to the approach, they should be mentioned. If relevant, include background information such as bug numbers, benchmark results, and links to design documents.

If you include links to external resources, consider that they may not be visible to future readers due to access restrictions or retention policies. Where possible, include enough context for reviewers and future readers to understand the CL.

Even for a small CL that deserves only a single line of description, it might still help to provide more context as to *why* you're making the change.

### Bad CL Descriptions

"Fix bug" is an inadequate CL description. What bug? What did you do to fix it? Other similarly bad descriptions include:

- "Fix build."
- "Add patch."
- "Moving code from A to B."
- "Phase 1."
- "Add convenience functions."
- "kill weird URLs."

Some of those are real CL descriptions. Although short, they do not provide enough useful information.

### Good CL Descriptions

Here are some examples of good descriptions.

**Functionality change**

> rpc: remove size limit on RPC server message freelist.
>
> Servers like FizzBuzz have very large messages and would benefit from reuse. Make the freelist larger, and add a goroutine that frees the freelist entries slowly over time, so that idle servers eventually release all freelist entries.

The first few words describe what the CL actually does. The rest of the description talks about the problem being solved, why this is a good solution, and a bit more information about the specific implementation.

**Refactoring**

> Construct a Task with a TimeKeeper to use its TimeStr and Now methods.
>
> Add a Now method to Task, so the borglet() getter method can be removed (which was only used by OOMCandidate to call borglet's Now method). This replaces the methods on Borglet that delegate to a TimeKeeper.
>
> Allowing Tasks to supply Now is a step toward eliminating the dependency on Borglet. Eventually, collaborators that depend on getting Now from the Task should be changed to use a TimeKeeper directly, but this has been an accommodation to refactoring in small steps.
>
> Continuing the long-range goal of refactoring the Borglet Hierarchy.

The first line describes what the CL does and how this is a change from the past. The rest of the description talks about the specific implementation, the context of the CL, that the solution isn't ideal, and possible future direction. It also explains *why* this change is being made.

**Small CL that needs some context**

> Create a Python3 build rule for status.py.
>
> This allows consumers who are already using this as in Python3 to depend on a rule that is next to the original status build rule instead of somewhere in their own tree. It encourages new consumers to use Python3 if they can, per go/python3-allowed.

The first sentence describes what's actually being done. The rest of the description explains *why* the change is being made and gives the reviewer a lot of context.

### Using Tags

Tags are labels in the form of words that we add to the beginning of CL descriptions, often surrounded by `[brackets]` though other forms like `tag:` are also common. For example, a CL might have `[tag1][tag2]` or `tag1: tag2:` at the start of its description.

This is a common practice, but not a required one. Doing this is most useful when:

- Your CL is part of a tracked initiative or set of tracked CLs and you want to make them easy to query later.
- Your CL needs to be queryable by other automated systems.
- You want to make it easy for readers to tell at a glance what general area or feature the CL is for.

When using tags, it's important to remember to keep the rest of your CL description informative on its own — don't lean on tags to provide context. Most viewers won't be familiar with the meaning of all your team's tags. Keep the number of tags small as too many will make the rest of the first line of your CL description hard to read.

### Generated CL Descriptions

Some CLs are generated by tools. Whenever possible, their descriptions should also follow the advice here. That is, their first line should be short, focused, and written in an imperative form, and the CL description body should include informative details that help reviewers and future code searchers understand each CL's effect.

### Review the description before submitting the CL

CLs can undergo significant change during review. It can be worthwhile to review a CL description before submitting the CL, to ensure that the description still reflects what the CL does.

---

## 2. Small CLs

### Why Write Small CLs?

Small, simple CLs are:

- **Reviewed more quickly.** It's easier for a reviewer to find five minutes several times to review small CLs than to set aside a 30 minute block to review one large CL.
- **Reviewed more thoroughly.** With large changes, reviewers and authors tend to get frustrated by large volumes of detailed commentary shifting back and forth — sometimes to the point where important points get missed or dropped.
- **Less likely to introduce bugs.** Since you're making fewer changes, it's easier for you and your reviewer to reason effectively about the impact of the CL and see if a bug has been introduced.
- **Less wasted work if they are rejected.** If you write a huge CL and then your reviewer says that the overall direction is wrong, you've wasted a lot of work.
- **Easier to merge.** Working on a large CL takes a long time, so you will have lots of conflicts when you merge, and you will have to merge frequently.
- **Easier to design well.** It's a lot easier to polish the design and code health of a small change than it is to refine all the details of a large change.
- **Less blocking on reviews.** Sending self-contained portions of your overall change allows you to continue coding while you wait for your current CL to be reviewed.
- **Simpler to roll back.** A large CL will more likely touch files that get updated between the initial CL submission and a rollback CL, complicating the rollback (the smaller the CL, the less likely anything will have changed in the meantime).

Note that **reviewers have discretion to reject your change outright for the sole reason of it being too large.** Usually they will thank you for your contribution but request that you somehow make it into a series of smaller changes. It can be a lot of work to split up a change after you've already written it, or require lots of time arguing about why the reviewer should accept your large change. It's easier to just write small CLs in the first place.

### What is Small?

In general, the right size for a CL is **one self-contained change**. This means that:

- The CL makes a minimal change that addresses **just one thing**. This is usually just one part of a feature, rather than a whole feature at once. In general it's better to err on the side of writing CLs that are too small vs. CLs that are too large. Work with your reviewer to find an acceptable size.
- The CL should include related test code.
- Everything the reviewer needs to understand about the CL (except future development) is in the CL, the CL's description, the existing codebase, or a CL they've already reviewed.
- The system will continue to work well for its users and for the developers after the CL is checked in.
- The CL is not so small that its implications are difficult to understand. If you add a new API, you should include a usage of the API in the same CL so that reviewers can better understand how the API will be used. This also prevents checking in an unused API.

There are no hard and fast rules about how large is "too large." 100 lines is usually a reasonable size for a CL, and 1000 lines is usually too large, but it's up to the judgment of your reviewer. The number of files that a change is spread across also affects its "size." A 200-line change in one file might be okay, but spread across 50 files it would usually be too large.

Keep in mind that although you have been intimately involved with your code from the moment you started to write it, the reviewer often has no context. What seems like an acceptably-sized CL to you might be overwhelming to your reviewer. When in doubt, write CLs that are smaller than you think you need to write. Reviewers rarely complain about getting CLs that are too small.

### When are Large CLs Okay?

There are a few situations in which large changes aren't as bad:

- You can usually count deletion of an entire file as being just one line of change, because it doesn't take the reviewer very long to review.
- Sometimes a large CL has been generated by an automatic refactoring tool that you trust completely, and the reviewer's job becomes just to sanity check and say that they really do want the change. These CLs can be larger, although some of the caveats from above (such as merging and testing) still apply.

### Splitting by Files

Another way to split up a CL is by groupings of files that will require different reviewers but are otherwise self-contained changes.

For example: you send off one CL for modifications to a protocol buffer and another CL for changes to the code that uses that proto. You have to submit the proto CL before the code CL, but they can both be reviewed simultaneously. If you do this, you might want to inform both sets of reviewers about the other CL that you wrote, so that they have context for your changes.

Another example: you send one CL for a code change and another for the configuration or experiment that uses that code; this is easier to roll back too, if necessary, as configuration or experiment files are sometimes pushed to production faster than code changes.

### Separate Out Refactorings

It's usually best to do refactorings in a separate CL from feature changes or bug fixes. For example, moving and renaming a class should be in a different CL from fixing a bug in that class. It is much easier for reviewers to understand the changes introduced by each CL when they are separate.

Small cleanups such as fixing a local variable name can be included inside of a feature change or bug fix CL, though. It's up to the judgment of developers and reviewers to decide when a refactoring is so large that it will make the review more difficult if included in your current CL.

### Keep related test code in the same CL

Avoid splitting test code into a separate CL. Test coverage for a change should be part of the same CL even if it increases the code line count.

However, *independent* test modifications can go into separate CLs first, similar to the refactoring guidelines explained above. That includes:

- validating pre-existing, submitted code with new tests.
  - Make sure to enable any tests that are disabled.
  - Verify the tests assert on appropriate values with appropriate inputs.
  - Ensure the existing code is not breaking in different scenarios.
- refactoring the test code (e.g. introduce helper functions).
- introducing larger test framework code (e.g. an integration test).

### Don't Break the Build

If you have several CLs that depend on each other, you need to find a way to make sure the whole system keeps working after each CL is submitted. Otherwise you might break the build for all your fellow developers for a few minutes between your CL submissions (or even longer if something goes wrong unexpectedly with your later CL submissions).

### Can't Make it Small Enough

Sometimes you will encounter situations where it seems like your CL *has* to be large. This is very rarely actually the case. Authors who practice writing small CLs can almost always find a way to decompose functionality into a series of small changes.

Before writing a large CL, consider whether preceding it with a refactoring-only CL could pave the way for a cleaner implementation. Talk to your teammates and see if anybody has thoughts on how to implement the functionality in small CLs instead.

If all of these options fail (which should be extremely rare) then get consent from your reviewers in advance to review a large CL, so they are warned about what is coming. In this situation, expect to be going through the review process for a long time, be vigilant about not introducing bugs, and be extra diligent about writing tests.

---

## 3. How to Handle Reviewer Comments

When a reviewer provides a code review comment, there are a few things you can do:

- If you agree with the comment, just do what they suggested and reply that you have done it.
- If you don't agree, respond and provide your reasoning for why you believe the original code is correct. Sometimes this results in a back-and-forth conversation that can get a little long. In any case, once you and the reviewer come to an agreement, please make the change or note that the change is being made.

### Don't Take it Personally

The goal of review is to maintain the quality of our codebase and our products. When a reviewer provides a critique of your code, think of it as their attempt to help you, the codebase, and Google, rather than as a personal attack on you or your abilities.

Sometimes reviewers feel frustrated and they express that frustration in their comments. This isn't a good practice for reviewers, but as a developer you should be prepared for this. Ask yourself: "What is the constructive thing that the reviewer is trying to communicate to me?" and then operate as though that's what they actually said.

**Never respond in anger to code review comments.** That is a serious breach of professional etiquette that will live forever in the code review tool. If you are too angry or annoyed to respond kindly, then walk away from your computer for a while, or work on something else until you feel calm enough to reply politely.

In general, if a reviewer isn't providing feedback in a way that's constructive and polite, explain this to them in person. If you can't talk to them in person or on a video call, then send them a private email. Explain to them in a kind way what you don't like and what you'd like them to do differently. If they also respond in a non-constructive way to this private discussion, or it doesn't have the intended effect, then escalate to your manager as appropriate.

### Fix the Code

If a reviewer says that they don't understand something in your code, your first response should be to clarify the code itself. If the code can't be clarified, add a code comment that explains why the code is there. If a comment seems pointless, only then should your response be an explanation in the code review tool.

If a reviewer didn't understand some piece of your code, it's likely other future readers of the code won't understand either. Writing a response in the code review tool doesn't help future code readers, but clarifying your code or adding code comments does help them.

### Think Collaboratively

Writing a CL can take a lot of work. It's often really gratifying to finally send one out for review, feel like it's done, and be pretty sure that no further work is needed. So when a reviewer comes back with comments on things that could be improved, it's easy to feel a bit defensive — perhaps you don't even want to think about making the suggested changes.

It's important to resist this reaction. Remind yourself that even if the reviewer's suggestion isn't perfect, it's likely they're working in the spirit of trying to help you and improve the codebase. Many disagreements can be resolved easily once you accept that the suggestion has merit and seriously consider it.

If you disagree, it's important to think about it carefully and come back with an explanation that's reasonable enough that the reviewer can understand and agree with you. Often, you might need to provide them with some context that they don't have, but otherwise the way to resolve disagreements is to talk things through, in person or over video chat if comments aren't resolving the issue. (If you do this, though, make sure to record the results of the discussion as a comment on the CL, for future readers.)

### Resolving Conflicts

If you are having a hard time agreeing with a reviewer, see [The Standard of Code Review](#1-the-standard-of-code-review) — these are guiding principles you can use to come to consensus with reviewers.
