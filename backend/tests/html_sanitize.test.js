import { describe, it, expect } from 'vitest';
import { sanitizeHtmlBlock } from '../src/lib/html_sanitize.js';

describe('sanitizeHtmlBlock', () => {
  it('preserves safe tags', () => {
    const html = '<p>hello <b>world</b></p>';
    expect(sanitizeHtmlBlock(html)).toBe('<p>hello <b>world</b></p>');
  });

  it('strips <script>', () => {
    const out = sanitizeHtmlBlock('<p>ok</p><script>alert(1)</script>');
    expect(out).not.toContain('<script>');
    expect(out).not.toContain('alert');
    expect(out).toContain('<p>ok</p>');
  });

  it('strips on* event handlers', () => {
    const out = sanitizeHtmlBlock('<a href="https://example.com" onclick="evil()">x</a>');
    expect(out).not.toContain('onclick');
    expect(out).toContain('href="https://example.com"');
  });

  it('strips javascript: hrefs', () => {
    const out = sanitizeHtmlBlock('<a href="javascript:evil()">x</a>');
    expect(out).not.toContain('javascript:');
  });

  it('keeps mailto: hrefs', () => {
    const out = sanitizeHtmlBlock('<a href="mailto:hi@example.com">mail</a>');
    expect(out).toContain('href="mailto:hi@example.com"');
  });

  it('keeps img with http(s) src', () => {
    const out = sanitizeHtmlBlock('<img src="https://example.com/x.png" alt="x">');
    expect(out).toContain('<img');
    expect(out).toContain('src="https://example.com/x.png"');
  });

  it('drops unknown tags', () => {
    const out = sanitizeHtmlBlock('<custom-thing>bad</custom-thing>');
    expect(out).not.toContain('custom-thing');
  });

  it('returns empty string for non-string input', () => {
    expect(sanitizeHtmlBlock(null)).toBe('');
    expect(sanitizeHtmlBlock(undefined)).toBe('');
    expect(sanitizeHtmlBlock(42)).toBe('');
  });
});
