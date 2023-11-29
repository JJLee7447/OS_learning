
BUILD:=../build
SRC:=.


.PHONY:bochs clean

bochs:$(BUILD)/master.img
	bochs -q


$(BUILD)/boot/%.bin:$(SRC)/boot/%.asm
	$(shell mkdir -p $(dir $@))
	nasm -f bin $< -o $@
clean:
	rm -rf $(BUILD)

$(BUILD)/master.img: $(BUILD)/boot/boot.bin \
	$(BUILD)/boot/loader.bin

	yes | bximage -q -hd=16 -func=create -sectsize=512 -imgmode=flat $@ 
	dd if=$(BUILD)/boot/boot.bin of=$@ seek=0 bs=512 count=1 conv=notrunc
	dd if=$(BUILD)/boot/loader.bin of=$@ seek=2 bs=512 count=4 conv=notrunc


test: $(BUILD)/master.img

