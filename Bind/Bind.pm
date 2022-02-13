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
	my ($host, $port); 
	$host = ";host=$init->{'db_host'}" if $init->{'db_host'};
	$port = ";port=$init->{'db_port'}" if $init->{'db_port'};

	$schema = Bind::Schema->connection("dbi:Pg:dbname=$init->{'db_name'}$host$port",
										$init->{'db_user'}, $init->{'db_pass'},
										{ pg_enable_utf8 => 1} );
	$self->{'lease_qty'} = 5 unless $init->{'lease_qty'};
	$self->{'lease_time'} = 60*60*24*30 unless $init->{'lease_time'};
# 	$self->init();
	return $self;
}

#############
sub lease {	#	Return clients node with assigned pool
#############
	my $self = shift;
	my $nodename = shift;
	my $nodeinfo = Node->new( lease_qty => $self->{'lease_qty'},
								name => $nodename
							);
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
{package Node;
use Data::Dumper;
	#############
	sub new {	#
	#############
		my $class = shift;
		my $init = { @_ };
		my $self = bless( $init, $class);

		$self->lease;
		return $self;
	}

	#############
	sub lease {	#	Assign some IPs to that
	#############
		my $self = shift;
		my $try = $self->{'lease_qty'};
		my @addlist = $schema->resultset('Address')->search( undef, 
									{ order_by =>'cnt,ip', 
									columns => 'ip'
									})->all;
		my $try = scalar( @addlist) - $self->{'lease_qty'};
my $uniq;
my $tries = 0;
		my $new_pool = [];
		for ( 0..$self->{'lease_qty'} -1 ) {			# Minimal times used IPs is prior
			push( @$new_pool, $addlist[$_]->ip);
		}
		my $candidate = [@$new_pool];		# Copy of pool been used for modding
		for ( 0..$try -1 ) {
			my $refstring = "\@> '{". join(',', @$candidate ) ."}'";		# Compose for WHERE of DBI placeholder
			my $exists = $schema->resultset('Node')->search( { ipref => \$refstring },
															{ columns =>['id', 'name']});
			if ( $exists->count ) {			# It always used
				$candidate = [@$new_pool];		# Reset candidate to original pool
				my $pointer = $self->{'lease_qty'} + $try -$_ -1;			# Get IP from tail of prepared list
				splice( @$candidate, $_, 1, $addlist[$pointer]->ip );

say "TRY: $try, RPL: $_, POINTER: $pointer OF ".scalar(@$addlist);
				$tries ++;
				next;
			}
			$uniq =1;
			$new_pool = $candidate;
			last;
		}
		my $criteria = [];
		for ( @$new_pool ) {
			push( @$criteria, { ip => $_ });
		}
		$schema->resultset('Address')->search( $criteria)->update_all( {cnt => \'cnt+1' } );	#' Increase usage counter
		
		my $find = { name => $self->{'name'} };			# Search our record
		$find = { id => $self->{'id'}} if $self->{'id'};
		my $node = $schema->resultset('Node')->find_or_create( $find,
													{ columns => ['id', 'ipref'] } );
# 		$self->release if $node->in_storage;
		$self->{'pool'} = $new_pool;
		$self->{'id'} = $node->id;
if ( $uniq ) {
# 	say "UNIQUE $self->{'name'} ID $self->{'id'} try $tries times";
} else {
# 	say "NOT UNIQUE $self->{'name'} ID $self->{'id'} try $tries times";
}
		$node->update( { ipref => $self->{'pool'},
						ltime => \'CURRENT_TIMESTAMP'} );	#' Store All-In-One
	}

	#############
	sub release {	#	Empty leased address pool
	#############
		my $self = shift;
		my $criteria = [];
		while ( my $ip = shift( @{$self->{'pool'}}) ) {
			push( @$criteria, { ip => $ip });
		}
		$schema->resultset('Address')->search( $criteria)
							->search( {cnt => \'>0'} )->update_all( {cnt => \'cnt-1' } );	#' Decrease usage counter
		return $self;
	}
}
1
