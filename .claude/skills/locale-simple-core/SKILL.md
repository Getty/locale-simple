---
name: locale-simple-core
description: Load on any change to locale-simple — the Perl, Python and JavaScript implementations of the gettext wrapper, the source scraper, the test suites and the dzil release path with the npm publish in CI.
---

# locale-simple — project-specific architecture

The conventions in `CLAUDE.md` are the source of truth. This skill encodes what this
repository actually is: one codebase that ships three packages with one API. Apply
silently, do not restate.

## One source, three packages

The repository publishes the same gettext wrapper three times. The msgids and the
`.po` files are shared; only the runtime differs.

| Package | Path | Runtime |
|---|---|---|
| `Locale-Simple` (CPAN) | `lib/Locale/Simple.pm` | Perl, `Locale::TextDomain` / `Locale::gettext_dumb` |
| `locale-simple` (PyPI) | `python/locale_simple.py` | Python 3, stdlib `gettext` |
| `locale-simple` (npm) | `js/src/index.js` | JavaScript/TypeScript, own `gettext` implementation |

The helper names are identical in all three: `l`, `ln`, `lp`, `lnp`, `ld`, `ldn`,
`ldp`, `ldnp` (the `ld*` family takes the text domain first), plus the configuration
calls `l_dir`, `l_lang`, `l_dry`, `l_nolocales` and the text-domain lookup `ltd`.

The `N_` family (`N_`, `Nn_`, `Np_`, `Nnp_`, `Nd_`, `Ndn_`, `Ndp_`, `Ndnp_`) are
**deferred-translation markers**: at runtime they are identity stubs that return
their arguments unchanged. They exist so the scraper finds the msgids of strings
that must be declared before the viewer's locale is known (attribute defaults,
DSLs, constants); the stored msgid is passed through the matching `l*()` later.
Perl implements them as `sub N_ { $_[0] }` and friends; Python as `def N_(msgid)`.

**A change to one implementation is usually a change to all three.** The three
siblings must stay in step — that is the whole point of the repository.

## Layout

| Path | Purpose |
|---|---|
| `lib/Locale/Simple.pm` | Perl implementation and the exported helpers |
| `lib/Locale/Simple/Scraper.pm` | the source scraper, finds translation tokens in a directory |
| `lib/Locale/Simple/Scraper/Parser.pm` | `Parser::MGC`-based source parser |
| `lib/Locale/Simple/Scraper/ParserShortcuts.pm` | parser shortcuts, among them `with_ws` |
| `bin/locale_simple_scraper` | CLI wrapper around the scraper |
| `bin/po2json` | PO → JSON converter for the JavaScript consumer |
| `python/locale_simple.py`, `python/test.py`, `python/pyproject.toml` | Python package, its test and the PEP 517 config |
| `js/src/index.js`, `js/src/index.d.ts`, `js/test/`, `js/rollup.config.js` | JS package, types, `node:test` suite, bundler |
| `xbin/release.pl` | the Python version bump and upload, called from `dist.ini` |
| `t/` | Perl test suite |
| `dist.ini`, `cpanfile`, `Changes` | the `[@Author::GETTY]` release config and the changelog |

## Build and test

```bash
prove -l t/                              # Perl suite
python python/test.py                    # Python suite
cd js && npm install && npm test         # JavaScript suite
cd js && npm run build                   # JS bundles into js/dist/
```

`dist.ini` runs the Python and the JS suite alongside `dzil test` via two
`run_test` lines, so `dzil test` covers all three languages.

## The release path

`dzil release` runs the `[@Author::GETTY]` bundle with these hooks:

1. **`run_before_release`** — `python python/test.py`, the JS suite, then
   `xbin/release.pl python-prep %v` (bumps `python/locale_simple.py` to the Perl
   version) and `npm run build && npm pack --dry-run`.
2. **Git tag + `cpan upload`** — the Perl release proper.
3. **`run_after_release`** — `xbin/release.pl python-upload` uploads the Python
   artifacts built in step 1.
