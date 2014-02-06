#!/usr/bin/perl

while (<STDIN>) {
        s/\r\n/\n/gi;	 # replace DOS returns with Unix newlines
        s/\r/\n/gi ;     # replace Mac returns with Unix newlines
        print $_ ;
}
