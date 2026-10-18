# AI Bridge v2 — ChatGPT / Codex and Google Antigravity
Date: 2026-10-18

## What this solves and what it does not
ChatGPT Desktop Settings > Import supports **Claude Code, Claude Cowork and Cursor**, per the official documentation at https://learn.chatgpt.com/docs/import . Google Antigravity is **not** a documented import source. “No new items found” is not fixed by MCP and is not necessarily a configuration error.

This branch stages a safe, separate exchange workflow. Nothing has been merged into `main`, and nothing executes on the Mac without local installation.

## Packages (private Google Drive)
- Google Drive AI_BRIDGE folder: https://drive.google.com/drive/folders/1QuvHRF9XWISvaN7_vIJKOXHYKAvX9C8P
- Folder `00_PROTOCOL` contains `ai_bridge_mcp_v2_hooks.zip` (v2 package) and `README_V2_HOOKS.md`
- The package includes stdlib-only Python 3.11 MCP server, per-workspace MCP installer, hooks installer and hook scripts; 14 automated local tests pass.
- Personal, medical and judicial files **must not** be committed to this public GitHub repository.

## Antigravity official local configuration
- MCP workspace config: `.agents/mcp_config.json`
- Hook workspace config: `.agents/hooks.json`
- Official docs: https://antigravity.google/docs/mcp and https://www.antigravity.google/docs/hooks

Download / unzip the v2 package **outside project source trees** and select a single local, fully synced Google Drive `AI_BRIDGE` folder. Review source before running.

Start with DRY RUN (nothing written):
```bash
python3.11 scripts/install_mcp.py --workspace "/actual/workspace" --bridge-root "/actual/Google Drive/AI_BRIDGE" --config "./config.local.json"
python3.11 scripts/install_hooks.py --workspace "/actual/workspace" --bridge-root "/actual/Google Drive/AI_BRIDGE" --project djproducertools
```
Only after inspecting the printed config, rerun the desired commands with `--apply`. They preserve existing settings and back up changed files. The hook installer enables SessionStart instructions; optional `--enable-stop-audit` logs **metadata only** to `99_AUDIT`, never transcripts.

The MCP server defaults to read-only. Explicit `--enable-writes` is needed to create new handoff files under `AI_BRIDGE/<project>/handoffs/`, not modify existing project data.

## Validation protocol
1. Confirm Google Drive Desktop local synchronization with a small non-sensitive file.
2. Run `python3.11 -m unittest discover -s tests -v`.
3. Verify MCP `bridge_status` and `list_handoffs` in Antigravity.
4. Enable handoff writing for a non-sensitive test only and publish an Antigravity report.
5. From ChatGPT, fetch report using connected Google Drive, review and publish a response to the same Drive project location.
6. In Antigravity, independently read that response with Google Drive MCP or exported JSON. Only then mark bilateral exchange VERIFIED.

## Forensic separation
The `legal_inah`, `legal_cnp`, and `legal_neighborhood` streams remain separate. Original evidence is read-only. Derived handoffs are agent reports (not primary evidence), retain provenance labels and must not be assumed proven. No automatic deletions or bulk transcription exports.
