Gencrypt v1.0.0 - One-way cryptographic hashes to identify overlapping individuals
Copyright (C) 2011 Turchin, M.C. and Hirschhorn, J.N.

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program.  If not, see <http://www.gnu.org/licenses/>.


Outline:

Gencrypt works by dividing up genetic information into groups of SNPs that are then processed through a one-way cryptographic hash algorithm. These groups of hashed SNPs are then compared between datasets, and pairs of individuals that have a large proportion of identical hash outputs are printed out. These pairs are suggested as being the same individual in each study compared.

The program itself is split into two scripts. HashPed.pl runs data through the one-way hash algorithm specified by the user, and CompHash.pl compares one-way hashed datasets to identify overlapping individuals. 

Gencrypt runs on Perl versions 5.8.9+


Details:

HashPed.pl

perl HashPed.pl --file1 <.ped file> --bimfile <.bim file> --digest <md5, whirlpool, or sha256> --seed <pos whole number> --output <output filename>

Main Arguments

--file1 <.ped file> Location of .ped file to be encrypted.

--bimfile <.bim file> Location of .bim file associated with .ped file being encrypted.

--digest <sha256, whirlpool or md5 > Name of the one-way cryptographic hash encryption algorithm to be used by the script. sha256 is the recommended algorithm. whirlpool and md5 are also supported.

--seed <pos whole number> Any whole number between 0 and 4294967295 to remain constant between datasets being compared using CompHash.pl.

--output <filename> Location of the output file. Default is 'outfile.txt'.

Additional Arguments

--numSNPs <pos whole number> Number of SNPs to include per hash. See Turchin and Hirschhorn 2011 for details, but for security reasons it is recommended that this value is kept at or above 150. The default value is 150.

--missthrsh <pos whole number> Number of SNPs that are allowed to be missing before the script abandons the hash and puts a 0 in its place. Gencrypt is able to handle low levels of missingness by replacing missing genotypic information with all 3 possible genotypic combinations at that locus. The number of times it replaces missing genotypic information per group of SNPs is set by --missthrsh. The result is multiple hash outputs representing a single group of SNPs, with each hash output containing one of the possible genotypes from the locus with the missing information. If this is done more than once, the total number of hash outputs produced for a group of SNPs is equal to 3n, where n is what --missthrsh is set to. When the number of missing genotypes in a group of SNPs is greater than n, the one-way hash is abandoned, and a 0 is outputted in its place. It is recommended that n is kept low, both because of computational reasons and to avoid breaking down the specificity this approach necessitates. The default value of n, and the value recommended by the authors, is 2. Gencrypt will not run if n is greater than 4.

--logfile <filename> Location of logfile. Default is 'log.txt'.

--hashoutfile <filename> Location of file listing rsIDs in the order they were included per hash. Default is 'hashlist.txt'


CompHash.pl

perl CompHash.pl --file1 <output from HashPed.pl > --file2 <output from HashPed.pl > --output <output file name>

Main Arguments

--file1 <output from HashPed.pl> Location of first output file from HashPed.pl you are comparing.

--file2 <output from HashPed.pl> Location of second output file from HashPed.pl you are comparing.

--output <output filename> Location of output file. Default is 'outfile.txt'.

Additional Arguments

--threshold <0 to 1> Threshold percentage of identical encrypted hashes two pairs must have before being displayed. Setting to 0 will display results of all pair-wise comparisons. Default is set at .1.


OverlappingSNPs.pl

perl OverlappingSNPs.pl --files <csv list of .bim files> --output <output filename>

Main Arguments

--files <csv list of .bim files> Comma-separated list of all .bim files to be compared

--output <output filename> Location of output file. Default is 'outfile.txt'.


ListSubset.pl

perl ListSubset.pl --file1 <input file1> --subset <whole number> --output <output filename>


Main Arguments

--file1 <input file1> Location of file1 that a subset of content will be taken from.

--subset <whole number> Number of rows to randomly extract from input file1. Must be less than or equal to total length of input file.

--output <output filename> Location of output file. Default is 'outfile.txt'.


Considerations:

HashPed.pl

