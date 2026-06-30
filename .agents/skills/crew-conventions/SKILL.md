---
name: crew-conventions
description: Author crew conventions together with the captain - create or edit the coding-convention presets that firstmate injects into crewmate briefs. Use when the captain invokes /crew-conventions (e.g. "/crew-conventions", "let's create a convention", "define crew conventions", "set up coding conventions for crews", "make a convention for F#", "edit the house style crews use"). Walks through scope, naming, and the actual rules; writes config/conventions/<name>.md and config/crew-conventions.json; validates and previews.
user-invocable: true
---

# crew-conventions

Co-author crew conventions with the captain. Crew conventions are reusable coding-convention presets - house style, comment policy, language idioms - that firstmate injects into a crewmate's brief so crews write code the captain's way (see the "Crew conventions" section of `AGENTS.md`). This skill is the authoring front end for them.

Two LOCAL, gitignored files in the firstmate home's `config/`:

- `config/crew-conventions.json` - the `always` list and the `when -> use` rules.
- `config/conventions/<name>.md` - the body of each named preset (markdown).

These are firstmate-private fleet config, not project files and not tracked: **write them directly, no branch, commit, PR, or gate.** (Only the conventions *mechanism* in `bin/` is tracked; the presets are the captain's.)

Resolve the config dir as `${FM_CONFIG_OVERRIDE:-$FM_HOME/config}` (the active home, so this works in a secondmate home too). All commands below are `bin/fm-conventions.sh ...` and `jq`.

## 1. Show the current state

Run `bin/fm-conventions.sh list`. If it reports none, this is the first preset and you will create the files. Otherwise read out the existing `always` list, rules, and preset names so the captain knows what is already there and whether this is a new preset or an edit.

## 2. Co-author the convention (the conversation)

Work through these with the captain. Use `AskUserQuestion` for the discrete choices; use plain chat to draft the rule text.

1. **Capture intent in the captain's words.** What should crews do, or stop doing, and why? Pin the concrete pain (for example: "stop adding XML doc comments to every F# member"). Do not move on until the rule is specific.
2. **New preset or edit?** A fresh preset, or a change to an existing one from the `list` above.
3. **Scope / selection** - this decides where it goes in `crew-conventions.json`:
   - **Universal** -> add the preset name to `always`; it rides every crew automatically.
   - **Conditional** -> a rule with a natural-language `when` (for example "F#/.NET work, or any task touching .fs/.cs files") and an optional `why`. Conventions **stack**, so a conditional preset layers on top of the `always` base.
4. **Name** the preset in kebab-case, scoped to its role: `base` (universal), `dotnet-fsharp`, `tradingteam-house-style`.
5. **Draft the body.** Turn the captain's intent into a tight markdown bullet list - each line one concrete do/don't, a brief *why* only where it is non-obvious. Keep it lean (the captain's own guidance is to avoid noise; a bloated preset is as bad as none). Show the draft and iterate until the captain approves the wording.

If this is the very first convention and the captain is unsure where to start, suggest a universal `base` preset capturing the no-doc-comments rule - it is the most common recurring crew mistake. `docs/examples/conventions/` has a copyable starting point.

## 3. Write the files

- **Preset body** -> `config/conventions/<name>.md`. Create `config/conventions/` if absent. Write the approved markdown body only (no frontmatter needed; the file *is* the body).
- **Selection** -> `config/crew-conventions.json`. Create it if absent, starting from `{ "always": [], "rules": [] }`. Edit it **safely with `jq`** (write to a temp file, then move into place) so it always stays valid JSON:
  - add to always: `jq '.always = ((.always // []) + ["<name>"] | unique)' config/crew-conventions.json > tmp && mv tmp config/crew-conventions.json`
  - append a rule: `jq '.rules = ((.rules // []) + [{"when":"<condition>","use":["<name>"],"why":"<optional>"}])' config/crew-conventions.json > tmp && mv tmp config/crew-conventions.json`
  - If `jq` is somehow unavailable, hand-edit, but re-validate afterwards.
- Never put preset bodies inside the JSON - bodies live in the `.md` files.

## 4. Validate and preview

- `bin/fm-conventions.sh validate` **must print nothing.** If it reports malformed JSON or a missing preset file, fix it before finishing - a broken file is skipped at dispatch and the convention silently does nothing.
- Preview what a crew will receive: `bin/fm-conventions.sh render <names>` for the rendered stack, and `bin/fm-conventions.sh list` for the rule view.
- Tell the captain, in plain terms, the final preset and exactly when it applies.

## 5. After

- It is **live immediately**: the next relevant dispatch carries it - `always` presets ride every crew; a conditional preset rides when firstmate judges its `when` fits the task (selection is firstmate's judgment at intake; this skill only authors the rules, it does not change matching - see `AGENTS.md`).
- It is inherited by secondmate homes on the next convergence, so their crews get it too.
- No commit, PR, or gate - it is local fleet config.
- Offer to add another preset or refine a `when`. Keep presets focused and composable (a universal `base`, then language/stack/project layers) rather than one giant preset.
