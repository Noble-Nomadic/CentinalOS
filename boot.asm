[org 0x7C00]      ; Boot sector loaded at 0x7C00 by BIOS

start:
    cli                     ; Disable interrupts
    cld                     ; Clear direction flag
    mov ax, 0x07C0          ; Bootloader loaded at 0x7C00
    mov ds, ax              ; DS = 0x07C0

    ; Save boot drive number
    mov [boot_drive], dl

    ; Set destination for loading the kernel
    mov ax, 0x9000          ; Segment for kernel
    mov es, ax              ; ES now points to 0x9000
    mov bx, 0               ; Offset = 0

    mov ss, ax           
    mov sp, 0xFFF0     

    ; Load kernel
    mov ah, 0x02
    mov al, 1
    mov ch, 0
    mov cl, 2
    mov dh, 0
    mov dl, [boot_drive]
    int 0x13
    
    mov [0x9000], dl  ; Store boot drive number at 0x9000

    jmp 0x9000:0000

hang:
    jmp hang

boot_drive: db 0

; Pad bootloader to 510 bytes and add boot signature
times 510 - ($ - $$) db 0
dw 0xAA55
