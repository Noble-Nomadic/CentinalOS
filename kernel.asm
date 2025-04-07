[org 0x0000]              ; Kernel starts at 0x9000 physical address

%define ENDL 0x0D, 0x0A    ; Define newline characters for printing

;-----------------------------------------
; Entry point, skip functions 
;-----------------------------------------
start:
    jmp main              ; Jump to main kernel code

;-----------------------------------------
; Adjusted Memory for Drivers:
;-----------------------------------------
; Screen driver: Segment 0xA200
; Keyboard driver: Segment 0xB200

;-----------------------------------------
; puts: Print string pointed to by DS:SI
;-----------------------------------------
puts:
    push si
    push ax
.print_loop:
    lodsb
    test al, al
    jz .done
    mov ah, 0x0E
    int 0x10
    jmp .print_loop
.done:
    pop ax
    pop si
    ret

;-----------------------------------------
; load_drivers: Load screen and keyboard drivers
;-----------------------------------------
load_drivers:
    ; Load screen driver
    mov ax, 0xA200
    mov es, ax
    mov bx, 0
    mov ah, 0x02
    mov al, 1
    mov ch, 0
    mov cl, 4               ; Screen driver starts at sector 4
    mov dh, 0
    mov dl, [boot_drive]
    int 0x13

    ; Load keyboard driver
    mov ax, 0xB200
    mov es, ax
    mov bx, 0
    mov al, 1
    mov cl, 5               ; Keyboard driver starts at sector 5
    int 0x13
    
    ret

;-----------------------------------------
; call_driver: Call a driver function dynamically
;-----------------------------------------
call_driver:
    mov ax, [bx]
    mov ds, ax
    jmp word [bx]

;-----------------------------------------
; main: Kernel entry point
;-----------------------------------------
main:
    mov ax, 0x9000
    mov ds, ax
    mov es, ax
    mov dl, [0x9000]

    mov ss, ax
    mov sp, 0xFFF0

    ; Startup messages
    mov si, msg_blank
    call puts
    mov si, msg_bootStart
    call puts
    mov si, msg_kernelStarting
    call puts

    ; Load drivers
    call load_drivers

    ; Set up function pointers
    mov word [print_string_ptr], 0xA220
    mov word [get_line_ptr], 0xB220
    mov si, msg_kernelDriversLoaded
    call puts

    ; DRIVER TEST CASES: Test drivers here

hang:
    jmp hang

;-----------------------------------------
; Data Section
;-----------------------------------------
section .data
print_string_ptr: dw 0xA220    ; Screen driver function
get_line_ptr: dw 0xB220        ; Keyboard driver function

msg_bootStart: db '[ok] Found bootloader for CentinalOS', ENDL, 0   ; Show bootloader found
msg_kernelStarting: db '[ok] Kernel starting', ENDL, 0              ; Show kernel loaded
msg_kernelDriversLoaded: db '[ok] Drivers loaded', ENDL, 0          ; Drivers loaded message
msg_blank: db ' ', ENDL, 0                                          ; Blank message for debugging

section .bss
line_buffer resb 256           ; Input buffer

boot_drive: resb 1             ; Boot drive

; Kernel padding to 1024 bytes
times 1024 - ($ - $$) db 0
