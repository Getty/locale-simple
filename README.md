# Locale::Simple

**Locale::Simple** is a lightweight translation framework providing a consistent
gettext-based API across **Perl**, **Python**, **JavaScript**, **PHP**, **Go**
and **Rust**. Write your translatable strings the same way in any of the six
languages, keep one shared `.po`/`.mo` workflow, and ship.

| Language | Package | Install |
|---|---|---|
| Perl | [`Locale::Simple`](https://metacpan.org/pod/Locale::Simple) | `cpanm Locale::Simple` |
| Python | [`locale-simple`](https://pypi.org/project/locale-simple/) | `pip install locale-simple` |
| JavaScript | [`locale-simple`](https://www.npmjs.com/package/locale-simple) | `npm install locale-simple` |
| PHP | [`raudssus/locale-simple`](https://packagist.org/packages/raudssus/locale-simple) | `composer require raudssus/locale-simple` |
| Go | [`github.com/Getty/locale-simple`](https://pkg.go.dev/github.com/Getty/locale-simple/go) | `go get github.com/Getty/locale-simple` |
| Rust | [`locale-simple`](https://crates.io/crates/locale-simple) | `cargo add locale-simple` |

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

### PHP

```php
use function Locale\Simple\{l, ln, l_dir, ltd, l_lang};

l_dir('data/locale');
ltd('myapp');
l_lang('de_DE');

echo l('Hello');                                               // "Hallo"
echo ln('You have %d message', 'You have %d messages', 4);     // "Du hast 4 Nachrichten"
```

### Go

Go exports capitalised names only, so the helpers are `L`, `Ln`, `Lp`, ...

```go
import ls "github.com/Getty/locale-simple/go"

ls.LDir("data/locale")
ls.Ltd("myapp")
ls.LLang("de_DE")

ls.L("Hello")                                                  // "Hallo"
ls.Ln("You have %d message", "You have %d messages", 4)        // "Du hast 4 Nachrichten"
```

### Rust

Rust has no variadic functions, so the helpers are macros, and the deferred
markers are lower-case (`n_!`, `nn_!`, ...).

```rust
use locale_simple::{l, ln, l_dir, ltd, l_lang};

l_dir("data/locale");
ltd("myapp");
l_lang("de_DE");

l!("Hello");                                                   // "Hallo"
ln!("You have %d message", "You have %d messages", 4);         // "Du hast 4 Nachrichten"
```

## API

### Setup

| Function | Purpose |
|---|---|
| `l_dir(dir)` | Set the locale directory (contains `<lang>/LC_MESSAGES/<domain>.mo`) |
| `ltd(domain)` | Set or switch the current text domain |
| `l_lang(lang)` | Set the active language (e.g. `de_DE`, `pt_BR`) |
| `l_dry(file, nowrite)` | Dry-run: write msgids to `file` instead of translating (all but JavaScript, which logs to `console.debug`) |
| `l_nolocales(x)` | Disable locale-dir requirement (a no-op in JavaScript) |

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
| `loadTranslations(domain, lang, data, pluralForms?)` | Register translations from a plain object; `pluralForms` is a `Plural-Forms` header value (default `n != 1`) |
| `loadLocaleData(domain, localeData)` | Register `po2json` output; the language and the plural rule come from its header |

## String extraction

The Perl distribution ships `locale_simple_scraper`. It walks the current
directory and writes a `.pot` template with every `l()`/`ln()`/… call and every
`N_` marker it can resolve statically — for all six languages in one run:
`.pl`, `.pm`, `.t`, `.py`, `.js`, `.php`, `.go`, `.rs` and Text::Xslate `.tx`
files.

```bash
locale_simple_scraper --ignore node_modules --ignore vendor > messages.pot
```

`--pl`, `--py`, `--js`, `--php`, `--go`, `--rs` and `--tx` add file extensions
to a language (`--js mjs,ts`); `perldoc locale_simple_scraper` lists all
options.

## JavaScript: `.po` to JSON

The JavaScript package reads JSON instead of `.mo` files. `po2json`, also part
of the Perl distribution, converts a `.po` file:

```bash
po2json data/locale/de_DE/LC_MESSAGES/myapp.po > myapp.de_DE.json
```

```js
import { loadLocaleData, ltd, l_lang, l } from 'locale-simple';
import de from './myapp.de_DE.json' with { type: 'json' };

loadLocaleData('myapp', { myapp: de });   // language and plural rule from the header
ltd('myapp');
l_lang('de_DE');
```

## License

MIT — see [LICENSE](LICENSE).
