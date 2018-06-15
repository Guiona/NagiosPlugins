#!/usr/bin/perl
############################## check_bpe.pl ##############
# Version    : 0.3
# Date       : 26/10/2016
# Author     : Guillaume ONA <guillaume.ona@axians.com>
# Licence    : GPL - http://www.fsf.org/licenses/gpl.txt
# Change Log : 
# TODO       : many.....
##########################################################
#
# help : ./check_bpe_ng.pl -h
#

use 5.010;
use strict;
use warnings;

# Modules
use LWP;
use XML::LibXML;
use Data::Dumper;
use Switch;
use Getopt::Long;

# My Variables
my $name     = "check_bpe_ng.pl";
my $version  = "0.3";
my $ok       = 0;
my $critical = 0;
my $warning  = 0;
my @errors;
my $state;
my $output;
my $o_verb;
my $o_help;
my $o_name;
my $o_url;
my $o_pname;
my $o_version;
my $o_crit;
my $o_warn;
my $o_mode;
my $o_file;
my $perfdata;
my %ERRORS=('OK'=>0,'WARNING'=>1,'CRITICAL'=>2,'UNKNOWN'=>3,'DEPENDENT'=>4);
my $t;
my @t;

#
# Functions
#

### function check_bpe_status
sub check_bpe_status {

    my ($names, $states, $queueds, $errors, $mypip, $warning, $critical, $mode) = @_;
    my @pipname = @{ $names };
    my @pipstate = @{ $states };
    my @pipqueued = @{ $queueds };
    my @piperrored = @{ $errors };

    my $i=0;
    foreach my $pipelineName (@pipname) {
    
        if ( $pipelineName eq $mypip ) {

            if ( defined($o_verb) ) {
                say "\t pipelineName: ", $pipelineName;
                say "\t \t Status : ", $pipstate[$i];
                say "\t \t Queued : ", $pipqueued[$i];
                say "\t \t Error : ", $piperrored[$i];
            }

            if ( $mode eq 'queued' ) {
                # Mode queued
                my $perfdata = "| queued=$pipqueued[$i];$warning;$critical;; errored=$piperrored[$i];;;;\n";
                if ( $pipstate[$i] ne "ONLINE" ) {
                    $state = $ERRORS{"CRITICAL"};
                    $output = "CRITICAL: $pipelineName is $pipstate[$i] - Queued: $pipqueued[$i] $perfdata";
                } else {
                    if ( $pipqueued[$i] > $critical ) {
                       $state = $ERRORS{"CRITICAL"};
                       $output = "CRITICAL : $pipelineName is $pipstate[$i] - Queued: $pipqueued[$i] > $critical $perfdata";
                    } elsif ( $pipqueued[$i] > $warning ) {
                        $state = $ERRORS{"WARNING"};
                        $output = "WARNING : $pipelineName is $pipstate[$i] - Queued: $pipqueued[$i] > $warning $perfdata";
                    } else {
                       $state = $ERRORS{"OK"};
                       $output = "OK: $pipelineName is $pipstate[$i] - Queued: $pipqueued[$i] $perfdata";
                    }
                }
            } elsif ( $mode eq 'errored' ) {
                # Mode Errors
                my $perfdata = "| queued=$pipqueued[$i];;;; errored=$piperrored[$i];$warning;$critical;;\n";
                if ( $pipstate[$i] ne "ONLINE" ) {
                    $state = $ERRORS{"CRITICAL"};
                    $output = "CRITICAL: $pipelineName is $pipstate[$i] - Errored: $piperrored[$i] $perfdata";
                } else {
                    if ( $piperrored[$i] > $critical ) { 
                        $state = $ERRORS{"CRITICAL"};
                        $output = "CRITICAL : $pipelineName is $pipstate[$i] - Errored: $piperrored[$i] > $critical $perfdata";
                    } elsif ( $piperrored[$i] > $warning ) {
                        $state = $ERRORS{"WARNING"};
                        $output = "WARNING : $pipelineName is $pipstate[$i] - Errored: $piperrored[$i] > $warning $perfdata";
                    } else {
                       $state = $ERRORS{"OK"};
                       $output = "OK: $pipelineName is $pipstate[$i] - Errored: $piperrored[$i] $perfdata";
                    }
                }
            }
            $i++;
        }
    }
    return($output, $state);
}

# Sub to print version
sub p_version {
    print "$name version : $version\n";
}

# Sub to print usage
sub print_usage {
    print "Usage: $name -u <url> -n <application name> -p <pipeline name> -w <integer> -c <integer> [-m errored] [-v] [-V]\n";
}

sub help {
   print "\nMonitoring Pipeline AGFA BPE ",$version,"\n";
   print "(c)2018 Guillaume ONA\n\n";
   print_usage();
   print <<EOT;
By default, plugin will monitor status of BPE pipeline :
-n, --name=<Application Name> 
    Application to monitor
-p, --pipeline=<Pipeline Name>
    Pipeline to monitor
-u, --url=url
    URL Of the webservice
-v, --verbose
    print extra debugging information
-V, --version
    print version information
-m, --mode=queued|errored
    Monitoring value, Default mode
-f, --file=/my/authfile
    username=XXXX
    password=YYYY
EOT
}

