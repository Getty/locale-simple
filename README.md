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

## Command line tools

The Perl distribution ships one command, `locale-simple`, with two subcommands.
`locale-simple help` prints the usage, `locale-simple scrape --help` the scrape
options.

### `locale-simple scrape`

Walks the current directory and writes a `.pot` template with every
`l()`/`ln()`/… call and every `N_` marker it can resolve statically, for all
six languages in one run: `.pl`, `.pm`, `.t`, `.py`, `.js`, `.php`, `.go`,
`.rs` and Text::Xslate `.tx` files. The template goes to STDOUT, the progress
and parse problems to STDERR.

```bash
locale-simple scrape --ignore node_modules --ignore vendor > messages.pot
```

`--pl`, `--py`, `--js`, `--php`, `--go`, `--rs` and `--tx` add file extensions
to a language (`--js mjs,ts`). `--only REGEX` limits the walk,
`--no_line_numbers` leaves out the `#:` location comments and
`--output po|perl|json|yaml` picks the format (`yaml` needs the Perl install
with the `YAML` module; the binary writes po, perl and json). The options are
listed by `locale-simple scrape --help`. The exit code is `0`, also when the
parser reports problems in a source file, `1` when the scrape itself fails and
`2` for a bad call (unknown option, unknown `--output` format).

`locale_simple_scraper` takes the same options and remains available under
its name.

### `locale-simple po2json`

The JavaScript package reads JSON instead of `.mo` files. `po2json` converts a
`.po` file to that JSON. Like `msgfmt`, it keeps no untranslated, fuzzy or
obsolete entries.

```bash
locale-simple po2json data/locale/de_DE/LC_MESSAGES/myapp.po > myapp.de_DE.json
locale-simple po2json --domain shop --pretty myapp.po > shop.de_DE.json
```

The output is wrapped as `{ "<domain>": ... }`. The domain defaults to the
file name without `.po` (`myapp` above); `--domain NAME` sets it and
`--pretty` indents the output.

The exit codes of `locale-simple` are `0` for success, `1` when a command
fails (a PO file that cannot be read or parsed) and `2` for a bad call (a
missing or unknown command, bad options or arguments).

```js
import { loadLocaleData, ltd, l_lang, l } from 'locale-simple';
import de from './myapp.de_DE.json' with { type: 'json' };

loadLocaleData('myapp', de);   // language and plural rule from the header
ltd('myapp');
l_lang('de_DE');
```

The `po2json FILE` command remains as well and writes the bare data without
the domain wrapper; hand it to `loadLocaleData` as `{ myapp: data }`.
`po2json -p FILE` writes it indented and wrapped in the file name as the
domain.

### Binary (no Perl needed)

Each GitHub release carries `locale-simple` as one standalone binary per
platform. It is the same command as above (`scrape`, `po2json`, `help`,
`--version`) with Perl and every module packed in; `scrape` writes po, perl and
json (`--output yaml` needs the Perl install with `YAML`).

| Platform | Asset (`<V>` is the release version, e.g. `0.200.0`) |
|---|---|
| Linux x86_64 | `locale-simple-<V>-linux-x86_64` |
| Linux aarch64 | `locale-simple-<V>-linux-aarch64` |
| macOS arm64 (Apple Silicon) | `locale-simple-<V>-macos-arm64` |

Each asset also comes as `.tar.gz` (a directory `locale-simple-<V>-<platform>/`
with `locale-simple`, `LICENSE` and `README`), and `locale-simple-<V>-checksums.txt`
holds the `sha256sum` line of every asset. The bare binary arrives without the
executable bit, as HTTP downloads carry no file mode; `install -m 755` (or
`chmod +x`) sets it, and the `.tar.gz` keeps it.

```bash
V=0.200.0 P=linux-x86_64
base=https://github.com/Getty/locale-simple/releases/download/v$V
curl -fLO "$base/locale-simple-$V-$P"
curl -fLO "$base/locale-simple-$V-checksums.txt"
grep " locale-simple-$V-$P\$" "locale-simple-$V-checksums.txt" | sha256sum -c
mkdir -p ~/.local/bin
install -m 755 "locale-simple-$V-$P" ~/.local/bin/locale-simple
locale-simple --version
```

On macOS, `shasum -a 256 -c` takes the place of `sha256sum -c`.

Linux needs glibc 2.31 or newer (Debian 11+, Ubuntu 20.04+, RHEL/Rocky/Alma 9)
and `libcrypt.so.1` (`libcrypt`). Debian and Ubuntu always carry it; on RHEL,
Rocky, Alma, Fedora, Amazon Linux and Arch install `libxcrypt-compat`. The
macOS binary runs on Apple Silicon (checked on macOS 14 and 15) and needs
nothing installed. It is unsigned: after a browser download clear the
quarantine flag with `xattr -d com.apple.quarantine locale-simple` (a `curl`
download sets no flag).

The first start unpacks the packed Perl into a cache under the temp
directory; later starts reuse it. Other systems (Windows, older glibc, Intel
Macs) use the Perl distribution: `cpanm Locale::Simple` installs the same
`locale-simple` command.

## License

MIT — see [LICENSE](LICENSE).
