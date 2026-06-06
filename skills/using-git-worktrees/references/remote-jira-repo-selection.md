# Remote Jira repo selection pitfalls

Use this reference when a Jira ticket is handled through the `desktop` SSH host and several `~/github/moreh-dev/*` repos look plausible.

## Lesson

Do not infer the repository solely from a bracketed Jira summary prefix. A prefix like `[heimdall]` may identify a component or product area, while the actual implementation can live in a narrower repo such as `heimdall-inference-scheduler`.

## Safer sequence

1. Read the Jira summary and description.
2. Extract concrete implementation clues from the description:
   - chart/resource names
   - YAML keys and values
   - CLI flags
   - package/import names
   - exact strings shown in AS-IS / TO-BE blocks
3. Search those concrete strings across likely repos before editing:
   - `~/github/moreh-dev/<summary-prefix>`
   - `~/github/moreh-dev/<component>-*`
   - any repo already named in the ticket title or parent epic
4. Create the worktree only after the repo is confirmed.
5. If the wrong repo was edited, restore it immediately and verify a clean status before continuing.

## Example patterns

For a ticket titled `[heimdall] Helm 기본 extraArgs 변경`, the concrete AS-IS / TO-BE flags (`--cache-info-metric`, `--metrics-endpoint-auth=false`, etc.) were the useful repo-selection signal, not the broad `[heimdall]` prefix. The matching chart lived in `heimdall-inference-scheduler`, not `heimdall`.

For a ticket titled `[odin] InferenceService admission fail-fast 검증 강화`, both `heimdall` and `odin` had an `internal/webhook/v1alpha1/inferenceservice_webhook.go` path. The decisive signal was not the shared path but concrete function names from the Jira description:

```bash
for r in ~/github/moreh-dev/heimdall ~/github/moreh-dev/odin; do
  echo "=== $r"
  grep -R "func (.*validateAll\|resolveInferenceService\|validateWorkloadTemplates" \
    -n "$r/internal/webhook/v1alpha1" 2>/dev/null | head -20
done
```

Only `odin` contained the described `validateAll`, `resolveInferenceService`, and `validateWorkloadTemplates` implementation, confirming the target repo.

## Existing ticket worktrees

Before creating the preferred remote worktree location, inspect `git worktree list --porcelain` in the confirmed repo. If a clean worktree for the same ticket already exists (even under a legacy/project-local path such as `.worktrees/MAF-20016`), reuse and fast-forward it instead of creating a duplicate under the nominal `~/worktrees/<repo>-<ticket>` path. Report the actual path in the final handoff so the user can find it.