sub check_options {
    Getopt::Long::Configure ("bundling");
    GetOptions(
        'v'     => \$o_verb,            'verbose'       => \$o_verb,
        'h'     => \$o_help,            'help'          => \$o_help,
        'u:s'   => \$o_url,             'url:s'         => \$o_url,
        'n:s'   => \$o_name,            'application:s' => \$o_name,
        'p:s'   => \$o_pname,           'pipeline:s'    => \$o_pname,
        'm:s'   => \$o_mode,            'mode:s'        => \$o_mode,
        'c:s'   => \$o_crit,            'critical:s'    => \$o_crit,
        'w:s'   => \$o_warn,            'warning:s'     => \$o_warn,
        'V'     => \$o_version,         'version'       => \$o_version,
        'f:s'   => \$o_file,            'file:s'        => \$o_file
    );

    # check -h
    if ( defined($o_help) ) {
        help();
        exit $ERRORS{"UNKNOWN"}
    }

    # check -V
    if ( defined($o_version) ) {
        p_version(); exit $ERRORS{"UNKNOWN"}
    }

    # Check arguments
    if ( !defined($o_name) && !defined($o_url) ) {
        print "Put Name of application to check and the url of webservices!\n";
        print_usage();
        exit $ERRORS{"UNKNOWN"};
    } elsif ( !defined($o_name) ) {
        print "You must defined name of the application!\n";
        print_usage();
        exit $ERRORS{"UNKNOWN"};
    } elsif ( !defined($o_url) ) {
        print "You must defined URL of webservice!\n";
        print_usage();
        exit $ERRORS{"UNKNOWN"};
    } elsif ( !defined($o_pname) ) {
        print "You must defined Pipeline Name!\n";
        print_usage();
        exit $ERRORS{"UNKNOWN"};
    }

    if ( !defined($o_warn) && !defined($o_crit) ) {
        print "You must defined thresold!\n";
        print_usage();
        exit $ERRORS{"UNKNOWN"};
    } elsif ( !defined($o_warn) ) {
        print "You must defined warning thresold!\n";
        print_usage();
        exit $ERRORS{"UNKNOWN"};
    } elsif ( !defined($o_crit) ) {
        print "You must defined critical thresold!\n";
        print_usage();
        exit $ERRORS{"UNKNOWN"};
    } elsif ( $o_warn > $o_crit ) {
        print "Warning threshold \"$o_warn\" cannot be greater than Critical thresold \"$o_crit\"\n";
        print_usage();
        exit $ERRORS{"UNKNOWN"};
    }

    # Mode options
    if ( !defined($o_mode) || $o_mode eq 'queued' ) {
        $o_mode = "queued";
    } else {
        if ( $o_mode ne 'errored' ) {
            print "Unknown mode \"$o_mode\"!\n";
            print_usage();
            exit $ERRORS{"UNKNOWN"};
        } else {
            $o_mode = "errored";
        }
    }

    # use file for Authentication
    if ( defined($o_file) ) {
        if ( -e $o_file ) {
            open(my $fh, '<:encoding(UTF-8)', $o_file) ;
            while (my $row = <$fh> ) {
                chomp $row;
                if ( $row =~ /^username=(.*)$/ ) {
                    # print $1;
                    $ENV{BPE_USER} = "$1";
                } elsif ( $row =~ /^password=(.*)$/ ) {
                    # print $1
                    $ENV{BPE_PASSW} = "$1";
                }
            }
            if ( $o_url =~ /^(http:\/\/)(.*)$/ ) {
                $o_url=$1 . $ENV{BPE_USER} . ':' . $ENV{BPE_PASSW} . '@' . $2;
            }
        } else {
            print "$o_file doesn't exist";
            exit $ERRORS{"UNKNOWN"};
        }
    }
}

#
# Main Program
#
check_options();

if ( defined($o_verb) ) {
    print " - Url : $o_url\n";
    print " - Name: $o_name\n";
    print " - Pipeline: $o_pname\n";
    print " - Mode : $o_mode\n";
}

# Retrieve webservice
#
my $ua = LWP::UserAgent->new();
#$ua->agent('UserAgent you want to mimic');
#$ua->credentials('URL','','USER', 'PASSWORD');
my $response = $ua->get($o_url);
my $dom = XML::LibXML->load_xml(string => $response->content, recover=>2);
#
#my $dom = XML::LibXML->load_xml(location => $o_url);
foreach my $app ($dom->findnodes('//applicationInfo')) {
    my $applicationName = $app->findvalue('./applicationName');
    # Ajouter traitement application non trouvee
    if ( $applicationName eq $o_name ) {
        my $i = 0;
        my @pipelineName    = map { $_->to_literal() } $app->findnodes('./pipelineInfo/pipelineName');
        my @pipelineQueued  = map { $_->to_literal() } $app->findnodes('./pipelineInfo/queued');
        my @pipelineErrored = map { $_->to_literal() } $app->findnodes('./pipelineInfo/errored');
        my @pipelineStatus  = map { $_->to_literal() } $app->findnodes('./pipelineInfo/status');
 
        @t = check_bpe_status(\@pipelineName, \@pipelineStatus, \@pipelineQueued, \@pipelineErrored, $o_pname, $o_warn, $o_crit, $o_mode);
        print "[$o_name] $t[0]";
        exit $t[1];
    } 
}
print "CRITICAL: $o_name not found on $o_url\n";
exit exit $ERRORS{"CRITICAL"};
#### End Of Scripts
