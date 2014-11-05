#!/bin/bash

# author        max.pilipenko@gmail.com
#               megashtyr@gmail.com

# in seconds
WARN_TIME="20"
CRIT_TIME="50"

# end of user-configurable parameters

PGREP_BIN=$(which pgrep)
if [ -z $PGREP_BIN ]; then
    echo "pgrep not found, exiting."
    exit 1
fi

PIDOF_BIN=$(which pidof)
if [ ! -z $PIDOF_BIN ]; then
    CRON_PID=$($PIDOF_BIN cron)
else
#    echo "Couldn't find pidof, had to grep through processlist for parent cron PID."
    CRON_PID=`ps ax|grep '/usr/sbin/cron'|grep -v grep|cut -d ' ' -f2`
fi

PIDS_TIMES=`{ for CHILD in $($PGREP_BIN -P $CRON_PID|sort -n); do ps -o pid,etimes -p $CHILD |tail -n 1|tr -s ' '; done }|sort -k 2 -rn|tr ' ' ','`

echo "Longest-running cron child tasks:"
for TUPLE in $PIDS_TIMES; do
    TIME=$(echo $TUPLE|cut -d ',' -f2);
    CPID=$(echo $TUPLE|cut -d ',' -f1);
    if [ $TIME -gt $WARN_TIME ] && [ $TIME -lt $CRIT_TIME ]; then
        JOB=$($PGREP_BIN -P $CPID);
        CMD=$(ps -o command -p $JOB|tail -n1);
        echo "WARNING! $TIME seconds, PID: $JOB, COMMAND: $CMD";
    fi;
    if [ $TIME -gt $CRIT_TIME ]; then
        JOB=$($PGREP_BIN -P $CPID);
        CMD=$(ps -o command -p $JOB|tail -n1);
        echo "CRITICAL! $TIME seconds, PID: $JOB, COMMAND: $CMD";
    fi;
    done


echo "Most old cron child PID: $($PGREP_BIN -P `echo $PIDS_TIMES|head -n1|cut -d ',' -f1`)"
