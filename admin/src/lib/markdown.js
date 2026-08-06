// Minimal, safe Markdown renderer for the admin moderation panel.
//
// Supports the subset the mock LLM produces today:
//   # / ## / ### headings
//   **bold** *italic*
//   `inline code` and fenced code blocks
//   - / * / + unordered lists, 1. / 2. ordered lists
//   > blockquotes
//   [text](url) links (http/https only — anything else is stripped)
//   blank-line paragraph breaks
//
// Everything else is HTML-escaped, so user-controlled content can't escape.

function escapeHtml(s) {
  return String(s)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

function renderInline(line) {
  // 1. inline code first (so we don't process markdown inside it)
  const codeTokens = [];
  let html = line.replace(/`([^`]+)`/g, (_, c) => {
    codeTokens.push(c);
    return `\u0000CODE${codeTokens.length - 1}\u0000`;
  });

  // 2. links [text](url) — only allow http(s) schemes
  html = html.replace(/\[([^\]]+)\]\(([^)]+)\)/g, (_, text, url) => {
    if (!/^https?:\/\//i.test(url)) return text;
    return `<a href="${escapeHtml(url)}" target="_blank" rel="noopener">${text}</a>`;
  });

  // 3. bold / italic (order matters: ** before *)
  html = html.replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>');
  html = html.replace(/(^|[^*])\*([^*\n]+)\*(?!\*)/g, '$1<em>$2</em>');

  // 4. restore code tokens
  html = html.replace(/\u0000CODE(\d+)\u0000/g, (_, i) =>
    `<code>${escapeHtml(codeTokens[Number(i)])}</code>`
  );

  return html;
}

function flushParagraph(buf) {
  if (buf.length === 0) return '';
  return `<p>${buf.map(renderInline).join(' ')}</p>`;
}

export function renderMarkdown(input) {
  if (input == null || input === '') return '';
  const lines = String(input).split(/\r?\n/);
  const out = [];
  let i = 0;
  while (i < lines.length) {
    const line = lines[i];

    // fenced code block
    const fence = line.match(/^```/);
    if (fence) {
      const codeLines = [];
      i += 1;
      while (i < lines.length && !/^```/.test(lines[i])) {
        codeLines.push(escapeHtml(lines[i]));
        i += 1;
      }
      if (i < lines.length) i += 1; // skip closing fence
      out.push(`<pre><code>${codeLines.join('\n')}</code></pre>`);
      continue;
    }

    // heading
    const heading = line.match(/^(#{1,3})\s+(.*)$/);
    if (heading) {
      const level = heading[1].length;
      out.push(`<h${level}>${renderInline(heading[2])}</h${level}>`);
      i += 1;
      continue;
    }

    // blockquote (one or more consecutive lines starting with >)
    if (/^>\s?/.test(line)) {
      const quoteLines = [];
      while (i < lines.length && /^>\s?/.test(lines[i])) {
        quoteLines.push(lines[i].replace(/^>\s?/, ''));
        i += 1;
      }
      out.push(`<blockquote>${renderInline(quoteLines.join(' '))}</blockquote>`);
      continue;
    }

    // unordered list
    if (/^[-*+]\s+/.test(line)) {
      const items = [];
      while (i < lines.length && /^[-*+]\s+/.test(lines[i])) {
        items.push(lines[i].replace(/^[-*+]\s+/, ''));
        i += 1;
      }
      out.push(
        `<ul>${items.map((t) => `<li>${renderInline(t)}</li>`).join('')}</ul>`
      );
      continue;
    }

    // ordered list
    if (/^\d+\.\s+/.test(line)) {
      const items = [];
      while (i < lines.length && /^\d+\.\s+/.test(lines[i])) {
        items.push(lines[i].replace(/^\d+\.\s+/, ''));
        i += 1;
      }
      out.push(
        `<ol>${items.map((t) => `<li>${renderInline(t)}</li>`).join('')}</ol>`
      );
      continue;
    }

    // paragraph (gather consecutive non-blank, non-special lines)
    if (line.trim() === '') {
      i += 1;
      continue;
    }
    const buf = [line];
    i += 1;
    while (
      i < lines.length &&
      lines[i].trim() !== '' &&
      !/^(#{1,3}\s|```|>\s?|[-*+]\s|\d+\.\s)/.test(lines[i])
    ) {
      buf.push(lines[i]);
      i += 1;
    }
    out.push(flushParagraph(buf));
  }
  return out.join('\n');
}
