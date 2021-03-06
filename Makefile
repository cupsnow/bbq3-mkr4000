#------------------------------------
#
-include site.mk
include $(PROJDIR:%=%/)proj.mk

ARDUINO_PLATFORM_PATH?=/home/joelai/.arduino15/packages/arduino
mkr4000_ARDUINO_PATH?=$(ARDUINO_PLATFORM_PATH)/hardware/samd_beta/1.6.25

CMSIS_PATH?=$(PROJDIR)/CMSIS_5

BOSSAC=$(PROJDIR)/bossa/bin/bossac --offset=0x2000 --verify --info \
  --port=$(notdir $(wildcard /dev/ttyACM0 /dev/ttyACM1))
ARMGCC=/home/joelai/07_sw/gcc-arm-none-eabi/bin/arm-none-eabi-gcc

ARM_TOOLCHAIN_PATH=$(abspath $(dir $(ARMGCC))..)
ARM_CROSS_COMPILE=$(patsubst %gcc,%,$(notdir $(ARMGCC)))

CROSS_COMPILE=$(ARM_CROSS_COMPILE)

EXTRA_PATH+=$(ARM_TOOLCHAIN_PATH:%=%/bin)

export PATH:=$(call ENVPATH,$(EXTRA_PATH))

$(info Makefile ... PATH: $(PATH)) 

#------------------------------------
#
mkr4000_CPPFLAGS+=-ffunction-sections -fdata-sections -mthumb -mcpu=cortex-m0plus \
  -Os -flto -D__SAMD21G18A__
mkr4000_CFLAGS+=-std=gnu99
mkr4000_LDFLAGS+=-Wl,--cref,--gc-sections --specs=nano.specs

#------------------------------------
#
mkr4000_ARDUINO_CPPFLAGS+= \
  -I$(ARDUINO_PLATFORM_PATH)/tools/CMSIS/4.5.0/CMSIS/Include \
  -I$(ARDUINO_PLATFORM_PATH)/tools/CMSIS-Atmel/1.2.0/CMSIS/Device/ATMEL \
  -DBOARD_ID_arduino_mkrvidor4000 -DSAM_BA_USBCDC_ONLY $(mkr4000_CPPFLAGS)

mkr4000_ARDUINO_LDFLAGS+=$(mkr4000_LDFLAGS) --specs=nosys.specs

#------------------------------------
#
test3_APP=$(patsubst $(PWD)/%,%,$(BUILDDIR)/mkr4000/test3)
test3_CPPFLAGS+=-I$(PROJDIR)/moss/inc -I$(PROJDIR)/moss/openbsd \
  -I$(PROJDIR)/cmsis-mkr4000/include -I$(CMSIS_PATH)/CMSIS/Core/Include \
  $(mkr4000_CPPFLAGS) -g
test3_CFLAGS+=$(mkr4000_CFLAGS)
test3_LDFLAGS+=$(mkr4000_LDFLAGS) --specs=nosys.specs -Wl,-Map=$@.map

$(eval $(call BUILD2,test3,mkr4000,$(patsubst $(PWD)/%,%, \
  $(wildcard $(PROJDIR)/moss/moss.c $(PROJDIR)/moss/moss_m0.c \
    $(addprefix $(PROJDIR)/cmsis-mkr4000/,*.c *.ld) \
    $(addprefix $(PROJDIR)/test/,test3.cpp)))))

test3_prog:
	$(BOSSAC) --erase --write --reset $(test3_APP).bin

test3:
	$(SIZE) --format=sysv -x $(test3_APP)
	$(OBJDUMP) -S $(test3_APP) > $(test3_APP).objdump
	$(OBJCOPY) -O binary $(test3_APP) $(test3_APP).bin

#------------------------------------
#
test2_APP=$(patsubst $(PWD)/%,%,$(BUILDDIR)/mkr4000/test2)
test2_CPPFLAGS+=$(mkr4000_ARDUINO_CPPFLAGS) \
  -I$(PROJDIR)/moss/inc -I$(PROJDIR)/moss/openbsd
test2_CFLAGS+=$(mkr4000_CFLAGS)
test2_LDFLAGS+=$(mkr4000_ARDUINO_LDFLAGS) -Wl,-Map=$@.map

