// Phase 4.16 follow-up — safe formula evaluator for `formula` custom-
// entity columns. Operators write expressions like `qty * price` or
// `(subtotal + tax) * 1.1`; the engine evaluates them at read time
// against the row's other columns.
//
// **Why not eval/Function/vm:** even sandboxed JS can be escaped. This
// language is deliberately tiny — only what's needed to compute
// numbers from other numbers. Adding strings/conditionals/functions
// happens in v2 if operators need it.
//
// Grammar:
//   expr   = term (('+'|'-') term)*
//   term   = unary (('*'|'/') unary)*
//   unary  = ('-' | '+')? factor
//   factor = NUMBER | IDENT | '(' expr ')'
//
// Null-propagating: if any referenced field is null/undefined, the
// whole expression returns null (matches SQL behavior — operators
// expect "missing input → missing output", not "0 + null = 0").

const TOKEN_NUMBER = 'NUMBER';
const TOKEN_IDENT = 'IDENT';
const TOKEN_OP = 'OP';
const TOKEN_EOF = 'EOF';

function tokenize(src) {
  const tokens = [];
  let i = 0;
  while (i < src.length) {
    const ch = src[i];
    if (/\s/.test(ch)) { i++; continue; }
    // Numbers must START with a digit. A bare `.` falls through to the
    // "Unexpected character" branch (which is right for things like
    // `process.exit()` — the `.` is the wrong-token signal).
    if (/[0-9]/.test(ch)) {
      let j = i;
      while (j < src.length && /[0-9.]/.test(src[j])) j++;
      const num = Number(src.slice(i, j));
      if (!Number.isFinite(num)) throw new Error(`Invalid number near "${src.slice(i, j)}"`);
      tokens.push({ type: TOKEN_NUMBER, value: num });
      i = j;
      continue;
    }
    if (/[A-Za-z_]/.test(ch)) {
      let j = i;
      while (j < src.length && /[A-Za-z0-9_]/.test(src[j])) j++;
      tokens.push({ type: TOKEN_IDENT, value: src.slice(i, j) });
      i = j;
      continue;
    }
    if ('+-*/()'.includes(ch)) {
      tokens.push({ type: TOKEN_OP, value: ch });
      i++;
      continue;
    }
    throw new Error(`Unexpected character "${ch}" at position ${i}`);
  }
  tokens.push({ type: TOKEN_EOF });
  return tokens;
}

// Parse → AST. AST nodes:
//   { kind: 'num', value }
//   { kind: 'ref', name }
//   { kind: 'unary', op, operand }
//   { kind: 'binary', op, left, right }
function parse(tokens) {
  let pos = 0;
  const peek = () => tokens[pos];
  const consume = (type, value) => {
    const t = tokens[pos];
    if (t.type !== type || (value !== undefined && t.value !== value)) {
      throw new Error(`Expected ${type}${value !== undefined ? `(${value})` : ''} but got ${t.type}(${t.value ?? ''})`);
    }
    pos++;
    return t;
  };

  function parseExpr() {
    let left = parseTerm();
    while (peek().type === TOKEN_OP && (peek().value === '+' || peek().value === '-')) {
      const op = consume(TOKEN_OP).value;
      const right = parseTerm();
      left = { kind: 'binary', op, left, right };
    }
    return left;
  }
  function parseTerm() {
    let left = parseUnary();
    while (peek().type === TOKEN_OP && (peek().value === '*' || peek().value === '/')) {
      const op = consume(TOKEN_OP).value;
      const right = parseUnary();
      left = { kind: 'binary', op, left, right };
    }
    return left;
  }
  function parseUnary() {
    if (peek().type === TOKEN_OP && (peek().value === '-' || peek().value === '+')) {
      const op = consume(TOKEN_OP).value;
      return { kind: 'unary', op, operand: parseUnary() };
    }
    return parseFactor();
  }
  function parseFactor() {
    const t = peek();
    if (t.type === TOKEN_NUMBER) { pos++; return { kind: 'num', value: t.value }; }
    if (t.type === TOKEN_IDENT) { pos++; return { kind: 'ref', name: t.value }; }
    if (t.type === TOKEN_OP && t.value === '(') {
      consume(TOKEN_OP, '(');
      const inner = parseExpr();
      consume(TOKEN_OP, ')');
      return inner;
    }
    throw new Error(`Unexpected token ${t.type}(${t.value ?? ''}) at position ${pos}`);
  }

  const ast = parseExpr();
  if (peek().type !== TOKEN_EOF) {
    throw new Error(`Unexpected trailing tokens starting at position ${pos}`);
  }
  return ast;
}

// Compile a formula string once → cached AST. Throws on parse error
// so the caller can surface "your formula is bad" to the operator.
const _astCache = new Map();
export function compileFormula(src) {
  if (typeof src !== 'string' || src.trim().length === 0) {
    throw new Error('Formula must be a non-empty string');
  }
  const cached = _astCache.get(src);
  if (cached) return cached;
  const ast = parse(tokenize(src));
  _astCache.set(src, ast);
  return ast;
}

// Evaluate an AST against a row. Returns null if any referenced field
// is null/undefined OR if a divide-by-zero happens (rather than NaN/
// Infinity, which serialize awkwardly to JSON).
export function evalFormula(ast, row) {
  return walk(ast, row);
}

function walk(node, row) {
  switch (node.kind) {
    case 'num':
      return node.value;
    case 'ref': {
      const v = row?.[node.name];
      if (v === null || v === undefined || v === '') return null;
      const n = typeof v === 'number' ? v : Number(v);
      return Number.isFinite(n) ? n : null;
    }
    case 'unary': {
      const operand = walk(node.operand, row);
      if (operand === null) return null;
      return node.op === '-' ? -operand : operand;
    }
    case 'binary': {
      const left = walk(node.left, row);
      if (left === null) return null;
      const right = walk(node.right, row);
      if (right === null) return null;
      switch (node.op) {
        case '+': return left + right;
        case '-': return left - right;
        case '*': return left * right;
        case '/': return right === 0 ? null : left / right;
        default: throw new Error(`Unknown binary op ${node.op}`);
      }
    }
    default:
      throw new Error(`Unknown AST node kind ${node.kind}`);
  }
}

// Convenience: parse + evaluate in one call. Useful for tests and
// one-off checks. For production reads, pre-compile and cache.
export function evaluate(src, row) {
  return evalFormula(compileFormula(src), row);
}

// Lists the field names a formula references. Useful for diagnostics
// and (eventually) dependency tracking when one formula references
// another.
export function referencedFields(ast) {
  const refs = new Set();
  function visit(n) {
    if (n.kind === 'ref') refs.add(n.name);
    else if (n.kind === 'unary') visit(n.operand);
    else if (n.kind === 'binary') { visit(n.left); visit(n.right); }
  }
  visit(ast);
  return Array.from(refs);
}
