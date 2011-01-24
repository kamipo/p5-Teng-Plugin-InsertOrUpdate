use strict;
use warnings;
use utf8;
use Test::More;
use DBI;

my $dbh = DBI->connect('DBI:mysql:test:localhost', 'root', '', {RaiseError => 1})
    or die 'cannot connect to db';

$dbh->do('DROP TABLE IF EXISTS `fuga`');
$dbh->do(q{
    CREATE TABLE IF NOT EXISTS `fuga` (
      `path` varchar(255) NOT NULL,
      `pageview` int(10) unsigned default 0,
      PRIMARY KEY (`path`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8
});

{
    package Hoge::Schema;
    use parent 'DBIx::Class::Schema::Loader';

    __PACKAGE__->naming('current');
}

my $schema  = Hoge::Schema->connect('DBI:mysql:test:localhost', 'root', '');
my $fuga_rs = $schema->resultset('Fuga');

subtest 'dbic find_or_create' => sub {
    for my $i (1..2) {
        $schema->txn_begin;

        my $fuga = $fuga_rs->find_or_create({
            path     => '/dbic_find_or_create',
            pageview => 0,
        });

        my $path     = $fuga->path;
        my $pageview = $fuga->pageview + 1;

        $fuga->update({ pageview => \'pageview + 1' });

        $schema->txn_commit;

        is "$path:$pageview", "/dbic_find_or_create:$i";
    }
};

done_testing;
