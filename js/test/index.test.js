import { describe, it, beforeEach } from 'node:test';
import assert from 'node:assert';
import {
  l_dir,
  l_lang,
  l_dry,
  ltd,
  loadTranslations,
  l,
  ln,
  lp,
  lnp,
  ld,
  ldn,
  ldp,
  ldnp,
} from '../src/index.js';

// Test translations (German)
const testTranslations = {
  'Hello': 'Hallo',
  'You have %d message': ['Du hast %d Nachricht', 'Du hast %d Nachrichten'],
  'You have %d message from %s': ['Du hast %d Nachricht von %s', 'Du hast %d Nachrichten von %s'],
  '%2$s has %1$d messages': ['%2$s hat %1$d Nachricht', '%2$s hat %1$d Nachrichten'],
  'Order here %2$s %1$s': 'Andere Reihenfolge hier %2$s %1$s',
  'alien\u0004Hello': 'Hallo Ausserirdischer',
};

const otherTranslations = {
  'Goodbye': 'Auf Wiedersehen',
};

describe('Locale Simple', () => {
  beforeEach(() => {
    // Reset state by setting up fresh
    l_dir('test/data/locale');
    l_lang('de_DE');
    l_dry(false);
    loadTranslations('test', 'de_DE', testTranslations);
    loadTranslations('other', 'de_DE', otherTranslations);
    ltd('test');
  });

  describe('l() - simple translation', () => {
    it('should translate a simple string', () => {
      assert.strictEqual(l('Hello'), 'Hallo');
    });

    it('should return msgid if no translation found', () => {
      assert.strictEqual(l('Unknown'), 'Unknown');
    });

    it('should handle empty string', () => {
      assert.strictEqual(l(''), '');
    });
  });

  describe('ln() - plural translation', () => {
    it('should use singular form for n=1', () => {
      assert.strictEqual(ln('You have %d message', 'You have %d messages', 1), 'Du hast 1 Nachricht');
    });

    it('should use plural form for n>1', () => {
      assert.strictEqual(ln('You have %d message', 'You have %d messages', 4), 'Du hast 4 Nachrichten');
    });

    it('should use plural form for n=0', () => {
      assert.strictEqual(ln('You have %d message', 'You have %d messages', 0), 'Du hast 0 Nachrichten');
    });

    it('should handle additional sprintf arguments', () => {
      assert.strictEqual(
        ln('You have %d message from %s', 'You have %d messages from %s', 1, 'harry'),
        'Du hast 1 Nachricht von harry'
      );
      assert.strictEqual(
        ln('You have %d message from %s', 'You have %d messages from %s', 4, 'harry'),
        'Du hast 4 Nachrichten von harry'
      );
    });
  });

  describe('lp() - context translation', () => {
    it('should translate with context', () => {
      assert.strictEqual(lp('alien', 'Hello'), 'Hallo Ausserirdischer');
    });

    it('should fall back to msgid if context not found', () => {
      assert.strictEqual(lp('unknown_context', 'Hello'), 'Hello');
    });
  });

  describe('sprintf', () => {
    it('should handle positional arguments', () => {
      assert.strictEqual(l('Order here %2$s %1$s', 'one', 'two'), 'Andere Reihenfolge hier two one');
    });

    it('should handle positional arguments with plural', () => {
      assert.strictEqual(
        ln('%2$s has %1$d messages', '%2$s has %1$d messages', 4, 'harry'),
        'harry hat 4 Nachrichten'
      );
    });
  });

  describe('ld() - domain translation', () => {
    it('should translate from specified domain', () => {
      assert.strictEqual(ld('other', 'Goodbye'), 'Auf Wiedersehen');
    });

    it('should fall back to msgid if domain not found', () => {
      assert.strictEqual(ld('nonexistent', 'Hello'), 'Hello');
    });
  });

  describe('l_dry() - dry run mode', () => {
    it('should return untranslated string in dry mode', () => {
      l_dry(true, true);
      assert.strictEqual(l('Hello'), 'Hello');
    });

    it('should handle plural in dry mode', () => {
      l_dry(true, true);
      assert.strictEqual(ln('You have %d message', 'You have %d messages', 1), 'You have 1 message');
      assert.strictEqual(ln('You have %d message', 'You have %d messages', 4), 'You have 4 messages');
    });
  });
});

describe('sprintf implementation', () => {
  beforeEach(() => {
    l_dry(true, true); // Dry mode to test sprintf without translations
    ltd('test');
  });

  it('should handle %s string placeholder', () => {
    assert.strictEqual(l('Hello %s', 'World'), 'Hello World');
  });

  it('should handle %d integer placeholder', () => {
    assert.strictEqual(l('Count: %d', 42), 'Count: 42');
  });

  it('should handle %f float placeholder', () => {
    assert.strictEqual(l('Value: %.2f', 3.14159), 'Value: 3.14');
  });

  it('should handle %% escape', () => {
    assert.strictEqual(l('100%% complete'), '100% complete');
  });

  it('should handle width padding', () => {
    assert.strictEqual(l('|%5d|', 42), '|   42|');
    assert.strictEqual(l('|%-5d|', 42), '|42   |');
    assert.strictEqual(l('|%05d|', 42), '|00042|');
  });

  it('should handle positional arguments', () => {
    assert.strictEqual(l('%2$s %1$s', 'World', 'Hello'), 'Hello World');
  });

  it('should handle mixed positional and sequential', () => {
    assert.strictEqual(l('%2$s %s %1$s', 'A', 'B'), 'B A A');
  });
});
