#!/usr/bin/perl

#
# ============================== SUMMARY =====================================
#
# Program   : notify_sms.pl
# Version   : 1.0
# Date      : March 19 2010
# Author    : Martin Steel / Mediaburst Ltd
# Copyright : Mediaburst Ltd 2011 All rights reserved.
# Summary   : This plugin sends SMS alerts through the Mediaburst SMS API
# License   : ISC
#
# =========================== PROGRAM LICENSE =================================
#
# Copyright (c) 2011 Mediaburst Ltd <hello@mediaburst.co.uk>
#
# Permission to use, copy, modify, and/or distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
# 
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
# ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
# ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
# OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
#
# =============================	MORE INFO ======================================
# 
# As released this plugin requires a Mediaburst SMS API account to send text
# messages.  To setup a Mediaburst SMS API account visit:
#   http://www.mediaburst.co.uk/api/
#
# The latest version of this plugin can be found on GitHub at:
#   http://github.com/mediaburst/Nagios-Plugins
#
# ============================= SETUP NOTES ====================================
# 
# Copy this file to your Nagios plugin folder
# On a Centos install this is /usr/lib/nagios/plugins or /usr/lib64/nagios/plugins
# other distributions may vary.
#
# NAGIOS SETUP
#
# 1. Create the SMS notification commands.  (Commonly found in commands.cfg)
#
# define command{
# 	command_name    notify-by-sms
#	command_line    $USER1$/notify_sms.pl -t $CONTACTPAGER$ -f Nagios -m "Service: $SERVICEDESC$\\nHost: $HOSTNAME$\\nAddress: $HOSTADDRESS$\\nState: $SERVICESTATE$\\nInfo: $SERVICEOUTPUT$\\nDate: $LONGDATETIME$"
# }
#
# define command{
#	command_name    host-notify-by-sms
#	command_line    $USER1$/notify_sms.pl -t $CONTACTPAGER$ -f Nagios -m "Host $HOSTNAME$ is $HOSTSTATE$\\nInfo: $HOSTOUTPUT$\\nTime: $LONGDATETIME$"
# }
#
# 2. In your nagios contacts (Commonly found on contacts.cfg) add 
#    the SMS notification commands:
#
#    service_notification_commands	notify-by-sms
#    host_notification_commands		host-notify-by-sms
#
# 3. Add a pager number to your contacts
#
#    pager	447700900000  
#


use strict;
use Getopt::Long;
use LWP;
use URI::Escape;

my $version='1.0';
my $verbose = undef; # Turn on verbose output
my $username = undef;
my $password = undef;
my $to = undef;
my $from = "Nagios";
my $message = undef;

sub print_version { print "$0: version $version\n"; exit(1); };
sub verb { my $t=shift; print "VERBOSE: ",$t,"\n" if defined($verbose) ; }
sub print_usage {
        print "Usage: $0 [-v] -u <username> -p <password> -t <to> [-f <from>] -m <message>\n";
}

sub help {
        print "\nNotify by SMS Plugin ", $version, "\n";
        print " Mediaburst Ltd - http://www.mediaburst.co.uk/\n\n";
        print_usage();
        print <<EOD;
-h, --help
        print this help message
-V, --version
        print version
-v, --verbose
        print extra debugging information
-u, --username=USERNAME
	SMS API Username
-p, --password=PASSWORD
	SMS API Password
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
		'u=s'	=> \$username,		'username=s'	=> \$username,
		'p=s'	=> \$password,		'password=s'	=> \$password,
                't=s'   => \$to,        	'to=s'          => \$to,
                'f=s'   => \$from,      	'from=s'        => \$from,
                'm=s'   => \$message,   	'message=s'     => \$message
        );

	if (!defined($username))
		{ print "ERROR: No username defined!\n"; print_usage(); exit(1); }
	if (!defined($password))
		{ print "ERROR: No password defined!\n"; print_usage(); exit(1); }
        if (!defined($to))
                { print "ERROR: No to defined!\n"; print_usage(); exit(1); }
        if (!defined($message))
                { print "ERROR: No message defined!\n"; print_usage(); exit(1); }

	if($to!~/^\d{7,15}$/) {
                { print "ERROR: Invalid to number!\n"; print_usage(); exit(1); }
	}
	verb "username = $username";
	verb "password = $password";
        verb "to = $to";
        verb "from = $from";
        verb "message = $message";
}

sub SendSMS {
	my $username = shift;
	my $password = shift;
	my $to = shift;
	my $from = shift;
	my $message = shift;

	# URL Encode parameters before making the HTTP POST
	$username=uri_escape($username);
	$password=uri_escape($password);
	$to=uri_escape($to);
	$from=uri_escape($from);
	$message=uri_escape($message);

	my $result;
	my $server = 'http://sms.message-platform.com/http/send.aspx';
	my $post = 'username='.$username;
	$post.='&password='.$password;
	$post.='&to='.$to;
	$post.='&from='.$from;
	$post.='&content='.$message;
	
	verb("Post Data: ".$post);
	
        my $ua=LWP::UserAgent->new();
	$ua->timeout(30);
	$ua->agent('Nagios-SMS-Plugin/'.$version);
        my $req=HTTP::Request->new('POST',$server);
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
my $send_result = SendSMS($username, $password, $to, $from, $message);

exit($send_result);

