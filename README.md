# ow2knx
Fetch 1-Wire sensor data via One Wire File System (owfs) and write to Group Addresses on the KNX Bus

This is a little bash script I wrote, to cyclically fetch temperatures from DS18B20 sensors on a 1-wire bus. The data is then converted to the KNX compliant DPT 9.x datapoint representation and sent to the KNX Bus using https://github.com/knxd/knxd or more precisely `knxtool groupwrite`.

The script might be executed by the systemd service unit provided. It should run as long as there is a owfs subsystem mounted at the specified mountpoint. The 1-Wire read interval as well as a 'force-rewrite-interval' can be set at the top of the script. Writes to the KNX Bus are usually only carried out, when a change in the value has occured. Except when the 'force-rewrite-interval' has been exceeded.

The OWFS 1-Wire File System is described here: https://owfs.org/

Specification of the datapoint types used on the KNX Bus may be found here: [Datapoint Types - KNX Association](https://www.google.com/url?sa=t&rct=j&q=&esrc=s&source=web&cd=&ved=2ahUKEwiImZSmz8vsAhWCsaQKHSxTCwgQFjAAegQIBhAC&url=https%3A%2F%2Fwww.knx.org%2FwAssets%2Fdocs%2Fdownloads%2FCertification%2FInterworking-Datapoint-types%2F03_07_02-Datapoint-Types-v02.01.02-AS.pdf&usg=AOvVaw1Sj0MeH30t81UNAIZd51KQ)

