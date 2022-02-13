use utf8;
package Bind::Schema::Result::Address;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Bind::Schema::Result::Address

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<address>

=cut

__PACKAGE__->table("address");

=head1 ACCESSORS

=head2 ip

  data_type: 'inet'
  is_nullable: 0

=head2 cnt

  data_type: 'smallint'
  default_value: 0
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "ip",
  { data_type => "inet", is_nullable => 0 },
  "cnt",
  { data_type => "smallint", default_value => 0, is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</ip>

=back

=cut

__PACKAGE__->set_primary_key("ip");


# Created by DBIx::Class::Schema::Loader v0.07045 @ 2022-02-12 19:30:15
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:y0i6jBPQSIPbj9/AGwa/+A


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