4. **Tag push** — `.github/workflows/publish-js.yml` fires on a `[0-9]*` tag,
   computes the npm version from the Perl tag, copies `Changes` to `js/CHANGELOG.md`,
   builds, tests and publishes with **npm Trusted Publishing (OIDC)**.

**Why JS is split off into CI.** npm requires OTP for publishing from a personal
account (classic Automation tokens were removed in December 2025, and the
granular-token "Bypass 2FA" option is broken for personal accounts — npm/cli#8869).
Keeping `npm publish` inside `dzil release` meant a missed OTP would leave CPAN and
PyPI uploaded but no git tag — a corrupt half-state. Now the JS publish is
asynchronous and can never poison the dzil release.

**The Python bump belongs to `run_before_release`, not after.** That way
`Git::Commit` (the release snapshot) folds the bumped `locale_simple.py` into the
release commit; the alternative leaves the bump dirty in the working tree until
someone commits it by hand. `commit_files_after_release = python/locale_simple.py`
makes that explicit — it is `@Git::VersionManager`'s hook and feeds
`Git::Commit`'s `allow_dirty`. Plain `Git::Commit.allow_dirty[]` does **not** work
as a bundle option.

Before a release, three things must hold:

- `~/.pypirc` carries a valid PyPI token (`__token__` + `pypi-*`).
- `Changes` has notes under `{{$NEXT}}`.
- The npm Trusted Publisher is configured for `locale-simple` → GitHub Actions,
  repo `Getty/locale-simple`, workflow `publish-js.yml`.

## The scraper

`Locale::Simple::Scraper` walks a directory and extracts translation tokens from
Perl, JavaScript, Python and Text::Xslate sources. `bin/locale_simple_scraper` is
its CLI wrapper. Two quirks are load-bearing:

- **`t/50-scrape.t` uses `Test::Regression`.** When the scraper's output changes on
  purpose, regenerate the references with
  `TEST_REGRESSION_GEN=1 prove -l t/50-scrape.t`.
- **The scraper must ignore `python`, `js`, `node_modules` and `author-pod-syntax.t`**
  (an ExtraTests artefact) — see the `@default` list in `t/50-scrape.t`. Without
  those, the scraper eats its own dog food.
- **`with_ws` must set both `$patterns{ws}` and `$patterns{_skip}`.** Newer
  `Parser::MGC` uses `_skip` (whitespace ∪ comment), so touching only `ws` is a
  no-op and the parsed strings lose their leading whitespace.

## House rules for this repository

- **Use `use Module;`** — `require` only for runtime plugin loading.
- **`->instance` for singletons**, `->new` otherwise.
- **Never copy `$VERSION` from a Getty-authored repository into a `cpanfile`** — pin
  to the latest released CPAN version (`cpanm --info ModuleName`).
- **Do not set the release branch in `dist.ini`** — the `[@Author::GETTY]` bundle
  defaults to `main`.

## The usage skills are canonical copies

`.claude/skills/` holds three **usage** skills for *consumers* of locale-simple,
not skills for working on this repository:

| Skill | Purpose |
|---|---|
| `perl-localization-with-locale-simple` | how to use `Locale::Simple` in a Perl app |
| `python-localization-with-locale-simple` | how to use `locale_simple` in a Python app |
| `js-localization-with-locale-simple` | how to use the npm package in a JS/TS app |

These are the canonical copies — other projects install them from here with
skilletor. Do not edit them here to change this repository; a change to the API
belongs in the implementation and in the usage skills together, but the usage skills
are edited in their own home.

## Known drift — reported, not fixed

Facts about the current tree, found by reading it. Findings for the maintainer, not
work items to repair on the side.

- **The Perl suite does not run on every box.** It needs `Locale::TextDomain`,
  `Locale::gettext_dumb`, `Parser::MGC` and the test modules `Test::InDistDir` and
  `Test::Regression`; without them every `t/*.t` aborts at compile time. That is an
  environment gap, not a defect.
- **`js/package.json` lists `CHANGELOG.md` in `files`, but `js/CHANGELOG.md` is
  gitignored** — it only exists in the npm tarball, written by the publish workflow
  from `Changes`.
- **`bin/locale_simple_scraper_old` is a leftover** of an earlier scraper version and
  is still tracked.
