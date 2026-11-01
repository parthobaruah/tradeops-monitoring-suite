#!/bin/bash
#Nagios plugin: check_cpu_temp.sh

WARN_THRESH=80
CRIT_THRESH=90

while getopts "w:c:h" opt; do
	case $opt in
		w) WARN_THRESH=$OPTARG ;;
		c) CRIT_THRESH=$OPTARG ;;
		h) 
		   echo "Usage: $0 -w <warning_temp_c> -c <critical_temp_c>"
		   exit 3
		   ;;

		  *)
		   echo "Invalid option. Use -h for help."
		   exit 3
		   ;;
	esac
done

CORE_DIR=$(grep -l "coretemp" /sys/class/hwmon/hwmon*/name 2>/dev/null | head -n 1 | sed 's#/name##')

if [ -z "$CORE_DIR" ] || [ ! -f "$CORE_DIR/temp1_input" ]; then
	echo "UNKNOWN - Unable to locate intel coretemp sensor in sysfs"
	exit 3
fi

RAW_MILLI=$(cat "$CORE_DIR/temp1_input")
CPU_TEMP=$((RAW_MILLI / 1000))

# 3. Read individual core inputs to find max core temp
MAX_CORE=$CPU_TEMP
for core_input in "$CORE_DIR"/temp*_input; do
    raw=$(cat "$core_input")
    val=$((raw / 1000))
    if [ "$val" -gt "$MAX_CORE" ]; then
        MAX_CORE=$val
    fi
done

# 4. Performance data string (for Nagios graphing)
PERF_DATA="temp=${CPU_TEMP}C;${WARN_THRESH};${CRIT_THRESH};0;105"

# 5. Evaluate Nagios status
if [ "$CPU_TEMP" -ge "$CRIT_THRESH" ]; then
    echo "CRITICAL - CPU Package Temp is ${CPU_TEMP}°C (Core Max: ${MAX_CORE}°C) | ${PERF_DATA}"
    exit 2
elif [ "$CPU_TEMP" -ge "$WARN_THRESH" ]; then
    echo "WARNING - CPU Package Temp is ${CPU_TEMP}°C (Core Max: ${MAX_CORE}°C) | ${PERF_DATA}"
    exit 1
else
    echo "OK - CPU Package Temp is ${CPU_TEMP}°C (Core Max: ${MAX_CORE}°C) | ${PERF_DATA}"
    exit 0
fi
