<?php

declare(strict_types=1);

namespace Locale\Simple\Tests;

use Locale\Simple\Internal;
use PHPUnit\Framework\Attributes\DataProvider;
use PHPUnit\Framework\TestCase;

use function Locale\Simple\{l, ln, lp, lnp, ld, ldn, ldp, ldnp, ltd, l_dir, l_lang, l_dry, l_nolocales};
use function Locale\Simple\{N_, Nn_, Np_, Nnp_, Nd_, Ndn_, Ndp_, Ndnp_};

/**
 * Port of python/test.py plus the shared vectors of t/data/plural-forms.json
 * (spec: .claude/skills/locale-simple-core/references/mo-reader.md).
 */
final class SimpleTest extends TestCase
{
    private const LOCALE_DIR = __DIR__ . '/../../t/data/locale';

    protected function setUp(): void
    {
        Internal::reset();
        l_dir(self::LOCALE_DIR);
        ltd('test');
        l_lang('de_DE');
    }

    // ------------------------------------------------------------------
    // python/test.py
    // ------------------------------------------------------------------

    public function testApiParity(): void
    {
        foreach (['l', 'ln', 'lp', 'lnp', 'ld', 'ldn', 'ldp', 'ldnp',
                  'N_', 'Nn_', 'Np_', 'Nnp_', 'Nd_', 'Ndn_', 'Ndp_', 'Ndnp_',
                  'l_dir', 'l_lang', 'l_dry', 'l_nolocales', 'ltd'] as $name) {
            $this->assertTrue(function_exists("Locale\\Simple\\$name"), $name);
        }
    }

    public function testTranslate(): void
    {
        $this->assertSame('Hallo', l('Hello'));
        $this->assertSame('Du hast 4 Nachrichten', ln('You have %d message', 'You have %d messages', 4));
        $this->assertSame('Du hast 1 Nachricht', ln('You have %d message', 'You have %d messages', 1));
        $this->assertSame('Du hast 0 Nachrichten', ln('You have %d message', 'You have %d messages', 0));
        $this->assertSame('Du hast 1 Nachricht von harry', ln('You have %d message of %s', 'You have %d messages of %s', 1, 'harry'));
        $this->assertSame('Du hast 4 Nachrichten von harry', ln('You have %d message of %s', 'You have %d messages of %s', 4, 'harry'));
        $this->assertSame('1 Nachricht gebracht von harry', ln('%2$s brought %1$d message', '%2$s brought %1$d messages', 1, 'harry'));
        $this->assertSame('harry hat 4 Nachrichten', ln('%2$s has %1$d message', '%2$s has %1$d messages', 4, 'harry'));
        $this->assertSame('Andere Reihenfolge hier two one', l('Change order test %s %s', 'one', 'two'));
        $this->assertSame(
            'Verhalten aus http://perldoc.perl.org/functions/sprintf.html 3 1 1',
            l('Other change order test %s %s %s', 1, 2, 3)
        );
        $this->assertSame('Hallo Ausserirdischer', lp('alien', 'Hello'));
        $this->assertSame('', l(''));
    }

    public function testContextPlural(): void
    {
        $this->assertSame('You have 1 message', lnp('some_ctxt', 'You have %d message', 'You have %d messages', 1));
        $this->assertSame('You have 4 messages', lnp('some_ctxt', 'You have %d message', 'You have %d messages', 4));
    }

    public function testDomainSwitching(): void
    {
        ltd('othertest');
        ltd('test');
        $this->assertSame('Anderes Hallo', ld('othertest', 'Hello'));
        $this->assertSame('Du hast 4 AndereNachrichten', ldn('othertest', 'You have %d message', 'You have %d messages', 4));
        $this->assertSame('Du hast 1 AndereNachricht', ldn('othertest', 'You have %d message', 'You have %d messages', 1));
        $this->assertSame('Hello', ld('nonexistent', 'Hello'));
        $this->assertSame('Hello', ldp('othertest', 'no_such_ctxt', 'Hello'));
        $this->assertSame('Hallo', l('Hello'), 'the current domain is untouched by ld()');
    }

