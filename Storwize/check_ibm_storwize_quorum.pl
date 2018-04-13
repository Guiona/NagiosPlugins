#!/usr/bin/perl
#
# check_ibm_spectrum_quorum.pl Nagios check
#
# Requires IBM's SVC.pm
#  http://www.alphaworks.ibm.com/tech/svctools
#
# Requires you configure an ssh key for logins to your storage array.
#
# Version 1.0, initial release
#

use strict;
use IBM::SVC;
use Getopt::Long;

my $message = "";
my $state   = "";
my $cpt     = '0';
my $cpterr  = '0';
my $errprd  = '0';
my $user    = "nagios";

my @warnings = ("Array mdisk is not protected by sufficient spares",
                "The operation requested could not be performed because software upgrade is in progress",
                "some other error that is actually OK",
                "ERROR: 256 : CMMVC5772E The operation requested could not be performed because software upgrade is in progress.");

my %OPTS = (
   debug    => 0,
   );

GetOptions (
   "cluster=s"      => \$OPTS{hostname},
   "keyfile=s"      => \$OPTS{keyfile},
   "verbose"        => \$OPTS{verbose},
   "debug"          => \$OPTS{debug},
   "count=i"        => \$OPTS{count},
   "warning=i"      => \$OPTS{warning},
   "critical=i"     => \$OPTS{critical},
   "user=s"         => \$OPTS{user}
   );
#or usage_error("");

# Nagios exit states
our %states = (
        OK       => 0,
        WARNING  => 1,
        CRITICAL => 2,
        UNKNOWN  => 3
);

# Nagios state names
our %state_names = (
        0 => 'OK',
        1 => 'WARNING',
        2 => 'CRITICAL',
        3 => 'UNKNOWN'
);

# process Arguments
if ( ! defined($OPTS{hostname}) || ! defined($OPTS{keyfile}) || ! defined($OPTS{warning}) || ! defined($OPTS{critical}) || ! defined($OPTS{count}) ) {
    usage();
}

if ( defined($OPTS{user}) ) {
    $user = $OPTS{user};
}



# Create the options hash for IBM::SVC
my %svc_opts = (
   cluster_name => $OPTS{hostname},
   debug => $OPTS{debug},
   user => $user,
);

# Build SVC options
$svc_opts{keyfile} = $OPTS{keyfile} if ($OPTS{keyfile} ne '');
$svc_opts{ssh_method} =  "ssh";

# SVC connection
my $svc = IBM::SVC->new(\%svc_opts);

print "- Getting information for $OPTS{hostname}\n" if ($OPTS{verbose});

