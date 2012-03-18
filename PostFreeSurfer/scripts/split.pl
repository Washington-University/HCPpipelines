#!/usr/bin/perl
use IO::File;
use strict;
use warnings;

if(@ARGV !=3)
{
	print "Need to supply the input file, the output header file, and the output coordinate file.\n";

}
my ($infile, $header, $coords) = @ARGV;
my $fhheader = IO::File->new(">$header");
my $fh = IO::File->new("$infile");
my $fhcoords = IO::File->new(">$coords");

my $count = 0;
while (my $line = <$fh>)
{
	if($line =~ /EndHeader/)
	{
		print $fhheader $line;
		$line = <$fh>;
		print $fhheader $line;
		close $fhheader;
		chomp $line;
		$count = $line;
		last;
	}
	else
	{
		print $fhheader $line;
	}
}
for(my $i=0;$i<$count;$i++)
{
	my $line = <$fh>;
	chomp $line;
	my (undef, @coords) = split /\s+/,$line;
	#print ,"\n";
	print $fhcoords join (" ",@coords),"\n";
}