    public function testDryRun(): void
    {
        $file = tempnam(sys_get_temp_dir(), 'dry');
        try {
            l_dry($file);
            $this->assertSame('Hello World', l('Hello %s', 'World'));
            $this->assertSame('One 1', ln('One %d', 'Many %d', 1));
            $this->assertSame('Many 5', ln('One %d', 'Many %d', 5));
            $this->assertSame('Hello', ldp('dom', 'ctx', 'Hello'));
            $content = file_get_contents($file);
            $this->assertStringContainsString('msgid "Hello %s"', $content);
            $this->assertStringContainsString('msgid "One %d"', $content);
            $this->assertStringContainsString('msgid_plural "Many %d"', $content);
            $this->assertStringContainsString("# domain: dom\nmsgctxt \"ctx\"\nmsgid \"Hello\"\n\n", $content);
        } finally {
            unlink($file);
        }
    }

    public function testDryRunNowriteWritesNothing(): void
    {
        $file = tempnam(sys_get_temp_dir(), 'dry');
        try {
            l_dry($file, true);
            $this->assertSame('Hello', l('Hello'));
            $this->assertSame('', file_get_contents($file));
        } finally {
            unlink($file);
        }
    }

    public function testNolocalesMode(): void
    {
        // directory sanity check is real in PHP, unlike in JS
        Internal::reset();
        try {
            l('Hello');
            $this->fail('expected RuntimeException');
        } catch (\RuntimeException $e) {
            $this->assertSame('please set a locale directory with l_dir() before using other translate functions', $e->getMessage());
        }
        l_nolocales(true);
        $this->assertSame('Hello 1', l('Hello %d', 1));
        l_nolocales(false);
        l_dir(self::LOCALE_DIR);
        ltd('test');
        l_lang('de_DE');
        l_nolocales(true);
        $this->assertSame('Hallo', l('Hello'));
    }

    public function testLanguageSwitchingLifecycle(): void
    {
        $this->assertSame('Hallo', l('Hello'));
        l_lang('xx_YY');
        $this->assertSame('Hello', l('Hello'));
        l_lang('de_DE');
        $this->assertSame('Hallo', l('Hello'));
    }

    public function testDeferredMarkers(): void
    {
        $this->assertSame('Hello', N_('Hello'));
        $this->assertSame('Open', Np_('menu', 'Open'));
        $this->assertSame('Hi', Nd_('app', 'Hi'));
        $this->assertSame('Open', Ndp_('app', 'menu', 'Open'));
        $this->assertSame(['1 file', '%d files'], Nn_('1 file', '%d files'));
        $this->assertSame(['1 file', '%d files'], Nnp_('ctx', '1 file', '%d files'));
        $this->assertSame(['1 file', '%d files'], Ndn_('dom', '1 file', '%d files'));
        $this->assertSame(['1 file', '%d files'], Ndnp_('dom', 'ctx', '1 file', '%d files'));

        $label = N_('Hello');
        $this->assertSame('Hallo', l($label));
        $this->assertSame('Du hast 1 Nachricht', ln(...Nn_('You have %d message', 'You have %d messages'), ...[1]));
        $this->assertSame('Du hast 4 Nachrichten', ln(...Nn_('You have %d message', 'You have %d messages'), ...[4]));
    }

    public function testLdnpFullForm(): void
    {
        $this->assertSame('Anderes Hallo', ldnp('othertest', null, 'Hello', null, null));
        $this->assertSame('Hallo Ausserirdischer', ldnp('', 'alien', 'Hello', null, null));
    }

    // ------------------------------------------------------------------
    // sprintf
    // ------------------------------------------------------------------

    /** @return array<string, array{string, list<mixed>, string}> */
    public static function sprintfCases(): array
    {
        return [
            'positional' => ['%2$s %1$s', ['a', 'b'], 'b a'],
            'mixed positional and sequential' => ['%1$s %s', ['a', 'b'], 'a a'],
            'width' => ['[%5d]', [42], '[   42]'],
            'left width' => ['[%-5d]', [42], '[42   ]'],
            'zero pad' => ['[%05d]', [42], '[00042]'],
            'precision' => ['%.2f', [3.14159], '3.14'],
            'percent' => ['100%% %s', ['x'], '100% x'],
            'custom pad' => ["[%'*8s]", ['ab'], '[******ab]'],
            'plus flag' => ['%+d', [5], '+5'],
            'binary' => ['%b', [5], '101'],
            'octal' => ['%o', [8], '10'],
            'hex' => ['%x %X', [255, 255], 'ff FF'],
            'char' => ['%c', [65], 'A'],
            'unsigned' => ['%u', [3], '3'],
            'extra args ignored' => ['%s', ['a', 'b', 'c'], 'a'],
            'missing arg leaves the string' => ['%s and %s', ['a'], '%s and %s'],
            'missing positional arg' => ['%3$s', ['a'], '%3$s'],
            'no placeholders' => ['plain', [], 'plain'],
        ];
    }

