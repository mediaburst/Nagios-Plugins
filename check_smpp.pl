#!/usr/bin/perl

# Tell Nagios not to use embedded perl interpreter as it doesn't work 
# correctly with sockets
# nagios: -epn

#
# ============================== SUMMARY =====================================
#
# Program   : check_smpp.pl
# Version   : 1.1
# Date      : Feb 3 2011
# Author    : Martin Steel - martin@mediaburst.co.uk
# Copyright : Mediaburst Ltd 2011 All rights reserved.
# Summary   : This plugin connects to an SMPP server and sends an SMS message
# License   : MIT
#
# =========================== PROGRAM LICENSE =================================
#
# Copyright (C) 2013 Mediaburst Ltd
#
# Permission is hereby granted, free of charge, to any person obtaining a
# copy of this software and associated documentation files (the "Software"),
# to deal in the Software without restriction, including without limitation
# the rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following conditions:#
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#
# ===================== INFORMATION ABOUT THIS PLUGIN =========================
#
# This program is written and maintained by: 
#   Mediaburst Ltd. http://www.mediaburst.co.uk
#
# The latest version of this plugin can be found on GitHub at:
#   http://github.com/mediaburst/Nagios-Plugins
#
# OVERVIEW
#
#
# Usage: check_smpp.pl [-v] -H <host> -u <username> -p <password> \
#                              [-t <to>] [-f <from>] [-m <message>] [-P <port>]\
#                              [--system-type] [--service-type] [--data-coding]
# -h, --help
#        print this help message
# -v, --version
#        print version
# -V, --verbose
#        print extra debugging information
# -H, --host=HOST
#        hostname or IP address of host to check
# -u, --username=USERNAME
# -p, --password=PASSWORD
# -t, --to=TO
#        mobile number to send SMS to
# -f, --from=FROM
#	 String to send message from (up to 11 chars)
# -m, --message=MESSAGE
#        content of the text message
# -P, --port=PORT
#        Port to connect to on the SMPP server
#     --system-type=SYSTEM_TYPE
#        System Type used on the SMPP Bind PDU
#     --service-type=SERVICE_TYPE	
#        Service Type used on the SMPP Short message PDU
#     --data-coding=DATA_CODING
#
# ============================= SETUP NOTES ====================================
#
# Copy this file to your Nagios plugin folder
# On a Centos install this is /usr/lib/nagios/plugins or /usr/lib64/nagios/plugins
# other distributions may vary.
#
# Manually test it with a command like the following:
# ./check_smpp.pl -H smpp.example.org -u username -p password -P 2775

# NAGIOS SETUP
#
# define command {
#        command_name    check_smpp
#        command_line    $USER1$/check_smpp.pl -H $HOSTADDRESS$ -u $ARG1$ -p $ARG2$ -P $ARG2$
# }
# define service {
#        use generic-service
#        host_name 		SMPP_SERVER
#        service_description 	Check SMPP Sending
#        check_command 		check_smpp!USERNAME!PASSWORD!PORT
#        normal_check_interval 	3
#        retry_check_interval 	1
# }

use Net::SMPP;
use Getopt::Long;

my %ERRORS=('OK'=>0,'WARNING'=>1,'CRITICAL'=>2,'UNKNOWN'=>3,'DEPENDENT'=>4);

my $version='1.0';
my $help = undef; # Flag to show help
my $opt_version = undef; # Flag to show version info
my $host = undef; # Hostname or IP address of SMPP Server
my $username= undef; # SMPP system_id (username)
my $password = undef; # SMPP Password
my $to = "447123456789";
my $from = "Nagios";
my $message = "Nagios SMPP Test ".localtime();
my $port = 2775; # Port on SMPP Server
my $system_type = undef; # System Type sent in the Bind Transmitter
my $service_type = undef; # Service Type sent on the Submit_SM PDU
my $data_coding = 0; # Data Coding used for message payload (0 = SMPP Server Default)

sub print_version { print "$0: version $version\n" };

sub verb { my $t=shift; print "VERBOSE: ",$t,"\n" if defined($verbose) ; }

sub print_usage {
        print "Usage: $0 [-v] -H <host> -u <username> -p <password> [-t <to>] [-f <from>] [-m <message>] [-P <port>] [--system-type] [--service-type] [--data-coding]\n";
}
sub help {
	print "\nCheck SMPP Service ", $version, "\n";
	print " Mediaburst Ltd - http://www.mediaburst.co.uk/tech/\n\n";
	print_usage();
	print <<EOD;
-h, --help
	print this help message
-V, --version
	print version
-v, --verbose
	print extra debugging information
-H, --host=HOST
	hostname or IP address of host to check
-u, --username=USERNAME
-p, --password=PASSWORD
-t, --to=TO
        mobile number to send SMS to
-f, --from=FROM
	string to send from (max 11 chars)
-m, --message=MESSAGE
        content of the text message
-P, --port=PORT
        Port to connect to on the SMPP server
    --system-type=SYSTEM_TYPE
        System Type used on the SMPP Bind PDU
    --service-type=SERVICE_TYPE
        Service Type used on the SMPP Short message PDU
    --data-coding=DATA_CODING
EOD
}

