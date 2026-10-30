/**
 * Locale Simple - Translation system based on gettext
 * Same API in Perl, Python and JavaScript
 *
 * @module locale-simple
 */

import { candidates, normalizeLang } from './locale-chain.js';

// Internal state
let currentDomain = null;
// Languages tried in order: the chain of l_lang(), then "" (bundles filed
// without a language)
let lookupChain = [''];
let localeDir = null;
let dryMode = false;
let noWrite = false;

// Translation data storage: { domain: { lang: { msgid: msgstr, ... } } }
const translations = {};

// Registered domains
const domains = new Set();

/**
 * sprintf implementation supporting positional and sequential placeholders
 * @param {string} format - Format string with %s, %d, %1$s style placeholders
 * @param {...any} args - Arguments to substitute
 * @returns {string} Formatted string
 */
function sprintf(format, ...args) {
  if (!format) return '';

  let argIndex = 0;

  return format.replace(
    /%%|%(?:(\d+)\$)?([+-]?)([ 0])?(\d+)?(?:\.(\d+))?([sdifoxXeEgGcb%])/g,
    (match, position, sign, pad, width, precision, type) => {
      if (match === '%%') return '%';

      const idx = position ? parseInt(position, 10) - 1 : argIndex++;
      let value = args[idx];

      if (value === undefined) return match;

      switch (type) {
        case 's':
          value = String(value);
          break;
        case 'd':
        case 'i':
          value = parseInt(value, 10).toString();
          break;
        case 'f':
          value = precision !== undefined
            ? parseFloat(value).toFixed(parseInt(precision, 10))
            : parseFloat(value).toString();
          break;
        case 'o':
          value = parseInt(value, 10).toString(8);
          break;
        case 'x':
          value = parseInt(value, 10).toString(16);
          break;
        case 'X':
          value = parseInt(value, 10).toString(16).toUpperCase();
          break;
        case 'e':
          value = parseFloat(value).toExponential(precision ? parseInt(precision, 10) : undefined);
          break;
        case 'E':
          value = parseFloat(value).toExponential(precision ? parseInt(precision, 10) : undefined).toUpperCase();
          break;
        case 'g':
        case 'G':
          value = parseFloat(value).toPrecision(precision ? parseInt(precision, 10) : undefined);
          if (type === 'G') value = value.toUpperCase();
          break;
        case 'c':
          value = String.fromCharCode(parseInt(value, 10));
          break;
        case 'b':
          value = parseInt(value, 10).toString(2);
          break;
      }

      // Handle width padding
      if (width) {
        const padChar = pad === '0' ? '0' : ' ';
        const padWidth = parseInt(width, 10);
        if (value.length < padWidth) {
          if (sign === '-') {
            value = value.padEnd(padWidth, padChar);
          } else {
            value = value.padStart(padWidth, padChar);
          }
        }
      }

      return value;
    }
  );
}

// Plural rules per loaded bundle: { domain: { lang: { nplurals, evaluate } } }
const pluralRules = {};

const DEFAULT_PLURAL_RULE = { nplurals: 2, evaluate: (n) => (n !== 1 ? 1 : 0) };

const MAX_PLURAL_DEPTH = 100;
const MAX_PLURAL_LENGTH = 1000;

let pluralWarned = false;

function warnPluralOnce(reason) {
  if (pluralWarned) return;
  pluralWarned = true;
  if (typeof console === 'object' && typeof console.warn === 'function') {
    console.warn('locale-simple: ' + reason + ', falling back to "n != 1"');
  }
}

const PLURAL_BINARY_LEVELS = [['||'], ['&&'], ['==', '!='], ['<', '>', '<=', '>='], ['+', '-'], ['*', '/', '%']];
const PLURAL_BINARY_OPS = {
  '||': (x, y) => (x || y ? 1 : 0),
  '&&': (x, y) => (x && y ? 1 : 0),
  '==': (x, y) => (x === y ? 1 : 0),
  '!=': (x, y) => (x !== y ? 1 : 0),
  '<': (x, y) => (x < y ? 1 : 0),
  '>': (x, y) => (x > y ? 1 : 0),
  '<=': (x, y) => (x <= y ? 1 : 0),
  '>=': (x, y) => (x >= y ? 1 : 0),
  '+': (x, y) => x + y,
  '-': (x, y) => x - y,
  '*': (x, y) => x * y,
  '/': (x, y) => (y === 0 ? 0 : Math.trunc(x / y)),
  '%': (x, y) => (y === 0 ? 0 : x % y),
};

