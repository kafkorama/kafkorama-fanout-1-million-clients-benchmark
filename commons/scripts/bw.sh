#!/bin/bash

USAGE="Usage: `basename $0` <interface> {in|out}"

if [ $# -ne 2 ]; then
        echo "$USAGE"
        exit 1
fi

INTERFACE="$1"
DIRECTION="$2"

if [ "$DIRECTION" == "in" ]; then
        echo "Measuring incoming bandwidth on $INTERFACE"
elif [ "$DIRECTION" == "out" ]; then
        echo "Measuring outgoing bandwidth on $INTERFACE"
else
        echo -e "Use 'in' or 'out' for the direction parameter!\n$USAGE"
        exit 1
fi

INTERVAL=10
TOTAL_PACKETS_PER_SEC=0
TOTAL_BYTES_PER_SEC=0
SAMPLES=0

cleanup()
{
        if [ $SAMPLES -gt 0 ]; then
                TOTAL_PACKETS_PER_SEC=`bc -l <<< "scale=2;$TOTAL_PACKETS_PER_SEC/$SAMPLES"`
                TOTAL_BYTES_PER_SEC=`bc -l <<< "scale=2;$TOTAL_BYTES_PER_SEC/$SAMPLES"`

                echo -n "Total (mean): "
                display $TOTAL_PACKETS_PER_SEC $TOTAL_BYTES_PER_SEC
        fi

        exit 0
}

display()
{
        BITS=`bc -l <<< "scale=2;$2*8"`
        KBITS=`bc -l <<< "scale=2;if ($BITS>1000 && $BITS<1000000) {print \"(\";print $BITS/1000;print \" Kbits/sec)\"}"`
        MBITS=`bc -l <<< "scale=2;if ($BITS>1000000 && $BITS<1000000000) {print \"(\";print $BITS/1000000;print \" Mbits/sec)\"}"`
        GBITS=`bc -l <<< "scale=2;if ($BITS>1000000000) {print \"(\";print $BITS/1000000000;print \" Gbits/sec)\"}"`

        KBYTES=`bc -l <<< "scale=2;if ($2>1024 && $2<1048576) {print \"(\";print $2/1024;print \" KB/sec)\"}"`
        MBYTES=`bc -l <<< "scale=2;if ($2>1048576 && $2<1073741824) {print \"(\";print $2/1048576;print \" MB/sec)\"}"`
        GBYTES=`bc -l <<< "scale=2;if ($2>1073741824) {print \"(\";print $2/1073741824;print \" GB/sec)\"}"`

        echo -e "$1 packets/sec \t $BITS bits/sec $KBITS$MBITS$GBITS \t $2 bytes/sec $KBYTES$MBYTES$GBYTES"
}

trap cleanup SIGINT

while [ true ]; do
        TIME1=`date +%s`
        DATA1=`grep $INTERFACE /proc/net/dev | awk -F: '{print $2}'`

        sleep $INTERVAL

        TIME2=`date +%s`
        DATA2=`grep $INTERFACE /proc/net/dev | awk -F: '{print $2}'`

        if [ "$DIRECTION" == "in" ]; then
                PACKETS1=`awk '{print $2}' <<< $DATA1`
                PACKETS2=`awk '{print $2}' <<< $DATA2`
                BYTES1=`awk '{print $1}' <<< $DATA1`
                BYTES2=`awk '{print $1}' <<< $DATA2`
        elif [ "$DIRECTION" == "out" ]; then
                PACKETS1=`awk '{print $10}' <<< $DATA1`
                PACKETS2=`awk '{print $10}' <<< $DATA2`
                BYTES1=`awk '{print $9}' <<< $DATA1`
                BYTES2=`awk '{print $9}' <<< $DATA2`
        fi

        TIME=$(($TIME2-$TIME1))
        PACKETS=$(($PACKETS2-$PACKETS1))
        BYTES=$(($BYTES2-$BYTES1))

        PACKETS_PER_SEC=`bc -l <<< "scale=2;$PACKETS/$TIME"`
        BYTES_PER_SEC=`bc -l <<< "scale=2;$BYTES/$TIME"`
        SAMPLES=$(($SAMPLES+1))
        TOTAL_PACKETS_PER_SEC=`bc -l <<< "scale=2;$TOTAL_PACKETS_PER_SEC+$PACKETS_PER_SEC"`
        TOTAL_BYTES_PER_SEC=`bc -l <<< "scale=2;$TOTAL_BYTES_PER_SEC+$BYTES_PER_SEC"`

        display $PACKETS_PER_SEC $BYTES_PER_SEC

done