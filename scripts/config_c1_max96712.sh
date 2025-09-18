#!/bin/bash

# [ISX021 + MAX9295 + MAX96712]
#
# 1st max96712 -> i2c_bus=9, deser_addr=0x4b (need CAM0_RST/MAX96712_1_RST on)
# 2nd max96712 -> i2c_bus=10, deser_addr=0x4b (need CAM1_RST/MAX96712_2_RST on)
#

I2C_SWITCH=9
if [ $1 ]; then
    I2C_SWITCH=$1
fi

# Use 4 Lanes:
LANE_CNT=0xC0
# Use 2 Lanes:
# LANE_CNT=0x40

# default deserializer 7bit addr
DESER_ADDR=0x4b

# default serializer 7bit addr
SER_DEFAULT=0x62

# new serializer (proxy) addr
SER0_7B=0x31
SER1_7B=0x32
SER2_7B=0x33
SER3_7B=0x34
SER0_8B=0x62
SER1_8B=0x64
SER2_8B=0x66
SER3_8B=0x68

# new sensor (proxy) addr
SENSOR0_7B=0x2b
SENSOR1_7B=0x2c
SENSOR2_7B=0x2d
SENSOR3_7B=0x2e
SENSOR0_8B=0x56
SENSOR1_8B=0x58
SENSOR2_8B=0x5A
SENSOR3_8B=0x5C

function red_print() {
    echo -e "\e[1;31m$1\e[0m"
}

function green_print() {
    echo -e "\e[1;32m$1\e[0m"
}

echo -----------------------------------
green_print "i2c_bus=$I2C_SWITCH"
green_print "de-serializer=$DESER_ADDR"
echo -----------------------------------


# off/on power to reset cameras
if [[ $I2C_SWITCH -eq 9 ]]; then
        POWER_PROTECT=0x28
else
        POWER_PROTECT=0x29
fi
echo POWER_PROTECT_BUS=$I2C_SWITCH
echo POWER_PROTECT=$POWER_PROTECT
i2ctransfer -f -y $I2C_SWITCH w2@$POWER_PROTECT 0x01 0x00 # power down
sleep 0.1
i2ctransfer -f -y $I2C_SWITCH w2@$POWER_PROTECT 0x01 0x0F # power up
sleep 0.1

i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x04 0x0B 0x00  # MIPI CSI disable
i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x00 0x06 0xF0  # disable all 4 Links in GMSL2 mode
sleep 0.1

i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x00 0x10 0x22  # MAX9295 use 6Gbps
i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x00 0x11 0x22
green_print "DPHY Speed 6Gbps"
sleep 0.1

i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x00 0xF0 0x62  # Enable Pipe 0/1 for Link A/B stream ID 2 (ST_ID=2 also means SER's Pipe Z)
i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x00 0xF1 0xEA  # Enable Pipe 2/3 for Link C/D stream ID 2
i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x00 0xF4 0x0F  # Enable 0 - 3 Pipes

# For Pipe 0, set source and destination VC/DT for 3 data types (yuv422, FS and FE)
i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x09 0x0B 0x07  # Enable mapping SRC_0 -> DST_0, SRC_1 -> DST_1, SRC_2 -> DST_2
i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x09 0x0D 0x1E  # SRC_0 for VC=0 & DT=yuv422
i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x09 0x0E 0x1E  # DST_0 for VC=0 & DT=yuv422
i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x09 0x0F 0x00  # SRC_1 for VC=0 & DT=Frame Start Code
i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x09 0x10 0x00  # DST_1 for VC=0 & DT=Frame Start Code
i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x09 0x11 0x01  # SRC_2 for VC=0 & DT=Frame End Code
i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x09 0x12 0x01  # DST_2 for VC=0 & DT=Frame End Code
i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x09 0x2D 0x15  # Map DST_0/1/2 to to MIPI PHY Controller 1 (Port A)

# For Pipe 1, set source and destination VC/DT for 3 data types (yuv422, FS and FE)
i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x09 0x4B 0x07
i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x09 0x4D 0x1E
i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x09 0x4E 0x5E  # DST VC=1
i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x09 0x4F 0x00
i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x09 0x50 0x40  # DST VC=1
i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x09 0x51 0x01
i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x09 0x52 0x41  # DST VC=1
i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x09 0x6D 0x15

# For Pipe 2, set source and destination VC/DT for 3 data types (yuv422, FS and FE)
i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x09 0x8B 0x07
i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x09 0x8D 0x1E
i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x09 0x8E 0x9E  # DST VC=2
i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x09 0x8F 0x00
i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x09 0x90 0x80  # DST VC=2
i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x09 0x91 0x01
i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x09 0x92 0x81  # DST VC=2
i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x09 0xAD 0x15

