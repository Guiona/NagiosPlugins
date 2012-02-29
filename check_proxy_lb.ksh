#!/bin/ksh
#set -x
# @(#)#=========================================================================#
# @(#)#                                                		                #
# @(#)# Script        : check_proxy_lb.sh                                       #
# @(#)#                                                                         #
# @(#)# Version       : 0.2                                                     #
# @(#)# Date          : 28/02/2012                                              #
# @(#)#                                                                         #
# @(#)# Author        : ONA Guillaume (guillaume dot ona at gmail dot com)      #
# @(#)#                                                                         #
# @(#)# Description   : Check Apache 2 Load Balancer Manager			#
# @(#)#                                                                         #
# @(#)# License       : GPL - http://www.gnu.org/licenses/                      #
# @(#)#                                                                 	#
# @(#)# TODO          : SSL Support                                     	#
# @(#)#               : Unknown Worker                                  	#
# @(#)#                                                                 	#
# @(#)#=========================================================================#

#-------------------------#
#        FUNCTIONS        #
#-------------------------#
# Print Usage
function f_usage {
    echo "
    check_proxy_lb -H hostname [-n ajp] [-u /url]

        -H|--hostname : Hostname of balancer manage (ex:myserver.domain.com)

        -n|--name     : AJP name in balancer manager (Default: All)

        -u|--url      : Url of balancer manager (Default: /balancer-manager)

        -v|--version  : Print version and license
"

    exit ${STATE_UNKNOWN}
}

# Print Version and license information
function f_version {
    echo "
    +-------------------------------+
    |        check_proxy_lb         |
    +-------------------------------+
        Version       : ${VERSION}
        Date          : ${DATE}
        Description   : Check Apache 2 Load Balancer Manager
        Author        : ONA Guillaume (guillaume dot ona at gmail dot com)
        License       : GPL - http://www.gnu.org/licenses/

    ****************************************************************************
    * This program is free software: you can redistribute it and/or modify     *
    * it under the terms of the GNU Affero General Public License as           *
    * published by the Free Software Foundation, either version 3 of the       *
    * License, or (at your option) any later version.                          *
    *                                                                          *
    * This program is distributed in the hope that it will be useful,          *
    * but WITHOUT ANY WARRANTY; without even the implied warranty of           *
    * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the             *
    * GNU Affero General Public License for more details.                      *
    *                                                                          *
    * You should have received a copy of the GNU Affero General Public License *
    * along with this program. If not, see <http://www.gnu.org/licenses/>.     *
    ****************************************************************************
"
    exit 0
}

#-------------------------#
#      MAIN PROGRAM       #
#-------------------------#
VERSION="0.2"
RELEASE_DATE="28/02/2012"

STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2
STATE_UNKNOWN=3

typeset -i NB_AJP=0
typeset -i NB_AJP_OK=0
typeset -i NB_AJP_WARNING=0
typeset -i NB_AJP_CRITICAL=0

# Check arguments
while (( $# > 0 )) ; do
    case $1 in
        '-H'|'--hostname')
            BALANCER_MANAGER_HOST=${2}
            shift 2
        ;;
        '-u'|'--url')
            BALANCER_MANAGER_URI=${2}
            shift 2
        ;;
        '-n'|'--name')
            BALANCER_MANAGER_ROUTE=${2}
            shift 2
        ;;
        '-v'|'--version')
            f_version
            shift
        ;;
        '-h'|'--help')
            f_usage
            shift
        ;;
        *)
            f_usage
            shift
        ;;
    esac
done

# Hostname required
if [ ! ${BALANCER_MANAGER_HOST} ] ; then
    echo "*** Hostname is required ***"
    f_usage
fi 

# Build full url of balancer manager
if [ ! ${BALANCER_MANAGER_URI} ] ; then
    BALANCER_MANAGER_URL="http://${BALANCER_MANAGER_HOST}/balancer-manager"
else
    BALANCER_MANAGER_URL="http://${BALANCER_MANAGER_HOST}${BALANCER_MANAGER_URI}"
fi

