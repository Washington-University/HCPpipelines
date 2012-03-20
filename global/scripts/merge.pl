#!/usr/bin/perl
use IO::File;
use strict;
use warnings;

if(@ARGV !=3)
{
	print "Need to supply the input header file, the input coordinate file, and the output file.\n";

}
my ($header, $coords, $outfile) = @ARGV;
my $fhheader = IO::File->new("$header");
my $fh = IO::File->new(">$outfile");
my $fhcoords = IO::File->new("$coords");

my $count = 0;
while (my $line = <$fhheader>)
{
	print $fh $line;
}
while (my $line = <$fhcoords>)
{
	print $fh $count," ",$line;
	$count++;
}