use strict;
use warnings;
use utf8;
use Test::More;
use DBI;
use DBIx::TransactionManager;
use Benchmark qw(:all);

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

subtest 'dbi update_or_insert' => sub {
    my $tm = DBIx::TransactionManager->new($dbh);
    for my $i (1..2) {
        $tm->txn_begin;

        my $sth = $dbh->prepare(
            'UPDATE fuga SET pageview = pageview + 1 WHERE path = ?'
        );

        my $path = '/dbi_update_or_insert';
        my $pageview;

        if ($sth->execute($path) eq '0E0') { # 0 rows affected
            my $sth = $dbh->prepare('INSERT INTO fuga (path, pageview) VALUES (?, 1)');
            $sth->execute($path);
            $pageview = 1;
        } else {
            my $sth = $dbh->prepare('SELECT pageview FROM fuga WHERE path = ?');
            $sth->execute($path);
            $pageview = $sth->fetchrow_array;
        }

        $tm->txn_commit;

        is "$path:$pageview", "/dbi_update_or_insert:$i";
    }
};

subtest 'dbi on_duplicate_key_update' => sub {
    for my $i (1..2) {
        my $sth = $dbh->prepare(
            'INSERT INTO fuga (path, pageview) VALUES (?, LAST_INSERT_ID(1)) ' .
            'ON DUPLICATE KEY UPDATE pageview = LAST_INSERT_ID(pageview + 1)'
        );

        my $path = '/dbi_on_duplicate_key_update';

        $sth->execute($path);

        my $pageview = $dbh->selectrow_array('SELECT LAST_INSERT_ID()');

        is "$path:$pageview", "/dbi_on_duplicate_key_update:$i";
    }
};

done_testing;