    /**
     * @param list<mixed> $args
     */
    #[DataProvider('sprintfCases')]
    public function testSprintf(string $fmt, array $args, string $want): void
    {
        $this->assertSame($want, Internal::format($fmt, $args));
    }

    public function testMissingArgumentThroughL(): void
    {
        $this->assertSame('Du hast %d Nachricht', l('You have %d message'));
    }

    // ------------------------------------------------------------------
    // .mo reader
    // ------------------------------------------------------------------

    public function testMoReaderBadInput(): void
    {
        $good = file_get_contents(self::LOCALE_DIR . '/de_DE/LC_MESSAGES/test.mo');
        $this->assertNotNull(Internal::parseMo($good));
        $this->assertNull(Internal::parseMo(''));
        $this->assertNull(Internal::parseMo(str_repeat("\0", 64)));
        $this->assertNull(Internal::parseMo(substr($good, 0, 120)), 'truncated');
        $this->assertNull(Internal::parseMo(substr($good, 0, 4) . "\0\0\1\0" . substr($good, 8)), 'major revision 1');
    }

    public function testMoReaderBigEndian(): void
    {
        $mo = self::buildMo(['' => "Plural-Forms: nplurals=2; plural=n != 1;\n", 'Hello' => 'Hallo'], 'N');
        $cat = Internal::parseMo($mo);
        $this->assertSame(['Hallo'], $cat['entries']['Hello']);
    }

    public function testMoReaderContextAndPlural(): void
    {
        $cat = Internal::parseMo(file_get_contents(self::LOCALE_DIR . '/de_DE/LC_MESSAGES/test.mo'));
        $this->assertSame(['Hallo Ausserirdischer'], $cat['entries']["alien\x04Hello"]);
        $this->assertSame(['Du hast %d Nachricht', 'Du hast %d Nachrichten'], $cat['entries']['You have %d message']);
    }

    public function testEmptyMsgstrFallsThroughTheChain(): void
    {
        $dir = self::tempLocaleDir();
        self::writeMo($dir, 'de_AT', 'd', ['' => "Plural-Forms: nplurals=2; plural=n != 1;\n", 'Hi' => '']);
        self::writeMo($dir, 'de', 'd', ['' => "Plural-Forms: nplurals=2; plural=n != 1;\n", 'Hi' => 'Hallo']);
        l_dir($dir);
        ltd('d');
        l_lang('de_AT');
        $this->assertSame('Hallo', l('Hi'));
    }

    // ------------------------------------------------------------------
    // shared vectors
    // ------------------------------------------------------------------

    /** @return array<string, mixed> */
    private static function vectors(): array
    {
        return json_decode(file_get_contents(__DIR__ . '/../../t/data/plural-forms.json'), true, 512, JSON_THROW_ON_ERROR);
    }

    /** @return array<string, array{string, ?string, bool, list<array{int, int}>}> */
    public static function pluralRows(): array
    {
        $v = self::vectors();
        $rows = [];
        foreach ($v['plural_forms'] as $r) {
            $rows['forms ' . $r['lang']] = ['f_' . $r['lang'], $r['header'], false, $r['cases']];
        }
        foreach ($v['plural_edge_cases'] as $r) {
            $rows['edge ' . $r['name']] = ['e_' . $r['name'], $r['header'], $r['warns'], $r['cases']];
        }
        return $rows;
    }

    /**
     * @param list<array{int, int}> $cases
     */
    #[DataProvider('pluralRows')]
    public function testPluralVectors(string $tag, ?string $header, bool $warns, array $cases): void
    {
        $nplurals = preg_match('/nplurals\s*=\s*(\d+)/', (string) $header, $m) ? (int) $m[1] : 2;
        $forms = [];
        for ($k = 0; $k < $nplurals; $k++) {
            $forms[] = "form$k";
        }
        $entries = ['one' => implode("\0", $forms)];
        if ($header !== null) {
            $entries[''] = $header . "\n";
        }
        $dir = self::tempLocaleDir();
        self::writeMo($dir, 'xx', 'pf', $entries, ['one' => 'many']);

        $warnings = [];
        set_error_handler(static function (int $no, string $msg) use (&$warnings): bool {
            $warnings[] = $msg;
            return true;
        }, E_USER_WARNING);
        try {
            Internal::resetPluralWarning();
            l_dir($dir);
            ltd('pf');
            l_lang('xx');
            foreach ($cases as [$n, $idx]) {
                $this->assertSame("form$idx", ln('one', 'many', $n), "$tag n=$n");
            }
        } finally {
            restore_error_handler();
        }
        $this->assertCount($warns ? 1 : 0, $warnings, "$tag: one-time warning");
    }