# For Pipe 3, set source and destination VC/DT for 3 data types (yuv422, FS and FE)
i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x09 0xCB 0x07
i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x09 0xCD 0x1E
i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x09 0xCE 0xDE  # DST VC=3
i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x09 0xCF 0x00
i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x09 0xD0 0xC0  # DST VC=3
i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x09 0xD1 0x01
i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x09 0xD2 0xC1  # DST VC=3
i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x09 0xED 0x15

sleep 0.1

i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x08 0xA0 0x04  # default MIPI PHY 2x4 lanes

# # Here we use both Port A and Port B
# i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x08 0xA2 0xF0  # Eable MIPI PHY 0/1/2/3 (Port A and Port B)
# i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x08 0xA3 0xE4  # Map PHY 0/1 (Port A) to data lane 0/1/2/3
# i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x08 0xA4 0xE4  # Map PHY 2/3 (Port B) to data lane 0/1/2/3
# i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x09 0x0A 0xC0  # default 4 data lane cnt for PHY 0
# i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x09 0x4A 0xC0  # default 4 data lane cnt for PHY 1
# i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x09 0x8A 0xC0  # default 4 data lane cnt for PHY 2
# i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x09 0xCA 0xC0  # default 4 data lane cnt for PHY 3

# Below we use Port A only
i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x08 0xA2 0x30  # Eable MIPI PHY 0/1 (Port A only)
i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x08 0xA3 0xE4  # Map PHY 0/1 (Port A) to data lane 0/1/2/3
# i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x09 0x0A 0xC0  # default 4 data lane cnt for PHY 0
# i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x09 0x4A 0xC0  # default 4 data lane cnt for PHY 1
# i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x09 0x0A 0x40  # default 2 data lane cnt for PHY 0
# i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x09 0x4A 0x40  # default 2 data lane cnt for PHY 1
i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x09 0x0A $LANE_CNT  # default ? data lane cnt for PHY 0
i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x09 0x4A $LANE_CNT  # default ? data lane cnt for PHY 1

# DPHY[connect with orin]
i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x04 0x15 0x2F
i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x04 0x18 0x2F
i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x04 0x1B 0x2F
i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x04 0x1E 0x2F
green_print "MIPI Speed 1.5Gbps"
# i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x04 0x15 0x38
# i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x04 0x18 0x38
# i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x04 0x1B 0x38
# i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x04 0x1E 0x38
# green_print "MIPI Speed 2.4Gbps"

sleep 0.1

