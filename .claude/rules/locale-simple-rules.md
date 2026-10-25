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
| Implement / refactor / debug the Perl, Python or JavaScript runtime, the scraper, the CLI wrappers | `locale-simple-worker` (default) |
| The PHP, Go or Rust port | `locale-simple-php-worker`, `locale-simple-go-worker`, `locale-simple-rust-worker` |
| Write and extend the tests of the six suites | `locale-simple-test-writer` |
| Commits, `Changes`, card → done, pre-release audit | `locale-simple-release-manager` |
| Read-only research, audit, gap analysis | `locale-simple-worker` ("read-only, change nothing") |

Behavior-relevant = runtime behavior, the public helper API of the three packages, the
scraper's output, the tests. Pure prose docs and `Changes` notes are not. The lane split
in detail: skill `locale-simple-core`.

## Release

`prove -l t/`, `python python/test.py`, `npm test` and `dzil build` are fine anytime. One
release publishes three packages (CPAN, PyPI, npm): a PyPI upload and an npm publish fall
under the publish gate like the CPAN upload, and the npm publish runs asynchronously in CI
after the tag push — an unauthorized tag push is an irreversible release. The pre-release
audit goes through `locale-simple-release-manager`, which reports and never releases. The
npm package's `bugs` field points at the GitHub issues, so every issue is visible to every
consumer.

## Deviations from the house rules

- **No new card for a finding outside the current card** — write it as a note on the card
  in hand.

## Perl / Python / JavaScript specifics — reference, don't restate

Layout, build and test commands, the release path and the scraper quirks live in skill
`locale-simple-core`.
