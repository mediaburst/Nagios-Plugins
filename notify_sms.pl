#!/usr/bin/perl

#
# ============================== SUMMARY =====================================
#
# Program   : notify_sms.pl
# Version   : 1.2.1
# Date      : Dec 14 2013
# Author    : Martin Steel / Mediaburst Ltd
# Copyright : Mediaburst Ltd 2013 All rights reserved.
# Summary   : This plugin sends SMS alerts through the Clockwork SMS API
# License   : MIT
#
# =========================== PROGRAM LICENSE =================================
#
#    Copyright (C) 2013 Mediaburst Ltd
#
#    Permission is hereby granted, free of charge, to any person obtaining a 
#    copy of this software and associated documentation files (the "Software"),
#    to deal in the Software without restriction, including without limitation 
#    the rights to use, copy, modify, merge, publish, distribute, sublicense, 
#    and/or sell copies of the Software, and to permit persons to whom the 
#    Software is furnished to do so, subject to the following conditions:#
#
#    The above copyright notice and this permission notice shall be included in 
#    all copies or substantial portions of the Software.
#
#    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR 
#    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, 
#    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE 
#    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER 
#    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
#    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN 
#    THE SOFTWARE.
#
# =============================	MORE INFO ======================================
# 
# As released this plugin requires a Clockwork account to send text
# messages.  To setup a Clockwork account visit:
#   http://www.clockworksms.com/platforms/nagios/
#
# The latest version of this plugin can be found on GitHub at:
#   http://github.com/mediaburst/Nagios-Plugins
#
# ============================= SETUP NOTES ====================================
# 
# Copy this file to your Nagios plugin folder
# On a Centos install this is /usr/lib/nagios/plugins (32 bit) 
# or /usr/lib64/nagios/plugins (64 bit) other distributions may vary.
#
# NAGIOS SETUP
#
# 1. Create the SMS notification commands.  (Commonly found in commands.cfg)
#    Don't forget to add your Clockwork API Key.
#
# define command{
# 	command_name    notify-by-sms
#	command_line    $USER1$/notify_sms.pl -k API_KEY -t $CONTACTPAGER$ -f Nagios -m "Service: $SERVICEDESC$\\nHost: $HOSTNAME$\\nAddress: $HOSTADDRESS$\\nState: $SERVICESTATE$\\nInfo: $SERVICEOUTPUT$\\nDate: $LONGDATETIME$"
# }
#
# define command{
#	command_name    host-notify-by-sms
#	command_line    $USER1$/notify_sms.pl -k API_KEY -t $CONTACTPAGER$ -f Nagios -m "Host $HOSTNAME$ is $HOSTSTATE$\\nInfo: $HOSTOUTPUT$\\nTime: $LONGDATETIME$"
# }
#
# 2. In your nagios contacts (Commonly found on contacts.cfg) add 
#    the SMS notification commands:
#
#    service_notification_commands	notify-by-sms
#    host_notification_commands		host-notify-by-sms
#
# 3. Add a pager number to your contacts, make sure it has the international 
#    prefix, e.g. 44 for UK or 1 for USA, without a leading 00 or +.
#
#    pager	447700900000  
#


use strict;
use Getopt::Long;
use LWP;
use URI::Escape;

my $version = '1.2';
my $verbose = undef; # Turn on verbose output
my $key = undef;
my $to = undef;
my $from = "Nagios";
my $message = undef;

sub print_version { print "$0: version $version\n"; exit(1); };
sub verb { my $t=shift; print "VERBOSE: ",$t,"\n" if defined($verbose) ; }
sub print_usage {
        print "Usage: $0 [-v] -k <key> -t <to> [-f <from>] -m <message>\n";
}

sub help {
        print "\nNotify by SMS Plugin ", $version, "\n";
        print " Clockwork - http://www.clockworksms.com/\n\n";
        print_usage();
        print <<EOD;
-h, --help
        print this help message
-V, --version
        print version
-v, --verbose
        print extra debugging information
-k, --key=KEY
	Clockwork API Key
-t, --to=TO
        mobile number to send SMS to in international format
-f, --from=FROM (Optional)
        string to send from (max 11 chars)
-m, --message=MESSAGE
        content of the text message
EOD
	exit(1);
}

sub check_options {
        Getopt::Long::Configure ("bundling");
        GetOptions(
                'v'     => \$verbose,		'verbose'       => \$verbose,
                'V'     => \&print_version,	'version'       => \&print_version,
		'h'	=> \&help,		'help'		=> \&help,
		'k=s'	=> \$key,		'key=s'	        => \$key,
                't=s'   => \$to,        	'to=s'          => \$to,
                'f=s'   => \$from,      	'from=s'        => \$from,
                'm=s'   => \$message,   	'message=s'     => \$message
        );

	if (!defined($key))
		{ print "ERROR: No API Key defined!\n"; print_usage(); exit(1); }
        if (!defined($to))
                { print "ERROR: No to defined!\n"; print_usage(); exit(1); }
        if (!defined($message))
                { print "ERROR: No message defined!\n"; print_usage(); exit(1); }

	if($to!~/^\d{7,15}$/) {
                { print "ERROR: Invalid to number!\n"; print_usage(); exit(1); }
	}
	verb "key = $key";
        verb "to = $to";
        verb "from = $from";
        verb "message = $message";
}

sub SendSMS {
	my $key = shift;
	my $to = shift;
	my $from = shift;
	my $message = shift;
	
	# Convert "\n" to real newlines (Nagios seems to eat newlines).
	$message=~s/\\n/\n/g;

	# URL Encode parameters before making the HTTP POST
	$key        = uri_escape($key);
	$to         = uri_escape($to);
	$from       = uri_escape($from);
	$message    = uri_escape($message);

	my $result;
	my $server = 'http://api.clockworksms.com/http/send';
	my $post = 'key=' . $key;
	$post .= '&to='.$to;
	$post .= '&from='.$from;
	$post .= '&content='.$message;
	
	verb("Post Data: ".$post);
	
        my $ua = LWP::UserAgent->new();
	$ua->timeout(30);
	$ua->agent('Nagios-SMS-Plugin/'.$version);
        my $req = HTTP::Request->new('POST',$server);
	$req->content_type('application/x-www-form-urlencoded');
	$req->content($post);
	my $res = $ua->request($req);

	verb("POST Status: ".$res->status_line);
	verb("POST Response: ".$res->content);
	
	if($res->is_success) {
		if($res->content=~/error/i) {
			print $res->content;
			$result = 1;
		} else {
			$result = 0;
		}
	} else {
		$result = 1;
		print $res->status_line;
	}

        return $result;
}


check_options();
my $send_result = SendSMS($key, $to, $from, $message);

exit($send_result);

