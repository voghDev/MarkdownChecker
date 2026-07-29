#!/bin/bash
set -euo pipefail

FILE_PATH="$1"

if [ -z "$FILE_PATH" ] || [ ! -f "$FILE_PATH" ]; then
    osascript -e 'display alert "MarkdownPreview" message "Please provide a valid .md file."'
    exit 1
fi

CONTENT_B64=$(base64 -b 0 -i "$FILE_PATH")
FILENAME_B64=$(printf '%s' "$(basename "$FILE_PATH")" | base64 -b 0)
TMPBASE=$(mktemp /tmp/md_preview_XXXXXX)
TMPFILE="${TMPBASE}.html"
mv "$TMPBASE" "$TMPFILE"

{
cat << 'HTML_PART1'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Markdown Preview</title>
  <script src="https://cdn.jsdelivr.net/npm/marked@9/marked.min.js"></script>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }

    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Helvetica, Arial, sans-serif;
      font-size: 15px;
      line-height: 1.6;
      color: #24292e;
      background: #f6f8fa;
    }

    #header {
      position: sticky;
      top: 0;
      background: #fff;
      border-bottom: 1px solid #d0d7de;
      padding: 10px 24px;
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 16px;
      z-index: 100;
      box-shadow: 0 1px 4px rgba(0,0,0,0.08);
    }

    #header-title {
      font-size: 14px;
      font-weight: 600;
      color: #24292e;
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
      flex: 1;
      min-width: 0;
    }

    #header-right {
      display: flex;
      align-items: center;
      gap: 12px;
      flex-shrink: 0;
    }

    #progress-text {
      font-size: 13px;
      color: #57606a;
      white-space: nowrap;
    }

    #progress-bar-bg {
      width: 160px;
      height: 6px;
      background: #e1e4e8;
      border-radius: 3px;
      overflow: hidden;
    }

    #progress-bar {
      height: 100%;
      width: 0%;
      background: #2ea043;
      border-radius: 3px;
      transition: width 0.2s ease;
    }

    #save-status {
      font-size: 12px;
      color: #2ea043;
      opacity: 0;
      transition: opacity 0.4s ease;
      white-space: nowrap;
    }

    #save-btn {
      background: #2ea043;
      color: #fff;
      border: none;
      border-radius: 6px;
      padding: 5px 14px;
      font-size: 13px;
      font-weight: 500;
      cursor: pointer;
      white-space: nowrap;
      transition: background 0.15s;
    }
    #save-btn:hover { background: #2c974b; }

    #content {
      max-width: 900px;
      margin: 24px auto;
      background: #fff;
      border: 1px solid #d0d7de;
      border-radius: 6px;
      padding: 32px 40px 48px;
    }

    h1, h2, h3, h4 {
      font-weight: 600;
      color: #24292e;
      margin-top: 1.4em;
      margin-bottom: 0.5em;
    }

    h1 {
      font-size: 1.75em;
      border-bottom: 1px solid #eaecef;
      padding-bottom: 0.3em;
      margin-top: 0;
    }

    h2 { font-size: 1.3em; }
    h3 { font-size: 1.1em; }

    ul {
      list-style: none;
      padding-left: 1.5em;
      margin: 0.2em 0;
    }

    #content > ul { padding-left: 0; }

    li { margin: 3px 0; padding: 1px 0; }

    li input[type="checkbox"] {
      vertical-align: middle;
      position: relative;
      top: -1px;
      margin-right: 7px;
      cursor: pointer;
      accent-color: #2ea043;
      width: 14px;
      height: 14px;
    }

    li.item-checked > p,
    li.item-checked > span {
      text-decoration: line-through;
      color: #8c959f;
    }

    li > strong:only-child,
    li > p > strong:only-child { font-weight: 600; }

    li > em:only-child,
    li > p > em:only-child { font-style: italic; color: #57606a; }

    del { color: #8c959f; text-decoration: line-through; }
    strong { font-weight: 600; }
    p { margin: 0.4em 0; }

    @media (max-width: 700px) {
      #content { margin: 12px; padding: 20px; }
      #progress-bar-bg { width: 80px; }
    }
  </style>
</head>
<body>
  <div id="header">
    <span id="header-title">Markdown Preview</span>
    <div id="header-right">
      <span id="progress-text">— / —</span>
      <div id="progress-bar-bg"><div id="progress-bar"></div></div>
      <span id="save-status">✓ Saved</span>
      <button id="save-btn" onclick="manualSave()">Save</button>
    </div>
  </div>
  <div id="content"></div>

  <script>
    const contentB64 =
HTML_PART1
printf "      '%s';\n" "$CONTENT_B64"
printf "    const filenameB64 = '%s';\n" "$FILENAME_B64"
cat << 'HTML_PART2'

    function b64ToUtf8(b64) {
      const bytes = Uint8Array.from(atob(b64), c => c.charCodeAt(0));
      return new TextDecoder('utf-8').decode(bytes);
    }

    function flashSaved() {
      const el = document.getElementById('save-status');
      el.style.opacity = '1';
      clearTimeout(el._t);
      el._t = setTimeout(() => { el.style.opacity = '0'; }, 1500);
    }

    function fallbackDownload(content) {
      const blob = new Blob([content], { type: 'text/plain' });
      const a = document.createElement('a');
      a.href = URL.createObjectURL(blob);
      a.download = filename;
      document.body.appendChild(a);
      a.click();
      document.body.removeChild(a);
      URL.revokeObjectURL(a.href);
    }

    // Save: native WKWebView bridge (instant, no dialog) or browser fallback
    function save(content) {
      if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.save) {
        window.webkit.messageHandlers.save.postMessage(content);
        flashSaved();
      } else {
        fallbackDownload(content);
      }
    }

    function autoSave()   { save(mdLines.join('\n')); }
    function manualSave() { save(mdLines.join('\n')); }

    function updateProgress() {
      const boxes = document.querySelectorAll('input[type="checkbox"]');
      const total = boxes.length;
      const checked = Array.from(boxes).filter(b => b.checked).length;
      document.getElementById('progress-text').textContent = `${checked} / ${total}`;
      const pct = total > 0 ? (checked / total * 100) : 0;
      document.getElementById('progress-bar').style.width = pct.toFixed(1) + '%';
    }

    let mdLines = [];
    let filename = '';

    function render() {
      const md = b64ToUtf8(contentB64);
      filename = b64ToUtf8(filenameB64);
      mdLines = md.split('\n');

      const checkboxLineIndices = mdLines.reduce((acc, line, idx) => {
        if (/^\s*-\s+\[[ xX]\]/.test(line)) acc.push(idx);
        return acc;
      }, []);

      marked.use({ gfm: true, breaks: false });
      document.getElementById('content').innerHTML = marked.parse(md);
      document.title = filename;
      document.getElementById('header-title').textContent = filename;

      document.querySelectorAll('input[type="checkbox"]').forEach((cb, i) => {
        cb.removeAttribute('disabled');
        cb.addEventListener('change', () => {
          const li = cb.closest('li');
          if (li) li.classList.toggle('item-checked', cb.checked);
          if (i < checkboxLineIndices.length) {
            const lineIdx = checkboxLineIndices[i];
            mdLines[lineIdx] = cb.checked
              ? mdLines[lineIdx].replace(/\[ \]/, '[x]')
              : mdLines[lineIdx].replace(/\[x\]/i, '[ ]');
          }
          updateProgress();
          autoSave();
        });
      });

      updateProgress();
    }

    if (typeof marked !== 'undefined') {
      render();
    } else {
      document.getElementById('content').innerHTML =
        '<p style="color:#cf222e;padding:16px">Could not load marked.js — please check your internet connection.</p>';
    }
  </script>
</body>
</html>
HTML_PART2
} > "$TMPFILE"

# When called from the Swift app (MDPREVIEW_OUTPUT=path), print the HTML path.
# When called directly from the terminal, open in the default browser.
if [ "${MDPREVIEW_OUTPUT:-}" = "path" ]; then
    echo "$TMPFILE"
else
    open "$TMPFILE"
fi
