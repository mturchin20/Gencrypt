################
#	Gencrypt v1.0.0 - One-way cryptographic hashes to identify overlapping individuals
#   Copyright (C) 2011  Turchin, M.C. and Hirschhorn, J.N.
#
#   This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.
################

#!/bin/perl -w
use strict;
use IO::File;
use IO::Uncompress::Gunzip qw(gunzip $GunzipError);

my $arg_str = join(' ', @ARGV);
my $options_in_effect = "";
my $files;
my $hash1ref;
my $outfile1 = "outfile1.txt";

if ($arg_str =~ m/--files\s+(\S+)/) {
	$files = $1;
	$options_in_effect .= "--files $1 \t";
}
if ($arg_str =~ m/--output\s+(\S+)/) {
	$outfile1 = $1;
	$options_in_effect .= "--outfile1 $1 \t";
}
if ($arg_str =~ m/--help/) {
	&InfoScreen();
	die;
}
	
#Error checking
if (!$files) {
	print STDERR "Missing comma-separated list of .bim files provided with --files.\n";
	print STDERR "Exiting program...\n\n";
	&InfoScreen();
	die;
}

my @fileList = split(/,/, $files);
my $count1 = 0;

foreach my $file1 (@fileList) {
	my %hash1;


	my $input1 = &Fzinopen($file1);
	
	while (<$input1>) {
		my @infoparse = split(/\s+/);
		chomp(@infoparse);
		if ($count1 == 0) {
			$hash1{$infoparse[1]} = 1;
		}
		elsif ($count1 == 1) {
			if (${$hash1ref}{$infoparse[1]}) {
				$hash1{$infoparse[1]} = 1;
			}
		}
		else {
			print STDERR "Error 1 - count1, $count1, surpassed 1. This, theoretically, should not be possible. Please download program again and rerun. Contact present Gencrypt administrator if this problem persists.\n\n";
			die;
		}
	}
	
	close($input1);

	if ($count1 == 0) {
		$count1++;
	}
	
	$hash1ref = \%hash1;

}
	
open (OUTPUT1, ">", $outfile1) || die "Cannot open location of $outfile1\nExiting program...\n";

foreach my $snp1 (keys %{$hash1ref}) {
	print OUTPUT1 $snp1, "\n";
}

close(OUTPUT1);

sub Fzinopen {
	my $filename = shift || "";
	my $fh;
	if($filename && ($filename =~ m/\.gz$/)) {
		$fh = new IO::Uncompress::Gunzip $filename or die "Cannot open location of $filename using gzip\nExiting program...\n";
	} 
	else {
		$fh = new IO::File;
		$fh->open("<$filename") or die "Cannot open location of $filename\nExiting program...\n";
	}
	return $fh;
}

sub InfoScreen {
	print STDERR "perl OverlappingSNPs.pl --files <csv list of .bim files> --output <output filename>\n";
	print STDERR "Main Arguments:\n";
	print STDERR "--files <csv list of .bim files>\tComma-separated list of all .bim files to be compared\n";
	print STDERR "--output <output filename>\tLocation of output file. Default is 'outfile.txt'.\n";
	exit 1;
}
