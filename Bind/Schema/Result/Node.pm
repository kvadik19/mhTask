use utf8;
package Bind::Schema::Result::Node;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Bind::Schema::Result::Node

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<nodes>

=cut

__PACKAGE__->table("nodes");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'nodes_id_seq'

=head2 name

  data_type: 'varchar'
  is_nullable: 1
  size: 128

=head2 ipref

  data_type: 'inet[]'
  is_nullable: 1

=head2 ltime

  data_type: 'timestamp'
  default_value: current_timestamp
  is_nullable: 1
  original: {default_value => \"now()"}

=cut

__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "nodes_id_seq",
  },
  "name",
  { data_type => "varchar", is_nullable => 1, size => 128 },
  "ipref",
  { data_type => "inet[]", is_nullable => 1 },
  "ltime",
  {
    data_type     => "timestamp",
    default_value => \"current_timestamp",
    is_nullable   => 1,
    original      => { default_value => \"now()" },
  },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");


# Created by DBIx::Class::Schema::Loader v0.07045 @ 2022-02-12 19:30:15
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:cqjxWz+GH36TQXP6CrVIRQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
