#! /usr/bin/perl -w
use strict;
use utf8;
use Encode;
use Bind::Bind;
use Data::Dumper;

my $bender = Bind::Bind->new(
# 					db_host => '185.98.86.77',
# 					db_port => 5432,
					db_user => 'vdk',
					db_name => 'test',
					db_pass => '14rucoO',
					lease_qty => 5,
					lease_time => 60*60*3
				);
$bender->init(from=>'192.168.1.1', qty=>16);
my $nlist = [];
for (0..1024) {
	push( @$nlist, $bender->lease("Node #$_"));
}
	print Dumper( $nlist->[2] );
$nlist->[2]->release;
	print Dumper( $nlist->[2] );
