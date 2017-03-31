use strict;

# TODO: need to cache the instance names

# inputs
my ($num, $instances_file, $image_id, $storage_system, $previousid) = @ARGV;

my $d = {};
if (-e $instances_file) {
  open IN, "<$instances_file" or die;
  while(<IN>) {
    chomp;
    $d->{$_} = 1;
  }
  close IN;
}
if ($previousid <=0) { $previousid = "null";}

# vars
my $template = `cat dashboard.template`;
my $instances = "";
my $token = `cat token.txt`;
chomp $token;

# get the list of instance IDs
#my $instances_list = `aws ec2 describe-instances | grep -i InstanceId`;
# get information for the instances that were created from the AMI that is used
# to run the performance tests; this will allow us to exclude all other instances
# that are running from our performance measurements
my $instances_list = `aws ec2 describe-instances --filters "Name=image-id,Values=$image_id Name=tag:Storage_system,Values=$storage_system" | grep -i InstanceId`;

my $first = 1;
foreach my $line (split /\n/, $instances_list) {
  $line =~ /"InstanceId": "(\S+)"/;
  $d->{$1} = 1;
}

# loop over templates
open OUT, ">$instances_file" or die;
foreach my $currinstance (keys %{$d}) {
  if ($first > 1 ) { $instances .= ","; }
  $instances .= qq|
                     {
                        "alias" : "Worker$first",
                        "period" : "60",
                        "region" : "us-west-2",
                        "metricName" : "NetworkIn",
                        "refId" : "A",
                        "namespace" : "AWS/EC2",
                        "statistics" : [
                           "Average"
                        ],
                        "dimensions" : {
                           "InstanceId" : "$currinstance"
                        }
                     }
  |;
  $first++;
  print OUT "$currinstance\n";
}
close OUT;

$template =~ s/\@INSTANCES\@/$instances/g;
$template =~ s/\@NUMBER\@/$num/g;
$template =~ s/\@ID\@/$previousid/g;

open OUT, ">dashboard.temp.json" or die;
print OUT $template;
close OUT;

my $result = system qq|curl -H "Authorization: Bearer $token" -H "Accept: application/json" -H "Content-Type: application/json" -X POST http://localhost:3000/api/dashboards/db -d \@dashboard.temp.json|;

#system ("rm dashboard.temp.json");
