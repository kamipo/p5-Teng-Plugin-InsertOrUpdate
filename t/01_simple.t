use strict;
use warnings;
use utf8;
use Test::More;
use DBI;
use Teng;
use Teng::Schema::Loader;

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
    __PACKAGE__->load_plugin('InsertOrUpdate');
}

my $schema = Teng::Schema::Loader->load(
    dbh       => $dbh,
    namespace => 'Hoge::DB',
);

my $teng = Hoge::DB->new(
    schema => $schema,
    dbh    => $dbh,
);

subtest 'find or create' => sub {
    $teng->txn_begin;

    my $body;

    my $fuga = $teng->find_or_create('fuga', {
        path => '/find_or_create',
    });

    $fuga->update({ pageview => \'pageview + 1' });
    $fuga = $fuga->refetch;

    $body = join ':', ($fuga->path, $fuga->pageview);
    is $body, '/find_or_create:1';


    $fuga->update({ pageview => \'pageview + 1' });
    $fuga = $fuga->refetch;

    $body = join ':', ($fuga->path, $fuga->pageview);
    is $body, '/find_or_create:2';

    $teng->txn_commit;
};


subtest 'insert or update' => sub {
    $teng->txn_begin;

    my $body;

    my $fuga = $teng->insert_or_update('fuga',
        {
            path     => '/insert_or_update',
            pageview => 1,
        },
        {
            pageview => \'pageview + 1',
        },
    );

    $fuga = $fuga->refetch;

    $body = join ':', ($fuga->path, $fuga->pageview);
    is $body, '/insert_or_update:1';


    $fuga = $teng->insert_or_update('fuga',
        {
            path     => '/insert_or_update',
            pageview => 1,
        },
        {
            pageview => \'pageview + 1',
        },
    );

    $fuga = $fuga->refetch;

    $body = join ':', ($fuga->path, $fuga->pageview);
    is $body, '/insert_or_update:2';

    $teng->txn_commit;
};

done_testing;
