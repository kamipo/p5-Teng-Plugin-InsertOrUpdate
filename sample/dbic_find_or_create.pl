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

subtest 'dbic update_or_new' => sub {
    for my $i (1..2) {
        $schema->txn_begin;

        my $fuga = $fuga_rs->update_or_new({
            path     => '/dbic_update_or_create',
            pageview => \'LAST_INSERT_ID(pageview + 1)',
        });

        if (!$fuga->in_storage) {
            $fuga->pageview(\'LAST_INSERT_ID(1)');
            $fuga->insert;
        }

        my $dbh = $schema->storage->dbh;
        my $pageview = $dbh->selectrow_array('SELECT LAST_INSERT_ID()');

        $schema->txn_commit;

        my $body = join ':', ($fuga->path, $pageview);

        is $body, "/dbic_update_or_create:$i";
    }
};

done_testing;
