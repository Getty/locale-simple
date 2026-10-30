---
name: locale-simple-core
description: Load on any change to locale-simple — its six runtimes (Perl, Python, JS, PHP, Go, Rust), the scraper, the six test suites and the release path.
---

# locale-simple — project-specific architecture

The conventions in `CLAUDE.md` are the source of truth. This skill encodes what this
repository is: one codebase that ships six packages with one API. Apply silently, do
not restate.

## One source, six packages

The msgids and the `.po`/`.mo` files are shared; only the runtime differs.

| Package | Path | Runtime |
|---|---|---|
| `Locale-Simple` (CPAN) | `lib/Locale/Simple.pm` | Perl, `Locale::TextDomain` (libintl-perl) |
| `locale-simple` (PyPI) | `python/locale_simple.py` | Python 3, stdlib `gettext` |
| `locale-simple` (npm) | `js/src/index.js` | JavaScript/TypeScript, reads po2json JSON |
| `raudssus/locale-simple` (Packagist) | `php/src/Simple.php`, `composer.json` | PHP ≥ 8.0, own `.mo` reader |
| `github.com/Getty/locale-simple` (Go) | `go/`, root `go.mod` | Go ≥ 1.21, own `.mo` reader, package `simple` |
| `locale-simple` (crates.io) | `rust/` | Rust ≥ 1.67, own `.mo` reader, macros |

The helpers: `l`, `ln`, `lp`, `lnp`, `ld`, `ldn`, `ldp`, `ldnp` (the `ld*` family takes
the text domain first), the configuration `l_dir`, `l_lang`, `l_dry`, `l_nolocales`,
`ltd`, and the deferred markers `N_`, `Nn_`, `Np_`, `Nnp_`, `Nd_`, `Ndn_`, `Ndp_`,
`Ndnp_` — identity stubs that exist so the scraper finds msgids declared before the
locale is known. Go capitalises (`L`, `LDir`, …), Rust uses macros (`l!`, `n_!`, …);
the full parity table and the accepted asymmetries are `.claude/rules/language-parity.md`.

**A change to one runtime is a change to all six**, bar those asymmetries.

## Layout

| Path | Purpose |
|---|---|
| `lib/Locale/Simple.pm` | Perl implementation and the exported helpers |
| `lib/Locale/Simple/Scraper.pm`, `Scraper/Parser.pm`, `Scraper/ParserShortcuts.pm` | the source scraper on `Parser::MGC` |
| `bin/locale_simple_scraper`, `bin/po2json` | CLI wrappers: `.pot` extraction, `.po` → JSON for JavaScript |
| `python/` | `locale_simple.py`, `test.py`, `pyproject.toml`, `LICENSE` |
| `js/` | `src/index.js`, `src/index.d.ts`, `test/` (`node:test`), `rollup.config.js`, `LICENSE` |
| `php/`, `composer.json` | PHP package, PHPUnit suite |
| `go/`, `go.mod` | Go package and its tests |
| `rust/` | crate, tests, `LICENSE` |
| `t/`, `t/data/` | Perl suite and the fixtures every suite shares (`locale/de_DE/LC_MESSAGES/*.mo`, `plural-forms.json`) |
| `xbin/release.pl` | Python version bump, build and upload, called from `dist.ini` |
| `xbin/run-sibling-tests.pl` | runs the PHP, Go and Rust suites, skips a missing toolchain visibly |
| `.github/workflows/` | `test.yml` (all six suites), `publish-js.yml`, `publish-rust.yml` |
| `dist.ini`, `cpanfile`, `Changes` | the `[@Author::GETTY]` release config and the changelog |

## Build and test

```bash
prove -lr t/                                 # Perl (-l is mandatory)
python python/test.py                        # Python
cd js && npm install && npm test             # JavaScript
cd js && npm run build                       # JS bundles into js/dist/ (@rollup/wasm-node, any CPU)
composer install && composer test            # PHP
go test ./go/...                             # Go
cargo test --manifest-path rust/Cargo.toml   # Rust
```

`dzil test` runs all six: Python and JS through `run_test`, PHP, Go and Rust through
`xbin/run-sibling-tests.pl`. A skipped suite is not a passed one; CI runs all six.

