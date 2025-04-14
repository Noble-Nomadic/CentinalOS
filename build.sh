# Compile bootloader using NASM
nasm -f bin -o boot.bin boot.asm
# Compile kernel with GCC
i686-elf-gcc -ffreestanding -c kernel.c -o kernel.o
i686-elf-ld -Ttext 0x8000 -o kernel.bin kernel.o --oformat binary

#================ Write binary to floppy disk==================

# Create an empty floppy disk image (1.44MB)
dd if=/dev/zero of=os.img bs=512 count=2880

# Write the bootloader to the first sector (sector 0)
dd if=boot.bin of=os.img bs=512 seek=0 conv=notrunc

# Write the kernel to the second sector (sector 1)
dd if=kernel.bin of=os.img bs=512 seek=2 conv=notrunc

# Run the floppy image in qemu
qemu-system-i386 -drive format=raw,file=os.img