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
my $file1;
my $subset;
my @array1;
my $outfile1 = "outfile1.txt";

if ($arg_str =~ m/--file1\s+(\S+)/) {
	$file1 = $1;
	$options_in_effect .= "--file1 $1 \t";
}
if ($arg_str =~ m/--subset\s+(\S+)/) {
	$subset = $1;
	$options_in_effect .= "--subset $1 \t";
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
if ((!$file1) || ($subset !~ m/\d+/)) {
	if (!$file1) {
		print STDERR "Missing location of input file1 with --file1.\n";
	}
	if ($subset !~ m/\d+/) {
		print STDERR "Missing numeric value for --subset.\n";
	}
	print STDERR "Exiting program...\n\n";
	&InfoScreen();
	die;
}

my $input1 = &Fzinopen($file1);
while (<$input1>) {
	my @temparray = split(/\s+/);
	chomp(@temparray);
	push (@array1, \@temparray);
}

close ($input1);

#Error checking 2
if ($subset > scalar(@array1)) {
	die "Subset amount $subset larger than number of input rows, " . scalar(@array1) . ". Rerun with correct --subset agrument.\nExiting program...\n\n";
}

open (OUTPUT1, ">", $outfile1) || die "Cannot open location of $outfile1\nExiting program...\n";

for (my $i = 0; $i < $subset; $i++) {
	my $val1 = rand($#array1);
	print OUTPUT1 join("\t", @{$array1[$val1]}), "\n";
	splice(@array1, $val1, 1);
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
	print STDERR "perl ListSubset.pl --file1 <input file1> --subset <whole number> --output <output filename>\n";
	print STDERR "Main Arguments:\n";
	print STDERR "--file1 <input file1>\tLocation of file1 that a subset of content will be taken from.\n";
	print STDERR "--subset <whole number>\tNumber of rows to randomly extract from input file1. Must be less than or equal to total length of input file.\n";
	print STDERR "--output <output filename>\tLocation of output file. Default is 'outfile.txt'.\n";
	exit 1;
}
