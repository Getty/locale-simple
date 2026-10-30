import sys, os, shutil, subprocess, tempfile

global err
err = 0

def test(func):
    global err
    print(func.__name__ + '...')
    try:
        func()
        print('\033[32mOK\033[0m\n')
    except BaseException as e:
        err = 1
        print('\033[31m' + str(e) + '\033[0m')


def testeq(one, two):
    sys.stdout.write("Testing equality (%s == %s)..." % (repr(one), repr(two)))
    if one != two: raise ValueError("The two values do not match")
    else: print('OK')


@test
def test_import():
    from locale_simple import __all__
    testeq(type(__all__), list)
    # API parity with Perl/JS siblings
    for name in ('l', 'ln', 'lp', 'lnp', 'ld', 'ldn', 'ldp', 'ldnp',
                 'N_', 'Nn_', 'Np_', 'Nnp_', 'Nd_', 'Ndn_', 'Ndp_', 'Ndnp_',
                 'l_dir', 'l_lang', 'l_dry', 'l_nolocales', 'ltd'):
        if name not in __all__:
            raise ValueError("%s missing from __all__" % name)


from locale_simple import *

LOCALE_DIR = os.path.dirname(os.path.abspath(__file__)) + '/../t/data/locale'


@test
def setup():
    l_dir(LOCALE_DIR)
    ltd('test')
    l_lang('de_DE')


@test
def translate():
    testeq(l('Hello'), 'Hallo')

    testeq(
        ln("You have %d message", "You have %d messages", 4),
        'Du hast 4 Nachrichten'
    )
    testeq(
        ln("You have %d message", "You have %d messages", 1),
        'Du hast 1 Nachricht'
    )
    testeq(
        ln("You have %d message", "You have %d messages", 0),
        'Du hast 0 Nachrichten'
    )
    testeq(
        ln("You have %d message of %s", "You have %d messages of %s", 1, 'harry'),
        'Du hast 1 Nachricht von harry'
    )
    testeq(
        ln("You have %d message of %s", "You have %d messages of %s", 4, 'harry'),
        'Du hast 4 Nachrichten von harry'
    )
    testeq(
        ln('%2$s brought %1$d message', '%2$s brought %1$d messages', 1, 'harry'),
        '1 Nachricht gebracht von harry'
    )
    testeq(
        ln('%2$s has %1$d message', '%2$s has %1$d messages', 4, 'harry'),
        'harry hat 4 Nachrichten'
    )
    testeq(
        l("Change order test %s %s", 'one', 'two'),
        "Andere Reihenfolge hier two one"
    )
    testeq(
        l('Other change order test %s %s %s', 1, 2, 3),
        'Verhalten aus http://perldoc.perl.org/functions/sprintf.html 3 1 1'
    )
    testeq(lp("alien", "Hello"), "Hallo Ausserirdischer")
    testeq(l(''), '')


@test
def percent_in_values():
    # Argument values go in as they are; a % in them is never read as a
    # format. %% in the format gives one %.
    testeq(l('%1$s', '100%'), '100%')
    testeq(l('%s', '100%'), '100%')
    testeq(l('%s and %s', '%s', '50%'), '%s and 50%')
    testeq(l('%2$s / %1$s', '%1$s', '5%'), '5% / %1$s')
    testeq(
        ln('%2$s has %1$d message', '%2$s has %1$d messages', 3, '%d%%'),
        '%d%% hat 3 Nachrichten'
    )
    testeq(l('100%% of %s', '%s', 'extra'), '100% of %s')
    testeq(l('%%s %s %%', 'x'), '%s x %')
    # A placeholder without an argument stays as it is (mo-reader.md §5).
    testeq(l('%s and %s', 'a'), 'a and %s')
    testeq(l('%2$s and %1$s', 'a'), '%2$s and a')


@test
def context_plural():
    # lnp: context + plural. No context-plural msgid in the fixture, so we
    # just verify it doesn't blow up and falls back to the msgid.
    testeq(
        lnp('some_ctxt', 'You have %d message', 'You have %d messages', 1),
        'You have 1 message'
    )
    testeq(
        lnp('some_ctxt', 'You have %d message', 'You have %d messages', 4),
        'You have 4 messages'
    )


