#!/bin/bash

I2C_SWITCH=9
if [ $1 ]; then
    I2C_SWITCH=$1
fi

DESER_ADDR=0x48
if [ $2 ]; then
    DESER_ADDR=$2
fi

# Use 4 Lanes:
LANE_CNT=0xC0
# Use 2 Lanes:
# LANE_CNT=0x40

# default serializer 7bit addr
#SER_DEFAULT=0x40
SER_DEFAULT=0x62

SER_A_8B=0x84
SER_B_8B=0xC0
SER_A_7B=0x42
SER_B_7B=0x60
# SER_A_8B=0x80
# SER_B_8B=0x84
# SER_A_7B=0x40
# SER_B_7B=0x42

SER_A_CONNECTED=0
SER_B_CONNECTED=0

# off/on power to reset cameras
POWER_PROTECT=0x28
if [[ $I2C_SWITCH -eq 32 || $I2C_SWITCH -eq 33 || $I2C_SWITCH -eq 11 || $I2C_SWITCH -eq 12 ]]; then
        POWER_PROTECT=0x29
fi

function red_print() {
    echo -e "\e[1;31m$1\e[0m"
}

function green_print() {
    echo -e "\e[1;32m$1\e[0m"
}

echo -----------------------------------
green_print "i2c_bus=$I2C_SWITCH"
green_print "de-serializer=$DESER_ADDR"
green_print "serializer=$SER_DEFAULT"
green_print "POWER_PROTECT=$POWER_PROTECT"
echo -----------------------------------

# control MAX20089: camera power regulator
i2ctransfer -f -y $I2C_SWITCH w2@$POWER_PROTECT 0x01 0x00 # power down
sleep 0.1

i2ctransfer -f -y $I2C_SWITCH w2@$POWER_PROTECT 0x01 0x0F # power up
sleep 0.1

# completely reset MAX9296
i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x00 0x10 0x80 # RESET_ALL
sleep 0.1

# Enable DES Link A to configure SER-A
i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x00 0x10 0x01
i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x00 0x10 0x21 # One-shot reset and Link A only
sleep 0.2

#######################
# The 1st SER: MAX9295
#######################
red_print "[9295]: serializer-a"
val=$(i2ctransfer -f -y $I2C_SWITCH w2@$SER_DEFAULT 0x00 0x00 r1)
ret=$?

