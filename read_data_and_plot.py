#!/usr/bin/env python
from __future__ import print_function, division
"""$
author Walt Shands
jshands@ucsc.edu$
"""
    
import boto3
import sys
    
def __main__(args):
    
    s3 = boto3.resource('s3')
    bucket = s3.Bucket('wshands-test-bucket')
    # Iterates through all the objects, doing the pagination for you. Each obj
    # is an ObjectSummary, so it doesn't contain the body. You'll need to call
    # get to get the whole body.


    GDC_total_bytes_downloaded = 0
    GDC_total_time_downloading = 0
    Redwood_total_bytes_downloaded = 0
    Redwood_total_time_downloading = 0
    GDC_download_successes = 0
    GDC_download_failures = 0
    Redwood_download_successes = 0
    Redwood_download_failures = 0

    num_items_in_bucket = 0
    for obj in bucket.objects.all():
        key = obj.key
        print("\n")
        print(key)
        num_items_in_bucket += 1    

        if 'GDC' in key:
            storage_system = 'GDC'
        elif 'Redwood' in key:
            storage_system = 'Redwood'
        else:
            print("ERROR: invalid storage system", file=sys.stderr)
            sys.exit(1)
        
        body = obj.get()['Body'].read()
        for line in body.split('\n'):
            print(line)
            line = line.strip()
            if line:
                line_tokens = line.split()

                if len(line_tokens) < 2:
                    download_success = False
                    continue
              
                if line_tokens[0] == 'EXITCODE':
                    download_success = line_tokens[1] == '0'
                elif line_tokens[0] == 'SIZE':
                    num_bytes_downloaded = int(line_tokens[1])
                elif line_tokens[0] == 'START':
                    download_start_time = int(line_tokens[1])
                elif line_tokens[0] == 'END':
                    download_end_time = int(line_tokens[1])
    
    
        if storage_system == 'GDC':
            if download_success:
                GDC_download_successes += 1
                GDC_total_bytes_downloaded += num_bytes_downloaded
                GDC_total_time_downloading += download_end_time - download_start_time
            else:
                GDC_download_failures += 1
        elif storage_system == 'Redwood':
            if download_success:
                Redwood_download_successes += 1
                Redwood_total_bytes_downloaded += num_bytes_downloaded
                Redwood_total_time_downloading += download_end_time - download_start_time
            else:
                Redwood_download_failures += 1
        else:
            print("ERROR: invalid storage system", file=sys.stderr)
            sys.exit(1)
        
        #DEBUG
        #break 

    print("Total num files in bucket = {}".format(num_items_in_bucket))

    print("Redwood download failures = {}".format(Redwood_download_failures))
    print("Redwood download successes = {}".format(Redwood_download_successes))

    print("GDC download failures = {}".format(GDC_download_failures))
    print("GDC download successes = {}".format(GDC_download_successes))

   
    print("Redwood total bytes downloaded = {}".format(Redwood_total_bytes_downloaded))
    print("Redwood total seconds downloading = {}".format(Redwood_total_time_downloading))

    print("GDC total bytes downloaded = {}".format(GDC_total_bytes_downloaded))
    print("GDC total seconds downloading = {}".format(GDC_total_time_downloading))
  
    if (Redwood_total_bytes_downloaded < 1) or (Redwood_total_time_downloading < 1):
       print("ERROR in getting Redwood data", file=sys.stderr)
    else:
       print("Redwood average download bytes per second = {}".format(Redwood_total_bytes_downloaded / Redwood_total_time_downloading))
     
    if (GDC_total_bytes_downloaded < 1) or (GDC_total_time_downloading < 1):
        print("ERROR in getting GDC data", file=sys.stderr)
    else:
        print("GDC average download bytes per second = {}".format(GDC_total_bytes_downloaded / GDC_total_time_downloading))
    
if __name__=="__main__":
         sys.exit(__main__(sys.argv))
    
    
    
    
