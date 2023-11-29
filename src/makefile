
BUILD:=../build
SRC:=.
ENTRYPOINT:=0x10000

.PHONY:bochs clean

bochs:$(BUILD)/master.img
	bochs -q

# 编译引导程序
$(BUILD)/boot/%.bin: $(SRC)/boot/%.asm
	$(shell mkdir -p $(dir $@))
	nasm -f bin $< -o $@
# 编译内核
$(BUILD)/kernel/%.o: $(SRC)/kernel/%.asm
	$(shell mkdir -p $(dir $@))
	nasm -f elf32 $< -o $@
# 编译内核
$(BUILD)/kernel.bin: $(BUILD)/kernel/start.o
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
clean:
	rm -rf $(BUILD)

test: $(BUILD)/master.img

