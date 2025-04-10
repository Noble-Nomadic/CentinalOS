[org 0x7C00]
start:
    cli                 ; Clear interrupts
    cld                 ; Clear direction flag
    
    mov ax, 0x07C0      ; Set up data segment
    mov ds, ax
    
    mov [boot_drive], dl ; Save boot drive
    
    ; Set up stack
    mov ax, 0x9000
    mov ss, ax
    mov sp, 0xFFF0
    
    ; Load kernel - read 8 sectors starting from sector 2 into memory at ES:BX (0x9000:0)
    mov ax, 0x9000
    mov es, ax
    mov bx, 0           ; Destination offset
    
    mov ah, 0x02        ; BIOS read function
    mov al, 8           ; Read 8 sectors
    mov ch, 0           ; Cylinder 0
    mov cl, 2           ; Start from sector 2
    mov dh, 0           ; Head 0
    mov dl, [boot_drive] ; Drive number
    int 0x13            ; Call BIOS
    
    ; Pass boot drive to kernel
    mov dl, [boot_drive]
    
    ; Jump to kernel
    jmp 0x9000:0000

boot_drive: db 0

times 510 - ($ - $$) db 0
dw 0xAA55