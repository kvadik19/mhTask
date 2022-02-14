#! /usr/bin/perl 

use strict;
use utf8;
use 5.18.0;
use Bind::Bind;
use Data::Dumper;

my $bender = Bind::Bind->new(
# 					db_host => '185.98.86.77',
# 					db_port => 5432,
					db_user => 'vdk',
					db_name => 'test',
					db_pass => '14rucoO',
					from => '192.168.1.1', 		# Optional, may be changed over `init` method
					qty => 64,					# Optional, may be changed over `init` method
					lease_qty => 5,
				);

$bender->init( from => '192.168.1.1', qty => 16, keep_nodes => 0);

#	Some diagnostic messages under comments below

my $nodes = [];
my $time_total = 0;
for (0..511) {
	my $node = $bender->lease("Node #$_");
	push( @$nodes, $node);
# 	say "ASSIGNED: $node->{'assigned'}, AFTER $node->{'tries'} TRIES ON $node->{'elapsed'} sec.";
	$time_total += $node->{'elapsed'};
}
say "Total time used $time_total sec.";

# say "ADDRESS\t\tUsed QTY";
# for ( @{$bender->dump_address} ) {
# 	say "$_->{'ip'}\t$_->{'cnt'}"
# }

# 	print Dumper( $nodes->[-1] );
# 
# $nodes->[-1]->lease;
# 	print Dumper( $nodes->[-1] );
# 
# $nodes->[-1]->release;
# 	print Dumper( $nodes->[-1] );
