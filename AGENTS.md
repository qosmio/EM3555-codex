# AGENTS.md

## Goal

This workspace uses the parent repo as the only Codex-deliverable transport layer.
Codex Cloud may edit files inside submodules, but it must **never depend on pushing those submodule repos** or opening PRs from them.
Instead, every submodule change must be exported back into the parent repo as a patch bundle plus a file overlay.

The current parent repo contains these submodules in `.gitmodules`: `gecko-sdk-v3.0` and `EM3555-osram-rgbw-flex`.

## Operating rules for Codex

1. **Edit the real files where they live.**
   - If the task is in `EM3555-osram-rgbw-flex`, edit files there.
   - If the task is in `gecko-sdk-v3.0`, edit only the minimal files needed there.

2. **Do not use the submodule repos as the delivery mechanism.**
   - Do not assume internet will be available when it is time to push.
   - Do not assume you can open a PR from either submodule.
   - Do not leave the submodule working tree as the only copy of the work.

3. **Do not rely on submodule gitlink updates as the solution.**
   - A changed gitlink only works if the target submodule commit exists on a reachable remote.
   - That is not guaranteed in Codex Cloud.
   - Keep the deliverable inside the parent repo instead.

4. **Before finishing any task that touches a submodule, export the changes into the parent repo.**
   Run:

   ```bash
   bash scripts/codex-maintenance.sh capture "<short summary>"
   ```

5. **Parent repo PRs must include the exported bundle.**
   The bundle is written to:

   ```text
   codex-artifacts/<timestamp>/
   ```

   Commit that directory in the parent repo PR.

6. **Do not stage or commit submodule pointers unless the user explicitly asks for a submodule bump.**
   In the normal flow, the parent repo PR should carry:
   - `AGENTS.md`
   - `scripts/codex-maintenance.sh`
   - `codex-artifacts/<timestamp>/...`
   - any parent-repo-only documentation you intentionally changed

7. **Keep SDK exports lean.**
   `gecko-sdk-v3.0` is very large, so never vendor the whole SDK into the parent repo.
   Only export:
   - the generated patch
   - the copied overlay of changed files
   - the metadata and apply instructions

8. **In the final handoff, always tell the user exactly what to replay outside Codex Cloud.**
   Include:
   - the bundle path under `codex-artifacts/`
   - which submodule(s) changed
   - the base SHA recorded in each submodule bundle
   - the fact that each bundle contains both `changes.patch` and `overlay/`

## Expected workflow

1. Make the requested code changes in the appropriate submodule(s).
2. Run:

   ```bash
   bash scripts/codex-maintenance.sh status
   ```

3. Export the work:

   ```bash
   bash scripts/codex-maintenance.sh capture "<short summary>"
   ```

4. Review the generated files in `codex-artifacts/<timestamp>/`.
5. Commit only the parent-repo artifacts and related docs.
6. Open the PR from the **parent repo only**.
7. Outside Codex Cloud, open the real submodule repo locally and follow each bundle's `APPLY.md`.

## What the maintenance bundle contains

For each changed submodule, the script creates a directory like:

```text
codex-artifacts/<timestamp>/submodules/<submodule-path>/
```

That directory contains:
- `changes.patch` — a binary-safe git diff against the gitlink SHA recorded by the parent repo
- `overlay/` — a direct copy of changed and untracked files for manual grab-and-copy
- `deleted-files.txt` — paths deleted relative to the recorded base
- `untracked-files.txt` — newly created files
- `status.txt` — capture-time git status
- `METADATA.txt` — base SHA, head SHA, branch, remote, summary
- `APPLY.md` — exact replay instructions for use outside Codex Cloud

## Why this pattern is preferred here

- It works even when Codex Cloud cannot push from submodules.
- It keeps the full deliverable in the only repo Codex can reliably PR.
- It avoids trying to vendor a 4GB SDK.
- It gives you two recovery paths outside Codex Cloud:
  - apply the patch cleanly with git
  - manually copy from `overlay/` when that is easier
