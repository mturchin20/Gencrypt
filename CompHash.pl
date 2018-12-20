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
my @fnlarray1;
my @fnlarray2;
my $file1;
my $file2;
my $threshold = .1;
my $outfile1 = "output.txt";

if ($arg_str =~ m/--file1\s+(\S+)/) {
	$file1 = $1;
	$options_in_effect .= "--file1 $1 \t";
}
if ($arg_str =~ m/--file2\s+(\S+)/) {
	$file2 = $1;
	$options_in_effect .= "--file2 $1 \t";
}
if ($arg_str =~ m/--threshold\s+(\S+)/) {
	$threshold = $1;
	$options_in_effect .= "--threshold $1 \t";
}
if ($arg_str =~ m/--output\s+(\S+)/) {
	$outfile1 = $1;
	$options_in_effect .= "--outfile $1 \t";
}
if ($arg_str =~ m/--help/) {
	&InfoScreen();
	die;
}

$options_in_effect .= "\n";

#Error checking
if (!$file1 || !$file2 || (($threshold < 0) || ($threshold > 1)) ) {
	if (!$file1) {
		print STDERR "Missing location of one-way hashed .ped file1 with --file1.\n";
	}
	if (!$file2) {
		print STDERR "Missing location of one-way hashed .ped file2 with --file2.\n";
	}
	if (($threshold < 0) || ($threshold > 1)) {
		print STDERR "Threshold $threshold is not between or equal to 0 and 1. Please rerun with a correct argument to the --threshold flag.\n";
	}
	print STDERR "Exiting program...\n\n";
	&InfoScreen();
	die;
}

my $input1 = &Fzinopen($file1);
while (<$input1>) {

	my @infoparse = split(/\s+/);
	chomp (@infoparse);
	my @temparray;
	foreach my $line (@infoparse) {
		$line =~ s/\x0D//g;
		push (@temparray, $line);
	}
	push (@fnlarray1, \@temparray);

}
close ($input1);

my $input2 = &Fzinopen($file2);
while (<$input2>) {

	my @infoparse = split(/\s+/);
	chomp (@infoparse);
	my @temparray;
	foreach my $line (@infoparse) {
		$line =~ s/\x0D//g;
		push (@temparray, $line);
	}
	push (@fnlarray2, \@temparray);

}
close ($input2);

open (OUTPUT1, ">", $outfile1) || die "Cannot open location of $outfile1\nExiting program...\n";

print OUTPUT1 "IID1\tIID2\tPercent_Identical_Hashes\n";

#Going through hashes
LP1: for (my $z=0; $z <= $#fnlarray1; $z++) {
	my @temparray1 = @{$fnlarray1[$z]};
	my $indvname1= $temparray1[1];
	print STDERR "Matching Individual $indvname1...\n";


	LP2: for (my $y=0; $y <= $#fnlarray2; $y++){
		my @temparray2 = @{$fnlarray2[$y]};
		my $correctcount = 0;
		my $totalcount = 0;
		my $indvname2 = $temparray2[1];


		LP3: for (my $x=2; $x <= $#temparray1; $x++) {	

			if ($temparray1[$x] eq 0) {
				$totalcount++;
			}
			else {
				my @cont1;
				my @cont2;
	
				if ($temparray1[$x] =~ m/,/) {
					my @list1 = split(/,/, $temparray1[$x]);
					foreach my $entry1 (@list1) {
						push (@cont1, $entry1);
					}
				}
				else {
					push (@cont1, $temparray1[$x]);
				}

					
				if ($temparray2[$x] =~ m/,/) {
					my @list2 = split(/,/, $temparray2[$x]);
					foreach my $entry2 (@list2) {
						push (@cont2, $entry2);
					}
				}
				else {
					push (@cont2, $temparray2[$x]);
				}
				
				LP4: foreach my $posb1 (@cont1) {
					LP5: foreach my $posb2 (@cont2) {
						if ($posb1 eq $posb2) {
							$correctcount++;
							$totalcount++;
							next LP3;
						}
					}
				}
				
				$totalcount++;
			}
		}
		
		my $overlap;

		if ($totalcount > 0) {
			$overlap = $correctcount/$totalcount;
		}
		else {
			$overlap = 0;
		}

		if ($overlap >= $threshold) {
			print OUTPUT1 $indvname1, "\t", $indvname2, "\t", $overlap, "\n";
		}

	}
}

print STDERR "Done!\n";

close (OUTPUT1);

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
	print STDERR "perl CompHash.pl --file1 <output from HashPed.pl> --file2 <output from HashPed.pl> --output <output filename>\n";
	print STDERR "Main Arguments:\n";
	print STDERR "--file1 <output from HashPed.pl>\tLocation of first output file from HashPed.pl you are comparing.\n";
	print STDERR "--file2 <output from HashPed.pl>\tLocation of second output file from HashPed.pl you are comparing.\n";
	print STDERR "--output <output filename>\tLocation of output file. Default is 'outfile.txt'.\n";
	print STDERR "Additional Arguments:\n";
	print STDERR "--threshold <0 to 1>\tThreshold percentage of identical encrypted hashes two pairs must have before being displayed. Setting to 0 will display results of all pair-wise comparisons. Default is set at .1.\n";
	exit 1;
}