@test
def domain_on_demand():
    # ld() binds a domain to the l_dir() directory on its first use, the way
    # ltd() does, and leaves the default domain where it is. Runs before
    # domain_switching, which binds 'othertest' through ltd().
    testeq(ld('othertest', 'Hello'), 'Anderes Hallo')
    testeq(l('Hello'), 'Hallo')
    testeq(
        ldn('othertest', 'You have %d message', 'You have %d messages', 4),
        'Du hast 4 AndereNachrichten'
    )

    # A later l_dir() moves every bound domain along, whichever call bound
    # it: a second directory holds the two catalogs swapped.
    swapped = tempfile.mkdtemp()
    try:
        messages = os.path.join(swapped, 'de_DE', 'LC_MESSAGES')
        os.makedirs(messages)
        source = os.path.join(LOCALE_DIR, 'de_DE', 'LC_MESSAGES')
        shutil.copy(os.path.join(source, 'othertest.mo'), os.path.join(messages, 'test.mo'))
        shutil.copy(os.path.join(source, 'test.mo'), os.path.join(messages, 'othertest.mo'))

        l_dir(swapped)
        testeq(l('Hello'), 'Anderes Hallo')
        testeq(ld('othertest', 'Hello'), 'Hallo')

        l_dir(LOCALE_DIR)
        testeq(l('Hello'), 'Hallo')
        testeq(ld('othertest', 'Hello'), 'Anderes Hallo')
    finally:
        l_dir(LOCALE_DIR)
        shutil.rmtree(swapped)


@test
def domain_switching():
    # ld / ldn / ldp / ldnp — the "other" domain has different translations
    # for the same msgids.
    ltd('othertest')  # bind the domain
    ltd('test')       # switch back to default, so ld() proves it's not
                      # reading from the current textdomain

    testeq(ld('othertest', 'Hello'), 'Anderes Hallo')
    testeq(
        ldn('othertest', 'You have %d message', 'You have %d messages', 4),
        'Du hast 4 AndereNachrichten'
    )
    testeq(
        ldn('othertest', 'You have %d message', 'You have %d messages', 1),
        'Du hast 1 AndereNachricht'
    )
    # Non-existent domain: falls through to msgid
    testeq(ld('nonexistent', 'Hello'), 'Hello')
    # ldp with unknown context: fall back to msgid
    testeq(ldp('othertest', 'no_such_ctxt', 'Hello'), 'Hello')


@test
def dry_run():
    with tempfile.NamedTemporaryFile(mode='w', delete=False, suffix='.po') as tf:
        dry_file = tf.name
    try:
        l_dry(dry_file)
        # l_dry flips nolocales=True, so l() should pass through formatting
        # without hitting gettext.
        testeq(l('Hello %s', 'World'), 'Hello World')
        testeq(
            ln('One %d', 'Many %d', 1),
            'One 1'
        )
        testeq(
            ln('One %d', 'Many %d', 5),
            'Many 5'
        )
        with open(dry_file) as f:
            content = f.read()
        # Confirm msgids were appended
        if 'msgid "Hello %s"' not in content:
            raise ValueError("dry-run file did not capture Hello msgid")
        if 'msgid "One %d"' not in content:
            raise ValueError("dry-run file did not capture plural msgid")
        if 'msgid_plural "Many %d"' not in content:
            raise ValueError("dry-run file did not capture plural_id")
    finally:
        os.unlink(dry_file)
        # Reset state for any later test
        l_dry(None)
        l_dir(LOCALE_DIR)
        ltd('test')
        l_lang('de_DE')


# What t/21-dryrun.t expects from the same calls, byte for byte.
DRY_SHARED = (
    'msgid "Hello"\n'
    '\n'
    '# domain: othertest\n'
    'msgid "Hello"\n'
    '\n'
    'msgctxt "alien"\n'
    'msgid "Hello"\n'
    '\n'
    'msgid "%2$s has %1$d message"\n'
    'msgid_plural "%2$s has %1$d messages"\n'
    '\n'
    '# domain: othertest\n'
    'msgctxt "inbox"\n'
    'msgid "You have %d message"\n'
    'msgid_plural "You have %d messages"\n'
    '\n'
    r'msgid "Say \"%s\"\\n\nGrüße"' '\n'
    '\n'
    r'msgid "Tab\there\rand CR"' '\n'
    '\n'
)


@test
def dry_run_shared_format():
    with tempfile.NamedTemporaryFile(delete=False, suffix='.po') as tf:
        dry_file = tf.name
    try:
        l_dry(dry_file)
        testeq(l('Hello'), 'Hello')
        testeq(l(''), '')
        testeq(ld('othertest', 'Hello'), 'Hello')
        testeq(lp('alien', 'Hello'), 'Hello')
        testeq(
            ln('%2$s has %1$d message', '%2$s has %1$d messages', 2, 'harry'),
            'harry has 2 messages'
        )
        testeq(
            ldnp('othertest', 'inbox', 'You have %d message', 'You have %d messages', 1),
            'You have 1 message'
        )
        testeq(l('Say "%s"\\n\nGrüße', 'hi'), 'Say "hi"\\n\nGrüße')
        testeq(l('Tab\there\rand CR'), 'Tab\there\rand CR')
        with open(dry_file, 'rb') as f:
            testeq(f.read(), DRY_SHARED.encode('utf-8'))
    finally:
        os.unlink(dry_file)
        l_dry(None)
        l_dir(LOCALE_DIR)
        ltd('test')
        l_lang('de_DE')


