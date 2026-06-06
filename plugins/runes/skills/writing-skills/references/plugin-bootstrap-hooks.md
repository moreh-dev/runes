# Plugin bootstrap hooks and context files

Use this reference when packaging a shared skills library as a plugin for multiple agent hosts, especially when adapting `obra/superpowers`-style bootstrapping.

## Key distinction

- Claude Code / Copilot-style hosts can use a plugin `SessionStart` hook to inject bootstrap context at session start.
- Gemini uses the extension manifest's `contextFileName` instead of the Claude hook mechanism. Add a root-level `GEMINI.md` and point `gemini-extension.json` at it.
- Skill files alone expose capabilities, but do not necessarily force an initial `using-superpowers` / skill-discovery bootstrap. That automatic startup behavior depends on the host-specific bootstrap path.

## Claude-style plugin layout

For a plugin rooted at `plugins/<name>/`, place hooks under the plugin root:

```text
plugins/<name>/
  .claude-plugin/plugin.json
  .codex-plugin/plugin.json
  hooks/
    hooks.json
    run-hook.cmd
    session-start
  skills/
    using-superpowers/SKILL.md
```

A minimal `hooks/hooks.json` should register `SessionStart` for `startup|clear|compact` and call the wrapper via `${CLAUDE_PLUGIN_ROOT}`:

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup|clear|compact",
        "hooks": [
          {
            "type": "command",
            "command": "\"${CLAUDE_PLUGIN_ROOT}/hooks/run-hook.cmd\" session-start",
            "async": false
          }
        ]
      }
    ]
  }
}
```

Use a cross-platform wrapper such as Superpowers' `run-hook.cmd` and an extensionless `session-start` script. Keep hook scripts executable and LF-normalized, for example:

```text
plugins/<name>/hooks/session-start text eol=lf
plugins/<name>/hooks/run-hook.cmd text eol=lf
```

## Gemini layout

For Gemini, mirror Superpowers' root layout:

```text
gemini-extension.json
GEMINI.md
skills/using-superpowers/SKILL.md
skills/using-superpowers/references/gemini-tools.md
```

`gemini-extension.json` should include:

```json
{
  "contextFileName": "GEMINI.md"
}
```

`GEMINI.md` should load the startup skill and Gemini tool mapping:

```md
@./skills/using-superpowers/SKILL.md
@./skills/using-superpowers/references/gemini-tools.md
```

## Validation checklist

Run host-neutral checks before committing:

```bash
python3 -m json.tool plugins/<name>/hooks/hooks.json >/dev/null
python3 -m json.tool gemini-extension.json >/dev/null
python3 -m json.tool plugins/<name>/.claude-plugin/plugin.json >/dev/null
python3 -m json.tool plugins/<name>/.codex-plugin/plugin.json >/dev/null
CLAUDE_PLUGIN_ROOT="$PWD/plugins/<name>" plugins/<name>/hooks/run-hook.cmd session-start > /tmp/session-start.json
python3 -m json.tool /tmp/session-start.json >/dev/null
python3 - <<'PY'
import json
ctx = json.load(open('/tmp/session-start.json'))['hookSpecificOutput']['additionalContext']
assert '<EXTREMELY_IMPORTANT>' in ctx
assert 'using-superpowers' in ctx
PY
```

If the repo has root skills copied to plugin skills, also run its sync check, e.g. `./scripts/check-skills-sync.sh`.

## Attribution

When copying or adapting bootstrap files from `obra/superpowers`, update the repository notice/license attribution with the upstream commit for hook files separately from any older copied skill commit.
