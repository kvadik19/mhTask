package Bind::Bind;

use strict;
use utf8;
use Encode;
use 5.18.0;
use DBIx::Class;

use Bind::Schema;

our $schema;
#############
sub new {	#
#############
	my $class = shift;
	my $init = { @_ };
	my $self = bless( $init, $class);
	my $host = ''; 
	$host = ":host=$init->{'db_host'}" if $init->{'db_host'};

	$schema = Bind::Schema->connection("dbi:Pg$host:dbname=$init->{'db_name'}",
										$init->{'db_user'}, $init->{'pass'},
										{ pg_enable_utf8 => 1} );
	$self->{'lease_qty'} = 5 unless $init->{'lease_qty'};
	$self->{'lease_time'} = 60*60*24*30 unless $init->{'lease_time'};
# 	$self->init();
	return $self;
}

#############
sub lease {	#	Assign some IPs to that
#############
	my $self = shift;
	my $nodename = shift;
	my $nodeinfo = {'name' => $nodename, 'pool' => []};
	my $addlist = $schema->resultset('Address')->search( undef, 
								{ order_by =>'cnt,ip', 
								rows => $self->{'lease_qty'},
								columns => 'ip'
								});

	for ( $addlist->all ) {
		push( @{$nodeinfo->{'pool'}}, $_->ip);
	}
	$addlist->update_all( {cnt => \'cnt+1' } );		#' Increase usage counter

	my $refstring = "\@> '{". join(',', @{$nodeinfo->{'pool'}} ) ."}'";		# Compose for WHERE of DBI placeholder
	my $exists = $schema->resultset('Node')->search( { ipref => \$refstring });
	
if ($exists->count) {
	say "$nodename EXIST ", ($exists->all)[0]->name;
}

	my $node = $schema->resultset('Node')->find_or_create( { name => $nodename }
												,{ columns => ['id', 'ipref'] } );
	$nodeinfo->{'id'} = $node->id;
	$node->update( { ipref => $nodeinfo->{'pool'},
					ltime => \'CURRENT_TIMESTAMP'} );	#' Store All-In-One

	return $nodeinfo;
}
#############
sub dump {	#
#############
	my $cnt = 1;
	my $out = [];
	for my $rec ( $schema->resultset( 'Address')->all ) {
		push( @$out, {'ip' => $rec->ip, 'cnt' => $rec->cnt});
	}
	return $out;
}
#############
sub init {	#	Reset address pool
#############
# dbicdump -o dump_directory=./ Bind::Schema 'dbi:Pg:dbname=test;host=localhost;port=5432' vdk 14rucoO
	my $self = shift;
	my $init = { @_ };
	my $ntoip = sub {
						my $intip = shift;
						my $d = $intip % 256; $intip -= $d; $intip /= 256;
						my $c = $intip % 256; $intip -= $c; $intip /= 256;
						my $b = $intip % 256; $intip -= $b; $intip /= 256;
						return "$intip.$b.$c.$d";
					};
	my $ipton = sub {
						my $ip = shift;
						my @a = split( /\./, $ip );
						return int($a[0])*256**3+int($a[1])*256**2+int($a[2])*256+int($a[3]);
					};

	$schema->resultset( 'Node')->delete if scalar( $schema->resultset( 'Node')->all);
	$schema->resultset( 'Address')->delete if scalar( $schema->resultset( 'Address')->all);

	my $ip_start = $init->{'from'} || 1539727873;
	$ip_start = $ipton->( $init->{'from'}) if $init->{'from'} =~ /^\d{1,3}(\.\d{1,3}){3}$/;
	my $qty = $init->{'qty'} || 253;
	for ( 0..$qty -1 ) {
		$schema->resultset( 'Address')->new( {'ip' => $ntoip->($ip_start + $_), 'cnt' => 0})->insert;
	}
}
1
