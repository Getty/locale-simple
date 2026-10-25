#![deny(warnings)]

use locale_simple::internal::sprintf;

#[test]
fn sprintf_table() {
    let cases: Vec<(&str, Vec<&dyn std::fmt::Display>, &str)> = vec![
        ("%2$s %1$s", vec![&"a", &"b"], "b a"),
        ("%1$s %s", vec![&"a", &"b"], "a a"),
        ("[%5d]", vec![&42], "[   42]"),
        ("[%-5d]", vec![&42], "[42   ]"),
        ("[%05d]", vec![&42], "[00042]"),
        ("[%05d]", vec![&-42], "[-0042]"),
        ("%.2f", vec![&1.23456], "1.23"),
        ("%f", vec![&1.5], "1.500000"),
        ("%F", vec![&1.5], "1.500000"),
        ("%e", vec![&1234.5], "1.234500e+03"),
        ("%.1e", vec![&0.00012], "1.2e-04"),
        ("100%% %s", vec![&"x"], "100% x"),
        ("[%'*8s]", vec![&"ab"], "[******ab]"),
        ("[%-'*8s]", vec![&"ab"], "[ab******]"),
        ("%+d %+d", vec![&5, &-5], "+5 -5"),
        ("% d", vec![&5], " 5"),
        ("%b %o %x %X", vec![&5, &8, &255, &255], "101 10 ff FF"),
        ("%c", vec![&65], "A"),
        ("%u", vec![&3], "3"),
        ("%.3s", vec![&"abcdef"], "abc"),
        ("%d", vec![&"12"], "12"),
        ("%d", vec![&3.9], "3"),
        ("%s", vec![&"a", &"b", &"c"], "a"),
        ("%s and %s", vec![&"a"], "a and %s"),
        ("%3$s", vec![&"a"], "%3$s"),
        ("%2$05d", vec![&0, &7], "00007"),
        ("50% off", vec![], "50% off"),
        ("%y", vec![&"a"], "%y"),
        ("plain", vec![], "plain"),
        ("héllo %s", vec![&"wörld"], "héllo wörld"),
        ("[%4s]", vec![&"é"], "[   é]"),
    ];
    for (fmt, args, want) in cases {
        assert_eq!(sprintf(fmt, &args), want, "sprintf({:?})", fmt);
    }
}
