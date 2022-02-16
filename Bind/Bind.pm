package Bind::Bind;

# Combinatorics test exercise by mac-t@yandex.ru
# Used 4 chars tab size

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
	$self->{'lease_qty'} = $init->{'lease_qty'} || 5;
	$self->{'lease_time'} = $init->{'lease_time'} || 60*60*24*30;		# Maybe used later

	if ( $init->{'from'} && $init->{'qty'} ) {			# Init sources
		$self->init( from => $init->{'from'},
					qty => $init->{'qty'},
					keep_nodes => $init->{'keep_nodes'}
					)
	} elsif( !scalar( $schema->resultset( 'Address')->all) ) {
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
#####################
sub dump_nodes {	#
#####################
	my $self = shift;
	return $self->dump( 'Node');
}
#####################
sub dump_address {	#
#####################
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

		$self->{'tries'} = 0;			# Some diagnostic
		$self->{'assigned'} = 0;
		my $time_start = Time::HiRes::time();

		my $spare = [];
		for ( $schema->resultset('Address')->search( undef, 
									{ order_by =>'cnt,ip', 		# Rare used IPs first
									columns => ['ip']
									})->all ) {
			push( @$spare, $_->ip);
		}

		my $node;
		if ( $self->{'id'} ) {			# Search our DB record
			$node = $schema->resultset('Node')->find( { id => $self->{'id'}}, { columns => ['id','ipref','name'] } );
		}
		if ( $node ) {		# May be undefined, despite of ID presence
			$self->release;		# Release address from assigned
		} else {
			$node = $schema->resultset('Node')->create( { name => $self->{'name'} } );
		}

		my $new_pool = [ splice(@$spare, 0, $self->{'lease_qty'}) ];			# Rare used IPs
		my $candidate = [@$new_pool];		# Copy of pool been used for modding
		my $spare_bk = [@$spare];		# Copy of pool been used for spare stock
		my $max_try = $#{$spare} > $#{$new_pool} ? $#{$spare} : $#{$new_pool};

		SEARCH_MODE:
		for my $mix_mode (0..1) {		# Variant enumeration mode

			my $mix_idx = 0;			# One IP replace in stack - mixing
			my $rep_idx = 0;			# Sequencing replace 
			my $mix_stop = $#{$new_pool};		# 
			my $spare_idx = 0;			# Pointer on <spare> storage
			my $try = 0;
			SEARCH_POOL:
			while ( $try <= $max_try ) {
				my $refstring = "\@> '{". join(',', @$candidate ) ."}'";		# Compose for WHERE of DBI placeholder
				my $exists = $schema->resultset('Node')->search( { ipref => \$refstring }, { columns =>['id', 'name']});

				if ( $exists->count ) {		# It always used?
					$self->{'tries'}++;

					my $free_ip = splice( @$candidate, $mix_idx, 1, splice( @$spare, $spare_idx, 1) );
					splice( @$spare, $spare_idx, 0, $free_ip);		# Move replaced address to spare list
					$try++;

					if( $mix_mode == 0) {	# Normal mode - replace single address in pool
						$spare = [@$spare_bk];			# Reset to originals
						$candidate = [@$new_pool];		# 
						last SEARCH_POOL if $try > $max_try;

						$mix_idx++;
						if ($mix_idx > $mix_stop) {
							$mix_idx = 0 ;
							$spare_idx++;
							$spare_idx = 0 if $spare_idx > $#{$spare} && $#{$spare} < $#{$new_pool};
						}

					} elsif( $mix_mode == 1) {		# Replace all of address from top
						if ( $try > $max_try ) {
							my $free_ip = splice( @$candidate, $mix_stop--, 1, splice( @$spare, $rep_idx, 1) );		# Fill new IPs from head of spares
							splice( @$spare, $rep_idx, 0, $free_ip);
							$rep_idx++;
							$rep_idx = 0 if $rep_idx > $#{$spare};
							$try = 0;
							last SEARCH_MODE if $mix_stop < 0;
						}
						$mix_idx++;
						if ($mix_idx > $mix_stop) {
							$mix_idx = 0 ;
							$spare_idx++;
							$spare_idx = 0 if $spare_idx > $#{$spare} && $#{$spare} < $#{$new_pool};
						}
					}

				} else {
					$self->{'assigned'} = 1;
					$new_pool = $candidate;
					last SEARCH_MODE;
				}
			}
		}

		if ( $self->{'assigned'} ) {
			my $criteria = [];			# Update used IPs counter
			for ( @$new_pool ) {
				push( @$criteria, { ip => $_ });
			}
			$schema->resultset('Address')->search( $criteria)->update_all( {cnt => \'cnt+1' } );	#' Increase usage counter

			$node->update( { ipref => $new_pool, ltime => \'CURRENT_TIMESTAMP'} );	#' Store All-In-One
			$self->{'pool'} = $new_pool;
		}

		$self->{'time'} = Time::HiRes::time();
		$self->{'elapsed'} = $self->{'time'} - $time_start;
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
	1
}
1
