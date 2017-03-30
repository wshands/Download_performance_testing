##About

This is a script that is designed to run on spot instances to perform downloads
from the ICGC storage system. It's designed to run on a spot instance and
repeat a random download for n times.  The bandwidth used can be monitored via
CloudWatch and this script will write a summary back to S3 for interpretation
later.

The companion script sets up a dashboard in Grafana and automatically adds all
running instances.

### launch_test_instances.pl

This creates multiple rounds of spot instance launches so it gradually ramps up the
fleet of images running the download test.  It also periodically calls the `create_dashboard.pl`
script to update the locally running Grafana instance.

The user-data provided will cause the run_download.pl script to run and include a shutdown command after
to ensure the host is terminated when it finishes its run.

    # testing
    perl launch_test_instances.pl --rounds 1 --instances 1 --download-counts 1 --delay-min 1
    # production
    perl launch_test_instances.pl --rounds 10 --instances 10 --download-counts 5 --delay-min 60

### run_download.pl

This runs on each test host and performs one or more download tests, writing metadata back to S3.

### create_dashboard.pl

This is called by launch_test_instances.pl after a VM is launched.  It's job is to setup
the instances in Grafana, it just looks for all instances that are currently running.

    git pull; perl create_dashboard.pl `date +%s` instances.txt

##Strategy

0. make a Grafana host and generate an API key, checkout this repo, install AWS CLI and configure it
0. make a base AMI with these scripts, the AWS CLI, configure it
0. on the Grafana host run the launch_test_instances.pl script to launch spot requests on a cycle, causing the run_download.pl to run on each and the hosts to shutdown once they complete their run
0. in parallel, run the create_dashboard.pl script that will periodically insert running instances into the dashboard, keeping a cache of previously seen instances so they don't get dropped

Test the whole thing with a dummy download that lasts only a few minutes

##References

* http://docs.aws.amazon.com/AWSEC2/latest/CommandLineReference/ApiReference-cmd-ModifyInstanceAttribute.html
* http://docs.aws.amazon.com/cli/latest/reference/ec2/modify-instance-attribute.html
* http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/terminating-instances.html#Using_ChangingInstanceInitiatedShutdownBehavior
* http://docs.aws.amazon.com/cli/latest/userguide/cli-ec2-launch.html
* http://stackoverflow.com/questions/10541363/self-terminating-aws-ec2-instance
