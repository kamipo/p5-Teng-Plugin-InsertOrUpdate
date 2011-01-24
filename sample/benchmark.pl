use strict;
use warnings;
use utf8;
use DBI;
use DBIx::TransactionManager;
use Teng;
use Teng::Schema::Loader;
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

{
    package Hoge::DB;
    use parent 'Teng';
    __PACKAGE__->load_plugin('FindOrCreate');
}

my $teng_schema = Teng::Schema::Loader->load(
    dbh       => $dbh,
    namespace => 'Hoge::DB',
);

my $teng = Hoge::DB->new(
    schema => $teng_schema,
    dbh    => $dbh,
);

{
    package Hoge::Schema;
    use parent 'DBIx::Class::Schema::Loader';

    __PACKAGE__->naming('current');
}

my $dbic_schema  = Hoge::Schema->connect('DBI:mysql:test:localhost', 'root', '');
my $fuga_rs = $dbic_schema->resultset('Fuga');

my $tm; # BIx::TransactionManager

cmpthese 1000 => {
    dbic => sub {
        #$dbic_schema->txn_begin;

        my $fuga = $fuga_rs->find_or_create({
            path     => '/dbic_find_or_create',
            pageview => 0,
        });

        my $path     = $fuga->path;
        my $pageview = $fuga->pageview + 1;

        $fuga->update({ pageview => \'pageview + 1' });

        #$dbic_schema->txn_commit;

        return ($path, $pageview);
    },
    teng => sub {
        #$teng->txn_begin;

        my $fuga = $teng->find_or_create('fuga', {
            path     => '/teng_find_or_create',
            #pageview => 0,
        });

        my $path     = $fuga->path;
        my $pageview = $fuga->pageview + 1;

        $fuga->update({ pageview => \'pageview + 1' });

        #$teng->txn_commit;

        return ($path, $pageview);
    },
    dbi1 => sub {
        #$tm ||= DBIx::TransactionManager->new($dbh);
        #$tm->txn_begin;

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

        #$tm->txn_commit;

        return ($path, $pageview);
    },
    dbi2 => sub {
        my $sth = $dbh->prepare(
            'INSERT INTO fuga (path, pageview) VALUES (?, LAST_INSERT_ID(1)) ' .
            'ON DUPLICATE KEY UPDATE pageview = LAST_INSERT_ID(pageview + 1)'
        );

        my $path = '/dbi_on_duplicate_key_update';

        $sth->execute($path);

        my $pageview = $dbh->selectrow_array('SELECT LAST_INSERT_ID()');

        return ($path, $pageview);
    },
};
