
BUILD:=../build
SRC:=.

CFLAGS:= -m32 
CFLAGS+= -fno-builtin 							# 不使用gcc 内建函数
CFLAGS+= -fno-stack-protector 					# 不使用栈保护
CFLAGS+= -nostdinc 								# 不需要标准头文件
CFLAGS+= -fno-pic								# no position independent code
CFLAGS+= -fno-pie							    # no position independent executable
CFLAGS+= -nostdlib 								# 不需要标准库

CFLAGS:= $(strip $(CFLAGS))

INCLUDE:= -I $(SRC)/include

DEBUG:= -g

ENTRYPOINT:=0x10000


# 编译引导程序
$(BUILD)/boot/%.bin: $(SRC)/boot/%.asm
	$(shell mkdir -p $(dir $@))
	nasm -f bin $< -o $@
# 编译内核
$(BUILD)/kernel/%.o: $(SRC)/kernel/%.asm
	$(shell mkdir -p $(dir $@))
	nasm -f elf32 $(DEBUG) $< -o $@

$(BUILD)/kernel/%.o: $(SRC)/kernel/%.c
	$(shell mkdir -p $(dir $@))
	gcc $(CFLAGS) $(DEBUG) $(INCLUDE) -c $< -o $@

# 编译内核
$(BUILD)/kernel.bin: $(BUILD)/kernel/start.o \
	$(BUILD)/kernel/main.o 
	
	$(shell mkdir -p $(dir $@))
	ld -m elf_i386 -static $^ -o $@ -Ttext $(ENTRYPOINT)
# 编译系统
$(BUILD)/system.bin: $(BUILD)/kernel.bin
	objcopy -O binary $< $@

# 生成内核符号表
$(BUILD)/system.map: $(BUILD)/kernel.bin
	nm $< | sort > $@

# 生成镜像文件
$(BUILD)/master.img: $(BUILD)/boot/boot.bin \
	$(BUILD)/boot/loader.bin \
	$(BUILD)/system.bin \
	$(BUILD)/system.map

	yes | bximage -q -hd=16 -func=create -sectsize=512 -imgmode=flat $@ 
	dd if=$(BUILD)/boot/boot.bin of=$@ seek=0 bs=512 count=1 conv=notrunc
	dd if=$(BUILD)/boot/loader.bin of=$@ seek=2 bs=512 count=4 conv=notrunc
	dd if=$(BUILD)/system.bin of=$@ seek=10 bs=512 count=200 conv=notrunc

test: $(BUILD)/master.img

.PHONY:clean
clean:
	rm -rf $(BUILD)

.PHONY:bochs 
bochs:$(BUILD)/master.img
	bochs -q -f ../bochs/.bochsrc

.PHONY:bochsgdb
bochsgdb:$(BUILD)/master.img
	bochs-gdb -q -f ../bochs/bochsrc.gdb

.PHONY:qemu
qemu:$(BUILD)/master.img
	qemu-system-i386 \
	-m 32M \
	-boot c \
	-hda $< \

.PHONY:qemugdb
qemugdb:$(BUILD)/master.img
	qemu-system-i386 \
	-s -S \
	-m 32M \
	-boot c \
	-hda $< \