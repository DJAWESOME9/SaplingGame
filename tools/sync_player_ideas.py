"""Append a JSON array of private inbox rows to Apple Notes; print confirmed IDs.

Input rows: id, display_name, idea, created_at. Database access stays with the
connected Supabase tool; this helper contains no credentials.
"""
import html
import json
import re
import subprocess
import sys
import tempfile
import uuid
from pathlib import Path

NOTE_ID = "x-coredata://44D9A5EE-2749-4646-A810-CA1A19008885/ICNote/p144"


def notes(script, *args):
    result = subprocess.run(
        ["osascript", "-", *args], input=script, text=True,
        capture_output=True,
    )
    if result.returncode:
        raise RuntimeError(result.stderr.strip())
    # osascript adds one output newline; preserve newlines in the note itself.
    return result.stdout[:-1] if result.stdout.endswith('\n') else result.stdout


READ = '''on run argv
tell application "Notes"
set targetNote to note id (item 1 of argv)
if name of targetNote is not "Sapling Ideas" then error "Unexpected note"
return body of targetNote
end tell
end run
'''
WRITE = '''on run argv
set expectedBody to read (POSIX file (item 2 of argv)) as «class utf8»
set newBody to read (POSIX file (item 3 of argv)) as «class utf8»
tell application "Notes"
set targetNote to note id (item 1 of argv)
if name of targetNote is not "Sapling Ideas" then error "Unexpected note"
if body of targetNote is not expectedBody then error "Note changed; retry later"
set body of targetNote to newBody
end tell
end run
'''


def append_rows(body, rows):
    section = re.search(r'<div>Player Ideas</div>\s*<ul>(.*?)</ul>', body, re.S)
    if not section:
        raise ValueError("Player Ideas section changed; preserve the note and repair the sync")
    additions, ids = [], []
    for row in rows:
        idea_id = str(uuid.UUID(row['id']))
        marker = f'Sapling idea {idea_id}'
        if marker not in body:
            text = html.escape(row['idea']).replace('\n', '<br>')
            name = html.escape(row['display_name'])
            date = html.escape(row['created_at'][:10])
            additions.append(f'<li>{text}<br><small>{name} · {date} · {marker}</small></li>\n')
        ids.append(idea_id)
    updated = body[:section.end(1)] + ''.join(additions) + body[section.end(1):]
    return updated, ids


def main():
    rows = json.load(sys.stdin)
    if not isinstance(rows, list):
        raise ValueError("Expected a JSON array")
    if not rows:
        print('[]')
        return
    body = notes(READ, NOTE_ID)
    updated, ids = append_rows(body, rows)
    if updated != body:
        with tempfile.TemporaryDirectory(prefix='sapling-ideas-') as directory:
            before = Path(directory) / 'before.html'
            after = Path(directory) / 'after.html'
            before.write_text(body, encoding='utf-8')
            after.write_text(updated, encoding='utf-8')
            notes(WRITE, NOTE_ID, str(before), str(after))
    verified = notes(READ, NOTE_ID)
    if not all(f'Sapling idea {idea_id}' in verified for idea_id in ids):
        raise RuntimeError("Note verification failed; do not mark rows delivered")
    print(json.dumps(ids))


if __name__ == '__main__':
    main()