# Check availability of balancer manager
/usr/bin/wget -q --delete-after ${BALANCER_MANAGER_URL} -O /tmp/balancer-manager.log
if [ ${?} -ne 0 ] ; then
	echo "AJP UNKNOWN - Can't connect to ${BALANCER_MANAGER_URL}"
	exit ${STATE_UNKNOWN}
fi

# Check a specific AJP
if [ ${BALANCER_MANAGER_ROUTE} ] ; then
    eval $(/usr/bin/curl -s ${BALANCER_MANAGER_URL} \
        | /bin/grep 'href' \
        | /bin/sed 's/<[^>]*>/;/g' \
        | /bin/awk -v ROUTE=${BALANCER_MANAGER_ROUTE} '
             BEGIN { FS=";" }
             {
                 if ( $6 == ROUTE ) {
                      find=1
                      if ( $14 == "Ok" ) {
                          printf("echo AJP OK - Worker URL: %s, Route: %s, State: %s && exit ${STATE_OK}", $3, $6, $14)
                      } else if ( $14 ~ "Err" ) {
                          printf("echo AJP CRITICAL - Worker URL: %s, Route: %s, State: %s && exit ${STATE_CRITICAL}", $3, $6, $14)
                      } else {
                          printf("echo AJP WARNING - Worker URL: %s, Route: %s, State: %s && exit ${STATE_WARNING}", $3, $6, $14)
                      }
                 }
             }')
else
    # Check All AJP
    /usr/bin/curl -s ${BALANCER_MANAGER_URL} \
        | /bin/grep 'href' \
        | /bin/sed 's/<[^>]*>/;/g' \
        | /bin/awk '
            BEGIN { FS=";" }
            {
                if ( $14 == "Ok" ) {
                    printf("OK;%s;%s;%s\n", $3, $6, $14)
                } else if ( $14 ~ "Err" ) {
                    printf("CRITICAL;%s;%s;%s\n", $3, $6, $14)
                } else {
                    printf("WARNING;%s;%s;%s\n", $3, $6, $14)
                }
            } ' \
        | while read line ; do
            NB_AJP=$((NB_AJP + 1))
            echo ${line} | grep "OK" >/dev/null 2>&1
            if [ ${?} -eq 0 ] ; then
                NB_AJP_OK=$((NB_AJP_OK + 1))
            else
                echo ${line} | grep "WARNING" >/dev/null 2>&1
                if [ $? -eq 0 ] ; then
                    NB_AJP_WARNING=$((NB_AJP_WARNING + 1))
                    AJP_WARNING="${AJP_WARNING} $(echo ${line} | /usr/bin/awk --field-separator=";" ' { print $3} ')"
                else
                    NB_AJP_CRITICAL=$((NB_AJP_CRITICAL + 1))
                    AJP_CRITICAL="${AJP_CRITICAL} $(echo ${line} | /usr/bin/awk --field-separator=";" ' { print $3} ')"
                fi
            fi
        done

    # All OK
    if [ ${NB_AJP} -eq ${NB_AJP_OK} ] ; then
        echo "AJP OK - All AJP are available"
        exit ${STATE_OK}
    # All critical
    elif [ ${NB_AJP} -eq ${NB_AJP_CRITICAL} ] ; then
        echo "AJP CRITICAL - All AJP are down, CRITICAL=${AJP_CRITICAL}"
        exit ${STATE_CRITICAL}
    # One or more warning without critical
    elif [ ${NB_AJP_WARNING} -gt 0  ${NB_AJP_CRITICAL} -eq 0 ] ; then
        echo "AJP WARNING - One or more AJP are not available, WARNING:${AJP_WARNING}"
        exit ${STATE_WARNING}
    # One or more critical and one or more warning
    elif [[ ${NB_AJP_CRITICAL} -gt 0 && ${NB_AJP_WARNING} -gt 0 ]] ; then
        echo "AJP CRITICAL - One or more AJP are not available, CRITICAL=${AJP_CRITICAL}, WARNING:${AJP_WARNING}"
        exit ${STATE_CRITICAL}
    fi
fi

# End Of Script
echo "AJP UNKNOWN - UNKNOWN"
exit ${STATE_UNKNOWN}
