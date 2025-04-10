nasm -f bin boot.asm -o boot.bin
nasm -f bin kernel.asm -o kernel.bin
rm os.img
dd if=/dev/zero of=os.img bs=512 count=2880  # Create an empty floppy image (1.44MB)
dd if=boot.bin of=os.img bs=512 count=1      # Write bootloader to sector 1
dd if=kernel.bin of=os.img bs=512 seek=1     # Write kernel starting at sector 2

qemu-system-i386 -drive format=raw,file=os.img
