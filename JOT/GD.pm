package JOT::GD;

$VERSION = "0.1";
sub Version { $VERSION; }

use JOT;
use GD;
@ISA = ("JOT");

my $VERSION = 0.01;

# Look at the bottom for documentation

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self  = $class->SUPER::new();

    bless ($self, $class);
    return $self;
}


sub GD {
	my $self = shift;
	
	$self->{"WIDTH"} 	= shift || warn "Please provide a width.";
	$self->{"HEIGHT"}	= shift || warn "Please provide a height.";
	$self->{"OFFSETX"}	= shift || 0;
	$self->{"OFFSETY"}	= shift || 0;
	
	$self->{"GD"} = new GD::Image( $self->{"WIDTH"}, $self->{"HEIGHT"} );
	return $self->{"GD"};
}	

sub draw {
	my ($self, $color) = @_;
	my ($xb, $yb, $xe, $ye, $xo, $yo, $im, $dx, $dy);

	$im = $self->{"GD"};
	
	$xo = $self->{"OFFSETX"};
	$yo = $self->{"OFFSETY"};
	
	foreach my $rec (@{$self->{"STRUCT"}}) {
		if ( $rec->{"TYPE"} eq INK_PENDATA_RECORD ) {
			# print "PENDATA\n";
			my @arx = @{$rec->{"DATA_X"}};
			my @ary = @{$rec->{"DATA_Y"}};			
			$xb = shift @arx;
			$yb = shift @ary;
			unless ( @arx ) {
				$im->line($xo + $xb, $yo + $yb, $xo + $xb, $yo + $yb, $color);
			}
			$xe = $xb;
			$ye = $yb;
			while ( @arx ) {
				$dx = shift @arx;
				$dy = shift @ary;
				$xe += $dx;
				$ye += $dy;
				$im->line($xo + $xb, $yo + $yb, $xo + $xe, $yo + $ye, $color);
				# printf( "DELTA(%d, %d)\n", $dx, $dy );
				$xb = $xe;
				$yb = $ye;
			}
		}
	}
}
1;
__END__

=pod

=head1 NAME

JOT::GD - Use a JOT file/stream to make an image

=head1 SYNOPSIS

	use JOT::GD;
	
	$jot = JOT::GD->new(500,500,250,250);
	$jot->parse_file( $ARGV[0] );
	
	$im = $jot->GD();
	
	$white = $im->colorAllocate(255,255,255);
	$black = $im->colorAllocate(0,0,0);
	
	$jot->draw( $black );
	
	open F, ">" . $ARGV[0]. ".png" or die "Could not open file ($!)!";
	print F $im->png;
	close F;

=head1 DESCRIPTION

JOT::GD is a subclass from JOT. It can be used to produce an image from
JOT data.

=head1 HISTORY

8 November 2000	:	First release
30 May 	2001	:	Adapted for CPAN release

=head1 THANKS

Thanks go to Avantgo, http://www.avantgo.com for supporting the scribble field.
Thanks go to Lincoln Stein ( http://stein.cshl.org/~lstein/ ) for GD.
and Thomas Bouttel ( http://www.boutell.com/gd/ ) for libgd.

=head1 AUTHOR AND COPYRIGHT

Johan Van den Brande E<lt>johan@vandenbrande.comE<gt>, http://www.vandenbrande.com/

Copyright (c) 2000 Johan Van den Brande.  All rights reserved.  This program is
free software; you can redistribute it and/or modify it under the terms
of the Artistic License, distributed with Perl.

=head1 VERSION

VERSION 0.01

=cut
