KERNELRELEASE                   := $(shell uname -r)
KERNEL_SRC_DIR                  := /lib/modules/$(shell uname -r)/build
TARGET_ISX021_DTS               := tier4-isx021-gmsl-device-tree-overlay-dlap212-r364
TARGET_IMX490_DTS               := tier4-imx490-gmsl-device-tree-overlay-dlap212-r364
TARGET_IMX728_DTS               := tier4-imx728-gmsl-device-tree-overlay-dlap212-r364
TARGET_ISX021_IMX490_DTS        := tier4-isx021-imx490-gmsl-device-tree-overlay-dlap212-r364
TARGET_ISX021_IMX490_IMX728_DTS := tier4-isx021-imx490-imx728-gmsl-device-tree-overlay-dlap212-r364
TARGET_IMX490_IMX728_DTS        := tier4-imx490-imx728-gmsl-device-tree-overlay-dlap212-r364
MAKE_OVERLAY_DTS_CMD            := make_overlay_dts_dlap212-orin-nx-r36.py r36.4

$(warning KERNELRELEASE  = $(KERNELRELEASE))
$(warning KERNEL_SRC_DIR = $(KERNEL_SRC_DIR))

$(warning TARGET_ISX021_DTS               = $(TARGET_ISX021_DTS))
$(warning TARGET_IMX490_DTS               = $(TARGET_IMX490_DTS))
$(warning TARGET_IMX728_DTS               = $(TARGET_IMX728_DTS))
$(warning TARGET_ISX021_IMX490_DTS        = $(TARGET_ISX021_IMX490_DTS))
$(warning TARGET_ISX021_IMX490_IMX728_DTS = $(TARGET_ISX021_IMX490_IMX728_DTS))
$(warning TARGET_IMX490_IMX728_DTS        = $(TARGET_IMX490_IMX728_DTS))

# ------------------------------------------------

.PHONY: all
all: dtbo

$(TARGET_ISX021_DTS).dts:
	python3 ./$(MAKE_OVERLAY_DTS_CMD) -8 C1
$(TARGET_IMX490_DTS).dts:
	python3 ./$(MAKE_OVERLAY_DTS_CMD) -8 C2
$(TARGET_IMX728_DTS).dts:
	python3 ./$(MAKE_OVERLAY_DTS_CMD) -8 C3
$(TARGET_ISX021_IMX490_DTS).dts:
	python3 ./$(MAKE_OVERLAY_DTS_CMD) -2 C1 -2 C2 -2 C1 -2 C2
$(TARGET_ISX021_IMX490_IMX728_DTS).dts:
	python3 ./$(MAKE_OVERLAY_DTS_CMD) -2 C1 -2 C2 -4 C3
$(TARGET_IMX490_IMX728_DTS).dts:
	python3 ./$(MAKE_OVERLAY_DTS_CMD) -4 C2 -4 C3

# Here we disable parallel build in order to rebuild the dts files step by step
.NOTPARALLEL:
dtbo: clean_dts $(TARGET_ISX021_DTS).dts $(TARGET_IMX490_DTS).dts $(TARGET_IMX728_DTS).dts  $(TARGET_ISX021_IMX490_DTS).dts $(TARGET_ISX021_IMX490_IMX728_DTS).dts $(TARGET_IMX490_IMX728_DTS).dts
	dtc -O dtb -o $(TARGET_ISX021_DTS).dtbo -@ $(TARGET_ISX021_DTS).dts
	dtc -O dtb -o $(TARGET_IMX490_DTS).dtbo -@ $(TARGET_IMX490_DTS).dts
	dtc -O dtb -o $(TARGET_IMX728_DTS).dtbo -@ $(TARGET_IMX728_DTS).dts
	dtc -O dtb -o $(TARGET_ISX021_IMX490_DTS).dtbo -@ $(TARGET_ISX021_IMX490_DTS).dts
	dtc -O dtb -o $(TARGET_ISX021_IMX490_IMX728_DTS).dtbo -@ $(TARGET_ISX021_IMX490_IMX728_DTS).dts
	dtc -O dtb -o $(TARGET_IMX490_IMX728_DTS).dtbo -@ $(TARGET_IMX490_IMX728_DTS).dts
	sudo cp -rf $(TARGET_ISX021_DTS).dtbo /boot
	sudo cp -rf $(TARGET_IMX490_DTS).dtbo /boot
	sudo cp -rf $(TARGET_IMX728_DTS).dtbo /boot
	sudo cp -rf $(TARGET_ISX021_IMX490_DTS).dtbo /boot
	sudo cp -rf $(TARGET_ISX021_IMX490_IMX728_DTS).dtbo /boot
	sudo cp -rf $(TARGET_IMX490_IMX728_DTS).dtbo /boot

clean_dts:
	# clean dts to make sure the dts file will be re-built everytime
	rm -f $(TARGET_ISX021_DTS).dts
	rm -f $(TARGET_IMX490_DTS).dts
	rm -f $(TARGET_IMX728_DTS).dts
	rm -f $(TARGET_ISX021_IMX490_DTS).dts
	rm -f $(TARGET_ISX021_IMX490_IMX728_DTS).dts
	rm -f $(TARGET_IMX490_IMX728_DTS).dts
	rm -f *.dtbo

