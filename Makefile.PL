use inc::Module::Install;

name 'Teng-Plugin-InsertOrUpdate';
all_from 'lib/Teng/Plugin/InsertOrUpdate.pm';

requires 'Teng';

test_requires 'Test::More' => 0.96; # done_testing, subtest
tests 't/*.t t/*/*.t';
author_tests('xt');

WriteAll;
