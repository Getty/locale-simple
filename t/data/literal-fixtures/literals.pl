# Perl: a double-quoted literal that interpolates is not a msgid; the calls in
# its arguments still are. Escaped sigils and sigils without a name are text.
l("PL hello $name is not read %s", l("PL inner of interpolation"));
l("PL list @items is not read");
l("PL block ${name} is not read");
l("PL expression @{[ 1 + 1 ]} is not read");
l("PL mail user@example.com is not read");
l("PL joined " . "PL $name is not read");
ln("PL one $name is not read", "PL many", $n);
ln("PL one", "PL many @items is not read", $n);
lp("PL ctx $name", "PL context is not read");
l("PL escaped \$name and \@items and \${name} and %2\$s");
l("PL at @ sign, 100% and 5 \$");
l('PL single $name @items ${name}');
