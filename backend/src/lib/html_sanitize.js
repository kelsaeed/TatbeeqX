import sanitizeHtml from 'sanitize-html';

// Phase 4.4 — sanitization for the page-builder `html` block.
// Whitelist of presentational tags + a small set of safe attributes.
// Anchors must use http(s) or mailto; inline scripts/handlers are stripped.

const DEFAULT_OPTIONS = {
  allowedTags: [
    'a', 'b', 'i', 'em', 'strong', 'u', 's', 'br', 'hr', 'p', 'span', 'div',
    'h1', 'h2', 'h3', 'h4', 'h5', 'h6',
    'ul', 'ol', 'li',
    'blockquote', 'code', 'pre',
    'table', 'thead', 'tbody', 'tr', 'th', 'td',
    'img',
  ],
  allowedAttributes: {
    a: ['href', 'name', 'target', 'rel'],
    img: ['src', 'alt', 'title', 'width', 'height'],
    '*': ['style', 'class', 'id'],
  },
  allowedSchemes: ['http', 'https', 'mailto'],
  allowedSchemesByTag: { img: ['http', 'https', 'data'] },
  allowedStyles: {
    '*': {
      color: [/^.*$/],
      'background-color': [/^.*$/],
      'text-align': [/^(left|right|center|justify)$/],
      'font-size': [/^\d+(?:\.\d+)?(?:px|em|rem|%)$/],
      'font-weight': [/^(normal|bold|\d{3})$/],
      margin: [/^[\d.\s%pxemrt]+$/],
      padding: [/^[\d.\s%pxemrt]+$/],
    },
  },
  // sanitize-html drops scripts, on*-handlers, and any tag/attr not on the list.
};

export function sanitizeHtmlBlock(html, options = {}) {
  if (typeof html !== 'string') return '';
  return sanitizeHtml(html, { ...DEFAULT_OPTIONS, ...options });
}
