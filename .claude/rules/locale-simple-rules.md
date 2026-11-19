# locale-simple House Rules

The shared house rules come from skilletor — bundle `getty-cpan-dist@getty`: engineering
discipline, the delegation lock, the publish gate, karr coordination, CPAN release. They
load as `.claude/rules/.local.*.md`; if they are missing, run `skilletor sync` and publish
nothing until they load. This file adds what is true only here, and wins where it differs.

## What this repo is

One gettext wrapper published as six packages — Perl (CPAN `Locale-Simple`), Python, JavaScript
and Rust (`locale-simple`), PHP (`raudssus/locale-simple`) and Go
(`github.com/Getty/locale-simple`) — with the same helper API; a change to one runtime is
usually a change to all six, bar the asymmetries in `language-parity.md`. Read first: the exports, the immediate callers and the shared
helpers of every runtime you touch.

## Agent team

| Task | Agent |
|---|---|
| Perl runtime, the scraper (reads all six languages), `Locale::Simple::CLI`, `PO2JSON`, Perl code of `bin/*` | `locale-simple-worker` (default) |
| Python port: `python/`, the Python bump and build path | `locale-simple-python-worker` |
| JavaScript port: `js/`, `publish-js.yml` | `locale-simple-js-worker` |
| PHP, Go or Rust port | `locale-simple-php-worker`, `locale-simple-go-worker`, `locale-simple-rust-worker` |
| The standalone binary (PAR, `scripts/*binary*`, `release-binaries.yml`) | `locale-simple-binary-worker` |
| Tests of the six suites, `.github/workflows/test.yml` | `locale-simple-test-writer` |
| `README.md`, per-language READMEs, POD prose, the six usage skills | `locale-simple-doc-writer` |
| Review of a diff — spec, parity, quality (read-only) | `locale-simple-reviewer` |
| Commits, `Changes`, card → done, pre-release audit | `locale-simple-release-manager` |
| Read-only research, audit, gap analysis | `locale-simple-worker` ("read-only, change nothing") |

Each lane has exactly one owner; the `publish-rust.yml` workflow belongs to
`locale-simple-rust-worker`. `dist.ini`, `xbin/` and `.gitattributes` are the
release-manager's to audit; a change needed there goes to the main agent as a note.

Behavior-relevant = runtime behavior, the public helper API of the six packages, the
scraper's output, the tests. Pure prose docs and `Changes` notes are not. The lane split
in detail: skill `locale-simple-core`.

## Release

The six suites and `dzil build` are fine anytime. One release publishes six packages: CPAN
and PyPI from `dzil release`; npm and crates.io from CI on the tag push; Packagist and the
Go proxy from the tag itself. Every upload and every tag push falls under the publish gate
like the CPAN upload — an unauthorized tag push is an irreversible release. The pre-release
audit goes through `locale-simple-release-manager`, which reports and never releases. The
`bugs` fields of all six packages point at the GitHub issues, so every issue is visible to
every consumer.

## Hazards

- **A finding outside the current card is a note on the card in hand,** not a new card.
- **Nobody but the release-manager commits;** the reviewer changes nothing at all.
- **A new lane gets one agent and one row here;** a file with two owners is a bug in
  this table.

## Runtime specifics — reference, don't restate

Layout, build and test commands, the release path and the scraper quirks live in skill
`locale-simple-core`.
