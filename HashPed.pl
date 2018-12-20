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
use Math::Random::MT qw(srand rand);

my $arg_str = join(' ', @ARGV);
my $options_in_effect = "";
my $file1;
my $bimfile;
my %infoguide1;
my %inforandom1;
my $digestchoice = "sha256";
my $stepsize = 300;
my $missvarthrsh = 2;
my $seed;
my $outfile1 = "outfile.txt";
my $logfile = "log.txt";
my $hshoutfile = "hashlist.txt";

if ($arg_str =~ m/--file1\s+(\S+)/) {
	$file1 = $1;
	$options_in_effect .= "--file1 $1 \t";
}
if ($arg_str =~ m/--digest\s+(\S+)/) {
	$digestchoice = $1;
	$options_in_effect .= "--digest $1 \t";
}
if ($arg_str =~ m/--bimfile\s+(\S+)/) {
       $bimfile = $1;
       $options_in_effect .= "--bimfile $1 \t";
}
if ($arg_str =~ m/--numSNPs\s+(\S+)/) {
	$stepsize = $1 * 2;
	$options_in_effect .= "--numSNPs $1 \t";
}
if ($arg_str =~ m/--missthrsh\s+(\S+)/) {
	$missvarthrsh = $1 ;
	$options_in_effect .= "--missthrsh $1 \t";
}
if ($arg_str =~ m/--seed\s+(\S+)/) {
	$seed = $1 ;
	$options_in_effect .= "--seed $1 \t";
}
if ($arg_str =~ m/--output\s+(\S+)/) {
	$outfile1 = $1;
	$logfile = $1.".log";
	$hshoutfile = $1.".hashlist";
	$options_in_effect .= "--outfile $1 \t";
}
if ($arg_str =~ m/--logfile\s+(\S+)/) {
	$logfile = $1;
	$options_in_effect .= "--logfile $1 \t";
}
if ($arg_str =~ m/--hashoutfile\s+(\S+)/) {
	$hshoutfile = $1;
	$options_in_effect .= "--hashoutfile $1 \t";
}
if ($arg_str =~ m/--help/) {
	&StderrLog(&InfoScreen());
	die;
}

$options_in_effect .= "\n";

open (LOG, ">", $logfile) || die "Cannot open location of $logfile\nExiting program...\n";

my $evalcount = 0;
eval {require Digest::MD5; import Digest::MD5 'md5_hex';}
or do { &StderrLog("$@\n"); &StderrLog("Digest::MD5 module not present on system. Cannot use MD5 in program.\n\n"); $evalcount++;};
eval {require Digest;}
or do { &StderrLog("$@\n"); &StderrLog("Digest module not present on system. Cannot use WHIRLPOOL in program.\n\n"); $evalcount++;};
eval {require Digest::SHA;}
or do { &StderrLog("$@\n"); &StderrLog("Digest::SHA module not present on system. Cannot use SHA-256 in program.\n\n"); $evalcount++;};
if ($evalcount == 3) {
	&StderrLog("Unable to locate any digest algorithm usable by this program on your computer. Please contact your system administrator.\n\n");
}

#Error checking
my $ErrFlg = 0;
if ($evalcount == 3 && $digestchoice ne "nothing") {
	&StderrLog("Attention -- unable to run program. None of the 3 possible digestion algorithms used by this script are present on your system.\n");
	$ErrFlg = 1;
}
if (!$file1 || !$bimfile || !$stepsize || !$digestchoice || !$seed || ($missvarthrsh > 4)) {
	if (!$file1) {
		&StderrLog("Missing location of .ped file with --file1.\n");
	}
	if (!$bimfile) {
		&StderrLog("Missing location of .vim file with --bimfile.\n");
	}
	if (!$stepsize) {
		&StderrLog("Missing amount of SNPs to use per hash with --numSNPs.\n");
	}
	if (!$digestchoice) {
		&StderrLog("Missing encryption algorithm choice with --digest.\n");
	}
	if (!$seed) {
		&StderrLog("Missing value between 0 and 4294967295 with --seed.\n");
	}
	if ($missvarthrsh > 4) {
		&StderrLog("Missing genotype threshold value $missvarthrsh provided by --missthrsh greater than 4. Max value for --missthrsh is 4. Recommended value, and program default, is 2.\n");
	}
	$ErrFlg = 1;
}

if ($ErrFlg == 1) {
	&StderrLog("Exiting program...\n\n");
	&InfoScreen();
	die;
}

