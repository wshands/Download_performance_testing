use strict;
use Getopt::Long;
use MIME::Base64 qw( encode_base64 );

# vars
my ($rounds, $instances_per_round, $delay_min, $download_counts, $storage_system);
my $instance_id = "ami-f4a33794";
my $key = "jshands_us_west";
my $sec_group = "sg-ed9b7496";
my $instance_type = "m4.xlarge";
my $spot_price = "0.06";

#print "security group:$sec_group\n";

# options
GetOptions ("rounds=i" => \$rounds,
"instances=i" => \$instances_per_round,
"download-counts=i" => \$download_counts,
"delay-min=i" => \$delay_min,
"storage-system=s" => \$storage_system);

if ($delay_min < 1) {$delay_min = 1;}
if ($rounds < 1) { $rounds = 1; }
if ($instances_per_round < 1) { $instances_per_round = 1; }
if ($download_counts < 1) { $download_counts = 1; }
if ($delay_min < 1) { $delay_min = 1; }
if ($storage_system eq '') { $storage_system = 'Redwood'; }

if ($storage_system ne 'GDC' and $storage_system ne 'Redwood') {
  die "Wrong storage system type; must be GDC or Redwood\n";
}


# main loop
for (my $i=0; $i<$rounds; $i++) {

  # user data
  # make the user data
  my $user_data_script =  encode_base64(qq|#!/bin/bash
perl /home/ubuntu/gitroot/Download_performance_testing/run_download.pl $download_counts $instance_type $storage_system
shutdown -h now
|, '');

#  my $user_data_script =  encode_base64(qq|#!/bin/bash
#perl /home/ubuntu/gitroot/Download_performance_testing/run_download.pl $download_counts $instance_type $storage_system
#|, '');


  chomp $user_data_script;

  # create a spot request(s)
  # make instance JSON, see http://docs.aws.amazon.com/cli/latest/reference/ec2/request-spot-instances.html
  open OUT, ">specification.json" or die;
  print OUT qq|{
  "ImageId": "$instance_id",
  "UserData": "$user_data_script",
  "KeyName": "$key",
  "SecurityGroupIds": [ "$sec_group" ],
  "InstanceType": "$instance_type"
}|;
  close OUT;

  my $status = system(qq|aws ec2 request-spot-instances --spot-price "$spot_price" --instance-count $instances_per_round --type "one-time" --launch-specification file://specification.json |);

  # now sleep between rounds
  sleep($delay_min * 60);

  # make dashboard
  system("perl create_dashboard.pl `date +\%s` instances.txt");
}

# cleanup
system("rm specification.json");