/**
 * Compile the expression of a Plural-Forms header into a function of n.
 * Recursive-descent parser over the C subset gettext uses; the expression is
 * data from a .po/.mo file, so it is never eval'ed. Nesting of parentheses,
 * "!" and the branches of "?:" is capped at MAX_PLURAL_DEPTH.
 * @param {string} src
 * @returns {(n: number) => number}
 */
function compilePluralExpr(src) {
  if (src.length > MAX_PLURAL_LENGTH) throw new Error('plural expression too long');
  const toks = [];
  const re = /\s*(\d+|n|\|\||&&|==|!=|<=|>=|[-+*/%<>!?:()])/y;
  let at = 0;
  while (at < src.length && src.slice(at).trim() !== '') {
    re.lastIndex = at;
    const m = re.exec(src);
    if (!m) throw new Error('unexpected input in plural expression');
    toks.push(m[1]);
    at = re.lastIndex;
  }
  let pos = 0;
  let depth = 0;

  const peek = () => toks[pos];
  const take = (t) => {
    if (toks[pos] !== t) throw new Error('expected ' + t);
    pos++;
  };
  const nested = (fn) => {
    if (++depth > MAX_PLURAL_DEPTH) throw new Error('plural expression nested too deeply');
    const r = fn();
    depth--;
    return r;
  };

  function expr() {
    const cond = binary(0);
    if (peek() !== '?') return cond;
    pos++;
    const a = nested(expr);
    take(':');
    const b = nested(expr);
    return (n) => (cond(n) ? a(n) : b(n));
  }

  function binary(level) {
    if (level === PLURAL_BINARY_LEVELS.length) return unary();
    let left = binary(level + 1);
    while (PLURAL_BINARY_LEVELS[level].includes(peek())) {
      const op = PLURAL_BINARY_OPS[toks[pos++]];
      const l = left;
      const r = binary(level + 1);
      left = (n) => op(l(n), r(n));
    }
    return left;
  }

  function unary() {
    if (peek() === '!') {
      pos++;
      const inner = nested(unary);
      return (n) => (inner(n) ? 0 : 1);
    }
    return primary();
  }

  function primary() {
    const t = toks[pos++];
    if (t === 'n') return (n) => n;
    if (t !== undefined && /^\d+$/.test(t)) {
      const v = parseInt(t, 10);
      return () => v;
    }
    if (t === '(') {
      const inner = nested(expr);
      take(')');
      return inner;
    }
    throw new Error('unexpected token ' + t);
  }

  const fn = expr();
  if (pos !== toks.length) throw new Error('trailing tokens in plural expression');
  return fn;
}

const compiledRules = new Map();

/**
 * Parse a Plural-Forms header value ("nplurals=2; plural=n != 1;", with or
 * without the leading "Plural-Forms:") into a rule. Returns null if unusable.
 * @param {string} header
 * @returns {{nplurals: number, evaluate: (n: number) => number}|null}
 */
function parsePluralForms(header) {
  if (typeof header !== 'string') return null;
  if (compiledRules.has(header)) return compiledRules.get(header);
  let rule = null;
  const np = /\bnplurals\s*=\s*(\d+)/.exec(header);
  const ex = /\bplural\s*=\s*([^;\n]*)/.exec(header);
  if (np && ex && parseInt(np[1], 10) >= 1) {
    try {
      const fn = compilePluralExpr(ex[1]);
      const nplurals = parseInt(np[1], 10);
      rule = {
        nplurals,
        evaluate(n) {
          const idx = fn(Math.abs(Math.trunc(n)));
          return idx < 0 || idx >= nplurals ? 0 : idx;
        },
      };
    } catch (e) {
      rule = null;
    }
  }
  compiledRules.set(header, rule);
  return rule;
}

