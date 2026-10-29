# Ancient Nest Project Memory

Small desktop notes window and command-line briefing, stored with the game. Requires Git and Python 3.11+ (including tkinter for the window). No AI API key or third-party Python packages.

## Use on Windows
From a checkout containing these files, double-click `Open Project Memory.cmd`.
1. At the beginning on another PC, use **Refresh from GitHub** with a clean checkout of the same branch.
2. Type a request, decision, bug, completed change, or handoff. Save note stores it locally.
3. **Publish notes** commits new note files and pushes the current branch upstream. Your repository is public: publish only information intended to be public.
4. **Copy briefing** gives Codex the overview, saved notes, validation report, local commit and recent history.

Git authentication and an upstream branch must already be configured. The app never stores credentials. Git calls may take up to 90 seconds; the small desktop window waits while they finish.
If remote/local commits differ, staged work exists, or a push fails, notes remain local. Ask Codex to reconcile the branch without deleting either computer's work, then push. The tool does not force-push, reset, stash, or silently merge conflicts. A failed push can leave a successful local commit; have Codex push it rather than trying to resave the note.

## Codex commands (CMD, repository root)
```
python ancient_memory.py brief
python ancient_memory.py add request "Make the menu text larger"
python ancient_memory.py add completed "Increased menu text size" --evidence "Changed game/path/to/file; record real checks and any untested limits here"
python ancient_memory.py brief --search menu
python ancient_memory.py publish
```

The completed example is illustrative, not an actual completed game change.
Say to Codex: **Save project memory**. Repository AGENTS.md directs it to record changes, evidence, remaining issues and next steps. Explicitly ask it to commit/push if you want the code and notes available on another computer. Publishing notes alone does not upload uncommitted game code.

## Limits
No automatic access to ChatGPT conversations, another Codex session, or unsaved game changes. Paste decisions from chats into a note or ask that session to save them. Notes are plain JSON under project-memory/entries; CURRENT.md is the curated overview. Search scans all entries and the briefing includes the full history; as the project grows, curate CURRENT.md and use search for focused sessions. Do not erase history to shorten prompts.
Keep code, relevant assets and memory on the same branch/commit. A note's source_commit identifies HEAD at recording time; uncommitted changes need explicit evidence. Inspect scenes/screenshots to understand appearance. This tool does not launch AI or certify completed work.

## Validation
Run `python test_ancient_memory.py`. Tests use temporary local Git repositories, including two-computer synchronization and protection of unrelated work. Real Windows UI and GitHub sign-in still require a PC check. No executable build is distributed.