## The release path

One tag publishes all six. The tag is `v%v.0` (`tag_format`), so Perl `0.200` is tag
`v0.200.0` — valid SemVer for npm, Go and crates.io.

1. **`run_before_release`** — the five sibling suites, `xbin/release.pl python-prep %v`
   (bumps `python/locale_simple.py`, `python -m build`, `twine check`), then
   `npm run build && npm pack --dry-run`.
2. **CPAN upload, release commit, tag, push** — the bundle; the GitHub release follows
   from `[GitHub::CreateRelease]`.
3. **`run_after_release`** — `xbin/release.pl python-upload` (twine, `~/.pypirc`).
4. **On the tag push** — `publish-js.yml` (npm) and `publish-rust.yml` (crates.io)
   take the version from the tag and publish with Trusted Publishing (OIDC).
   Packagist follows through its GitHub hook, the Go module proxy on the first fetch.

The Python bump runs before the release commit on purpose:
`commit_files_after_release = python/locale_simple.py` folds it into that commit.
npm and crates.io publish from CI so that a failing upload never leaves a half-done
dzil release.

The releasing box needs `python -m build`, `twine` and `~/.pypirc` with a PyPI token.
The registries need the npm Trusted Publisher (`publish-js.yml`), the crates.io
Trusted Publisher (`publish-rust.yml`) and the Packagist package with its GitHub hook.

`.gitattributes` shapes the Packagist download (GitHub zip = `git archive`): it keeps
`lib/`, `t/`, `python/`, `js/`, `bin/`, `xbin/` out and `composer.json`, `php/` in.
Check with `git archive --format=zip HEAD | zipinfo -1 -`. The Go module zip ignores
`export-ignore` and always holds the whole repository.

## The scraper

`Locale::Simple::Scraper` walks the current directory and extracts the calls of all
six languages plus Text::Xslate templates (`.pl .pm .t .py .js .php .go .rs .tx`).
The quirks that carry weight:

- **`t/50-scrape.t` uses `Test::Regression`.** When the output changes on purpose,
  regenerate with `TEST_REGRESSION_GEN=1 prove -l t/50-scrape.t` and read the
  `t/out/` diff. The test scrapes `lib/` too, so POD edits in `Locale::Simple` move
  `t/out/scrape_00_err`.
- **The `@default` list in `t/50-scrape.t` keeps out** `python`, `js`,
  `node_modules`, `xt/`, the generated `t/author-*`/`t/release-*` tests and every
  fixture directory (`n-`, `arg-`, `escape-`, `literal-fixtures`). A new fixture
  directory gets its `--ignore` there, or it moves the references.
- **Only constant literals become msgids.** The msgid, plural, context and domain
  must be literals in the language's own forms and escapes; interpolating literals
  (Perl `$`/`@`, PHP `$name`) and Python f-/b-strings are skipped and reported.
  The count and later arguments may be any code. `t/52`–`t/55` pin this per
  language; their fixtures were checked against the real interpreters.
- **`with_ws` sets both `$patterns{ws}` and `$patterns{_skip}`.** `Parser::MGC` skips
  `_skip` (whitespace and comments).
- **Go fixtures under `t/data/` start with `//go:build ignore`** — the root `go.mod`
  would compile them.

## House rules for this repository

- **Use `use Module;`** — `require` only for runtime plugin loading.
- **`->instance` for singletons**, `->new` otherwise.
- **Pin Getty-authored dependencies to their latest CPAN release** in `cpanfile`
  (`cpanm --info ModuleName`).
- **The release branch comes from the bundle** (`main`), not from `dist.ini`.

## The usage skills are canonical copies

`.claude/skills/{perl,python,js,php,go,rust}-localization-with-locale-simple` are
skills for *consumers* of locale-simple; other projects install them from here with
skilletor. A change to the public API updates the implementation and these six skills
together.

## References

- `.claude/rules/language-parity.md` — what stays in sync, the accepted asymmetries.
- `references/mo-reader.md` — the `.mo` reader, locale chain, Plural-Forms and
  sprintf specification for the runtimes with an own reader (PHP, Go, Rust, and
  JavaScript for the chain and the plural evaluator).
