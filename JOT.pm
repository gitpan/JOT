package JOT;

$VERSION = "0.1";
sub Version { $VERSION; }

use strict;

# Look at the bottom for documentation

my $VERSION = 0.01;

use constant inkRecordEnd		=> 0x0000;
use constant inkRecordBundle	=> 0x4001;
use constant inkRecordPendata	=> 0xC002;

use constant INK_BUNDLE_RECORD	=> "INK_BUNDLE_RECORD";
use constant INK_PENDATA_RECORD	=> "INK_PENDATA_RECORD";
use constant INK_END_RECORD		=> "INK_END_RECORD";

### PUBLIC functions 

#  constructor
sub new {
	my $proto = shift;
	my $class = ref( $proto ) || $proto;
	my $self = {};	
	
	$self->{"STRUCT"} = [];
	$self->{"LENGTH"} = 0;
	
	bless( $self, $class );
	return $self;
}

# parse from a file
sub parse_file {
	my ($self, $file) = @_;
	my ( $buff, $string);
	local *F;
	unless ( open F, $file ) {
		warn "Could not open file: $file ($!)\n";
		return undef;
	}
	binmode F;
	$string .= $buff while( read(F, $buff, 8192 ) );  	
	close F;
	
	return $self->_parse( $string );
}

# parse from a string
sub parse_string {
	my ($self, $string) = @_;
	
	return $self->_parse( $string );
}	

# return an array with al the coordinates
sub coords {
	my ($self) = @_;
	my (@array, @arx, @ary);
	my ( $x, $y );
	foreach my $rec (@{$self->{"STRUCT"}}) {
		if ( $rec->{"TYPE"} eq INK_PENDATA_RECORD ) {
			@arx = @{$rec->{"DATA_X"}};
			@ary = @{$rec->{"DATA_Y"}};			
			$x = shift @arx;
			$y = shift @ary;
			push( @array, $x, $y );
			while ( @arx ) {
				$x += shift @arx;
				$y += shift @ary;
				push( @array, $x, $y );
			}
		}
	}
	return @array;
}

# return the max. bounding box
sub dimensions {
	my ($self) = @_;
	my (@arx, @ary, $minx, $miny, $maxx, $maxy);
	
	$minx = $miny = 65536;
	$maxx = $maxy = 0;
		
	foreach my $rec (@{$self->{"STRUCT"}}) {
		if ( $rec->{"TYPE"} eq INK_PENDATA_RECORD ) {
			$minx = ($rec->{"ORIGIN_X"} < $minx)?$rec->{"ORIGIN_X"}:$minx;
			$miny = ($rec->{"ORIGIN_Y"} < $miny)?$rec->{"ORIGIN_Y"}:$miny;
			
			$maxx = ($rec->{"WIDTH"} > $maxx)?$rec->{"WIDTH"}:$maxx;
			$maxy = ($rec->{"HEIGHT"} > $maxy)?$rec->{"HEIGHT"}:$maxy;
		}
	}
	return ( $minx, $miny, $maxx, $maxy );
}

### PRIVATE functions

