"""Split a Markdown table row on column pipes.

scripts/idstack-report-section and scripts/idstack-ste-check both import this
file, so a pipe inside inline code is one cell in both checks. Runs on Python 3.9.
"""


def split_pipes(text):
    """Split a table row on '|'. A pipe inside `code`, or \\|, stays in the cell.

    A backtick with no closing backtick does not hide later pipes.
    """
    parts = []
    buf = []
    i = 0
    n = len(text)
    while i < n:
        if text[i] == '`':
            end = text.find('`', i + 1)
            if end == -1:
                buf.append(text[i])
                i += 1
                continue
            buf.append(text[i:end + 1])
            i = end + 1
            continue
        if text[i] == '\\' and i + 1 < n and text[i + 1] == '|':
            buf.append('\\|')
            i += 2
            continue
        if text[i] == '|':
            parts.append(''.join(buf))
            buf = []
            i += 1
            continue
        buf.append(text[i])
        i += 1
    parts.append(''.join(buf))
    return parts
