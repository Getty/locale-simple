requires 'perl', '5.020';
requires 'curry';
requires 'IO::All', '0.41';
requires 'JSON::PP', '2.27';
requires 'Locale::TextDomain', '1.23';
requires 'Moo';
requires 'Parser::MGC';
requires 'Try::Tiny';
recommends 'YAML';

on test => sub {
    requires 'Capture::Tiny';
    requires 'File::pushd';
    requires 'Path::Tiny';
    requires 'Test::Fatal';
    requires 'Test::InDistDir';
    requires 'Test::More', '0.98';
    requires 'Test::Regression';
    requires 'Test::Warn';
};
