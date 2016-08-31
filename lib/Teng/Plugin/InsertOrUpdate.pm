package Teng::Plugin::InsertOrUpdate;
use strict;
use warnings;
use utf8;

our @EXPORT = qw/insert_or_update/;

sub insert_or_update {
    my ($self, $table, $args, $update_args) = @_;

    my $prefix = 'INSERT';
    my $tbl = $self->schema->get_table($table);

    for my $col (keys %{$args}) {
        $args->{$col} = $tbl->call_deflate($col, $args->{$col});
    }

    my ($sql1, @binds1) = $self->sql_builder->insert( $table, $args, { prefix => $prefix } );

    $update_args ||= [%$args];

    for my $col (keys %{$update_args}) {
        $update_args->{$col} = $tbl->call_deflate($col, $update_args->{$col});
    }

    my ($sql2, @binds2) = $self->sql_builder->update( $table, $update_args );
    $sql2 =~ s/^UPDATE\s(?:\S+)\sSET/ ON DUPLICATE KEY UPDATE/;

    my $sth = $self->execute($sql1.$sql2, [(@binds1, @binds2)], $table);

    $tbl->row_class->new(
        {
            row_data   => $args,
            teng       => $self,
            table_name => $table,
        }
    );
}


1;
__END__

=encoding utf8

=head1 NAME

Teng::Plugin::InsertOrUpdate -

=head1 SYNOPSIS

  use Teng::Plugin::InsertOrUpdate;

=head1 DESCRIPTION

Teng::Plugin::InsertOrUpdate is

=head1 AUTHOR

Ryuta Kamizono E<lt>kamipo@gmail.comE<gt>

=head1 SEE ALSO

=head1 LICENSE

Copyright (C) Ryuta Kamizono

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
