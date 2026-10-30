import { describe, it } from 'node:test';
import assert from 'node:assert';
import { readFileSync } from 'node:fs';
import { l_lang, ltd, loadLocaleData, l, ln, lp } from '../src/index.js';

// The real output of bin/po2json for the shared Perl fixture. Own file, so the
// module state starts empty: index.test.js loads the same msgids under de_DE
// through loadTranslations and would mask where this bundle lands.
const raw = readFileSync(
  new URL('../../t/data/locale/de_DE/LC_MESSAGES/test.json', import.meta.url),
  'utf8'
);
const data = JSON.parse(
  raw.trim().replace(/^locale_data\['test'\]\s*=\s*/, '').replace(/;$/, '')
);

describe('loadLocaleData() with bin/po2json output', () => {
  loadLocaleData('test', { test: data });
  ltd('test');

  it('translates under the language of the bundle', () => {
    l_lang('de_DE');
    assert.strictEqual(l('Hello'), 'Hallo');
    assert.strictEqual(
      ln('You have %d message', 'You have %d messages', 4),
      'Du hast 4 Nachrichten'
    );
    assert.strictEqual(lp('alien', 'Hello'), 'Hallo Ausserirdischer');
  });

  it('stores the bundle under de_DE, not as the "" fallback', () => {
    l_lang('fr_FR');
    assert.strictEqual(l('Hello'), 'Hello');
    l_lang('de_DE');
    assert.strictEqual(l('Hello'), 'Hallo');
  });
});
