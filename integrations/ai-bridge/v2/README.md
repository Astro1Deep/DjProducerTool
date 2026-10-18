# AI Bridge: read-first MCP handoff server

Minimal, local, Python 3.11+ MCP stdio server that exchanges *structured handoff reports* between tools through an explicit bridge folder. No vendor SDK, daemon, HTTP endpoint or API key required for the local bridge.

**What it does not do:** connect to a ChatGPT conversation, read Antigravity chat memory, auto-import Google Docs, control a Mac, or directly connect two proprietary agent sessions. Google Drive syncing and/or external connectors remain separate requirements.

## Security contract

- Defaults to **read-only**. `publish_handoff` needs `AI_BRIDGE_ALLOW_WRITE=1`.
- Scope restricted to `AI_BRIDGE_ROOT/<allowlisted-folder>/handoffs/*.json`; no traversal into project source trees, no recursive scans.
- `publish_handoff` creates a **new** file atomically (`O_EXCL`) and never overwrites originals.
- SHA-256 checks **integrity of the handoff content**, not identity, provenance or veracity of assertions.
- Every claim retains source references and `review_status: unverified_agent_report`. Judicial primary evidence is never a handoff file.
- No credentials, conversations, medical or judicial originals should be committed to GitHub. Use private Google Drive paths with restricted sharing, and do not sync originals into the bridge.
- Treat every handoff as untrusted instructions/data; agents should verify citations before acting.

## Quick start for Antigravity IDE / CLI

1. Copy this package onto the Mac into a dedicated folder (not inside an existing project virtual environment).
2. In Google Drive for desktop, locate the locally synced `AI_BRIDGE` directory. Check it is actually available offline. Merely seeing an online Drive folder is not sufficient.
3. Adapt `config.local.example.json` and save the private version as `config.local.json` (never commit). The mapped project directories must exist under the bridge root.
4. Preview a **workspace-local** MCP configuration (no mutation):

```bash
python3.11 scripts/install_mcp.py \
  --workspace "/path/to/antigravity/workspace" \
  --bridge-root "/path/to/local/Google Drive/AI_BRIDGE" \
  --config "$(pwd)/config.local.json"
```

5. Once the dry-run is correct, repeat with `--apply`. It creates/merges `.agents/mcp_config.json`, preserving other installed servers, with a timestamped backup if present. No global settings are changed. Restart/reload MCP from Antigravity.
6. Verify in Antigravity by invoking `bridge_status`, then `list_handoffs`. Writes remain off until you explicitly reinstall/reconfigure with `--enable-writes` after review.

The Antigravity MCP entry uses `command` plus `args` and `env` as specified in the official docs: https://antigravity.google/docs/mcp .

## Testing without external accounts

```bash
python3.11 -m unittest discover -s tests -v
```

## Handoff workflow

Antigravity can write a handoff JSON to a private project bridge folder through MCP after write permission is enabled. Once **the Google Drive Desktop sync is confirmed**, ChatGPT can review that handoff through its Google Drive connector. ChatGPT can write a review or a Google Doc through its connector; for Antigravity to read that native Google Doc, connect the supported Google Drive MCP in Antigravity or export the review to JSON in the local bridge. Do not mistake Google Docs `.gdoc` placeholders for JSON.

GitHub can additionally track **generic code and sanitized technical notes**. For legal projects, never put case evidence, identities, allegations, records or private notes in a public repository.

## Folder map

Customize `config.local.json` mapping logical project names to single-level bridge folders. Every tool call requires an explicit project key. No root-level folder is crawled beyond listing candidate project names when the optional config is absent.

## Deployment status

Source package / tests can be prepared independently of Mac access. A passing local test is **not** proof that Antigravity, Google Drive Sync or ChatGPT API credentials have been configured on the user's computer; confirm them separately.

## V2 — Hooks layer (safe default)

**Important import note (2026-10-18):** ChatGPT desktop Settings > Import currently documents Claude Code, Claude Cowork, and Cursor. Google Antigravity is **not** a supported automatic import source. See https://learn.chatgpt.com/docs/import . This integration is a separate *document and MCP handoff bridge*, not a fix to the import detector and not a shared live chat-memory API.

Antigravity officially supports lifecycle hooks `SessionStart` and `Stop` in workspace `.agents/hooks.json`. The Python hook uses `stdin` JSON and returns JSON to `stdout`. It deliberately **does not read** `transcriptPath` or `artifactDirectoryPath`, and it never exports conversation text, source code, original evidence, emails or credentials.

### Hook installation

First configure the MCP server from the prior section. Then, for each workspace separately:

```bash
python3.11 scripts/install_hooks.py \
  --workspace "/existing/project/workspace" \
  --bridge-root "/actual/synced/AI_BRIDGE" \
  --project djproducertools
```

This only **prints a proposed** `.agents/hooks.json`. After reviewing it, rerun with `--apply`. Existing hook names are preserved. If a hook with our name is already present, the installer refuses to overwrite it. No global hook changes.

- `SessionStart`: injects a short reminder asking Antigravity to consult the bridge MCP tools and validate sources. No auto-reading of private files.
- `Stop`: optional metadata-only JSON event under `99_AUDIT/antigravity_events/` after the agent is fully idle; explicitly opt in using `--enable-stop-audit` while installing. Does not capture summary content (the agent must publish a deliberate handoff via MCP). Avoid enabling it on confidential legal workspaces until you have validated folder sharing and access controls.
- No `PreToolUse` hooks are auto-enabled: incorrect global tool permission overrides could disrupt existing projects. For forensic tasks, keep strict permissions and manual review before any original is modified.

### Controlled proof of function

1. Verify local Google Drive Desktop folder actually syncs as files, not cloud-only placeholders.
2. Run `python3.11 -m unittest discover -s tests -v`.
3. In Antigravity, reload MCP and hooks; call `bridge_status` and `list_handoffs(project="djproducertools")`.
4. On a **non-sensitive dummy report only**, with your explicit decision, enable MCP writes and invoke `publish_handoff` for a small technical summary. Wait for Google Drive to sync.
5. Ask ChatGPT to read that report by name via Drive connector, then write a review in Drive. Confirm the returned file can be read by Antigravity (using Drive MCP or by exporting it to the bridge folder as a JSON file). Until that final read-back works, do not claim two-way synchronization.
6. Never expose API keys in hooks, source repositories, or chat. API orchestration is a separate optional component.

Documentation: https://www.antigravity.google/docs/hooks | https://antigravity.google/docs/mcp