# SVC Command
my $svcquorum = svcinfo($svc,"lsquorum");
chomp $svcquorum;
my $count= scalar @{$svcquorum};
####################################
#$count = 3;
####################################
if ( $count == $OPTS{count} ) {
    # Quorum IP are online 
    foreach my $line (@{$svcquorum}) {
        chomp $line;
        #############################################
        #if ( $line->{site_id} == 1 ) {
        #    $line->{status} = "offline";
        #    print "- $line->{site_name} is $line->{status} .\n" if ($OPTS{verbose});
        #

        #if ( $line->{site_id} == 2 ) {
        #     $line->{status} = "offline";
        #     print "- $line->{site_name} is $line->{status} .\n" if ($OPTS{verbose});
        #}
        #############################################
        if ( $line->{"status"} eq "online" ) {
            $cpt++;
            print "- Quorum $line->{quorum_index} from $line->{site_name} is online.\n" if ($OPTS{verbose});
        } else {
            if ( $line->{site_id} == 1  || $line->{site_id} == 2 ) {
                $errprd = 1;
            }
            $cpterr++;
            if ( $line->{name} ) {
                print "- Quorum $line->{name} ($line->{quorum_index}) from $line->{site_name} is $line->{status}.\n" if ($OPTS{verbose});
                $message .= "Quorum $line->{name} ($line->{quorum_index}) from $line->{site_name} is $line->{status} - ";
            } else {
                print "- Quorum $line->{quorum_index} from $line->{site_name} is $line->{status}.\n" if ($OPTS{verbose});
                $message .= "Quorum $line->{quorum_index} from $line->{site_name} is $line->{status} - "; 
            }
        }
    }

    #  Processing results
    if ($OPTS{verbose}) {
        print "- Counter OK : $cpt\n";
        print "- Counter KO : $cpterr\n";
        print "- Thresolh warning: $OPTS{warning}\n";
        print "- Thresolh critical: $OPTS{critical}\n";
    }

    if ( $cpt == $OPTS{count} ) {
        $message = "All quorum are online.";
        $state = "OK";
    } elsif ( $cpterr ge $OPTS{"critical"} ) {
        $state = "CRITICAL";
    } elsif ( $errprd ) {
        $state = "CRITICAL";
    } elsif ( $cpterr ge $OPTS{"warning"} ) {
        $state = "WARNING";
    } else {
        $state = "UNKNOWN";
    }
} else {
    # Quorum IP doesn't appear offline
    if ($OPTS{verbose}) {
        print "- Number of quorum known by the cluster: $count\n" if ($OPTS{verbose});
        print "- Number of quorum expected: $OPTS{count}\n" if ($OPTS{verbose});
        print "- Thresolh warning: $OPTS{warning}\n";
        print "- Thresolh critical: $OPTS{critical}\n";
    }
    
    my $countdiff = $OPTS{count} - $count;

    if ( $countdiff ge $OPTS{"critical"} ) {
        $state = "CRITICAL";
        $message = "All IP quorum are offline - ";
        
    } else {
        $state = "WARNING";
        $message = "One IP Quorum is offline - ";
    }

    foreach my $line (@{$svcquorum}) {
        chomp $line;
        #############################################
        #if ( $line->{site_id} == 1 ) {
        #    $line->{status} = "offline";
        #}
        #if ( $line->{site_id} == 2 ) {
        #    $line->{status} = "offline";
        #}
        #############################################
        
        if ( $line->{site_id} == 1  || $line->{site_id} == 2 ) {
            if ( $line->{status} eq "online" ) {
                print "- $line->{site_name} is online.\n" if ($OPTS{verbose});
            } else {
                print "- Quorum $line->{name} from $line->{site_name} is $line->{status}.\n" if ($OPTS{verbose});
                $message .= "Quorum $line->{name} ($line->{quorum_index}) from $line->{site_name} is $line->{status} - ";
                $state = "CRITICAL";
                $cpterr++;
            }
        }
    }
    print "- Count KO (Site 1 or 2 only): $cpterr\n" if ($OPTS{verbose});
} 


# End Of Script $string =~ s/[$oldchars]//g
$message =~ s/- $//g; # Remove caracters
print "$message\n";
exit $states{$state};

# Subroutine
sub svcinfo {
   my $svc = shift;
   my ($rc, $result) = $svc->svcinfo(@_);
   assert("$rc : $result",!$rc);
   return $result;
}

sub svctask {
   my $svc = shift;
   my ($rc, $result) = $svc->svctask(@_);
   assert("$rc : $result",!$rc);
   return $result;
}
sub assert {
   return if ($_[1]);
   $message = "ERROR: ".$_[0];
   chop $message;
   $state = warnorerror($message);
   print $message."\n";
   exit $states{$state};
}
sub usage_error {
   my $msg = shift;
   print STDERR $msg."\n";
   exit 1;
}

sub warnorerror {
   my $msg = shift;
        # is the error really a warning?

        if ( grep ( /^$msg$/,@warnings ) ) {
                $state = 'WARNING';
        }
        else {
                $state = 'CRITICAL';
        }
   return $state;
}

sub usage {
    print "Usage: check_ibm_spectrum_quorum.pl -cluster=IPADDRESS -keyfile=/PATH/TO/SSH/KEY -warning X -critical Y -count Z [-user argos] [-debug] [-v]\n";
    print "   -cluster=IPADDRESS         => Address to connect \n";
    print "   -keyfile=/PATH/TO/SSH/KEY  => Path to ssh key allowed on the Cluster\n";
    print "   -warning=X                 => Warning threshold\n";
    print "   -critical=Y                => Critical threshold\n";
    print "   -count=Z                   => Number of quorum expected in normal situation\n";
    print "   [-user=username]           => Username to use with ssh key (default is nagios)\n";
    print "   [-debug]                   => Debug output\n";
    print "   [-v]                       => Verbose output\n";
    exit  $states{UNKNOWN};
}
