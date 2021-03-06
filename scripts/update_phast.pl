#!/usr/bin/env perl
use strict;
use warnings;
use File::Fetch;
use Getopt::Long;
use Bio::Perl;
use File::Basename qw/basename/;

$0=basename $0;
sub logmsg{print STDERR "$0: @_\n"; }
exit main();

sub main{
  my $settings={};
  GetOptions($settings,qw(help outfile=s force));
  die usage() if($$settings{help});
  die "ERROR: need output file\n".usage() unless($$settings{outfile});

  if(-e $$settings{outfile}){
    die "ERROR: $$settings{outfile} already exists" unless($$settings{force});
  }

  if(-e "prophage_virus.db"){
    logmsg "Already downloaded prophage_virus.db.  Will not download again.";
  } else {
    logmsg "Downloading prophage_virus.db using File::Fetch";
    my $ff=File::Fetch->new(uri => "http://phast.wishartlab.com/phage_finder/DB/prophage_virus.db");
    my $where=$ff->fetch() or die $ff->error; # download to $PWD
  }

  logmsg "Downloaded prophage_virus.db and am now reformatting the deflines for CGP format.";
  my $in=Bio::SeqIO->new(-file=>"prophage_virus.db",-format=>"fasta");
  open (OUT,">",$$settings{outfile}) or die "ERROR in opening $$settings{outfile}: $!";
  my $seqCounter=0;
  while(my $seq=$in->next_seq){
    # defline looks like 
    #    >PROPHAGE_Xantho_306-gi|21243357|ref|NP_642939.1| phage-related integrase [Xanthomonas axonopodis pv. citri str. 306]
    #    >PHAGE_Abaca_bunchy_top_virus_NC_010314-gi|167006426|ref|YP_001661656.1| putative nuclear shuttle protein [Abaca_bunchy_top_virus]
    my ($id,$gid,undef,$NP)=split /\|/,$seq->id;

    # CGP format is $xref, $EC, ncbi GI, $product separated by tildes
    $seq->id($id);
    $seq->desc(join("~~~",'',$gid,$seq->desc));
    print OUT as_fasta($seq);

    if(++$seqCounter % 10000 == 0){
      $|++;print ".";$|--;
    }
  }
  print "\n";
  close OUT;

  system("makeblastdb -dbtype prot -in '$$settings{outfile}'");
  die if $?;

  return 0;
}

# Properly format a seq object to a string
sub as_fasta{
  my($seqObj)=@_;
  my $sequence=$seqObj->seq;
  $sequence=~s/(.{60})/$1\n/g;
  return ">".$seqObj->id." ".$seqObj->desc."\n$sequence\n";
}

sub usage{
  "Downloads the phast database and formats it for CGP
  Usage: $0 -o prophage_virus.db
  --force to allow overwriting of the output file
  ";
}