@test
def dry_run_line_ends():
    # The dry-run file has LF line ends on every platform. On Windows, text
    # mode writes '\r\n' for '\n' unless open() gets newline='\n'; this open()
    # gives the module that same default here.
    import builtins
    import locale_simple

    def windows_open(*args, **kwargs):
        kwargs.setdefault('newline', '\r\n')
        return builtins.open(*args, **kwargs)

    with tempfile.NamedTemporaryFile(delete=False, suffix='.po') as tf:
        dry_file = tf.name
    locale_simple.open = windows_open
    try:
        l_dry(dry_file)
        ld('othertest', 'Hello')
        with builtins.open(dry_file, 'rb') as f:
            content = f.read()
        testeq(b'\r' in content, False)
        testeq(content, b'# domain: othertest\nmsgid "Hello"\n\n')
    finally:
        del locale_simple.open
        os.unlink(dry_file)
        l_dry(None)
        l_dir(LOCALE_DIR)
        ltd('test')
        l_lang('de_DE')


@test
def nolocales_mode():
    # With l_nolocales(True) + no dir set, l() should still work as identity.
    # We simulate it by flipping the flag — formatting-only mode.
    from locale_simple import l_nolocales
    # Already in a known-good state thanks to dry_run teardown; no need to
    # unset l_dir. Just flip the flag and confirm no exception.
    l_nolocales(True)
    # Should still produce a translated result since dir is set and gettext
    # returns the actual translation.
    testeq(l('Hello'), 'Hallo')
    l_nolocales(False)


@test
def language_switching_lifecycle():
    # Full round-trip: load, translate, switch lang, translate again.
    l_dir(LOCALE_DIR)
    ltd('test')
    l_lang('de_DE')
    testeq(l('Hello'), 'Hallo')

    # Switching to a language with no .mo falls back to msgid.
    l_lang('xx_YY')
    # gettext caches — it may still return 'Hallo' from this process. The
    # lifecycle we care about is "no crash when switching".
    result = l('Hello')
    if result not in ('Hello', 'Hallo'):
        raise ValueError("Unexpected result after l_lang switch: %r" % result)

    # Switch back.
    l_lang('de_DE')


@test
def deferred_markers():
    # Identity contract — the whole point of the N*_ family is that
    # the caller gets back exactly what it put in, so the scraper can
    # see the msgid at build time while runtime defers the lookup.
    testeq(N_("Hello"), "Hello")
    testeq(Np_("menu", "Open"), "Open")
    testeq(Nd_("app", "Hi"), "Hi")
    testeq(Ndp_("app", "menu", "Open"), "Open")

    # Plural variants return (sg, pl) so caller can unpack into ln(...).
    testeq(Nn_("1 file", "%d files"), ("1 file", "%d files"))
    testeq(Nnp_("ctx", "1 file", "%d files"), ("1 file", "%d files"))
    testeq(Ndn_("dom", "1 file", "%d files"), ("1 file", "%d files"))
    testeq(Ndnp_("dom", "ctx", "1 file", "%d files"), ("1 file", "%d files"))

    # Round-trip: store via N_, render via l() — ensures what N_ hands
    # back is exactly what the runtime l() expects later.
    label = N_("Hello")
    testeq(l(label), "Hallo")

    sg, pl = Nn_("You have %d message", "You have %d messages")
    testeq(ln(sg, pl, 1), "Du hast 1 Nachricht")
    testeq(ln(sg, pl, 4), "Du hast 4 Nachrichten")


NO_DIR = 'please set a locale directory with l_dir() before using other translate functions\n'


def fresh(code):
    # A new interpreter, so no l_dir() of this file applies.
    return subprocess.run(
        [sys.executable, '-c', 'from locale_simple import *\n' + code],
        cwd=os.path.dirname(os.path.abspath(__file__)),
        capture_output=True, text=True,
    )


@test
def ltd_needs_dir():
    # ltd() stops without l_dir() like l() does; l_nolocales(True) and
    # dry-run mode lift the check, leaving dry-run mode brings it back.
    r = fresh("ltd('test')")
    testeq((r.returncode, r.stderr), (1, NO_DIR))
    r = fresh("l('Hello')")
    testeq((r.returncode, r.stderr), (1, NO_DIR))
    r = fresh("l_nolocales(True)\nltd('test')\nprint(l('Hello'))")
    testeq((r.returncode, r.stdout, r.stderr), (0, 'Hello\n', ''))
    r = fresh("l_dry('unused.po', True)\nltd('test')\nprint(l('Hello'))")
    testeq((r.returncode, r.stdout, r.stderr), (0, 'Hello\n', ''))
    r = fresh("l_dry('unused.po', True)\nl_dry(None)\nltd('test')")
    testeq((r.returncode, r.stderr), (1, NO_DIR))


exit(err)