sub check_options {
	Getopt::Long::Configure ("bundling");
	GetOptions(
		'v'	=> \$verbose,	'verbose'	=> \$verbose,
		'V'	=> \$opt_version,	'version'	=> \$opt_version,
		'h'	=> \$help,	'help'		=> \$help,
		'H=s'	=> \$host,	'host=s'	=> \$host,
		'u=s'	=> \$username,	'username=s'	=> \$username,
		'p=s'	=> \$password,	'password=s'	=> \$password,
		't=s'	=> \$to,	'to=s'		=> \$to,
		'f=s'	=> \$from,	'from=s'	=> \$from,
		'm=s'	=> \$message,	'message=s'	=> \$message,
		'P=i'	=> \$port,	'port=i'	=> \$port,
		'system-type=s'	=> \$system_type,
		'service-type=s'=> \$service_type,
		'data-coding=i'	=> \$data_coding
	);

	if (defined($help) ) { help(); exit $ERRORS{"UNKNOWN"}; }
	if (defined($opt_version) ) { print_version(); exit $ERRORS{"UNKNOWN"}; }
	if (!defined($host)) 
		{ print "ERROR: No host defined!\n"; print_usage(); exit $ERRORS{"UNKNOWN"}; }
	if (!defined($username)) 
		{ print "ERROR: No username defined!\n"; print_usage(); exit $ERRORS{"UNKNOWN"}; }
	if (!defined($password)) 
		{ print "ERROR: No password defined!\n"; print_usage(); exit $ERRORS{"UNKNOWN"}; }

	verb "host = $host";
	verb "username = $username";
	verb "password = $password";
	verb "to = $to";
	verb "from = $from";
	verb "message = $message";
	verb "port = $port";
	verb "system_type = $sytem_type";
	verb "service_type = $service_type";
	verb "data_coding = $data_coding";
}

check_options();

TestSMPP();

printf("SMPP ");

printf("$statuscode - $statusinfo");

print "\n";

exit $ERRORS{$statuscode};

sub TestSMPP() {
	my $smpp = Net::SMPP->new_connect($host, port=>$port, async=>1);
	if(!$smpp) {
		$statusinfo = "Failed to connect to SMPP server $host:$port";
		$statuscode="CRITICAL";
		return;
	}
        my $seq_num = $smpp->bind_transmitter(system_id => $username, password => $password, async=>1, system_type=>$system_type);
        if(!$seq_num) {
                $statusinfo = "Failed to send bind transmitter";
                $statuscode="CRITICAL";
		return;
        }
        my $resp_pdu = $smpp->wait_pdu(Net::SMPP::CMD_bind_transmitter_resp,$seq_num);
	if(!$resp_pdu || $resp_pdu->{status} != 0) {
                $statusinfo = "Non-zero Bind Transmitter Response: ". $resp_pdu ? $resp_pdu->explain_status() : "";
                $statuscode="CRITICAL";
                return;
	}
	$seq_num = $smpp->submit_sm(source_addr_ton => 0x05,
                                source_addr_npi => 0x00,
                                source_addr => $from,
                                dest_addr_npi => 0x01,
                                dest_addr_ton => 0x01,
                                destination_addr => $to,
                                registered_delivery => 0x00,
                                data_coding=>$data_coding,
                                service_type => $service_type,
                                short_message => $message);
	if(!$seq_num) {
                $statusinfo = "Failed to send Submit SM";
                $statuscode="CRITICAL";
                return;
        }
	my $not_got_resp=1;
        while($not_got_resp) {
		$pdu=$smpp->read_pdu();
		$sequence_id=$pdu->{seq};
		if($pdu->cmd==Net::SMPP::CMD_submit_sm_resp) {
			verb "Got submit_sm_resp\n";
			if($sequence_id==$seq_num) {
                                $not_got_resp=0;
				verb "Got submit_sm_resp for message\n";
				if($pdu->status) {
					$statusinfo = "Submit SM Response Error:" . $pdu->explain_status();
					$statuscode="CRITICAL";
				} else {
                                        my $msg_id=$pdu->message_id;
					$statusinfo = "Message ID: $msg_id";
					$statuscode="OK";
				}
			} else {
				verb "Got differing sequence number\n";
			}
		} elsif($pdu->cmd==Net::SMPP::CMD_enquire_link) {
			# Respond to the enquire link so the server knows the connection is till active
			verb "Got enquire_link\n";
			$smpp->enquire_link_resp(seq => $sequence_id);
		} else {
			verb "Got differing PDU command\n";
		}
	}
	$seq_num=$smpp->unbind();
	if(!$seq_num) {
                $statusinfo = "Failed to send unbind";
                $statuscode="WARNING";
                return;
        }
	$resp_pdu=$smpp->wait_pdu(Net::SMPP::CMD_unbind_resp,$seq_num);
	if(!$resp_pdu || $resp_pdu->{status} != 0) {
        	$statusinfo = "Non-zero Unbind Response: ". $resp_pdu ? $resp_pdu->explain_status() : "";
                $statuscode="WARNING";
                return;
        }


}