/**
 * Turn the optional pluralForms argument into a rule.
 * @param {string|{evaluate: Function}|null|undefined} spec
 * @param {boolean} warnIfAbsent - warn when nothing was given (header-based loading)
 */
function resolvePluralRule(spec, warnIfAbsent) {
  if (spec && typeof spec === 'object' && typeof spec.evaluate === 'function') return spec;
  if (spec === undefined || spec === null) {
    if (warnIfAbsent) warnPluralOnce('no Plural-Forms header');
    return DEFAULT_PLURAL_RULE;
  }
  const rule = parsePluralForms(spec);
  if (rule) return rule;
  warnPluralOnce('unusable Plural-Forms header');
  return DEFAULT_PLURAL_RULE;
}

function storePluralRule(domain, lang, rule) {
  if (!pluralRules[domain]) pluralRules[domain] = {};
  pluralRules[domain][lang] = rule;
}

/**
 * Get plural form index from the rule of a loaded bundle
 * @param {number} n - Count
 * @param {{evaluate: (n: number) => number}} rule
 * @returns {number} Plural form index
 */
function getPluralIndex(n, rule) {
  return rule.evaluate(n);
}

/**
 * Write dry-run output (for extracting translatable strings)
 * @param {string|null} domain
 * @param {string|null} msgctxt
 * @param {string} msgid
 * @param {string|null} msgid_plural
 */
function writeDry(domain, msgctxt, msgid, msgid_plural) {
  if (noWrite) return;
  if (typeof console !== 'object' || typeof console.debug !== 'function') return;

  if (domain) console.debug('# domain: ' + domain);
  if (msgctxt) console.debug('msgctxt "' + msgctxt + '"');
  if (msgid) console.debug('msgid "' + msgid + '"');
  if (msgid_plural) console.debug('msgid_plural "' + msgid_plural + '"');
  console.debug('');
}

const hasOwn = Object.prototype.hasOwnProperty;

/**
 * Own property only: msgids and languages are data, never prototype members
 * @param {Object|undefined} obj
 * @param {string} key
 */
function own(obj, key) {
  return obj != null && hasOwn.call(obj, key) ? obj[key] : undefined;
}

/**
 * Look up a translation across the locale chain (mo-reader.md §2): the first
 * language whose bundle has the key with a non-empty msgstr wins (for plurals:
 * a non-empty form, selected by that bundle's own rule); an empty or missing
 * one falls through to the next language, after the chain to the bundle filed
 * without a language, and finally to the msgid.
 * @param {string} domain
 * @param {string|null} msgctxt
 * @param {string} msgid
 * @param {string|null} msgid_plural
 * @param {number|null} n
 * @returns {string}
 */
function lookup(domain, msgctxt, msgid, msgid_plural, n) {
  const domainData = own(translations, domain);
  if (domainData) {
    const key = msgctxt ? msgctxt + '\u0004' + msgid : msgid;
    for (const lang of lookupChain) {
      const entry = own(own(domainData, lang), key);
      if (entry === undefined) continue;
      const forms = Array.isArray(entry) ? entry : [entry];
      const rule = own(own(pluralRules, domain), lang) || DEFAULT_PLURAL_RULE;
      const text = forms[msgid_plural && n !== null ? getPluralIndex(n, rule) : 0];
      if (typeof text === 'string' && text !== '') return text;
    }
  }
  return msgid_plural && n !== 1 ? msgid_plural : msgid;
}

// ============================================================================
// Public API - Setup functions
// ============================================================================

/**
 * Set the locale directory
 * @param {string} dir - Path to locale directory
 */
export function l_dir(dir) {
  localeDir = dir;
}

/**
 * Set the current language. A colon-separated list is tried in order, and
 * every entry also tries its language part: 'de_AT:fr' looks in de_AT, de,
 * fr, then in a bundle loaded without a language.
 * @param {string} lang - Language code (e.g., 'de_DE', 'pt-BR', 'de_AT:fr')
 */
export function l_lang(lang) {
  lookupChain = [...candidates(lang), ''];
}

