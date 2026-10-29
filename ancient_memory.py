"""Ancient Nest project memory. Python 3.11+, standard library only."""
import argparse
import datetime as dt
import json
import os
from pathlib import Path
import subprocess
import sys
import uuid

ROOT = Path(__file__).resolve().parent
KINDS = ('request', 'decision', 'completed', 'bug', 'handoff')


def git(*args):
    env = dict(os.environ, GIT_TERMINAL_PROMPT='0')
    p = subprocess.run(['git', '-C', str(ROOT), *args], capture_output=True,
                       text=True, encoding='utf-8', errors='replace', env=env, timeout=90)
    if p.returncode:
        raise RuntimeError('Git command failed: git ' + ' '.join(args[:2]) +
                           '. Check Git authentication, branch and conflicts in CMD. Your files were preserved.')
    return p.stdout.strip()


def save(kind, body, evidence=''):
    if kind not in KINDS or not body.strip():
        raise ValueError('Choose a category and enter a note.')
    if kind == 'completed' and not evidence.strip():
        raise ValueError('Completed work needs evidence: changed files/commit and test results or untested limits.')
    entry = {'id': uuid.uuid4().hex, 'time': dt.datetime.now(dt.timezone.utc).isoformat(),
             'kind': kind, 'text': body.strip(), 'evidence': evidence.strip(),
             'source_commit': git('rev-parse', 'HEAD')}
    folder = ROOT / 'project-memory' / 'entries'
    folder.mkdir(parents=True, exist_ok=True)
    path = folder / (entry['id'] + '.json')
    # Unique immutable records avoid two computers editing the same history file.
    with path.open('x', encoding='utf-8') as f:
        json.dump(entry, f, ensure_ascii=False, indent=2)
        f.write('\n')
    return path


def brief(query=''):
    chunks = ['# Ancient Nest — working briefing',
              'Branch: ' + git('branch', '--show-current'),
              'Local commit: ' + git('rev-parse', 'HEAD'),
              'Working tree:\n' + (git('status', '--short') or 'clean'),
              'Local view only. Fetch/refresh before claiming this is the newest remote state.',
              'Notes are recorded statements, not proof that code or live services work.']
    for name in ('project-memory/CURRENT.md', 'README.md', 'VALIDATION.md'):
        path = ROOT / name
        if path.exists():
            chunks.append('\n## ' + name + '\n' + path.read_text(encoding='utf-8'))
    entries = []
    for path in (ROOT / 'project-memory' / 'entries').glob('*.json'):
        entry = json.loads(path.read_text(encoding='utf-8'))
        if not query or query.casefold() in json.dumps(entry, ensure_ascii=False).casefold():
            entries.append(entry)
    chunks.append('\n## Saved history (oldest first; corrections should cite earlier IDs)')
    for e in sorted(entries, key=lambda e: (e['time'], e['id'])):
        chunks.append('\n### {time} [{kind}] {id}\n{text}\nEvidence: {evidence}\nSource commit: {source_commit}'.format(**e))
    chunks.append('\n## Recent local commits\n' + git('log', '-12', '--oneline'))
    chunks.append('\nRead PC_CODEX_HANDOFF.md and relevant source/assets before implementation. '
                  'For visual changes inspect scenes and screenshots; this briefing is not a rendered game preview.')
    return '\n\n'.join(chunks)


def refresh():
    if git('status', '--porcelain'):
        raise RuntimeError('Refresh stopped: local changes exist. Save/commit or reconcile them with Codex first; nothing was discarded.')
    git('pull', '--ff-only')
    return 'Downloaded the current branch upstream. No forced merge or reset.'