init_serializer() {
    local SER_DEFAULT=$1
    local SER_8B=$2
    local SENSOR_ALIAS=$3
    echo "init serializer new 8bit addr=$SER_8B"

    i2ctransfer -f -y $I2C_SWITCH w3@$SER_DEFAULT 0x00 0x10 0x21
    sleep 0.1 # wait for reset

# Tier4 
    i2ctransfer -f -y $I2C_SWITCH w3@$SER_DEFAULT 0x00 0x03 0x03 # Set RCLKOUT soruce to the reference PLL clock
    i2ctransfer -f -y $I2C_SWITCH w3@$SER_DEFAULT 0x03 0xF0 0x5A # PLL setting & Reset PLL
    sleep 0.1
#

    # i2ctransfer -f -y $I2C_SWITCH w3@$SER_DEFAULT 0x00 0x6B 0x10 # ???
    # i2ctransfer -f -y $I2C_SWITCH w3@$SER_DEFAULT 0x00 0x73 0x11 # ???
    # i2ctransfer -f -y $I2C_SWITCH w3@$SER_DEFAULT 0x00 0x7B 0x31 # TX_SRC_ID=1
    # i2ctransfer -f -y $I2C_SWITCH w3@$SER_DEFAULT 0x00 0x83 0x31 # TX_SRC_ID=1
    # i2ctransfer -f -y $I2C_SWITCH w3@$SER_DEFAULT 0x00 0x93 0x31 # TX_SRC_ID=1
    # i2ctransfer -f -y $I2C_SWITCH w3@$SER_DEFAULT 0x00 0x9B 0x31
    # i2ctransfer -f -y $I2C_SWITCH w3@$SER_DEFAULT 0x00 0xA3 0x31 # TX_SRC_ID=1
    # i2ctransfer -f -y $I2C_SWITCH w3@$SER_DEFAULT 0x00 0xAB 0x31 # TX_SRC_ID=1
    # i2ctransfer -f -y $I2C_SWITCH w3@$SER_DEFAULT 0x00 0x8B 0x00 # ???

    # set alias sensor addr e.g. 0x2B
    i2ctransfer -f -y $I2C_SWITCH w3@$SER_DEFAULT 0x00 0x44 $SENSOR_ALIAS # alias sensor address on host (0x2b)
    i2ctransfer -f -y $I2C_SWITCH w3@$SER_DEFAULT 0x00 0x45 0x20 # default sensor address (0x10)
    
    # # GPIO0 for SER-A
    i2ctransfer -f -y $I2C_SWITCH w3@$SER_DEFAULT 0x02 0xBE 0x90 # SER GPIO output=1
    i2ctransfer -f -y $I2C_SWITCH w3@$SER_DEFAULT 0x02 0xBF 0x60 # SER GPIO_TX_ID=0
    i2ctransfer -f -y $I2C_SWITCH w3@$SER_DEFAULT 0x03 0xF1 0x89 # RCLK output pin select
# Tier4
    i2ctransfer -f -y $I2C_SWITCH w3@$SER_DEFAULT 0x03 0xF0 0x59 # PLL setting & Enable PLL
#

    i2ctransfer -f -y $I2C_SWITCH w3@$SER_DEFAULT 0x03 0x30 0x00 # [default: 0x00] disable VC mapping, 1x4 lane (one port with 4 lanes)
    i2ctransfer -f -y $I2C_SWITCH w3@$SER_DEFAULT 0x03 0x31 0x30 # select controller 1 (SER Port B) for 4 lanes
    i2ctransfer -f -y $I2C_SWITCH w3@$SER_DEFAULT 0x03 0x32 0xE0 # [default: 0xE0] PHY1 lane0->2, lane1->3
    i2ctransfer -f -y $I2C_SWITCH w3@$SER_DEFAULT 0x03 0x33 0x04 # [default: 0x04] PHY2 lane0->0, lane1->1
    
    # data type routing for SER
    # i2ctransfer -f -y $I2C_SWITCH w3@$SER_DEFAULT 0x03 0x14 0xF0 # enable(=bit6) datatype ? route to pipe X
    i2ctransfer -f -y $I2C_SWITCH w3@$SER_DEFAULT 0x03 0x18 0x5E # enable(=bit6) datatype 0x1E route to pipe Z
    # i2ctransfer -f -y $I2C_SWITCH w3@$SER_DEFAULT 0x03 0x11 0xF0 # start pipe X/Y/Z/U from SER's port B
    i2ctransfer -f -y $I2C_SWITCH w3@$SER_DEFAULT 0x03 0x11 0x40 # start pipe Z from SER's port B
    # i2ctransfer -f -y $I2C_SWITCH w3@$SER_DEFAULT 0x03 0x08 0x65 # select SER's port B for pipe X/Z
    i2ctransfer -f -y $I2C_SWITCH w3@$SER_DEFAULT 0x03 0x08 0x64 # select SER's port B for pipe Z

    # i2ctransfer -f -y $I2C_SWITCH w3@$SER_DEFAULT 0x02 0xD8 0x10 # GPIO_RX_ID=0x10
    # i2ctransfer -f -y $I2C_SWITCH w3@$SER_DEFAULT 0x02 0xD6 0x04 # GPIO_RX_EN=true
    # i2ctransfer -f -y $I2C_SWITCH w3@$SER_DEFAULT 0x00 0x02 0xF3 # Enable SER Pipe X/Y/Z/U (RSVD for bit 0/1)
    i2ctransfer -f -y $I2C_SWITCH w3@$SER_DEFAULT 0x00 0x02 0x43 # Enable SER Pipe Z (RSVD for bit 0/1)
    sleep 0.1
    
# Tier4
    i2ctransfer -f -y $I2C_SWITCH w3@$SER_DEFAULT 0x02 0xD6 0x00 # GPIO_OUT=false
    sleep 0.1
    i2ctransfer -f -y $I2C_SWITCH w3@$SER_DEFAULT 0x02 0xCD 0x04 # 
    sleep 0.1
    i2ctransfer -f -y $I2C_SWITCH w3@$SER_DEFAULT 0x02 0xCA 0x10 # 
    sleep 0.1
    i2ctransfer -f -y $I2C_SWITCH w3@$SER_DEFAULT 0x02 0xD6 0x10 # GPIO_OUT=true
    sleep 0.1
#
    
    i2ctransfer -f -y $I2C_SWITCH w3@$SER_DEFAULT 0x00 0x00 $SER_8B
}