srand($seed);

#Loading .bim file. Contains true location of every SNP, and will be used to create the random order SNPs will be hashed in
my $input2 = &Fzinopen($bimfile);

my $count1 = 6;

while(<$input2>) {

	my @infoparse = split(/\s+/);
	chomp(@infoparse);
	$infoparse[4] =~ s/\x0D//g;
	$infoparse[5] =~ s/\x0D//g;
	$infoguide1{ $infoparse[1] } = $count1; 
	$inforandom1{ $count1 } = \@infoparse; 
	$count1 += 2;

}

close ($input2);

#Creating homozygous positive control
my @PstCtrl;

push(@PstCtrl, ("PosCtrl", "PosCtrl", 0, 0, 0, 0));

foreach my $cnt1 (sort {$a <=> $b} keys %inforandom1) {
	my $a1 = ${$inforandom1{$cnt1}}[4];
	my $a2 = ${$inforandom1{$cnt1}}[5];

	my $use;
	if (($a1 gt $a2) || ($a1 eq $a2)) {
		$use = $a1;
	}
	elsif ($a2 gt $a1) {
		$use = $a2;
	}
	else {
		&StderrLog("Error 1 - Variable \$a1 is neither greater than, less than or equal to variable \$a2: $a1 $a2. This, theoretically, should not occur. This code has potentially been corrupted. Please download the program again and rerun.\n");
		&StderrLog("Exiting program...\n");
		die;
	}

	$PstCtrl[$infoguide1{${$inforandom1{$cnt1}}[1]}] = $use;
	$PstCtrl[$infoguide1{${$inforandom1{$cnt1}}[1]}+1] = $use;
}

#Creating random order for SNPs to be hashed based on .bim file and --seed value provided
my @bimKeys = keys %inforandom1;
my @bimValues = values %inforandom1;
&fisher_yates_shuffle(\@bimValues);
@inforandom1{@bimKeys} = (@bimValues);

#Beginning main loop
my $input1 = &Fzinopen($file1);
open (OUTPUT1, ">", $outfile1) || die "Cannot open location of $outfile1\nExiting program...\n";

print LOG "Hashing $file1 ... \n";

#Entering actual data
my $PstCtrlFlg = 0;
my $misshshtotal = 0;
my $hashtotal = 0;
my @locarray;