# 7bit 0x62 = 8bit 0xC4
if [[ $ret -eq 0 && $val -eq $((16#C4)) ]]; then
    SER_A_CONNECTED=1
    echo "SER-A connected"
    i2ctransfer -f -y $I2C_SWITCH w3@$SER_DEFAULT 0x00 0x00 $SER_A_8B
elif [[ $ret -eq 0 && $val -eq $((16#00)) ]]; then
    # there is a confliction when using Leopard board
    i2ctransfer -f -y $I2C_SWITCH w3@$SER_DEFAULT 0x00 0x00 $SER_A_8B
    val=$(i2ctransfer -f -y $I2C_SWITCH w2@$SER_A_7B 0x00 0x00 r1)
    ret=$?
    if [[ $ret -eq 0 && $val -eq $((16#84)) ]]; then
            SER_A_CONNECTED=1
            echo "SER-A connected"
    else
            echo "SER-A NOT connected"
    fi
else
    echo "SER-A NOT connected"
fi

    i2ctransfer -f -y $I2C_SWITCH w3@$SER_A_7B 0x00 0x10 0x21
    sleep 0.1 # wait for reset

# Tier4 
    i2ctransfer -f -y $I2C_SWITCH w3@$SER_A_7B 0x00 0x03 0x03 # Set RCLKOUT soruce to the reference PLL clock
    i2ctransfer -f -y $I2C_SWITCH w3@$SER_A_7B 0x03 0xF0 0x5A # PLL setting & Reset PLL
    sleep 0.1
#

    i2ctransfer -f -y $I2C_SWITCH w3@$SER_A_7B 0x00 0x6B 0x10 # ???
    i2ctransfer -f -y $I2C_SWITCH w3@$SER_A_7B 0x00 0x73 0x11 # ???
    i2ctransfer -f -y $I2C_SWITCH w3@$SER_A_7B 0x00 0x7B 0x31 # TX_SRC_ID=1
    i2ctransfer -f -y $I2C_SWITCH w3@$SER_A_7B 0x00 0x83 0x31 # TX_SRC_ID=1
    i2ctransfer -f -y $I2C_SWITCH w3@$SER_A_7B 0x00 0x93 0x31 # TX_SRC_ID=1
    i2ctransfer -f -y $I2C_SWITCH w3@$SER_A_7B 0x00 0x9B 0x31
    i2ctransfer -f -y $I2C_SWITCH w3@$SER_A_7B 0x00 0xA3 0x31 # TX_SRC_ID=1
    i2ctransfer -f -y $I2C_SWITCH w3@$SER_A_7B 0x00 0xAB 0x31 # TX_SRC_ID=1

    i2ctransfer -f -y $I2C_SWITCH w3@$SER_A_7B 0x00 0x44 0x3A # alias sensor address on host (0x1d)
    i2ctransfer -f -y $I2C_SWITCH w3@$SER_A_7B 0x00 0x45 0x34 # default sensor address (0x1a)

    # GPIO0 for SER-A
    i2ctransfer -f -y $I2C_SWITCH w3@$SER_A_7B 0x02 0xBE 0x90 # SER GPIO output=1
    i2ctransfer -f -y $I2C_SWITCH w3@$SER_A_7B 0x02 0xBF 0x60 # SER GPIO_TX_ID=0
    i2ctransfer -f -y $I2C_SWITCH w3@$SER_A_7B 0x03 0xF1 0x89 # RCLK output pin select
# Tier4
    i2ctransfer -f -y $I2C_SWITCH w3@$SER_A_7B 0x03 0xF0 0x59 # PLL setting & Enable PLL
#

# Enable DES Link B to configure SER-B
i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x00 0x10 0x02
i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x00 0x10 0x22 # One-shot reset and Link B only
sleep 0.2

#######################
# The 2nd SER: MAX9295
#######################
red_print "[9295]: serializer-b"
val=$(i2ctransfer -f -y $I2C_SWITCH w2@$SER_DEFAULT 0x00 0x00 r1)
ret=$?
if [[ $ret -eq 0 && $val -eq $((16#C4)) ]]; then
    SER_B_CONNECTED=1
    i2ctransfer -f -y $I2C_SWITCH w3@$SER_DEFAULT 0x00 0x00 $SER_B_8B
    echo "SER-B connected"
elif [[ $ret -eq 0 && $val -eq $((16#00)) ]]; then
    # There is 0x40 device in i2c-1 for Leopard board which will ack 0x00
    i2ctransfer -f -y $I2C_SWITCH w3@$SER_DEFAULT 0x00 0x00 $SER_B_8B
    val=$(i2ctransfer -f -y $I2C_SWITCH w2@$SER_B_7B 0x00 0x00 r1)
    ret=$?
    if [[ $ret -eq 0 && $val -eq $((16#C0)) ]]; then
            SER_B_CONNECTED=1
            echo "SER-B connected"
    else
            echo "SER-B NOT connected"
    fi
else
    echo "SER-B NOT connected"
fi

    i2ctransfer -f -y $I2C_SWITCH w3@$SER_B_7B 0x00 0x10 0x22
    sleep 0.1 # wait for reset

    i2ctransfer -f -y $I2C_SWITCH w3@$SER_B_7B 0x00 0x6B 0x12 # ???
    i2ctransfer -f -y $I2C_SWITCH w3@$SER_B_7B 0x00 0x73 0x13 # ???
    i2ctransfer -f -y $I2C_SWITCH w3@$SER_B_7B 0x00 0x7B 0x32 # TX_SRC_ID=2
    i2ctransfer -f -y $I2C_SWITCH w3@$SER_B_7B 0x00 0x83 0x32 # TX_SRC_ID=2
    i2ctransfer -f -y $I2C_SWITCH w3@$SER_B_7B 0x00 0x93 0x32 # TX_SRC_ID=2
    i2ctransfer -f -y $I2C_SWITCH w3@$SER_B_7B 0x00 0x9B 0x32
    i2ctransfer -f -y $I2C_SWITCH w3@$SER_B_7B 0x00 0xA3 0x32 # TX_SRC_ID=2
    i2ctransfer -f -y $I2C_SWITCH w3@$SER_B_7B 0x00 0xAB 0x32 # TX_SRC_ID=2
    i2ctransfer -f -y $I2C_SWITCH w3@$SER_B_7B 0x00 0x8B 0x32 # TX_SRC_ID=2

    i2ctransfer -f -y $I2C_SWITCH w3@$SER_B_7B 0x00 0x44 0xB8 # alias sensor address on host (0x5c)
    i2ctransfer -f -y $I2C_SWITCH w3@$SER_B_7B 0x00 0x45 0x20 # default sensor address (0x10)

    # GPIO0 for SER-B
    i2ctransfer -f -y $I2C_SWITCH w3@$SER_B_7B 0x02 0xBE 0x90 # SER GPIO output=1
    i2ctransfer -f -y $I2C_SWITCH w3@$SER_B_7B 0x02 0xBF 0x60 # SER GPIO_TX_ID=0
    i2ctransfer -f -y $I2C_SWITCH w3@$SER_B_7B 0x03 0xF1 0x89 # RCLK output pin select
    sleep 0.1

if [ $SER_A_CONNECTED -eq 1 ] && [ $SER_B_CONNECTED -eq 1 ];
then
    echo "enable link A & B"
    # i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x00 0x10 0x03 # Enable Link A and B (reverse splitter mode)
    i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x00 0x10 0x23 # One-shot reset; enable Link A and B
elif [ $SER_A_CONNECTED -eq 1 ] && [ $SER_B_CONNECTED -eq 0 ];
then
    i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x00 0x10 0x01 # Enable Link A only
    i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x00 0x10 0x21 # One-shot reset; enable Link A only
elif [ $SER_A_CONNECTED -eq 0 ] && [ $SER_B_CONNECTED -eq 1 ];
then
    i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x00 0x10 0x02 # Enable Link B only
    i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x00 0x10 0x22 # One-shot reset; enable Link B only
fi
sleep 0.1

# i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x03 0x13 0x02 # Enable CSI out
# i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x03 0x32 0x30 # Put PHY2/3 in standby mode to save power
# sleep 0.1

#####################
# SER A setup stream
#####################
# i2ctransfer -f -y $I2C_SWITCH w3@$SER_A_7B 0x03 0x30 0x08 # reset MIPI RX

i2ctransfer -f -y $I2C_SWITCH w3@$SER_A_7B 0x03 0x30 0x00 # [default: 0x00] disable VC mapping, 1x4 lane (one port with 4 lanes)
i2ctransfer -f -y $I2C_SWITCH w3@$SER_A_7B 0x03 0x31 0x30 # select controller 1 (SER Port B) for 4 lanes
i2ctransfer -f -y $I2C_SWITCH w3@$SER_A_7B 0x03 0x32 0xE0 # [default: 0xE0] PHY1 lane0->2, lane1->3
i2ctransfer -f -y $I2C_SWITCH w3@$SER_A_7B 0x03 0x33 0x04 # [default: 0x04] PHY2 lane0->0, lane1->1

# below are same as Tier4 driver:
i2ctransfer -f -y $I2C_SWITCH w3@$SER_A_7B 0x03 0x14 0xF0 # enable(=bit6) datatype ? route to pipe X
i2ctransfer -f -y $I2C_SWITCH w3@$SER_A_7B 0x03 0x18 0x5E # enable(=bit6) datatype 0x1E route to pipe U
i2ctransfer -f -y $I2C_SWITCH w3@$SER_A_7B 0x03 0x11 0xF0 # start pipe X/Y/Z/U from SER's port B
i2ctransfer -f -y $I2C_SWITCH w3@$SER_A_7B 0x03 0x08 0x65 # select SER's port B for pipe X/Z
#

# i2ctransfer -f -y $I2C_SWITCH w3@$SER_A_7B 0x03 0x08 0x61 # select SER's port B for pipe X
# i2ctransfer -f -y $I2C_SWITCH w3@$SER_A_7B 0x03 0x08 0x62 # select SER's port B for pipe Y
# i2ctransfer -f -y $I2C_SWITCH w3@$SER_A_7B 0x03 0x08 0x64 # select SER's port B for pipe Z
# i2ctransfer -f -y $I2C_SWITCH w3@$SER_A_7B 0x03 0x08 0x68 # select SER's port B for pipe U
# i2ctransfer -f -y $I2C_SWITCH w3@$SER_A_7B 0x03 0x08 0x6F # select SER's port B for pipe X/Y/Z/U

# i2ctransfer -f -y $I2C_SWITCH w3@$SER_A_7B 0x03 0x11 0x10 # start pipe X from SER's port B
# i2ctransfer -f -y $I2C_SWITCH w3@$SER_A_7B 0x03 0x11 0x20 # start pipe Y from SER's port B
# i2ctransfer -f -y $I2C_SWITCH w3@$SER_A_7B 0x03 0x11 0x40 # start pipe Z from SER's port B
# i2ctransfer -f -y $I2C_SWITCH w3@$SER_A_7B 0x03 0x11 0x80 # start pipe U from SER's port B
# i2ctransfer -f -y $I2C_SWITCH w3@$SER_A_7B 0x03 0x11 0xF0 # start pipe X/Y/Z/U from SER's port B

# i2ctransfer -f -y $I2C_SWITCH w3@$SER_A_7B 0x03 0x14 0x6C # enable(=bit6) datatype 0x2C route to pipe X
# i2ctransfer -f -y $I2C_SWITCH w3@$SER_A_7B 0x03 0x16 0x6C # enable(=bit6) datatype 0x2C route to pipe Y
# i2ctransfer -f -y $I2C_SWITCH w3@$SER_A_7B 0x03 0x18 0x6C # enable(=bit6) datatype 0x2C route to pipe Z
# i2ctransfer -f -y $I2C_SWITCH w3@$SER_A_7B 0x03 0x1A 0x6C # enable(=bit6) datatype 0x2C route to pipe U

# i2ctransfer -f -y $I2C_SWITCH w3@$SER_A_7B 0x00 0x02 0x13 # Enable SER Pipe X (RSVD for bit 0/1)
# i2ctransfer -f -y $I2C_SWITCH w3@$SER_A_7B 0x00 0x02 0x23 # Enable SER Pipe Y (RSVD for bit 0/1)
# i2ctransfer -f -y $I2C_SWITCH w3@$SER_A_7B 0x00 0x02 0x43 # Enable SER Pipe Z (RSVD for bit 0/1)
# i2ctransfer -f -y $I2C_SWITCH w3@$SER_A_7B 0x00 0x02 0x83 # Enable SER Pipe U (RSVD for bit 0/1)
# i2ctransfer -f -y $I2C_SWITCH w3@$SER_A_7B 0x00 0x02 0xF3 # Enable SER Pipe X/Y/Z/U (RSVD for bit 0/1)

# i2ctransfer -f -y $I2C_SWITCH w3@$SER_A_7B 0x00 0x53 0x00 # set ST_ID=0 video_x
# i2ctransfer -f -y $I2C_SWITCH w3@$SER_A_7B 0x00 0x57 0x00 # set ST_ID=0 video_y
# i2ctransfer -f -y $I2C_SWITCH w3@$SER_A_7B 0x00 0x5B 0x00 # set ST_ID=0 video_z
# i2ctransfer -f -y $I2C_SWITCH w3@$SER_A_7B 0x00 0x5F 0x00 # set ST_ID=0 video_u

# i2ctransfer -f -y $I2C_SWITCH w3@$SER_A_7B 0x02 0xD8 0x10 # GPIO_RX_ID=0x10
# i2ctransfer -f -y $I2C_SWITCH w3@$SER_A_7B 0x02 0xD6 0x04 # GPIO_RX_EN=true
i2ctransfer -f -y $I2C_SWITCH w3@$SER_A_7B 0x00 0x02 0xF3 # Enable SER Pipe X/Y/Z/U (RSVD for bit 0/1)
# sleep 0.1

#####################
# SER B setup stream
#####################
# i2ctransfer -f -y $I2C_SWITCH w3@$SER_B_7B 0x03 0x30 0x08 # reset MIPI RX

i2ctransfer -f -y $I2C_SWITCH w3@$SER_B_7B 0x03 0x30 0x00 # [default: 0x00] disable VC mapping, 1x4 lane (one port with 4 lanes)
i2ctransfer -f -y $I2C_SWITCH w3@$SER_B_7B 0x03 0x31 0x30 # select controller 1 (SER Port B) for 4 lanes
i2ctransfer -f -y $I2C_SWITCH w3@$SER_B_7B 0x03 0x32 0xE0 # [default: 0xE0] PHY1 lane0->2, lane1->3
i2ctransfer -f -y $I2C_SWITCH w3@$SER_B_7B 0x03 0x33 0x04 # [default: 0x04] PHY2 lane0->0, lane1->1

# below are same as driver:
i2ctransfer -f -y $I2C_SWITCH w3@$SER_B_7B 0x03 0x16 0x70 # enable(=bit6) datatype ? route to pipe Y
i2ctransfer -f -y $I2C_SWITCH w3@$SER_B_7B 0x03 0x1A 0x5E # enable(=bit6) datatype 0x1E route to pipe U
i2ctransfer -f -y $I2C_SWITCH w3@$SER_B_7B 0x03 0x11 0xF0 # start pipe X/Y/Z/U from SER's port B
i2ctransfer -f -y $I2C_SWITCH w3@$SER_B_7B 0x03 0x08 0x6A # select SER's port B for pipe Y/U

#
# Even SER B uses the same pipe X as SER A, but the configured stream ID (ST_ID) is different. 
# So the deserializer will route the data according to its ST_ID. 
#   SER ST_ID 0 -> DES pipe X
#   SER ST_ID 1 -> DES pipe Y
#   SER ST_ID 2 -> DES pipe Z
#   SER ST_ID 3 -> DES pipe U
# Even though the routing pipes in DES are different, data will conflict on the MIPI PHY if the VC ID is the same.
#
# i2ctransfer -f -y $I2C_SWITCH w3@$SER_B_7B 0x03 0x08 0x61 # select SER's port B for pipe X
# i2ctransfer -f -y $I2C_SWITCH w3@$SER_B_7B 0x03 0x08 0x62 # select SER's port B for pipe Y
# i2ctransfer -f -y $I2C_SWITCH w3@$SER_B_7B 0x03 0x08 0x64 # select SER's port B for pipe Z
# i2ctransfer -f -y $I2C_SWITCH w3@$SER_B_7B 0x03 0x08 0x68 # select SER's port B for pipe U
# i2ctransfer -f -y $I2C_SWITCH w3@$SER_B_7B 0x03 0x08 0x6F # select SER's port B for pipe X/Y/Z/U

# i2ctransfer -f -y $I2C_SWITCH w3@$SER_B_7B 0x03 0x11 0x10 # start pipe X from SER's port B
# i2ctransfer -f -y $I2C_SWITCH w3@$SER_B_7B 0x03 0x11 0x20 # start pipe Y from SER's port B
# i2ctransfer -f -y $I2C_SWITCH w3@$SER_B_7B 0x03 0x11 0x40 # start pipe Z from SER's port B
# i2ctransfer -f -y $I2C_SWITCH w3@$SER_B_7B 0x03 0x11 0x80 # start pipe U from SER's port B
# i2ctransfer -f -y $I2C_SWITCH w3@$SER_B_7B 0x03 0x11 0xF0 # start pipe X/Y/Z/U from SER's port B

# i2ctransfer -f -y $I2C_SWITCH w3@$SER_B_7B 0x03 0x14 0x6C # enable(=bit6) datatype 0x2C route to pipe X
# i2ctransfer -f -y $I2C_SWITCH w3@$SER_B_7B 0x03 0x16 0x6C # enable(=bit6) datatype 0x2C route to pipe Y
# i2ctransfer -f -y $I2C_SWITCH w3@$SER_B_7B 0x03 0x18 0x6C # enable(=bit6) datatype 0x2C route to pipe Z
# i2ctransfer -f -y $I2C_SWITCH w3@$SER_B_7B 0x03 0x1A 0x6C # enable(=bit6) datatype 0x2C route to pipe U

# i2ctransfer -f -y $I2C_SWITCH w3@$SER_B_7B 0x00 0x02 0x13 # Enable SER Pipe X (RSVD for bit 0/1)
# i2ctransfer -f -y $I2C_SWITCH w3@$SER_B_7B 0x00 0x02 0x23 # Enable SER Pipe Y (RSVD for bit 0/1)
# i2ctransfer -f -y $I2C_SWITCH w3@$SER_B_7B 0x00 0x02 0x43 # Enable SER Pipe Z (RSVD for bit 0/1)
# i2ctransfer -f -y $I2C_SWITCH w3@$SER_B_7B 0x00 0x02 0x83 # Enable SER Pipe U (RSVD for bit 0/1)
# i2ctransfer -f -y $I2C_SWITCH w3@$SER_B_7B 0x00 0x02 0xF3 # Enable SER Pipe X/Y/Z/U (RSVD for bit 0/1)

# i2ctransfer -f -y $I2C_SWITCH w3@$SER_B_7B 0x00 0x53 0x01 # set ST_ID=1 video_x
# i2ctransfer -f -y $I2C_SWITCH w3@$SER_B_7B 0x00 0x57 0x01 # set ST_ID=1 video_y
# i2ctransfer -f -y $I2C_SWITCH w3@$SER_B_7B 0x00 0x5B 0x01 # set ST_ID=1 video_z
# i2ctransfer -f -y $I2C_SWITCH w3@$SER_B_7B 0x00 0x5F 0x01 # set ST_ID=1 video_u

# i2ctransfer -f -y $I2C_SWITCH w3@$SER_B_7B 0x02 0xD8 0x10 # GPIO_RX_ID=0x10
# i2ctransfer -f -y $I2C_SWITCH w3@$SER_B_7B 0x02 0xD6 0x04 # GPIO_RX_EN=true
i2ctransfer -f -y $I2C_SWITCH w3@$SER_B_7B 0x00 0x02 0xF3 # Enable SER Pipe X/Y/Z/U (RSVD for bit 0/1)

sleep 0.1

######################
# For Pipe X DST VC=0
######################
# i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x00 0x50 0x02 # Control ST_ID=2 from SER's pipe Z to DES's Pipe X
# # i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x00 0x50 0x00 # Control ST_ID=0 from SER to DES's Pipe X
# i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x04 0x0B 0x07 # Enable mapping SRC_0/1/2 -> DST_0/1/2
# i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x04 0x2D 0x15 # Map DST_0/1/2 to to MIPI PHY Controller 1 (Port A)
# i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x04 0x0D 0x1E # SRC_0 for VC=0 & DT=yuv422
# i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x04 0x0E 0x1E # DST_0 for VC=0 & DT=yuv422
# i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x04 0x0F 0x00 # SRC_1 for VC=0 & DT=Frame Start Code
# i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x04 0x10 0x00 # DST_1 for VC=0 & DT=Frame Start Code
# i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x04 0x11 0x01 # SRC_2 for VC=0 & DT=Frame End Code
# i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x04 0x12 0x01 # DST_2 for VC=0 & DT=Frame End Code
#
# For 0x1e sensor, VC=1
#
i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x00 0x50 0x03 # Map ST_ID=3 from SER' pipe U to DES's Pipe X
i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x04 0x0B 0x07 # Enable mapping SRC_0/1/2 -> DST_0/1/2
i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x04 0x2D 0x15 # Map DST_0/1/2 to to MIPI PHY Controller 1 (Port A)
i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x04 0x0D 0x1E # SRC_0 for VC=0 & DT=yuv422
i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x04 0x0E 0x5E # DST_0 for VC=1 & DT=yuv422
i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x04 0x0F 0x00 # SRC_1 for VC=0 & DT=Frame Start Code
i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x04 0x10 0x40 # DST_1 for VC=1 & DT=Frame Start Code
i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x04 0x11 0x01 # SRC_2 for VC=0 & DT=Frame End Code
i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x04 0x12 0x41 # DST_2 for VC=1 & DT=Frame End Code

######################
# For Pipe Y DST VC=1
######################
# i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x00 0x51 0x03 # Control ST_ID=3 from SER's pipe U to DES's Pipe Y
# # i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x00 0x51 0x01 # Control ST_ID=1 from SER to DES's Pipe Y
# i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x04 0x4B 0x07 # Enable mapping SRC_0/1/2 -> DST_0/1/2
# i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x04 0x6D 0x15 # Map DST_0/1/2 to to MIPI PHY Controller 1 (Port A)
# i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x04 0x4D 0x1E # SRC_0 for VC=0 & DT=yuv422
# i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x04 0x4E 0x5E # DST_0 for VC=1 & DT=yuv422
# i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x04 0x4F 0x00 # SRC_1 for VC=0 & DT=Frame Start Code
# i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x04 0x50 0x40 # DST_1 for VC=1 & DT=Frame Start Code
# i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x04 0x51 0x01 # SRC_2 for VC=0 & DT=Frame End Code
# i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x04 0x52 0x41 # DST_2 for VC=1 & DT=Frame End Code
#
# For 0x1d sensor, VC=0
#
i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x00 0x51 0x02 # Map ST_ID=2 from SER' pipe Z to DES's Pipe Y
i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x04 0x4B 0x07 # Enable mapping SRC_0/1/2 -> DST_0/1/2
i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x04 0x6D 0x15 # Map DST_0/1/2 to to MIPI PHY Controller 1 (Port A)
i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x04 0x4D 0x1E # SRC_0 for VC=0 & DT=yuv422
i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x04 0x4E 0x1E # DST_0 for VC=0 & DT=yuv422
i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x04 0x4F 0x00 # SRC_1 for VC=0 & DT=Frame Start Code
i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x04 0x50 0x00 # DST_1 for VC=0 & DT=Frame Start Code
i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x04 0x51 0x01 # SRC_2 for VC=0 & DT=Frame End Code
i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x04 0x52 0x01 # DST_2 for VC=0 & DT=Frame End Code

# ######################
# # For Pipe Z DST VC=0
# ######################
# i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x00 0x52 0x02 # Control ST_ID=2 from SER to DES's Pipe Z
# i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x04 0x8B 0x07 # Enable mapping SRC_0/1/2 -> DST_0/1/2
# i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x04 0xAD 0x15 # Map DST_0/1/2 to to MIPI PHY Controller 1 (Port A)
# i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x04 0x8D 0x2C # SRC_0 for VC=0 & DT=raw12
# i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x04 0x8E 0x2C # DST_0 for VC=0 & DT=raw12
# i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x04 0x8F 0x00 # SRC_1 for VC=0 & DT=Frame Start Code
# i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x04 0x90 0x00 # DST_1 for VC=0 & DT=Frame Start Code
# i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x04 0x91 0x01 # SRC_2 for VC=0 & DT=Frame End Code
# i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x04 0x92 0x01 # DST_2 for VC=0 & DT=Frame End Code

# ######################
# # For Pipe U DST VC=1
# ######################
# i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x00 0x53 0x03 # Control ST_ID=3 from SER to DES's Pipe U
# i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x04 0xCB 0x07 # Enable mapping SRC_0/1/2 -> DST_0/1/2
# i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x04 0xED 0x15 # Map DST_0/1/2 to to MIPI PHY Controller 1 (Port A)
# i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x04 0xCD 0x2C # SRC_0 for VC=0 & DT=raw12
# i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x04 0xCE 0x6C # DST_0 for VC=1 & DT=raw12
# i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x04 0xCF 0x00 # SRC_1 for VC=0 & DT=Frame Start Code
# i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x04 0xD0 0x40 # DST_1 for VC=1 & DT=Frame Start Code
# i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x04 0xD1 0x01 # SRC_2 for VC=0 & DT=Frame End Code
# i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x04 0xD2 0x41 # DST_2 for VC=1 & DT=Frame End Code

# Common DES config

# i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x04 0x4A 0xD8 # 4 lanes for Port A, +RSVD, enable VC extension
# i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x04 0x4A 0xC0 # 4 lanes for Port A (controller 1)
# i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x04 0x4A 0x40 # 2 lanes for Port A (controller 1)
i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x04 0x4A $LANE_CNT # ? lanes for Port A (controller 1)

i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x03 0x30 0x04 # ??? CSI 2x4 mode (2 groups for 4 lanes)
i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x03 0x33 0x4E # => Port A: D2 D3 D0 D1 (PHY0 D0->D2 D1->D3, PHY1 D0->D0 D1->D1)
i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x03 0x34 0xE4 # => Port B: D0 D1 D2 D3 (not used in RQX-59G)

# deskew
# i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x04 0x43 0x01 # controller 1 deskew_init
# i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x04 0x44 0x01 # controller 1 deskew_periodic

# i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x1d 0x00 0xF4 # ? not reset PLL
i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x03 0x20 0x2F # DPHY 1.5 Gbps
# i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x03 0x20 0x35 # DPHY? 2.1 Gbps
# i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x1d 0x00 0xF5 # ? reset PLL

# deskew
# i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x04 0x43 0x81 # controller 1 deskew_init
# i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x04 0x44 0x81 # controller 1 deskew_periodic


# i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x00 0x05 0x00 # disable LOCK/ERRB
# i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x02 0xB0 0x83 # GPIO_TX_EN=true; GPIO output driver disabled
# i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x02 0xB1 0x10 # GPIO_TX_ID=0x10

# Routing has already configured above
# i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x00 0x50 0x00 # Map ST_ID=0 from SER to DES's Pipe X
# i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x00 0x51 0x01 # Map ST_ID=1 from SER to DES's Pipe Y
# i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x00 0x52 0x02 # Map ST_ID=2 from SER to DES's Pipe Z
# i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x00 0x53 0x03 # Map ST_ID=3 from SER to DES's Pipe U


# # Free-run for DES
# i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x02 0xB0 0x83 # GPIO_TX_EN=true; GPIO output driver disabled
# i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x02 0xB1 0x10 # GPIO_TX_ID=0
# sleep 0.1
# i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x02 0xB0 0x03 # GPIO_TX_EN=true; GPIO output driver disabled
# i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x02 0xB1 0x06 # GPIO_TX_ID=0
# i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x02 0xB2 0x00

# # Fsync for DES
# i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x02 0xB0 0x03 # GPIO_TX_EN=true; GPIO output driver disabled
# i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x02 0xB1 0x06 # GPIO_TX_ID=6
# i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x02 0xB2 0x00

# # GPIO for SER-A
# echo "[sync]: SER-A"
i2ctransfer -f -y $I2C_SWITCH w3@$SER_A_7B 0x02 0xD6 0x00 # GPIO_OUT=false
sleep 0.1
i2ctransfer -f -y $I2C_SWITCH w3@$SER_A_7B 0x02 0xCD 0x04 # 
sleep 0.1
i2ctransfer -f -y $I2C_SWITCH w3@$SER_A_7B 0x02 0xCA 0x10 # 
sleep 0.1
i2ctransfer -f -y $I2C_SWITCH w3@$SER_A_7B 0x02 0xD6 0x10 # GPIO_OUT=true
sleep 0.1
# i2ctransfer -f -y $I2C_SWITCH w3@$SER_A_7B 0x02 0xD7 0x00 # GPIO_TX_ID
# i2ctransfer -f -y $I2C_SWITCH w3@$SER_A_7B 0x02 0xD8 0x06 # GPIO_RX_ID=6
# sleep 0.1

# # GPIO for SER-B
# echo "[sync]: SER-B"
i2ctransfer -f -y $I2C_SWITCH w3@$SER_B_7B 0x02 0xD6 0x00 # GPIO_OUT=false
sleep 0.1
i2ctransfer -f -y $I2C_SWITCH w3@$SER_B_7B 0x02 0xCD 0x04 # 
sleep 0.1
i2ctransfer -f -y $I2C_SWITCH w3@$SER_B_7B 0x02 0xCA 0x10 # 
sleep 0.1
i2ctransfer -f -y $I2C_SWITCH w3@$SER_B_7B 0x02 0xD6 0x10 # GPIO_OUT=true
sleep 0.1
# i2ctransfer -f -y $I2C_SWITCH w3@$SER_B_7B 0x02 0xD6 0x04 # GPIO_RX_EN=true
# i2ctransfer -f -y $I2C_SWITCH w3@$SER_B_7B 0x02 0xD7 0x00 # GPIO_TX_ID
# i2ctransfer -f -y $I2C_SWITCH w3@$SER_B_7B 0x02 0xD8 0x06 # GPIO_RX_ID=6
# sleep 0.1


for SENSOR in 0x1D 0x1E; do
# tier4_isx021_set_response_mode
    i2ctransfer -f -y $I2C_SWITCH w3@$SENSOR 0x8A 0x55 0x06 2>/dev/null
    sleep 0.1
    i2ctransfer -f -y $I2C_SWITCH w3@$SENSOR 0x8A 0x55 0x06 2>/dev/null
    sleep 0.1
    i2ctransfer -f -y $I2C_SWITCH w3@$SENSOR 0xBE 0xF0 0x53 2>/dev/null
    sleep 0.1
    i2ctransfer -f -y $I2C_SWITCH w3@$SENSOR 0x8A 0x55 0x02 2>/dev/null
    sleep 0.1
    i2ctransfer -f -y $I2C_SWITCH w3@$SENSOR 0x8A 0x01 0x00 2>/dev/null
    sleep 0.1
    i2ctransfer -f -y $I2C_SWITCH w3@$SENSOR 0x8A 0x55 0x06 2>/dev/null
    sleep 0.1
    
# start stream
    # tier4_isx021_set_auto_exposure
    i2ctransfer -f -y $I2C_SWITCH w3@$SENSOR 0xAB 0xC0 0x00 2>/dev/null
    i2ctransfer -f -y $I2C_SWITCH w3@$SENSOR 0xAC 0x4C 0x03 2>/dev/null
    i2ctransfer -f -y $I2C_SWITCH w3@$SENSOR 0xAC 0x4D 0x03 2>/dev/null
    i2ctransfer -f -y $I2C_SWITCH w3@$SENSOR 0xAC 0x4E 0x03 2>/dev/null
    i2ctransfer -f -y $I2C_SWITCH w3@$SENSOR 0xAC 0x40 0x00 2>/dev/null
    i2ctransfer -f -y $I2C_SWITCH w3@$SENSOR 0xAC 0x41 0x00 2>/dev/null
    i2ctransfer -f -y $I2C_SWITCH w3@$SENSOR 0xAC 0x44 0x02 2>/dev/null
    i2ctransfer -f -y $I2C_SWITCH w3@$SENSOR 0xAC 0x45 0x2B 2>/dev/null
    i2ctransfer -f -y $I2C_SWITCH w3@$SENSOR 0xAC 0x48 0xE8 2>/dev/null
    i2ctransfer -f -y $I2C_SWITCH w3@$SENSOR 0xAC 0x49 0x80 2>/dev/null
    sleep 0.1
    
    # tier4_isx021_write_mode_set_f_lock_register
    i2ctransfer -f -y $I2C_SWITCH w3@$SENSOR 0x8A 0x55 0x06 2>/dev/null
    sleep 0.1
    i2ctransfer -f -y $I2C_SWITCH w3@$SENSOR 0xBE 0xF0 0x53 2>/dev/null
    sleep 0.1
    i2ctransfer -f -y $I2C_SWITCH w3@$SENSOR 0x8A 0x55 0x02 2>/dev/null
    sleep 0.1
    
    # tier4_isx021_transit_to_startup_state
    i2ctransfer -f -y $I2C_SWITCH w3@$SENSOR 0x8A 0x01 0x00 2>/dev/null
    sleep 0.1
    
    # disable distortion correction
    i2ctransfer -f -y $I2C_SWITCH w3@$SENSOR 0xCC 0x04 0x00 2>/dev/null
    sleep 0.1
    i2ctransfer -f -y $I2C_SWITCH w3@$SENSOR 0x8A 0xB8 0x00 2>/dev/null
    sleep 0.1
    
    # tier4_isx021_setup_embedded_data
        # tier4_isx021_write_mode_set_f_lock_register
        i2ctransfer -f -y $I2C_SWITCH w3@$SENSOR 0x8A 0x55 0x06 2>/dev/null
        sleep 0.1
        i2ctransfer -f -y $I2C_SWITCH w3@$SENSOR 0xBE 0xF0 0x53 2>/dev/null
        sleep 0.1
        i2ctransfer -f -y $I2C_SWITCH w3@$SENSOR 0x8A 0x55 0x02 2>/dev/null
        sleep 0.1
        
        # tier4_isx021_transit_to_startup_state
        i2ctransfer -f -y $I2C_SWITCH w3@$SENSOR 0x8A 0x01 0x00 2>/dev/null
        sleep 0.1
    
        # DCROP_ON_APL registers
        i2ctransfer -f -y $I2C_SWITCH w3@$SENSOR 0xBF 0x04 0x00 2>/dev/null
        i2ctransfer -f -y $I2C_SWITCH w3@$SENSOR 0x8A 0xA8 0x00 2>/dev/null
        sleep 0.1
        
        # Disabling Front Embedded
        i2ctransfer -f -y $I2C_SWITCH w3@$SENSOR 0x01 0x71 0x00 2>/dev/null
        i2ctransfer -f -y $I2C_SWITCH w3@$SENSOR 0xBD 0xF8 0x00 2>/dev/null
        i2ctransfer -f -y $I2C_SWITCH w3@$SENSOR 0xBD 0xFB 0x12 2>/dev/null
        
        # Disabling Rear Embedded
        i2ctransfer -f -y $I2C_SWITCH w3@$SENSOR 0x01 0x72 0x00 2>/dev/null
        i2ctransfer -f -y $I2C_SWITCH w3@$SENSOR 0xBD 0xF9 0x0C 2>/dev/null
        i2ctransfer -f -y $I2C_SWITCH w3@$SENSOR 0xBD 0xFC 0x35 2>/dev/null
        
        # IFD_DATATYPE_VISIBLE
        i2ctransfer -f -y $I2C_SWITCH w3@$SENSOR 0xBD 0xFE 0x1E 2>/dev/null
        
        # tier4_isx021_write_mode_set_f_lock_register
        i2ctransfer -f -y $I2C_SWITCH w3@$SENSOR 0x8A 0x55 0x06 2>/dev/null
        sleep 0.1
        i2ctransfer -f -y $I2C_SWITCH w3@$SENSOR 0xBE 0xF0 0x53 2>/dev/null
        sleep 0.1
        i2ctransfer -f -y $I2C_SWITCH w3@$SENSOR 0x8A 0x55 0x02 2>/dev/null
        sleep 0.1
        
        # tier4_isx021_transit_to_streaming_state
        i2ctransfer -f -y $I2C_SWITCH w3@$SENSOR 0x8A 0x01 0x80 2>/dev/null
        sleep 0.1
    
done
        
# end

sleep 0.1

echo "[9296-bit3]: GMSL2 link locked"
val=$(i2ctransfer -f -y $I2C_SWITCH w2@$DESER_ADDR 0x00 0x13 r1)
lock=$((val & 0x08))
if [[ ! $lock -eq $((16#8)) ]]; then
	echo MAX9296 GMSL LINK is NOT locked!
else
	echo MAX9296 GMSL LINK locked
fi

echo "[9296-bit6]: Video pipeline locked"
val=$(i2ctransfer -f -y $I2C_SWITCH w2@$DESER_ADDR 0x01 0x08 r1)
lock=$((val & 0x40))
if [[ ! $lock -eq $((16#40)) ]]; then
	echo Video pipe x is NOT locked!
else
	echo video pipe x locked
fi
val=$(i2ctransfer -f -y $I2C_SWITCH w2@$DESER_ADDR 0x01 0x1A r1)
lock=$((val & 0x40))
if [[ ! $lock -eq $((16#40)) ]]; then
	echo Video pipe y is NOT locked!
else
	echo video pipe y locked
fi
val=$(i2ctransfer -f -y $I2C_SWITCH w2@$DESER_ADDR 0x01 0x2C r1)
lock=$((val & 0x40))
if [[ ! $lock -eq $((16#40)) ]]; then
	echo Video pipe z is NOT locked!
else
	echo video pipe z locked
fi
val=$(i2ctransfer -f -y $I2C_SWITCH w2@$DESER_ADDR 0x01 0x3E r1)
lock=$((val & 0x40))
if [[ ! $lock -eq $((16#40)) ]]; then
	echo Video pipe u is NOT locked!
else
	echo video pipe u locked
fi


