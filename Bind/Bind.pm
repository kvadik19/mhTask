package Bind::Bind;

use strict;
use utf8;
use DBIx::Class;
use Time::HiRes;
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
	$self->{'lease_time'} = 60*60*24*30 unless $init->{'lease_time'};		# Maybe used later

	if ( $init->{'from'} && $init->{'qty'} ) {			# Init sources
		$self->init( from => $init->{'from'},
					qty => $init->{'qty'},
					keep_nodes => $init->{'keep_nodes'}
					)
	} elsif( !scalar($schema->resultset( 'Address')->all) ) {
		$self->init();
	}
	return $self;
}

#############
sub lease {	#	Return clients node with assigned pool
#############
	my $self = shift;
	my $nodename = shift || '****-****';
	return Node->new( lease_qty => $self->{'lease_qty'},
								name => $nodename
							);
}
#############
sub dump {	#		Dump table content
#############
	my $self = shift;
	my $name = shift;
	my $out = [];
	for ( $schema->resultset( $name)->all ) {
		my $def = {};
		for my $col ( $_->columns ) {
			$def->{ $col} = $_->$col;
		}
		push( @$out, $def);
	}
	return $out;
}
#############
sub dump_nodes {	#
#############
	my $self = shift;
	return $self->dump( 'Node');
}
#############
sub dump_address {	#
#############
	my $self = shift;
	return $self->dump( 'Address');
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
	$schema->resultset( 'Node')->delete unless $init->{'keep_nodes'};
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
		$self->{'id'} = 0;
		$self->{'pool'} = [];

		$self->lease;
		return $self;
	}

	#############
	sub lease {	#	Assign some IPs to that
	#############
		my $self = shift;

		my $time_start = Time::HiRes::time();
		my @addlist = $schema->resultset('Address')->search( undef, 
									{ order_by =>'cnt,ip', 		# Unused address first
									columns => ['ip']
									})->all;

		my $node;
		if ( $self->{'id'} ) {			# Search our DB record
			$node = $schema->resultset('Node')->find( { id => $self->{'id'}}, { columns => ['id','ipref','name'] } );
		}
		if ( $node ) {		# May be undefined, despite of ID presence
			$self->release;		# Release address from assigned
		} else {
			$node = $schema->resultset('Node')->create( { name => $self->{'name'} } );
		}

		my $new_pool = [];
		for ( 0..$self->{'lease_qty'} -1 ) {			# Rarely used IPs is prior
			push( @$new_pool, $addlist[$_]->ip);
		}
		my $max_search = scalar( @addlist) - $self->{'lease_qty'};
		my $mix_idx = 0;			# One IP replace in stack
		my $rep_idx = 0;		# Sequenced IP replace 
		my $candidate = [@$new_pool];		# Copy of pool been used for modding

		$self->{'tries'} = 0;			# Some diagnostic
		$self->{'assigned'} = 0;
		my $try = 0;
		while ( $try < $max_search ) {
			my $refstring = "\@> '{". join(',', @$candidate ) ."}'";		# Compose for WHERE of DBI placeholder
			my $exists = $schema->resultset('Node')->search( { ipref => \$refstring },
															{ columns =>['id', 'name']});
			if ( $exists->count ) {		# It always used?
				$self->{'tries'}++;
				$candidate = [@$new_pool];		# Reset candidate to original pool

				my $pointer = $self->{'lease_qty'} + $try;			# Get IP from head of prepared list (rarely used first)
# 				my $pointer = $self->{'lease_qty'} + $max_search -$try -1;		# Get IP from tail of prepared list (often used first)

				splice( @$candidate, $mix_idx++, 1, $addlist[$pointer]->ip );
				$mix_idx = $rep_idx if $mix_idx == $self->{'lease_qty'};		# Cyclic from begin
				$try++;
				if ( $try == $max_search ) {
					splice( @$new_pool, $rep_idx++, 1, $addlist[$pointer]->ip );
					$mix_idx = $rep_idx;
					$try = 0;
					last if $rep_idx == $self->{'lease_qty'};		# Unsuccess tries limit
				}
				next;
			}
			$self->{'assigned'} = 1;
			$new_pool = $candidate;
			last;
		}

		my $criteria = [];			# Update used IPs counter
		for ( @$new_pool ) {
			push( @$criteria, { ip => $_ });
		}

		$schema->resultset('Address')->search( $criteria)->update_all( {cnt => \'cnt+1' } );	#' Increase usage counter

		$node->update( { ipref => $new_pool, ltime => \'CURRENT_TIMESTAMP'} );	#' Store All-In-One

		$self->{'time'} = Time::HiRes::time();
		$self->{'elapsed'} = $self->{'time'} - $time_start;
		$self->{'pool'} = $new_pool;
		$self->{'id'} = $node->id;
	}

	#################
	sub release {	#	Empty leased address pool
	#################
		my $self = shift;
		my $criteria = [];
		while ( my $ip = shift( @{$self->{'pool'}}) ) {
			push( @$criteria, { ip => $ip });
		}
		$self->{'time'} = Time::HiRes::time();
		$self->{'elapsed'} = 0;
		$self->{'tries'} = 0;
		$self->{'assigned'} = 0;
		$schema->resultset('Address')->search( $criteria)
							->search( {cnt => \'>0'} )->update_all( {cnt => \'cnt-1' } );	#' Decrease usage counter
		return $self;
	}
}
1