echo "[sensors]: serializer-a"
i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x00 0x06 0xF1 # Enable only LinkA
sleep 0.2
init_serializer $SER_DEFAULT $SER0_8B $SENSOR0_8B # Init serializer and sensor A

echo "[sensors]: serializer-b"
i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x00 0x06 0xF2 # Enable only LinkB
sleep 0.2
init_serializer $SER_DEFAULT $SER1_8B $SENSOR1_8B # Init serializer and sensor B

echo "[sensors]: serializer-c"
i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x00 0x06 0xF4 # Enable only LinkC
sleep 0.2
init_serializer $SER_DEFAULT $SER2_8B $SENSOR2_8B # Init serializer and sensor C

echo "[sensors]: serializer-d"
i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x00 0x06 0xF8 # Enable only LinkD
sleep 0.2
init_serializer $SER_DEFAULT $SER3_8B $SENSOR3_8B # Init serializer and sensor D


sleep 0.2
# i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x00 0x06 0x3F # Enable all A/B Links in GMSL2 mode
i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x00 0x06 0xFF # Enable all 4 Links in GMSL2 mode
i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x00 0x18 0x0F # One-shot reset
sleep 0.1

i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x04 0x0B 0x02 # Enable MIPI CSI
i2ctransfer -f -y $I2C_SWITCH w3@$DESER_ADDR 0x08 0xA0 0x84 # Force all MIPI clocks running

sleep 0.2


# AR0233 start stream for sensors
for SENSOR in $SENSOR0_7B $SENSOR1_7B $SENSOR2_7B $SENSOR3_7B; do
    echo ""[setup stream]: sensor-$SENSOR
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

echo "[96712-bit3]: GMSL2 link locked"
val=$(i2ctransfer -f -y $I2C_SWITCH w2@$DESER_ADDR 0x00 0x1A r1)
echo LINK A: $val
lock=$((val & 0x08))
if [[ ! $lock -eq $((16#8)) ]]; then
	echo LINK A is NOT locked!
else
	echo LINK A locked
fi
val=$(i2ctransfer -f -y $I2C_SWITCH w2@$DESER_ADDR 0x00 0x0A r1)
echo LINK B: $val
lock=$((val & 0x08))
if [[ ! $lock -eq $((16#8)) ]]; then
	echo LINK B is NOT locked!
else
	echo LINK B locked
fi
val=$(i2ctransfer -f -y $I2C_SWITCH w2@$DESER_ADDR 0x00 0x0B r1)
echo LINK C: $val
lock=$((val & 0x08))
if [[ ! $lock -eq $((16#8)) ]]; then
	echo LINK C is NOT locked!
else
	echo LINK C locked
fi
val=$(i2ctransfer -f -y $I2C_SWITCH w2@$DESER_ADDR 0x00 0x0C r1)
echo LINK D: $val
lock=$((val & 0x08))
if [[ ! $lock -eq $((16#8)) ]]; then
	echo LINK D is NOT locked!
else
	echo LINK D locked
fi

echo "[96712-bit6]: Video pipeline locked"
val=$(i2ctransfer -f -y $I2C_SWITCH w2@$DESER_ADDR 0x01 0x08 r1)
echo Video pipe: $val
lock=$((val & 0x40))
if [[ ! $lock -eq $((16#40)) ]]; then
	echo Video pipe 0 is NOT locked!
else
	echo video pipe 0 locked
fi
val=$(i2ctransfer -f -y $I2C_SWITCH w2@$DESER_ADDR 0x01 0x1A r1)
echo Video pipe: $val
lock=$((val & 0x40))
if [[ ! $lock -eq $((16#40)) ]]; then
	echo Video pipe 1 is NOT locked!
else
	echo video pipe 1 locked
fi
val=$(i2ctransfer -f -y $I2C_SWITCH w2@$DESER_ADDR 0x01 0x2C r1)
echo Video pipe: $val
lock=$((val & 0x40))
if [[ ! $lock -eq $((16#40)) ]]; then
	echo Video pipe 2 is NOT locked!
else
	echo video pipe 2 locked
fi
val=$(i2ctransfer -f -y $I2C_SWITCH w2@$DESER_ADDR 0x01 0x3E r1)
echo Video pipe: $val
lock=$((val & 0x40))
if [[ ! $lock -eq $((16#40)) ]]; then
	echo Video pipe 3 is NOT locked!
else
	echo video pipe 3 locked
fi