/**
 * Enable dry-run mode for string extraction
 * @param {boolean} dry - Enable dry mode
 * @param {boolean} [nw=false] - Suppress output
 */
export function l_dry(dry, nw = false) {
  dryMode = dry;
  noWrite = nw;
}

/**
 * Accepted for API symmetry with the siblings, where it lifts the
 * "set l_dir first" check. JavaScript has no locale directory, so this
 * is a no-op.
 * @param {boolean} x - Ignored
 */
export function l_nolocales(x) {}

/**
 * Set the current text domain
 * @param {string} textdomain - Domain name
 */
export function ltd(textdomain) {
  if (!domains.has(textdomain)) {
    domains.add(textdomain);
  }
  currentDomain = textdomain;
}

/**
 * Load translation data for a domain
 * This should be called with the JSON data from po2json
 *
 * @example
 * // Load from JSON file or inline
 * loadTranslations('myapp', 'de_DE', {
 *   "Hello": "Hallo",
 *   "You have %d message": ["Du hast %d Nachricht", "Du hast %d Nachrichten"]
 * });
 *
 * @param {string} domain - Domain name
 * @param {string} lang - Language code, filed normalised ('pt-BR' → 'pt_BR');
 *   '' for a bundle that answers every language
 * @param {Object} data - Translation data object
 * @param {string|{evaluate: Function}} [pluralForms] - Plural-Forms header value,
 *   e.g. "nplurals=3; plural=...;". Omitted: "n != 1".
 */
export function loadTranslations(domain, lang, data, pluralForms) {
  lang = normalizeLang(lang);
  if (!translations[domain]) {
    translations[domain] = {};
  }
  translations[domain][lang] = data;
  storePluralRule(domain, lang, resolvePluralRule(pluralForms, false));
}

/**
 * Load translation data in po2json format (Gettext.js compatible)
 * @param {string} domain - Domain name
 * @param {Object} localeData - locale_data object from po2json
 */
export function loadLocaleData(domain, localeData) {
  const domainData = localeData[domain];
  if (!domainData) return;

  // Language from the header: "lang", else the gettext field "Language"
  // that bin/po2json writes (with a leading space); "" when neither is set
  const header = domainData[''] || {};
  const lang = normalizeLang(String(header.lang || header.Language || '').trim());

  if (!translations[domain]) {
    translations[domain] = {};
  }

  // Convert po2json format to our internal format
  const data = {};
  for (const [key, value] of Object.entries(domainData)) {
    if (key === '') continue; // Skip header
    // po2json format: msgid: [null, msgstr] or msgid: [null, msgstr[0], msgstr[1], ...]
    if (Array.isArray(value)) {
      if (value.length === 2 && value[0] === null) {
        data[key] = value[1];
      } else if (value.length > 2 || (value.length === 2 && value[0] !== null)) {
        // msgid_plural first, then one entry per plural form (a single one for nplurals=1)
        data[key] = value.slice(1);
      }
    } else {
      data[key] = value;
    }
  }

  translations[domain][lang] = data;
  storePluralRule(domain, lang, resolvePluralRule(header['Plural-Forms'], true));
}

// ============================================================================
// Public API - Translation functions
// ============================================================================

/**
 * Translate a string
 * @param {string} msgid - Message ID
 * @param {...any} args - sprintf arguments
 * @returns {string} Translated string
 */
export function l(msgid, ...args) {
  return ldnp('', null, msgid, null, null, ...args);
}

/**
 * Translate with plural forms
 * @param {string} msgid - Singular message ID
 * @param {string} msgid_plural - Plural message ID
 * @param {number} n - Count for plural selection
 * @param {...any} args - sprintf arguments
 * @returns {string} Translated string
 */
export function ln(msgid, msgid_plural, n, ...args) {
  return ldnp('', null, msgid, msgid_plural, n, ...args);
}

/**
 * Translate with context
 * @param {string} msgctxt - Message context
 * @param {string} msgid - Message ID
 * @param {...any} args - sprintf arguments
 * @returns {string} Translated string
 */
