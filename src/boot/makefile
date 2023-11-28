.PHONY:bochs clean
bochs:master.img
	bochs -q
clean:
	rm *.bin *.img *.ini *.lock

master.img:boot.bin loader.bin
	yes | bximage -q -hd=16 -func=create -sectsize=512 -imgmode=flat master.img 
	dd if=boot.bin of=master.img seek=0 bs=512 count=1 conv=notrunc
	dd if=loader.bin of=master.img seek=2 bs=512 count=4 conv=notrunc

boot.bin:boot.asm
	nasm -f bin boot.asm -o boot.bin 
loader.bin:loader.asm
	nasm -f bin loader.asm -o loader.bin 
