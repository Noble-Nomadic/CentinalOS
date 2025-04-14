[org 0x7c00]   ; The bootloader's code starts at 0x7C00
bits 16

; Bootloader entry point
jmp start

start:
    ; Set up registers for reading the kernel from disk
    mov ah, 0x02      ; BIOS read sectors function
    mov al, 0x01      ; Number of sectors to read (1 sector)
    mov ch, 0         ; Cylinder 0
    mov dh, 0         ; Head 0
    mov dl, 0x80      ; Drive 0 (Floppy)
    mov bx, 0x8000    ; Destination memory address (0x8000 is a safe address)

    ; Read the kernel (sector 1) into memory at 0x8000
    int 0x13          ; BIOS interrupt for disk I/O
    
    ; After loading the kernel, jump to it
    jmp 0x8000        ; Jump to the kernel's entry point

times 510-($-$$) db 0  ; Fill the rest with 0s
dw 0xAA55              ; Bootloader signature (required for BIOS to recognize it)
