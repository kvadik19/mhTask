#! /usr/bin/perl -w
use strict;
use utf8;
use Encode;
use Bind::Bind;
use Data::Dumper;

my $bender = Bind::Bind->new(
					db_user => 'vdk',
					db_name => 'test',
					db_pass => '14rucoO',
					lease_qty => 5,
					lease_time => 60*60*3
				);
$bender->init(from=>'192.168.1.1', qty=>66);
for (0..127) {
	my $node = $bender->lease("Node #$_");
# 	print Dumper( $node );
}