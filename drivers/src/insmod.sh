#!/bin/bash

sudo insmod ./tier4-fpga.ko
sleep 0.5
sudo insmod ./tier4-max9296.ko
sleep 0.5
sudo insmod ./tier4-max9295.ko
sleep 0.5
sudo insmod ./tier4-isx021.ko
