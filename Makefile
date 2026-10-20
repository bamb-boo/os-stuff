build:
	nasm -f bin code.asm -o code.bin

run: build
	qemu-system-i386 -drive format=raw,file=code.bin
    