def publish():
    # Never include pre-staged work or silently upload other local commits.
    if git('diff', '--cached', '--name-only'):
        raise RuntimeError('Publish stopped: staged work exists. Ask Codex to finish that commit first.')
    git('fetch')
    upstream = git('rev-parse', '--abbrev-ref', '@{upstream}')
    ahead = git('rev-list', '--count', '@{upstream}..HEAD')
    behind = git('rev-list', '--count', 'HEAD..@{upstream}')
    if ahead != '0' or behind != '0':
        raise RuntimeError('Publish stopped: this branch differs from ' + upstream +
                           '. Ask Codex to reconcile/push the existing commits first. Notes remain saved locally.')
    paths = git('ls-files', '--others', '--exclude-standard', '--', 'project-memory/entries/*.json').splitlines()
    if not paths:
        return 'No new notes to publish. Existing note edits must be reviewed with Codex.'
    for name in paths:
        json.loads((ROOT / name).read_text(encoding='utf-8'))
    git('add', '--', *paths)
    git('commit', '-m', 'Record Ancient Nest project notes', '--', *paths)
    # Non-fast-forward rejection preserves both PCs' histories.
    git('push')
    return 'Notes committed and pushed to this branch. Refresh the same branch on the other PC.'


def gui():
    import tkinter as tk
    from tkinter import ttk, messagebox
    from tkinter.scrolledtext import ScrolledText
    app = tk.Tk()
    app.title('Ancient Nest — Project Memory')
    app.geometry('850x700')
    ttk.Label(app, text='Save what changed. Give Codex the same memory on every PC.', font=('', 14)).pack(pady=12)
    ttk.Label(app, text='Notes publish to this repository/branch. Public repository = public notes. Never enter secrets.').pack()
    kind = tk.StringVar(value='request')
    ttk.Combobox(app, textvariable=kind, values=KINDS, state='readonly').pack(pady=8)
    note = ScrolledText(app, height=9, wrap='word'); note.pack(fill='x', padx=15)
    ttk.Label(app, text='Evidence / files / tests / limits (required for completed work)').pack()
    evidence = ttk.Entry(app); evidence.pack(fill='x', padx=15, pady=6)
    status = tk.StringVar(value='Save locally first. Publish uploads notes; Refresh downloads the same branch.')
    ttk.Label(app, textvariable=status, wraplength=800).pack(pady=8)
    row = ttk.Frame(app); row.pack()
    output = ScrolledText(app, wrap='word'); output.pack(fill='both', expand=True, padx=15, pady=10)
    def run(action):
        try:
            status.set(action())
            output.delete('1.0', 'end'); output.insert('1.0', brief())
        except Exception as exc:
            messagebox.showerror('Project Memory', str(exc))
    def record():
        path = save(kind.get(), note.get('1.0', 'end'), evidence.get())
        note.delete('1.0', 'end'); evidence.delete(0, 'end')
        return 'Saved locally: ' + path.name + '. Publish when ready.'
    def copy():
        app.clipboard_clear(); app.clipboard_append(brief())
        return 'Briefing copied. Paste it into Codex, or ask Codex to run python ancient_memory.py brief.'
    def upload():
        if messagebox.askyesno('Publish notes', 'Upload new notes to the current Git branch? Anyone with repository access can read them.'):
            return publish()
        return 'Notes remain local.'
    for label, action in [('Save note', record), ('Publish notes', upload), ('Refresh from GitHub', refresh), ('Copy briefing', copy)]:
        ttk.Button(row, text=label, command=lambda a=action: run(a)).pack(side='left', padx=5)
    run(lambda: 'Ready. Local view; refresh before starting on another computer.')
    app.mainloop()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='command')
    add = sub.add_parser('add'); add.add_argument('kind', choices=KINDS)
    add.add_argument('text'); add.add_argument('--evidence', default='')
    b = sub.add_parser('brief'); b.add_argument('--search', default='')
    for command in ('gui', 'refresh', 'publish'):
        sub.add_parser(command)
    args = parser.parse_args()
    try:
        if args.command == 'add': print(save(args.kind, args.text, args.evidence))
        elif args.command == 'brief': print(brief(args.search))
        elif args.command == 'refresh': print(refresh())
        elif args.command == 'publish': print(publish())
        else: gui()
    except (RuntimeError, ValueError, OSError, subprocess.SubprocessError) as exc:
        print(str(exc), file=sys.stderr); return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
