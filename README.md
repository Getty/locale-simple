# Locale::Simple

**Locale::Simple** is a lightweight translation framework providing a consistent
gettext-based API across **Perl**, **Python**, and **JavaScript**. Write your
translatable strings the same way in any of the three languages, keep one
shared `.po`/`.mo` workflow, and ship.

| Language | Package | Install |
|---|---|---|
| Perl | [`Locale::Simple`](https://metacpan.org/pod/Locale::Simple) | `cpanm Locale::Simple` |
| Python | [`locale-simple`](https://pypi.org/project/locale-simple/) | `pip install locale-simple` |
| JavaScript | [`locale-simple`](https://www.npmjs.com/package/locale-simple) | `npm install locale-simple` |

## Usage

Setup is `l_dir` (locale directory) → `ltd` (text domain) → `l_lang`
(language). Then use `l`, `ln`, `lp`, `lnp`, `ld`, `ldn`, `ldp`, `ldnp` to
translate.

### Perl

```perl
use Locale::Simple;

l_dir('data/locale');
ltd('myapp');
l_lang('de_DE');

print l("Hello");                                               # "Hallo"
print ln("You have %d message", "You have %d messages", 4);     # "Du hast 4 Nachrichten"
```

### Python

```python
from locale_simple import *

l_dir('data/locale')
ltd('myapp')
l_lang('de_DE')

print(l("Hello"))                                               # "Hallo"
print(ln("You have %d message", "You have %d messages", 4))     # "Du hast 4 Nachrichten"
```

### JavaScript

```js
import { l_dir, l_lang, ltd, loadTranslations, l, ln } from 'locale-simple';

loadTranslations('myapp', 'de_DE', {
  'Hello': 'Hallo',
  'You have %d message': ['Du hast %d Nachricht', 'Du hast %d Nachrichten']
});

ltd('myapp');
l_lang('de_DE');

console.log(l("Hello"));                                        // "Hallo"
console.log(ln("You have %d message", "You have %d messages", 4)); // "Du hast 4 Nachrichten"
```

The JS build also ships a UMD bundle (`dist/locale-simple.umd.js`) for
dropping into a browser as a global `LocaleSimple`.

## API

### Setup

| Function | Purpose |
|---|---|
| `l_dir(dir)` | Set the locale directory (contains `<lang>/LC_MESSAGES/<domain>.mo`) |
| `ltd(domain)` | Set or switch the current text domain |
| `l_lang(lang)` | Set the active language (e.g. `de_DE`, `pt_BR`) |
| `l_dry(file, nowrite)` | Dry-run: write msgids to `file` instead of translating (Perl/Python) |
| `l_nolocales(x)` | Disable locale-dir requirement (Perl/Python) |

### Translation

| Function | Arguments |
|---|---|
| `l` | `msgid, ...args` |
| `ln` | `msgid, msgid_plural, n, ...args` |
| `lp` | `msgctxt, msgid, ...args` |
| `lnp` | `msgctxt, msgid, msgid_plural, n, ...args` |
| `ld` | `domain, msgid, ...args` |
| `ldn` | `domain, msgid, msgid_plural, n, ...args` |
| `ldp` | `domain, msgctxt, msgid, ...args` |
| `ldnp` | `domain, msgctxt, msgid, msgid_plural, n, ...args` |

Format strings follow `sprintf` conventions, including positional arguments
(`%1$s`, `%2$d`) — the JavaScript implementation matches the Perl/Python
behaviour.

### JavaScript-only helpers

| Function | Purpose |
|---|---|
| `loadTranslations(domain, lang, data)` | Register translations from a plain object |
| `loadLocaleData(domain, localeData)` | Load `po2json`-style locale data |

## String extraction (Perl)

The Perl distribution ships a `locale_simple_scraper` CLI that walks your
source tree (`.pl`, `.pm`, `.py`, `.js`, `.tx`) and emits a `.po` template with
every `l()`/`ln()`/… call it can statically resolve:

```bash
locale_simple_scraper --ignore node_modules --ignore build > messages.pot
```

## License

MIT — see [LICENSE](LICENSE).
