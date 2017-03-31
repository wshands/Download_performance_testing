use strict;
use Getopt::Long;
use MIME::Base64 qw( encode_base64 );
use JSON;

# vars
my ($rounds, $instances_per_round, $delay_min, $download_counts, $storage_system);
my $instance_id = "ami-fc1d899c";
my $key = "jshands_us_west";
my $sec_group = "sg-ed9b7496";
my $instance_type = "c4.8xlarge";
my $spot_price = "1.00";

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

#  my $status = system(qq|aws ec2 request-spot-instances --spot-price "$spot_price" --instance-count $instances_per_round --type "one-time" --launch-specification file://specification.json |);

  my $status;
  my $stdout_put = `aws ec2 request-spot-instances --spot-price "$spot_price" --instance-count $instances_per_round --type "one-time" --launch-specification file://specification.json`;
  $status = $?;

  print("stdout:\n$stdout_put\n\n");

  #convert the JSON stdout from the requests instances command to a JSON structure
  my $json = JSON->new;
  my $data = $json->decode($stdout_put);

  #get the spot instance ids for the requested instances
  for ( @{$data->{SpotInstanceRequests}} ) {
      #tag the EC2 spot instances so we can see on the console what storage system they are for 
      #and tag them with an owner
      my $spot_instance_request_id = $_->{SpotInstanceRequestId};
      my $status = system(qq|aws ec2 create-tags --resources $spot_instance_request_id --tags Key=Owner,Value=jshands\@ucsc.edu Key=Name,Value=$storage_system|);
      if( $status == 0) {
          print("Successfully tagged spot instance id:$spot_instance_request_id.\n");
      }
      else {
           print("Error could not tag spot instance id:$spot_instance_request_id.\n");
      }        
  }

  # now sleep between rounds
  sleep($delay_min * 60);

  # make dashboard
  system("perl create_dashboard.pl `date +\%s` instances.txt");
}

# cleanup
system("rm specification.json");
