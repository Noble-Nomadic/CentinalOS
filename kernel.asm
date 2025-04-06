[org 0x0000]              ; Kernel is loaded at physical address 0x0000

%define ENDL 0x0D, 0x0A    ; Define newline characters for printing

;-----------------------------------------
; Entry Point
;-----------------------------------------
start:
    jmp main              ; Jump to main kernel code

;-----------------------------------------
; puts: Print string pointed to by DS:SI
;-----------------------------------------
puts:
    push si               ; Save SI (pointer to string)
    push ax               ; Save AX (used for printing)

.print_loop:
    lodsb                 ; Load byte from DS:SI into AL and increment SI
    test al, al           ; Check for null terminator
    jz .done              ; If null byte is found, terminate
    mov ah, 0x0E          ; BIOS teletype function to print character
    int 0x10              ; Call BIOS interrupt to print AL
    jmp .print_loop       ; Repeat for next character

.done:
    pop ax                ; Restore AX
    pop si                ; Restore SI
    ret                   ; Return from puts function

;-----------------------------------------
; load_drivers: Load screen and keyboard drivers
;-----------------------------------------
load_drivers:
    ; Load screen driver from disk
    mov ax, 0xA000        ; Screen driver memory location
    mov es, ax            ; Set ES to screen driver memory segment
    mov bx, 0             ; Offset in segment
    mov ah, 0x02          ; BIOS read sectors function
    mov al, 1             ; Read one sector
    mov ch, 0             ; Cylinder 0
    mov cl, 3             ; Sector where screen driver is stored
    mov dh, 0             ; Head 0
    mov dl, [boot_drive]  ; Boot drive number from memory
    int 0x13              ; BIOS interrupt to read sector into memory

    ; Load keyboard driver from disk
    mov ax, 0xB000        ; Keyboard driver memory location
    mov es, ax            ; Set ES to keyboard driver memory segment
    mov bx, 0             ; Offset in segment
    mov al, 1             ; Read one sector
    mov cl, 4             ; Sector where keyboard driver is stored
    int 0x13              ; BIOS interrupt to read keyboard driver

    ret                   ; Return from load_drivers

;-----------------------------------------
; call_driver: Call a driver function dynamically
;-----------------------------------------
call_driver:
    mov ax, [bx]          ; Load function pointer stored at address in BX
    mov ds, ax            ; Set DS to the driver segment
    jmp word [bx]         ; Jump to function address dynamically

;-----------------------------------------
; main: Kernel entry point
;-----------------------------------------
main:
    mov ax, 0x9000        ; Set up segment registers
    mov ds, ax
    mov es, ax
    mov dl, [0x9000]      ; Retrieve boot drive number

    mov ss, ax            ; Set SS (stack segment) to AX
    mov sp, 0xFFF0        ; Set stack pointer (SP) to high memory

    ; Print startup messages
    mov si, msg_blank
    call puts

    mov si, msg_bootStart
    call puts

    mov si, msg_kernelStarting
    call puts

    ; Load drivers
    call load_drivers

    ; Set up function pointers for drivers
    mov word [print_string_ptr], 0xA020    ; Pointer to print_string (screen driver)
    mov word [get_line_ptr], 0xB020        ; Pointer to get_line (keyboard driver)

    ; Inform the user that drivers have been loaded
    mov si, msg_kernelDriversLoaded
    call puts

    ; DRIVER TEST CASES: You can add tests for your screen and keyboard drivers here

; Pause system (infinite loop)
hang:
    jmp hang             ; Loop forever, halt the system

;-----------------------------------------
; Data Section
;-----------------------------------------
section .data

print_string_ptr: dw 0xA020    ; Pointer for screen driver's print_string function
get_line_ptr: dw 0xB020        ; Pointer for keyboard driver's get_line function

msg_bootStart: db '[ok] Found bootloader for CentinalOS', ENDL, 0
msg_kernelStarting: db '[ok] Kernel starting', ENDL, 0
msg_kernelDriversLoaded: db '[ok] Drivers loaded', ENDL, 0
msg_blank: db ' ', ENDL, 0
test_string: db 'Testing screen and keyboard drivers!', ENDL, 0

section .bss
line_buffer resb 256      ; Reserve 256 bytes for user input buffer
boot_drive: resb 1        ; Reserve 1 byte for boot drive

section .text

; Pad kernel to exactly 512 bytes (a single sector)
times 512 - ($ - $$) db 0  ; Fill remaining space to ensure 512-byte size