1) Which one-way cryptographic hash algorithm to use. As stated in the manuscript, the default and recommended one-way cryptographic hash algorithm used by Gencrypt is SHA-256. SHA-256 is currently the most secure and reliable one-way cryptographic hash algorithm supported by Gencrypt. SHA-256 has yet to be broken, or have any official collisions reported (though they are possible theoretically). However, for flexibility purposes, WHIRLPOOL and MD5 are supported as well. Use of these alternative one-way cryptographic hash algorithms is left to the user’s discretion. It is recommended that users understand the caveats of either alternative algorithm prior to using them.

2) What SNPs to use. It is required that SNPs used be included in all datasets being compared. SNPs used from within this subset should contain low levels of missingness (<2% SNP missingness, or SNPs that produce <1% individual missingess), and not be not rare (MAF > 5%). If possible, choosing SNPs whose MAFs are between 40% and 50% is ideal, since these SNPs will have the most variability between individuals, and therefore provide the greatest power. It is also preferable not to include AT/GC SNPs (SNPs whose reference allele and other allele are either A/T, or G/C), to avoid issues determining strandedness between datasets being compared. 

3) Total number of SNPs to use. The recommended number is 20,000. This number is kept low to facilitate researchers finding overlapping SNPs of high genotyping quality between multiple studies. Going lower than this number increasingly raises the likelihood of falsely identifying two individuals as identical. Going higher than this number is fine if there are more overlapping SNPs of high quality available.

4) Order in which SNPs are hashed. The order in which SNPs are hashed is determined by the .bim file. HashPed.pl goes down the .bim file in multiples of what --numSNPs specifies. Leaving the .bim file in the default PLINK chromosomal basepair order produces cryptic patterns of relation between hashes due to underlying linkage disequilibrium between SNPs. This in turn can increase the likelihood of the original input being recovered from the one-way cryptographic hash outputs. Due to this potentially confounding effect, it is recommended that .bim files are randomly reorganized. Doing so should break up any underlying relations hashes could have with one another due to linkage disequilibrium. 
       To facilitate this process, HashPed.pl internally randomly reorganizes the input .bim file during the running of the script. However, to ensure that different runs of the program produce the same randomized order, the user is able to specify a --seed value. This value primes the random number generator the code is using, and as long as the same --seed value is specified in multiple runs of HashPed.pl, the same random order of SNPs will be used. Users wanting to compare output from different runs of HashPed.pl are therefore required to provide the same --seed value for each run. Otherwise, output from HashPed.pl is not directly comparable, and results from CompHash.pl using these outputs are uninterpretable.

5) SNPs used, and SNP order, must remain the same across all datasets being compared. If the SNPs being used and their associated order are not the same between studies being compared, then the output from CompHash.pl is not interpretable, since different SNPs were included in each hash between each study. Therefore, an important part of implementing this program is to establish which SNPs are being used across every dataset, and the --seed value being used (i.e. the order in which SNPs will be hashed), prior to running HashPed.pl and comparing its output between different datasets.

6) Negative Control. A file containing the order in which SNPs were included per hash is automatically outputted at the end of HashPed.pl with the extension “.hashlist”. Given the same input --seed value, the same list of SNPs should be reported in this file. Given these lists, users can then determine whether the same orders of SNPs were used in their respective runs of HashPed.pl. If the same order is not created given the same input --seed value, please re-download the program and try again. If the problem persists, contact the e-mail listed on the Gencrypt webpage.

7) Positive control. A simulated individual homozygous for every SNP’s reference allele is produced by HashPed.pl at the beginning of each hash output file to act as a positive control. When datasets are compared that used the same --seed value, there should be a 100% match between the two, simulated positive controls within each dataset. A failure to reach 100% implies there was an error at some point in producing the two datasets being compared; for example, not the same --seed value was used for both datasets.


Example Run:

Please see http://www.broadinstitute.org/software/gencrypt/ExampleFiles.tar.gz for example data and example run instructions


URL:

http://www.broadinstitute.org/software/gencrypt/


Reference:

Turchin, M.C. and Hirschhorn, J.N. 2012. Gencrypt: one-way cryptographic hashes to detect overlapping individuals across samples. Bioinformatics. 28(6): 868-8

