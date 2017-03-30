use strict;

my ($repeats, $instance_type, $storage_system) = @ARGV;

if ($instance_type eq '') {
  $instance_type = "unknown";
}

if ($storage_system ne 'GDC' and $storage_system ne 'Redwood') {
  die "Wrong storage system type; must be GDC or Redwood\n";
}

if ($repeats < 1) { $repeats = 1; }

my $manifest_url;
if ($storage_system eq 'Redwood') {
  $manifest_url = "https://raw.githubusercontent.com/wshands/Download_performance/feature/GMKFdownloadtest/Treehousemanifest.tsv";
#my $manifest_url = "https://raw.githubusercontent.com/briandoconnor/my-sandbox/develop/20160403_icgc_storage_download_test/manifest.txt";
} else {
  $manifest_url = "https://raw.githubusercontent.com/wshands/Download_performance/feature/GMKFdownloadtest/gdc_manifest.2017-03-28T20-00-34.619716.tsv";
}

# next setup directory
system ("mkdir -p /home/ubuntu/data");

# read the manifest file and push into array
my @d = ();
system("curl -s $manifest_url > /tmp/manifest.txt");
open IN, "</tmp/manifest.txt" or die;
while (my $line = <IN>) {
#  print("$line");
  $line =~ /^$/ and next;
  $line =~ /^#/ and next;
  $line =~ /^Program/ and next;
  $line =~ /^repo_code/ and next;
  $line =~ /^id/ and next;
  my @a = split("\t+", $line);
  if ($storage_system eq 'Redwood') {
    push @d, "$a[16]|$a[17]";
    #print("file name:$a[16] file uuid:$a[17]\n")
  }
  else {
    push @d, "$a[3]|$a[0]";
  }
}
close IN;

my $curr = $repeats;
if ($curr <= 0) { $curr = 1; $repeats = 1; }
while($curr > 0) {

  # loop
  $curr--;

  # clean
  system ("sudo rm -rf /home/ubuntu/data/*");

  # first sleep randomly 10-120 seconds
  sleep (int(rand(111)) + 10);

  # randomly select one for download
  my $max = scalar(@d);
  my $index = int(rand($max));
  my $sample = $d[$index];
  my @tokens = split /\|/, $sample;
  my $name = $tokens[0];
  my $oid = $tokens[1];

  # create touch file and upload
  my $start_time = `date +\%s`;
  chomp $start_time;
  open OUT, ">/home/ubuntu/$oid.tsv" or die;

  if ($storage_system eq 'Redwood') {
    print OUT "OID\t$oid\nINSTANCE\t$instance_type\nNAME\t$name\nSTART\t$start_time\n";
  } else {
    print OUT "OID\t$oid\nINSTANCE\t$instance_type\nSIZE\t$name\nSTART\t$start_time\n";
  }
  close OUT;

  # upload to s3
  system ("aws s3 cp /home/ubuntu/$oid.tsv s3://wshands-test-bucket/GMKF-storage-download-testing/$storage_system/$oid.$repeats.$instance_type.running.tsv");

  # do download

=pod
  my $status;
  if ($storage_system eq 'Redwood') {
    my $redwood_access_token = `cat /home/ubuntu/redwood_access_token.txt`;
    chomp $redwood_access_token;
    $status = system("docker run --rm -e ACCESS_TOKEN=$redwood_access_token -e REDWOOD_ENDPOINT=storage.ucsc-cgl.org -v /home/ubuntu:/dcc/data quay.io/ucsc_cgl/core-client:1.0.4 download  $oid  /dcc/data/data");
  } else {
    $status = system("/home/ubuntu/gdc-client//gdc-client download -t /home/ubuntu/gdc-user-token.txt -d /home/ubuntu/data $oid");
  }

  # update touch file and upload
  my $end_time = `date +\%s`;
  chomp $end_time;
  open OUT, ">>/home/ubuntu/$oid.tsv" or die;
  print OUT "END\t$end_time\nEXITCODE\t$status";
  close OUT;
=cut


  my $size;
  my $status;
  if ($storage_system eq 'Redwood') {
    my $redwood_access_token = `cat /home/ubuntu/redwood_access_token.txt`;
    chomp $redwood_access_token;
    my $stdout_put = `docker run --rm -e ACCESS_TOKEN=$redwood_access_token -e REDWOOD_ENDPOINT=storage.ucsc-cgl.org -v /home/ubuntu:/dcc/data quay.io/ucsc_cgl/core-client:1.0.4 download  $oid  /dcc/data/data 2>&1`;
    $status = $?;

    print("stdout from test:\n$stdout_put\n\n");

    #docker run stdout prints "Total bytes written :   5,051,725,449"
    foreach (split(/\n/, $stdout_put)) {
      if (/Total bytes written :/) {
        print("line:$_\n");
        my @tokens = split /\s+/, $_ ;
        $size = $tokens[-1];
        $size =~ s/,//g;
        print("size is \'$size\'\n");
        last;      
      }
    }
  } else {
    $status = system("/home/ubuntu/gdc-client//gdc-client download -t /home/ubuntu/gdc-user-token.txt -d /home/ubuntu/data $oid");
  }

  # update touch file and upload
  my $end_time = `date +\%s`;
  chomp $end_time;
  open OUT, ">>/home/ubuntu/$oid.tsv" or die;

  if ($storage_system eq 'Redwood') {
    print OUT "SIZE\t$size\nEND\t$end_time\nEXITCODE\t$status";
  } else {
    print OUT "END\t$end_time\nEXITCODE\t$status";
  }

  close OUT;


  # upload to s3
  system ("aws s3 rm s3://wshands-test-bucket/GMKF-storage-download-testing/$storage_system/$oid.$repeats.$instance_type.running.tsv");
  system ("aws s3 cp /home/ubuntu/$oid.tsv s3://wshands-test-bucket/GMKF-storage-download-testing/$storage_system/$oid.$repeats.$instance_type.finished.tsv");
  system("rm /home/ubuntu/$oid.tsv");
  
}

system("rm /tmp/manifest.txt");