$(eval $(call BUILD2,test2,mkr4000,$(patsubst $(PWD)/%,%, \
  $(PROJDIR)/moss/moss.c $(PROJDIR)/moss/moss_m0.c \
  $(PROJDIR)/test/test2.cpp $(PROJDIR)/test/test2_startup.S \
  $(mkr4000_ARDUINO_PATH)/variants/mkrvidor4000/linker_scripts/gcc/flash_with_bootloader.ld)))

test2_prog:
	$(BOSSAC) --erase --write --reset $(test2_APP).bin

test2:
	$(SIZE) --format=sysv -x $(test2_APP)
	$(OBJDUMP) -S $(test2_APP) > $(test2_APP).objdump
	$(OBJCOPY) -O binary $(test2_APP) $(test2_APP).bin

#------------------------------------
#
test1-mkr4000_APP=$(patsubst $(PWD)/%,%,$(BUILDDIR)/mkr4000/test1)
test1-mkr4000_CPPFLAGS+=-I$(PROJDIR)/moss/inc -I$(PROJDIR)/moss/openbsd \
  $(mkr4000_CPPFLAGS) -g
test1-mkr4000_CFLAGS+=$(mkr4000_CFLAGS)
test1-mkr4000_LDFLAGS+=$(mkr4000_LDFLAGS) --specs=nosys.specs -Wl,-Map=$@.map
$(eval $(call BUILD2,test1-mkr4000,mkr4000,$(patsubst $(PWD)/%,%, \
  $(PROJDIR)/moss/moss.c $(PROJDIR)/moss/moss_m0.c \
  $(PROJDIR)/test/test1.cpp)))

test1-host_APP=$(patsubst $(PWD)/%,%,$(BUILDDIR)/host/test1)
test1-host_CPPFLAGS+=-ffunction-sections -fdata-sections \
  -g -I$(PROJDIR)/moss/inc -I$(PROJDIR)/moss/openbsd
test1-host test1-host%: CROSS_COMPILE= 
$(eval $(call BUILD2,test1-host,host,$(patsubst $(PWD)/%,%, \
  $(PROJDIR)/moss/moss.c $(PROJDIR)/moss/moss_pc.c \
  $(PROJDIR)/test/test1.cpp)))


#------------------------------------
#
bootloader_APP=$(patsubst $(PWD)/%,%,$(BUILDDIR)/mkr4000/bootloader)
bootloader_CPPFLAGS+=$(mkr4000_ARDUINO_CPPFLAGS)
bootloader_CFLAGS+=$(mkr4000_CFLAGS)
bootloader_LDFLAGS+=$(mkr4000_ARDUINO_LDFLAGS) -Wl,-Map=$@.map

$(eval $(call BUILD2,bootloader,mkr4000,$(patsubst $(PWD)/%,%, \
  $(addprefix $(mkr4000_ARDUINO_PATH)/bootloaders/zero/, \
    board_driver_i2c.c board_driver_led.c board_driver_pmic.c board_driver_jtag.c \
    board_driver_serial.c board_driver_usb.c board_init.c board_startup.c \
    main.c sam_ba_usb.c sam_ba_cdc.c sam_ba_monitor.c sam_ba_serial.c \
    bootloader_samd21x18.ld))))

bootloader: bootloader_post

bootloader_post: $(bootloader_APP)
	$(SIZE) --format=sysv -x $<
	$(OBJDUMP) -S $< > $(bootloader_APP).objdump
	$(OBJCOPY) -O binary $< $(bootloader_APP).bin

#------------------------------------
#
bossa_download: ;
	git clone https://github.com/shumatech/BOSSA.git $(PROJDIR)/bossa

bossa: bossa_ ;
bossa%:
	[ -d $(PROJDIR)/bossa ] || $(MAKE) bossa_download
	$(MAKE) -C $(PROJDIR)/bossa Q= $(patsubst _%,%,$(@:bossa%=%))

.PHONY: bossa bossa%

#------------------------------------
#
$(eval $(call BUILD2_OBJGEN,host))
$(eval $(call BUILD2_OBJGEN,mkr4000))

#------------------------------------
all: ;

#------------------------------------
#------------------------------------
#------------------------------------
#------------------------------------
#------------------------------------
