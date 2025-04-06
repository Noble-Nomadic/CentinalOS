[org 0x0000]              ; Kernel is loaded at physical address 0x0000

%define ENDL 0x0D, 0x0A

;-----------------------------------------
; Entry Point
;-----------------------------------------
start:
    jmp main              ; Jump to main code

;-----------------------------------------
; puts: Print string pointed to by DS:SI
;-----------------------------------------
puts:
    push si              ; Save SI (pointer to string)
    push ax              ; Save AX (will be used for printing)
.print_loop:
    lodsb                ; Load byte from DS:SI into AL and increment SI
    test al, al          ; Check for null terminator
    jz .done             ; Stop if null is found
    mov ah, 0x0E         ; BIOS teletype function
    int 0x10             ; Print AL
    jmp .print_loop      ; Continue loop
.done:
    pop ax               ; Restore AX
    pop si               ; Restore SI
    ret

;-----------------------------------------
; load_drivers: Load the screen & keyboard drivers
;-----------------------------------------
load_drivers:
    mov ax, 0xA000          ; Screen driver memory location
    mov es, ax              ; Set segment where data is read
    mov bx, 0               ; Offset in segment

    mov ah, 0x02            ; BIOS read sectors function
    mov al, 1               ; Read one sector
    mov ch, 0               ; Cylinder 0
    mov cl, 3               ; Sector where screen driver is stored
    mov dh, 0               ; Head 0
    mov dl, [boot_drive]    ; Drive number
    int 0x13                ; Read driver into memory

    mov ax, 0xB000          ; Keyboard driver memory location
    mov es, ax
    mov bx, 0

    mov al, 1               ; Read one sector
    mov cl, 4               ; Sector where keyboard driver is stored
    int 0x13                ; Read keyboard driver

    ret

;-----------------------------------------
; call_driver: Call a driver function dynamically
;-----------------------------------------
call_driver:
    mov ax, [bx]  ; Load function pointer stored at address in BX
    mov ds, ax    ; Set segment to driver memory
    jmp word [bx] ; Jump to function dynamically

;-----------------------------------------
; main: Kernel entry point
;-----------------------------------------
main:
    mov ax, 0x9000
    mov ds, ax
    mov es, ax
    mov dl, [0x9000]  ; Retrieve boot drive number

    mov ss, ax
    mov sp, 0xFFF0

    ; Print startup messages
    mov si, msg_blank
    call puts

    mov si, msg_bootStart
    call puts

    mov si, msg_kernelStarting
    call puts

    ; Load drivers
    call load_drivers

    ; Setup function pointers
    mov word [print_char_ptr], 0xA010   ; Address for screen driver function
    mov word [print_string_ptr], 0xA020
    mov word [get_key_ptr], 0xB010
    mov word [get_line_ptr], 0xB020

    mov si, msg_kernelDriversLoaded
    call puts
    

; Pause system
hang:
    jmp hang             ; Loop forever

;-----------------------------------------
; Data Section
;-----------------------------------------
print_char_ptr: dw 0x0000
get_key_ptr: dw 0x0000

msg_bootStart: db '[ok] Found bootloader for CentinalOS', ENDL, 0
msg_kernelStarting: db '[ok] Kernel starting', ENDL, 0
msg_kernelDriversLoaded: db '[ok] Drivers loaded', ENDL, 0

msg_blank: db ' ', ENDL, 0

print_string_ptr: dw 0x0000    ; Pointer for screen driver's print_string
get_line_ptr: dw 0x0000        ; Pointer for keyboard driver's get_line

boot_drive: db 0

; Pad kernel to exactly 512 bytes (a single sector)
times 512 - ($ - $$) db 0