# parse the jot stream
sub _parse {
	my ($self, $string) = @_;
	my (@array, $token, $struct);

	@array = split( //, $string );
	
	while ( @array ) {
		# Read in Record header
		$token = unpack( "v", $self->_read( \@array, 2 ) );
		SWITCH: {
			$token == inkRecordBundle 	&& do { $struct = $self->_processBundle(  \@array,  $token );   last; };
			$token == inkRecordPendata 	&& do { $struct = $self->_processPendata( \@array,  $token ); 	last; };
			$token == inkRecordEnd		&& do { $struct = $self->_processEnd(); 						last; };
		};
		push( @{$self->{"STRUCT"}}, $struct );
		$self->{"LENGTH"}++;
	}
	return $self->{"STRUCT"};
}	


## process the bundle
sub _processBundle {
	my ($self, $arr, $recordheader) = @_;
	my ($token, $reclength, $version, $compactiontype, $pux, $puy, $struct);
	
	$reclength = ord( $self->_read( $arr, 1 ) );
	$version = ord( $self->_read( $arr, 1 ) );
	$compactiontype = ord( $self->_read( $arr, 1 ) );
	# skip bundle flags ...
	$token = $self->_read( $arr, 2 );
	$pux = unpack( "V", $self->_read( $arr, 4 ) );
	$puy = unpack( "V", $self->_read( $arr, 4 ) );
	
	# add this to the PenBundle record
	$struct = {};
	$struct->{"TYPE"} 				= INK_BUNDLE_RECORD;
	$struct->{"LENGTH"}				= $reclength;
	$struct->{"VERSION"}			= $version;
	$struct->{"COMPACTIONTYPE"}		= $compactiontype;
	$struct->{"PEN_UNITS_PER_X"}	= $pux;
	$struct->{"PEN_UNITS_PER_Y"}	= $puy;
	
	return $struct;
}


## process the ink data
sub _processPendata {
	my ($self, $arr, $recordheader) = @_;
	my ($token, $reclength, $orx, $ory, $width, $height, $struct, $x, $y, $utoken);
	my ($t_size);
	
	$reclength = unpack( "V", $self->_read( $arr, 4 ) );
	$orx = unpack( "V", $self->_read( $arr, 4 ) );
	$ory = unpack( "V", $self->_read( $arr, 4 ) );
	$width = unpack( "V", $self->_read( $arr, 4 ) );
	$height = unpack( "V", $self->_read( $arr, 4 ) );
	
	# add this to the PenBundle record
	$struct = {};
	$struct->{"TYPE"} 				= INK_PENDATA_RECORD;
	$struct->{"LENGTH"}				= $reclength;
	$struct->{"ORIGIN_X"}			= $orx;
	$struct->{"ORIGIN_Y"}			= $ory;
	$struct->{"WIDTH"}				= $width;
	$struct->{"HEIGHT"}				= $height;
	$struct->{"DATA_X"}				= [];
	$struct->{"DATA_Y"}				= [];
	
	# print "PENDATA\n";
	
	for ( my $i=22; $i < $reclength; ) {
		$utoken = unpack( "C", $self->_read( $arr, 1 ) );
		$i++;
		
		SWITCH2: {
			($utoken & 0xC0) == 0x00 && do {
				$t_size = "32";
			 
				$x = $utoken;
				my $xh = unpack( "C", $self->_read( $arr, 1 ));
				my $xl = unpack( "S", $self->_read( $arr, 2 ));
				my $yt = unpack( "L", $self->_read( $arr, 4 ));
				$x = ($x << 24) | ( $xh << 16 ) | $xl;
				$x&=0x3FFFFFFF;
				$x|= (($yt & 0x80000000) >> 1);
				$y = $yt & 0x7FFFFFFF;
				$y = ( $y >> 1 ) | (( $y & 0x00000001 ) << 30);
				$x = $self->_makeSigned( $x, 32 );
				$y = $self->_makeSigned( $y, 32 );						
				$i+=7;
				warn("32 BIT DELTA NOT YET TESTED.");												
				last; 
			 };
			($utoken & 0xC0) == 0x40 && do {
				$t_size = "16";

				$x = $utoken;
				my $xt = unpack( "C", $self->_read( $arr, 1 ) );
				$x = ($x << 8) | $xt;
				my $yt = unpack( "n", $self->_read( $arr, 2 ) );
				$x =$x & 0x3FFF;
				$x = $x | ( ( $yt & 0x8000 ) >> 1 );
				$y = $yt & 0x7FFF;
				$y = ( $y >> 1 ) | ( ( $y & 0x0001 ) << 14);
				$x = $self->_makeSigned( $x, 16 );
				$y = $self->_makeSigned( $y, 16 );		
				$i+=3;
				last; 
			};
			($utoken & 0xC0) == 0x80 && do {
				$t_size = "8";

				$x = $utoken;
				# $y = unpack( "C", $self->_read( $arr, 1 ) );

				# $x = ( $x & 0x3f ) | ( ( $y & 0x80 ) >> 1 );
				# $y = $y & 0x7f;

				$x = $x & 0x3F;
				$y = unpack( "C", $self->_read( $arr, 1 ) );
				$x = ($x | (( $y & 0x80 ) >> 1)) & 0x7F;
				$y = $y & 0x7F;
				$y = ( $y >> 1 ) | ( ( $y & 0x01 ) << 6);
				
				$x = $self->_makeSigned( $x, 8 );
				$y = $self->_makeSigned( $y, 8 );			
				$i++;				
				last;
			};
			($utoken & 0xC0) == 0xC0 && do { 
				$t_size = "4";
				
				$x = ( $utoken & 0x38 ) >> 3;
				$y = $utoken & 0x07;
	
				if ( $x & 0x04 ) {
					$x = 0xfffffff8 | $x;
				}
				$x = sprintf("%d", $x);
	
				if ( $y & 0x04 ) {
					$y = 0xfffffff8 | $y; 
				}
				$y = sprintf("%d", $y);

				last;
			};
		}
		push( @{$struct->{"DATA_X"}}, $x );
		push( @{$struct->{"DATA_Y"}}, $y );
		# print "D($x, $y) " . $t_size . "\n";
	}
	return $struct;
}

# process  end
sub _processEnd {
	my ($self ) = @_;
	my ($struct);
	
	$struct = {};
	$struct->{"TYPE"} 				= INK_END_RECORD;
	$struct->{"LENGTH"}				= 0;
	
	return $struct;
}

sub _makeSigned {
	my ( $self, $val, $l ) = @_;
	my $v;
	SWITCHX: {
		$l == 4 && do {
				$v =( ($val & 0x00000004) != 0x00000004 )?($val & 0x00000003):( ($val & 0x00000003) * -1 );
				last;
		};
		$l == 8 && do {
				$v =( ($val & 0x00000040) != 0x00000040 )?($val & 0x0000003F):( ($val & 0x0000003F) * -1 );
				last;
		};
		$l == 16 && do {
				$v =( ($val & 0x00004000) != 0x00004000 )?($val & 0x00003FFF):( ($val & 0x00003FFF) * -1 );				
				last;
		};
		$l == 32 && do {
				$v =( ($val & 0x40000000) != 0x40000000 )?($val & 0x3FFFFFFF):( ($val & 0x3FFFFFFF) * -1 );
				last;
		}; 
	}	
	return sprintf("%d", $v);
}


sub _XmakeSigned {
	my ( $self, $val, $l ) = @_;
	my $v = $val;

	# print "$val|$l\n";

	SWITCHX: {
		$l == 4 && do {
			if ( $val & 0x04 ) {
				$v = 0xfffffff8 | $val;
			}
			last;
		};
		$l == 8 && do {
			if ( $val & 0x40 ) {
				$v = 0xffffff80 | $val;
			}
			last;
		};
		$l == 16 && do {
			if ( $val & 0x4000 ) {
				$v = 0xffff8000 | $val;
			}
			last;
		};
		$l == 32 && do {
			if ( $val & 0x40000000 ) {
				$v = 0x80000000 | $val;
			}
			last;
		}; 
	}
	# printf("(%d)\n", $v);	
	return sprintf("%d", $v);
}

sub _read {
	return join( "", splice( @{$_[1]}, 0, $_[2] ) );
}
1;
__END__

=pod

=head1 NAME

JOT - Parses the JOT specification for Ink Storage and Interchange Format

=head1 SYNOPSIS

	use JOT;
	
	$jot = JOT->new();
	$jot->parse_file( $ARGV[0] );
	
	@array = $jot->coords();
	while ( @array ) {
		printf("(%d, %d)\n", shift @array, shift @array );
	}

=head1 DESCRIPTION

JOT is a specification for ink storage. JOT was the proposed standard to use
when a browser implements the scribble input field ( I<E<lt>input type="scribble"E<gt>> ).
The JOT specification did not make it into the definitive HTML3 spec,
but you can still find some references to it in the proposed HTML3 standard from the W3C.

The only broser I'm aware of that implements this format is Xmosaic.

Because JOT is a lightweight format, it is very interesting to use it on small
devices like a PDA. The Avantgo browser for the PalmPilot implements the scribble
input tag. 

JOT is also interesting because it stores an image as a 2D vector format with
timely information. It does not only record the coordinates of the lines that a
person draws on a tablet, but also records the speed, pressure, etc .... of the
pen on the tablet. This can come handy in recognizing signatures or handwrite
recognition.

=head1 COMPATIBILITY

This implementation only supports INK_BUNDLE_RECORD, INK_PENDATA_RECORD and INK_END_RECORD.
It also does not use any of the B<Bundle Flags> and assumes a compaction type of 1.
This is sufficient to parse the Avantgo implementation of JOT.

=head1 USAGE

=head2 parse_file $file 

Parses a JOT file, returns an reference to an array that contains the records:

	$struct = $jot->parse_file( "./test.jot" );
	# $struct->[0] contains the INK BUNDLE RECORD
	# $struct->[1..n-1] contains the INK PENDATA RECORDS
	# $struct->[n] contains the INK END RECORD
	
	INK BUNDLE RECORD:
		$struct = {};
		$struct->{"TYPE"} 				= INK_BUNDLE_RECORD;
		$struct->{"LENGTH"}
		$struct->{"VERSION"}
		$struct->{"COMPACTIONTYPE"}
		$struct->{"PEN_UNITS_PER_X"}
		$struct->{"PEN_UNITS_PER_Y"}
	
	INK PENDATA RECORD
		$struct = {};
		$struct->{"TYPE"}
		$struct->{"LENGTH"}
		$struct->{"ORIGIN_X"}
		$struct->{"ORIGIN_Y"}
		$struct->{"WIDTH"}
		$struct->{"HEIGHT"}
		$struct->{"DATA_X"}	= [];
		$struct->{"DATA_Y"}	= [];
	
	INK END RECORD
		$struct = {};
		$struct->{"TYPE"}	= INK_END_RECORD;
		$struct->{"LENGTH"}	= 0;

=head2 parse_string $string 

Parses a JOT stream in a string. Handy for doing JOT parsing from a submit.
Please note: Avantgo submits the scribble field as Base64 encoded.

=head2 coords

Returns the all the coordinates from a JOT file. This is a convenience function
and can be used to easily implement a JOT to PNG tool.

=head1 HISTORY

8 November 2000	:	First release
30 May 2001		:	Adapted for release on CPAN

=head1 THANKS

Thanks go to Avantgo, http://www.avantgo.com for supporting the scribble field.
Thanks go to David Williams, who was kind enough to tell me Avantgo uses.
JOT as their scribble format.

=head1 AUTHOR AND COPYRIGHT

Johan Van den Brande E<lt>johan@vandenbrande.comE<gt>, http://www.vandenbrande.com/

Copyright (c) 2000-2001 Johan Van den Brande.  All rights reserved.  This program is free software; you can redistribute it and/or modify it under the terms
of the Artistic License, distributed with Perl.

=head1 VERSION

VERSION 0.01

=cut
