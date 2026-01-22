#!/bin/bash

#pull the machine serial
getSerial=`/usr/sbin/system_profiler SPHardwareDataType | /usr/bin/awk '/Serial\ Number\ \(system\)/ {print $NF}'`

#verify the serial was pulled 
echo "Serial: $getSerial"

#check current machine name
machineName=$(scutil --get ComputerName)
echo "Machine: $machineName"

#set nomenclature imac-serial
fullComputerName=imac-$getSerial	

#assign names
scutil --set ComputerName $fullComputerName
scutil --set LocalHostName $fullComputerName
scutil --set HostName $fullComputerName

#verify name
echo "ComputerName"
scutil --get ComputerName
echo "HostName"
scutil --get HostName
echo "LocalHostName"
scutil --get LocalHostName
