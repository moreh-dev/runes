# Moreh Rust Jira Worktree Verification

Use this reference when a Jira ticket leads to a Moreh Rust repository (for example scheduler, gateway, or Helm-adjacent Rust code) and the work is being done in a remote desktop worktree.

## Implementation loop

1. Read the Jira issue and identify concrete strings from the request: config keys, enum/value names, chart paths, command-line flags, or package names.
2. Search the confirmed repository for those strings before editing. For config-shape changes, inspect both the public docs/PRDs and the factory/deserialization path that builds runtime objects.
3. Add or adjust focused tests first when behavior is semantic, not just mechanical. Cover:
   - default behavior when the new field is omitted;
   - each explicit accepted value;
   - rejection of unknown values when config validation/deserialization should fail;
   - the runtime scoring/selection behavior affected by the config.
   - denominator semantics for scoring/normalization modes: build an asymmetric fixture where the weighted match score, input-block count, and prefix-hash count differ, so `input` and `longestPrefix` cannot both pass by accident.
4. Implement the smallest config surface that matches the user/Jira wording. Keep names exactly aligned with the requested external API spelling.
5. When a Jira/user correction names an external enum such as `longestPrefix`, do not infer the denominator from an internal helper name. Trace the actual runtime inputs and encode the issue wording directly in tests and docs (for example, `longestPrefix` normalization should divide by `block_hashes.len()` when that is the externally defined longest prefix).
5. Update docs/PRDs or examples in the same commit scope when the external config schema changes.

## Verification sequence

Prefer a layered check sequence before reporting completion:

```bash
mise run fmt
cargo test -p <package> --lib <focused_module_or_test_filter> -- --nocapture
cargo test -p <package> --lib <factory_or_config_filter> -- --nocapture
mise run lint
mise run test:unit
git diff --check
git status --short --branch
git diff --stat
```

Notes:
- Use focused `cargo test -p ... --lib ...` runs while iterating so failures stay attributable to the change.
- Still run the repo-level `mise` checks before claiming completion.
- If a repo-level check passes with warnings, report the warning only if it is relevant or likely pre-existing; do not encode it as a durable rule.
- Final status should include the worktree path, branch name, changed behavior, and exact verification commands that passed.