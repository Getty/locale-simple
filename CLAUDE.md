# CLAUDE.md — locale-simple

**One codebase, three packages.** This repository publishes the same gettext
wrapper as a Perl CPAN distribution (`Locale-Simple`), a Python package
(`locale-simple`) and a JavaScript npm package (`locale-simple`). All three
implement the same helper API (`l`, `ln`, `lp`, `ld`, the `ld*` family, the
`l_dir` / `l_lang` configuration, the `N_` markers) — a change to one runtime is
usually a change to all three.

**`dist.ini` is the truth for the build and the release.** The `[@Author::GETTY]`
bundle drives the CPAN release, the Python bump and the Python upload; the npm
publish happens asynchronously in CI after the tag push.

Project knowledge — layout, build and test commands, the release path, the
scraper quirks, the house rules — lives in skill `locale-simple-core`.

## Delegation

Delegate behavior-relevant code to the right agent instead of touching it
yourself — principle and lane are in `.claude/rules/locale-simple-rules.md`.

| Task | Agent |
|---|---|
| Implement / refactor / debug the Perl, Python or JavaScript runtime, the scraper, the CLI wrappers | `locale-simple-worker` (default) |
| Write/extend the tests of the three suites | `locale-simple-test-writer` |
| Commits, `Changes`, card → done, pre-release audit | `locale-simple-release-manager` |

The agents carry their skills via `briefing.skills` (see `.claude/agents/`); the
main agent delegates rather than loading them. Skill sources live under
`.claude/skills/`.

## Tests

```bash
prove -l t/                      # Perl suite
python python/test.py            # Python suite
cd js && npm install && npm test # JavaScript suite
```

`prove -l` is mandatory: without it the installed CPAN release is loaded instead
of `lib/`.

## Skills

| Skill | Source | Purpose |
|---|---|---|
| `locale-simple-core` | this repository | project knowledge — architecture, release path, known drift |
| `getty-perl-core`, `getty-perl-moo`, `getty-perl-distribution`, `getty-git-commit-style`, `getty-git-usage`, `perl-release-dist-ini` | installed by `skilletor` | shared library conventions |
| `kanban-issues-karr-coordination`, `kanban-issues-karr-ticket` | installed by `skilletor` | the karr board |
| `perl-localization-with-locale-simple`, `python-localization-with-locale-simple`, `js-localization-with-locale-simple` | tracked in this repository | **usage** skills for consumers of locale-simple — not build skills |

The installed skills are build artefacts of `skilletor sync` — never edit them
here; change the source.