export function lp(msgctxt, msgid, ...args) {
  return ldnp('', msgctxt, msgid, null, null, ...args);
}

/**
 * Translate with context and plural forms
 * @param {string} msgctxt - Message context
 * @param {string} msgid - Singular message ID
 * @param {string} msgid_plural - Plural message ID
 * @param {number} n - Count for plural selection
 * @param {...any} args - sprintf arguments
 * @returns {string} Translated string
 */
export function lnp(msgctxt, msgid, msgid_plural, n, ...args) {
  return ldnp('', msgctxt, msgid, msgid_plural, n, ...args);
}

/**
 * Translate with domain
 * @param {string} domain - Text domain
 * @param {string} msgid - Message ID
 * @param {...any} args - sprintf arguments
 * @returns {string} Translated string
 */
export function ld(domain, msgid, ...args) {
  return ldnp(domain, null, msgid, null, null, ...args);
}

/**
 * Translate with domain and plural forms
 * @param {string} domain - Text domain
 * @param {string} msgid - Singular message ID
 * @param {string} msgid_plural - Plural message ID
 * @param {number} n - Count for plural selection
 * @param {...any} args - sprintf arguments
 * @returns {string} Translated string
 */
export function ldn(domain, msgid, msgid_plural, n, ...args) {
  return ldnp(domain, null, msgid, msgid_plural, n, ...args);
}

/**
 * Translate with domain and context
 * @param {string} domain - Text domain
 * @param {string} msgctxt - Message context
 * @param {string} msgid - Message ID
 * @param {...any} args - sprintf arguments
 * @returns {string} Translated string
 */
export function ldp(domain, msgctxt, msgid, ...args) {
  return ldnp(domain, msgctxt, msgid, null, null, ...args);
}

/**
 * Translate with domain, context and plural forms (full form)
 * @param {string} domain - Text domain (empty string for current domain)
 * @param {string|null} msgctxt - Message context
 * @param {string} msgid - Singular message ID
 * @param {string|null} msgid_plural - Plural message ID
 * @param {number|null} n - Count for plural selection
 * @param {...any} args - sprintf arguments
 * @returns {string} Translated string
 */
export function ldnp(domain, msgctxt, msgid, msgid_plural, n, ...args) {
  const td = domain || currentDomain || '';

  // Add n to args if plural
  const allArgs = msgid_plural ? [n, ...args] : args;

  if (dryMode) {
    writeDry(domain || null, msgctxt, msgid, msgid_plural);
    const text = msgid_plural && n !== 1 ? msgid_plural : msgid;
    return sprintf(text, ...allArgs);
  }

  const translated = lookup(td, msgctxt, msgid, msgid_plural, n);
  return sprintf(translated, ...allArgs);
}

// ============================================================================
// Deferred-translation markers
// ============================================================================
//
// Runtime no-ops that exist so the scraper can treat them as msgid sources
// while render-time code stays in charge of the actual lookup. Use these
// where the locale is not yet known (module top-level, DSLs, class fields)
// and hand the stored msgid(s) to the matching l*() later. Plural variants
// return [sg, pl] so the caller can spread them into ln(...plur, n).

export function N_(msgid)                      { return msgid; }
export function Nn_(sg, pl)                    { return [sg, pl]; }
export function Np_(ctxt, msgid)               { return msgid; }
export function Nnp_(ctxt, sg, pl)             { return [sg, pl]; }
export function Nd_(domain, msgid)             { return msgid; }
export function Ndn_(domain, sg, pl)           { return [sg, pl]; }
export function Ndp_(domain, ctxt, msgid)      { return msgid; }
export function Ndnp_(domain, ctxt, sg, pl)    { return [sg, pl]; }

// ============================================================================
// Default export with all functions
// ============================================================================

export default {
  l_dir,
  l_lang,
  l_dry,
  l_nolocales,
  ltd,
  loadTranslations,
  loadLocaleData,
  l,
  ln,
  lp,
  lnp,
  ld,
  ldn,
  ldp,
  ldnp,
  N_,
  Nn_,
  Np_,
  Nnp_,
  Nd_,
  Ndn_,
  Ndp_,
  Ndnp_,
};