MAIN: while(<$input1>){
	
	my @locarray;
	if ($PstCtrlFlg == 0) {		#Determining if positive control has been hashed or not. If not, i.e. PstCntrlFlg == 0, running positive control individual through MAIN loop. Afterwards, rerunning MAIN loop so that the first line of input from file1 is not skipped.
		@locarray = @PstCtrl;
	}
	else {
		@locarray = split(/\s+/);
	}
	chomp(@locarray); 
	my @fnloutarray;
	print "Individual $locarray[1]: Hashing...\n";
	print OUTPUT1 $locarray[0], "\t", $locarray[1], "\t";

	my $i = 6;
	
	OUTHASH: for (; $i <= $#locarray; $i += $stepsize) { 
		my @outarraycol;
		my $hashedoutval;
		my $digestmechanism;

		#Setting up hashing functions
		if ($digestchoice eq "md5") {
			$digestmechanism = Digest::MD5->new;	
		}
		elsif ($digestchoice eq "whirlpool") {
			$digestmechanism = Digest->new( 'Whirlpool' );
		}
		elsif ($digestchoice eq "sha256") {
			$digestmechanism = Digest::SHA->new(256);
		}
		elsif ($digestchoice eq "nothing") {

		}
		else {
			&StderrLog("Did not use correct --digest flag argument. Default is \"sha256\". Please read provided documentation for proper --digest use and arguments.\n");
			die;
		}
		
		#Setting up beginning variables
		my $arraycnt = 0;
		my $k = $i;
		my $h = $k + $stepsize;
		my $flag1 = 0;
		my $flag2 = 0;
		my $missvarcnt = 0; 

		#Beginning loop by checking end of file isn't coming up. If so, loop is exited.
		if (defined $locarray[$h]) {
			INHASH: for (; $k < $h; $k += 2) {
				my $trueloc = 0;
				my $snp = ${$inforandom1{$k}}[1];
				
				#Expected genotypes
				my $c = lc(${$inforandom1{$k}}[4]);	
				my $d = lc(${$inforandom1{$k}}[5]);
			
				#Actual location of SNP in .ped file
				$trueloc = $infoguide1{$snp};
				
				#Observed genotypes
				my $a = lc($locarray[$trueloc]);
				my $b = lc($locarray[$trueloc+1]);
				
				#Creating list of genotype possibilities
				my @possibilities1 = ([($c, $c)], [($c, $d)], [($d, $d)]);		
				my @possibilities2 = ($c, $d);		
				my @possibilities3;		
				
				my $acmp = &ComplementBP($a);
				if ($acmp eq "-9") {
					&StderrLog("Individual $locarray[0] SNP $snp position $trueloc: $a is not a recognized basepair. Fix and rerun program.\n");
					die;
				}
				my $bcmp = &ComplementBP($b);
				if ($bcmp eq "-9") {
					&StderrLog("Individual $locarray[0] SNP $snp position " . ($trueloc+1) . ": $b is not a recognized basepair. Fix and rerun program.\n");
					die;
				}
	
				my $possibilities3ref;
				($a, $b, $possibilities3ref) = @{&SNPFlip($a, $b, $c, $d, $acmp, $bcmp, $k, $snp, $locarray[0], $trueloc)};
				@possibilities3 = @{$possibilities3ref};
				
				#Checking to see if either allele is missing, then figuring out what to do next if so
				if (($a eq "0") || ($b eq "0")) {
					
					#If missing genotypes exceeds $missvarthrsh threshold, exit current group of SNPs and assign a 0 instead of an encrypted hash output
					if ($missvarcnt >= $missvarthrsh) { 
						$flag2 = 1;
						$missvarcnt++;
						$misshshtotal++;
						$hashtotal++; 
						last INHASH;
					}
					
					
					#If either or both alleles are missing, and this has occured in less than $missvarthrsh SNPs thus far, give every possible genotype that could be present and continue on 
					my @outarraycoltemp;
					if (($a eq "0") && ($b eq "0")) {
						foreach my $pos1set (@possibilities1) {
							$a = ${$pos1set}[0];
							$b = ${$pos1set}[1];
							push (@outarraycoltemp, &Transform($a, $b, $c, $d, $k, $snp, $locarray[0], $trueloc));
						}
					}
					elsif (($a eq "0") && ($b ne "0")) {
						foreach my $posfora (@possibilities2) {
							$a = $posfora;
							push (@outarraycoltemp, &Transform($a, $b, $c, $d, $k, $snp, $locarray[0], $trueloc));
						}
					}
					elsif (($a ne "0") && ($b eq "0")) {
						foreach my $posforb (@possibilities3) {
							$b = $posforb;
							push (@outarraycoltemp, &Transform($a, $b, $c, $d, $k, $snp, $locarray[0], $trueloc));
						}
					}
					else {
					
					}
					
					my $strngadd = "[" . join("/", @outarraycoltemp) . "]";
					$outarraycol[$arraycnt] = $strngadd;
				
					$missvarcnt++;
				
				}
				#Otherwise, just include next SNP
				else {		
						$outarraycol[$arraycnt] = &Transform($a, $b, $c, $d, $k, $snp, $locarray[0], $trueloc);
				}
			
				$arraycnt++;
			
			}

		}
		else {
			$flag1 = 1;
		}
		
		#Hashing, and checking to see if there are multiple possibilties for any single SNP position.			
		if (($flag1 == 0) && ($flag2 == 0)) {
			my @hashedoutarray;
			my $outarraycolbgn = join("", @outarraycol);;
			my @outarraycoltemp1 = ();
			my @outarraycoltemp2 = ($outarraycolbgn);
					
			while ($outarraycolbgn =~ m/.*\[.*\].*/) {
				@outarraycoltemp1 = @outarraycoltemp2;
				@outarraycoltemp2 = ();
				my $rounds = $#outarraycoltemp1;
				if ($rounds == -1) {
					$rounds = 0;
				}
				RNDS: for (my $l = 0; $l <= $rounds; $l++) {
					my $outarraycolcrt;
					if ($rounds == 0) {
						$outarraycolcrt = $outarraycolbgn;
					}
					elsif ($rounds > 0) {
						$outarraycolcrt = $outarraycoltemp1[$l];
					}
					else {
						&StderrLog("Error 2 - Variable \$rounds is neither positive or equal to 0. This, theoretically, should not occur. This code has potentially been corrupted. Please download the program again and rerun.\n");
						&StderrLog("Exiting program...\n");
						die;
					}
						
					if ($outarraycolcrt =~ m/(.*)(\[.*\])(.*)/) {
						my ($tempval1, $tempval2, $tempval3) = ($1, $2, $3);
						$tempval2 =~ s/\[//g;
						$tempval2 =~ s/\]//g;
						my @varnts2 = split(/\//, $tempval2);
						for (my $m = 0; $m <= $#varnts2; $m++) {
							my $newstrng2 = $tempval1 . $varnts2[$m] . $tempval3;
							push (@outarraycoltemp2, $newstrng2);
						}
					}
					else {

					}
				}
			
				$outarraycolbgn = join("", $outarraycoltemp2[0]);

			}
			
			push (@outarraycoltemp1, @outarraycoltemp2);

			OUTARRAY1: for (my $l = 0; $l <= $#outarraycoltemp1; $l++) {
				if ($digestchoice eq "md5") {
					chomp($hashedoutval = $digestmechanism->add($outarraycoltemp1[$l])->hexdigest);
				}
				elsif ($digestchoice eq "whirlpool") {
					chomp($hashedoutval = $digestmechanism->add($outarraycoltemp1[$l])->hexdigest);
				}
				elsif ($digestchoice eq "sha256") {
					chomp($hashedoutval = $digestmechanism->add($outarraycoltemp1[$l])->hexdigest);
				}	
				elsif ($digestchoice eq "nothing") {
					$hashedoutval = $outarraycoltemp1[$l];
				}
				else {
					&StderrLog("Did not use correct --digest flag argument. Default is \"sha256\". Please read provided documentation for proper --digest use and arguments.\n");
					die;
				}	
				push(@hashedoutarray, $hashedoutval);
			} 
			
			print OUTPUT1 join(",", @hashedoutarray), "\t";
			
		}	
		elsif ($flag2 == 1) {
			print OUTPUT1 0, "\t";
		}
		elsif ($flag1 == 1) {
			last OUTHASH; 
		}
		else {
		
		}
		$hashtotal++;
	}	
	
	print OUTPUT1 "\n";

	if ($PstCtrlFlg == 0) {		#Redoing MAIN loop, but now going ahead with input file data
		$PstCtrlFlg = 1;
		redo MAIN;
	}

}

close($input1);
close(OUTPUT1);

#Printing out order in which SNPs were included per hash
print LOG "Printing out SNP hash order...\n";
open (HASHLST, ">", $hshoutfile) || die "Cannot open location of $hshoutfile\nExiting program...\n";

@bimKeys = sort {$a <=> $b } keys %inforandom1;
foreach my $hshkey (@bimKeys) {
	print HASHLST ${inforandom1{$hshkey}}[1], "\n";
}

close(HASHLST);

print LOG "Success!\n";
print LOG "Out of $hashtotal total hashes, $misshshtotal had missing data above the threshold of $missvarthrsh.\n";

&StderrLog("Finished.\n");


########
#Extra Functions
########

#Print to STDERR and LOG file
sub StderrLog {
	my $line = $_[0];
	print STDERR $line;
	print LOG $line;
}

#Open a zipped or unzipped file
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

#Lowercase complement basepair function
sub ComplementBP {
	my $allele1 = $_[0];
	if ($allele1 eq "a") {
		$allele1 = "t";
	}
	elsif ($allele1 eq "g") {
		$allele1 = "c";
	}
	elsif ($allele1 eq "c") {
		$allele1 = "g";
	}
	elsif ($allele1 eq "t") {
		$allele1 = "a";
	}
	elsif ($allele1 eq "0") {
		$allele1 = "0";
	}
	else {
		$allele1 = "-9";
	}
	
	return $allele1;
}

#Coding combinations of alleles
sub Transform { 
	my $afa = $_[0];
	my $afb = $_[1];
	my $afc = $_[2];
	my $afd = $_[3];
	my $kcpy = $_[4];
	my $snpcpy = $_[5];
	my $locarraycpy = $_[6];
	my $trueloccpy = $_[7];
	my $retval;
		
	#Checking all genotype possibilities to determine replacement letter for hash use
	if ($afa eq "a") {
		if ($afb eq "a") {
			$retval = "a";
		}
		elsif ($afb eq "g") {
			$retval = "b";
		}
		elsif ($afb eq "t") {
			$retval = "c";
		}
		elsif ($afb eq "c") {
			$retval = "d";
		}					
		else {
			&StderrLog("Individual $locarraycpy SNP $snpcpy position " . ($trueloccpy+1) . ". Second chromosome genotype $afb is not a recognized basepair. Fix and rerun program.\n");
			die;
		}
	}
	elsif ($afa eq "g") {
		if ($afb eq "a") {
			$retval = "e";
		}
		elsif ($afb eq "g") {
			$retval = "f";
		}
		elsif ($afb eq "t") {
			$retval = "g";
		}
		elsif ($afb eq "c") {
			$retval = "h";
		}					
		else {
			&StderrLog("Individual $locarraycpy SNP $snpcpy position " . ($trueloccpy+1) . ": Second chromosome genotype $afb is not a recognized basepair. Fix and rerun program.\n");
			die;
		}
	}
	elsif ($afa eq "t") {
		if ($afb eq "a") {
			$retval = "i";
		}
		elsif ($afb eq "g") {
			$retval = "j";
		}
		elsif ($afb eq "t") {
			$retval = "k";
		}
		elsif ($afb eq "c") {
			$retval = "l";
		}					
		else {
			&StderrLog("Individual $locarraycpy SNP $snpcpy position " . ($trueloccpy+1) . ": Second chromosome genotype $afb is not a recognized basepair. Fix and rerun program.\n");
			die;
		}
	}
	elsif ($afa eq "c") {
		if ($afb eq "a") {
			$retval = "m";
		}
		elsif ($afb eq "g") {
			$retval = "n";
		}
		elsif ($afb eq "t") {
			$retval = "o";
		}
		elsif ($afb eq "c") {
			$retval = "p";
		}					
		else {
			&StderrLog("Individual $locarraycpy SNP $snpcpy position " . ($trueloccpy+1) . ": Second chromosome genotype $afb is not a recognized basepair. Fix and rerun program.\n");
			die;
		}
	}
	else {
		&StderrLog("Individual $locarraycpy SNP $snpcpy position $trueloccpy: First chromosome genotype $afa is not a recognized basepair. Fix and rerun program.\n");
		die;
	}

	return $retval;

}

#Checking to see if current alleles, or flipped alleles, match expected genotypes from SNP input file
sub SNPFlip { 
	my $afa = $_[0];
	my $afb = $_[1];
	my $afc = $_[2];
	my $afd = $_[3];
	my $afacmp = $_[4];
	my $afbcmp = $_[5];
	my $kcpy = $_[6];
	my $snpcpy = $_[7];
	my $locarraycpy = $_[8];
	my $trueloccpy = $_[9];
	my @possibilities32;
	my @results2sub;

	#First identifying whether genotypes are missing
	if (($afa eq "0") || ($afb eq "0")) {
		if (($afa eq "0") && ($afb eq "0")) {
						
		}
		elsif ($afa eq "0") {
			if (($afbcmp eq $afc) || ($afbcmp eq $afd)) {
				print LOG "Individual $locarraycpy SNP $snpcpy position " . ($trueloccpy+1) . ": Flipping strand of second chromosome genotype $afb to $afbcmp.\n";
				$afb = $afbcmp;
			}
			if ($afb eq $afc) {

			}
			elsif ($afb eq $afd) {

			}
			else {
				&SderrLog("Individual $locarraycpy SNP $snpcpy position " . ($trueloccpy+1) . ": Genotypes $afb and flipped strand version $afbcmp do not match expected genotypes $afc or $afd. Check your data and rerun.\n");
				die;
			}
		}
		elsif ($afb eq "0") {
			if (($afacmp eq $afc) || ($afacmp eq $afd)) {
				print LOG "Individual $locarraycpy SNP $snpcpy position $trueloccpy: Flipping strand of first chromosome genotype $afa to $afacmp.\n";
				$afa = $afacmp;
			}
			if ($afa eq $afc) {
				@possibilities32 = ($afc, $afd);
			}
			elsif ($afa eq $afd) {
				@possibilities32 = ($afd);
			}
			else {
				&SderrLog("Individual $locarraycpy SNP $snpcpy position $trueloccpy: Genotypes $afa and flipped strand version $afacmp do not match expected genotypes $afc or $afd. Fix and rerun.\n");
				die;
			}
		}
		else {

		}
	}
				
	#Checking switch/flip status if neither genotype is missing
	else {		
		if ((($afa eq $afc) && ($afb eq $afc)) || (($afa eq $afc) && ($afb eq $afd)) || (($afa eq $afd) && ($afb eq $afc)) || (($afa eq $afd) && ($afb eq $afd)) || (($afacmp eq $afc) && ($afbcmp eq $afc)) || (($afacmp eq $afc) && ($afbcmp eq $afd)) || (($afacmp eq $afd) && ($afbcmp eq $afc)) || (($afacmp eq $afd) && ($afbcmp eq $afd)))  {
		
			#Checking to see if expected alleles are being used
			if ((($afa eq $afc) && ($afb eq $afc)) || (($afa eq $afc) && ($afb eq $afd)) || (($afa eq $afd) && ($afb eq $afd))) {

			}
			
			#Checking to see if alleles should be switched
			elsif (($afa eq $afd) && ($afb eq $afc)) {
				print LOG "Individual $locarraycpy SNP $snpcpy position $trueloccpy: Switching order of genotypes $afa and $afb to $afb and $afa.\n";
				($afa, $afb) = ($afb, $afa);
			}	
			
			#Checking to see if alleles should be flipped, or flipped and switched						
			elsif ((($afacmp eq $afc) && ($afbcmp eq $afc)) || (($afacmp eq $afc) && ($afbcmp eq $afd)) || (($afacmp eq $afd) && ($afbcmp eq $afc)) || (($afacmp eq $afd) && ($afbcmp eq $afd))) {
				if (($afacmp eq $afd) && ($afbcmp eq $afc)) {
					print LOG "Individual $locarraycpy SNP $snpcpy position $trueloccpy: Flipping strand and switching position of genotypes $afa and $afb to $afbcmp and $afacmp.\n";
					($afa, $afb) = ($afbcmp, $afacmp);
				}
				else {
					print LOG "Individual $locarraycpy SNP $snpcpy position $trueloccpy: Flipping strand of genotypes $afa and $afb to $afacmp and $afbcmp.\n";
					($afa, $afb) = ($afacmp, $afbcmp);
				}	
			}
			
			else {

			}
		}
		
		else {
			&StderrLog("Individual $locarraycpy SNP $snpcpy positions $trueloccpy & " . ($trueloccpy+1) . " : Genotypes $afa, $afb, and flipped strand versions $afacmp and $afbcmp, do not match expected genotypes $afc and/or $afd. Fix and rerun.\n");
			die;
		}
	}
	
	@results2sub = ($afa, $afb, \@possibilities32);
				
	return \@results2sub;
	
}

#Fisher yates shuffle algorithm

sub fisher_yates_shuffle {
	my $deck = shift;  # $deck is a reference to an array
	my $j = @$deck;
	while (--$j) {
		my $k = int rand ($j+1);
		next if $j == $k;	
		@$deck[$j,$k] = @$deck[$k,$j];
	}
}

#Help info screen

sub InfoScreen { 
	print STDERR "perl HashPed.pl --file1 <.ped file> --bimfile <.bim file> --digest <md5, whirlpool, or sha256> --ssed <pos whole number> --output <output filename>\n";
	print STDERR "Main Arguments:\n";
	print STDERR "--file1 <.ped file>\tLocation of .ped file to be encrypted.\n";
	print STDERR "--bimfile <.bim file>\tLocation of .bim file associated with .ped file being encrypted.\n";
	print STDERR "--digest <sha256, whirlpool or md5>\tName of the one-way cryptographic hash encryption algorithm to be used by the script. sha256 is the recommended algorithm.\n";
	print STDERR "--seed <pos whole number>\tAny whole number between 0 and 4294967295 to remain constant between datasets being compared using CompHash.pl.\n"; 
	print STDERR "--output <filename>\tLocation of output file. Default is 'outfile.txt'.\n";
	print STDERR "\n";	
	print STDERR "Additional Arguments:\n";
	print STDERR "--numSNPs <pos whole number>\tNumber of SNPs to include per hash. Recommended number is 150 SNPs per hash.\n";
	print STDERR "--missthrsh <pos whole number>\tNumber of SNPs that are allowed to be missing before the script abandons the hash and puts a 0 in its place. Value must be less than or equal to 4. The default value is 2.\n";
	print STDERR "--logfile <filename>\tLocation of logfile. Default is 'log.txt'.\n";
	print STDERR "--hashoutfile <filename>\tLocation of file listing rsIDs in the order they were included per hash. Default is 'hashlist.txt'.\n";
	exit 1;
}

close(LOG);
