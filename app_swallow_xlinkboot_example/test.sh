#!/bin/bash
I=0
while :
do
	xrun --io --id 0 bin/swallow_xlinkboot.xe
	I=$(($I+1))
	echo $I
done
