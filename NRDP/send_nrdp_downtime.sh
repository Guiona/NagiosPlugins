#!/usr/bin/ksh
#
# Author ONA Guillaume
# Version 1.0
# 


# Fixed variables
Now=`date +%s`
NagiosUser=admin

# Variables
NagiosServer=10.132.9.13
NrdpToken=b23r622e8bot787bn09g8789y458z11p
NagiosHost=
Comment="Reboot"
Duration=7200

while getopts "c:d:hH:s:t:" option ; do
    case $option in
        c) # Comment
            Comment=$OPTARG
        ;;

        d) # Duration of Downtime
            Duration=$OPTARG
            Duration=$(($Duration*60))
            End=$(($Now + $Duration))
        ;;

        h) # Usage
           echo 'send_nrdp_downtime -H NagiosHost -c "Comment" -d "duration in minutes" -s "NRDP Server" -t "Nrdp Token"'
           exit 1
        ;;

        H) # Host Nagios
            NagiosHost=$OPTARG
        ;;

        s) # NRDP server
            NagiosServer=$OPTARG
        ;;

        t) # NRDP Token
            NrdpToken=$OPTARG
        ;;
    esac
done

# Generated URL
#End=$(($Now + $Duration))
Url="https://$NagiosServer/nrdp/?token=$NrdpToken&cmd=submitcmd&command=SCHEDULE_HOST_DOWNTIME;$NagiosHost;$Now;$End;1;0;$Duration;$NagiosUser;$Comment"

# Processing
if which wget >/dev/null ; then
    rslt=$(wget --sslcheckcert=0 -q -O - "$Url")
    ret=$?
else
    echo "wget required!"
    exit 1
fi

status=`echo $rslt | sed -n 's|.*<status>\(.*\)</status>.*|\1|p'`
message=`echo $rslt | sed -n 's|.*<message>\(.*\)</message>.*|\1|p'`
if [[ ${ret} == "0" ]] ; then
    if [[ ${message} != "OK" ]] ; then
        echo "${status}"
        exit 1
    else
        echo "Command submit successfully"
        exit 0
    fi
else
    echo "Une erreur s'est produite avec la commande wget"
    echo "$resultat"
    exit 1
fi
