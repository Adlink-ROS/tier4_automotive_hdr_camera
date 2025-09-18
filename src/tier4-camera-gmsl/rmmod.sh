#!/bin/bash

sudo rmmod tier4-imx728
sudo rmmod tier4-imx490
sudo rmmod tier4-gw5300
sudo rmmod tier4-isx021
sudo rmmod tier4-max9295
sudo rmmod tier4-max9296
sudo rmmod tier4-fpga
sudo rmmod max20089

 i2ctransfer -f -y 9 w2@0x28 0x01 0x00
 i2ctransfer -f -y 10 w2@0x29 0x01 0x00
 sleep 0.1
 i2ctransfer -f -y 9 w2@0x28 0x01 0x0F
 i2ctransfer -f -y 10 w2@0x29 0x01 0x0F

 # reset max96712
 i2ctransfer -f -y 9 w3@0x4b 0x00 0x10 0x80 # RESET_ALL
 i2ctransfer -f -y 10 w3@0x4b 0x00 0x10 0x80 # RESET_ALL

 # enable SW MAX96712_RST pin
 sudo i2cset -f -y 0 0x66 0x04 0x18
 sleep 0.3