    public function testPluralWarningOncePerProcess(): void
    {
        $warnings = [];
        set_error_handler(static function (int $no, string $msg) use (&$warnings): bool {
            $warnings[] = $msg;
            return true;
        }, E_USER_WARNING);
        try {
            Internal::resetPluralWarning();
            $dir = self::tempLocaleDir();
            self::writeMo($dir, 'aa', 'w', ['x' => 'y']);
            self::writeMo($dir, 'bb', 'w', ['x' => 'z'], [], 'Plural-Forms: nplurals=2; plural=n ** 2;');
            l_dir($dir);
            ltd('w');
            foreach (['aa', 'bb', 'aa'] as $lang) {
                l_lang($lang);
                l('x');
                ln('x', 'xs', 3);
            }
            l_lang('nothing');
            l('x');
        } finally {
            restore_error_handler();
        }
        $this->assertCount(1, $warnings);
    }

    /** @return array<string, array{string, list<string>}> */
    public static function fallbackRows(): array
    {
        $rows = [];
        foreach (self::vectors()['locale_fallback'] as $r) {
            $rows[json_encode($r['input'])] = [$r['input'], $r['candidates']];
        }
        return $rows;
    }

    /**
     * @param list<string> $candidates
     */
    #[DataProvider('fallbackRows')]
    public function testLocaleFallback(string $input, array $candidates): void
    {
        $this->assertSame($candidates, Internal::candidates($input));
    }

    /** @return array<string, array{array<string, string>, string}> */
    public static function envRows(): array
    {
        $rows = [];
        foreach (self::vectors()['env_resolution'] as $r) {
            $rows[json_encode($r['env'])] = [$r['env'], $r['effective']];
        }
        return $rows;
    }

    /**
     * @param array<string, string> $env
     */
    #[DataProvider('envRows')]
    public function testEnvResolution(array $env, string $effective): void
    {
        $this->assertSame($effective, Internal::effectiveLang($env, null));
    }

    public function testLLangWinsOverEnvironment(): void
    {
        $this->assertSame('fr', Internal::effectiveLang(['LANGUAGE' => 'de'], 'fr'));
    }

    // ------------------------------------------------------------------
    // helpers
    // ------------------------------------------------------------------

    private static function tempLocaleDir(): string
    {
        $dir = sys_get_temp_dir() . '/locale-simple-' . bin2hex(random_bytes(6));
        mkdir($dir);
        return $dir;
    }

    /**
     * @param array<string, string> $entries msgid => msgstr (plural forms NUL-joined)
     * @param array<string, string> $plurals msgid => msgid_plural
     */
    private static function writeMo(string $dir, string $lang, string $domain, array $entries, array $plurals = [], ?string $header = null): void
    {
        if ($header !== null) {
            $entries[''] = $header . "\n";
        }
        @mkdir("$dir/$lang/LC_MESSAGES", 0777, true);
        file_put_contents("$dir/$lang/LC_MESSAGES/$domain.mo", self::buildMo($entries, 'V', $plurals));
    }

    /**
     * @param array<string, string> $entries
     * @param array<string, string> $plurals
     */
    private static function buildMo(array $entries, string $f, array $plurals = []): string
    {
        $pairs = [];
        foreach ($entries as $id => $str) {
            $pairs[] = [isset($plurals[$id]) ? $id . "\0" . $plurals[$id] : (string) $id, $str];
        }
        usort($pairs, static fn ($a, $b) => strcmp($a[0], $b[0]));
        $n = count($pairs);
        $o = 28;
        $t = $o + 8 * $n;
        $pos = $t + 8 * $n;
        $otab = $ttab = $blob = '';
        foreach ($pairs as [$id, $str]) {
            $otab .= pack("{$f}2", strlen($id), $pos + strlen($blob));
            $blob .= $id . "\0";
            $ttab .= pack("{$f}2", strlen($str), $pos + strlen($blob));
            $blob .= $str . "\0";
        }
        return pack("{$f}7", 0x950412de, 0, $n, $o, $t, 0, 0) . $otab . $ttab . $blob;
    }
}
