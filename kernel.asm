[org 0x0000]
[bits 16]

%define ENDL 0x0D, 0x0A

start:
    jmp main

;-----------------------------------------------------
; Delay for visual pacing (not timing-accurate)
;-----------------------------------------------------
delay:
    push ax
    push bx
    mov ax, 0xFFFF
.outer:
    mov bx, 0x03FF
.inner:
    nop
    dec bx
    jnz .inner
    dec ax
    jnz .outer
    pop bx
    pop ax
    ret

;=====================================================
; DRIVERS
;=====================================================
;-----------------------------------------------------
; SCREEN DRIVER
;-----------------------------------------------------

;-----------------------------------------------------
; Print string at DS:SI
;-----------------------------------------------------
print_string:
    push ax
    push si          ; Save SI register
.print_loop:
    lodsb
    test al, al
    jz .done
    mov ah, 0x0E
    int 0x10
    jmp .print_loop
.done:
    pop si           ; Restore SI register
    pop ax
    ret

;-----------------------------------------------------
; Set pixel in mode 13h (AL=color, CX=x, DX=y)
;-----------------------------------------------------
set_pixel:
    push ax
    push bx
    push cx
    push dx
    push di
    push es
    
    ; Ensure coordinates are within bounds (320x200 screen)
    cmp cx, 320
    jae .done
    cmp dx, 200
    jae .done

    ; Save color value
    mov bl, al       ; Store color in BL temporarily
    
    ; Calculate the pixel's memory address
    mov ax, 320      ; 320 pixels per row
    mul dx           ; AX = Y * 320
    add ax, cx       ; AX = X + (Y * 320)
    mov di, ax       ; DI = offset in video memory
    
    ; Set up ES to point to video memory
    mov ax, 0xA000   ; Video memory segment for mode 13h
    mov es, ax
    
    ; Set the pixel
    mov al, bl       ; Restore color from BL
    mov byte [es:di], al  ; Set the pixel at the computed position

.done:
    pop es
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret

;-----------------------------------------------------
; Clear screen (sets all pixels to black)
;-----------------------------------------------------
clear_screen:
    push ax
    push cx
    push di
    push es
    
    mov ax, 0xA000      ; Video memory segment for mode 13h
    mov es, ax
    xor di, di          ; Start at the beginning of the screen memory
    xor al, al          ; Color 0 (black)
    mov cx, 320*200     ; Number of pixels (320x200)
    rep stosb           ; Repeat STOSB instruction CX times
    
    pop es
    pop di
    pop cx
    pop ax
    ret

;-----------------------------------------------------
; KEYBOARD DRIVER
;-----------------------------------------------------
get_input:
    push ax
    push si
    mov si, input_buffer
.input_loop:
    mov ah, 0x00
    int 0x16
    cmp al, 0x0D
    je .done
    cmp al, 0x08
    je .backspace
    mov [si], al
    inc si
    mov ah, 0x0E
    int 0x10
    jmp .input_loop
.backspace:
    cmp si, input_buffer
    je .input_loop
    dec si
    mov ah, 0x0E
    mov al, 0x08
    int 0x10
    mov al, ' '
    int 0x10
    mov al, 0x08
    int 0x10
    jmp .input_loop
.done:
    mov byte [si], 0
    pop si
    pop ax
    ret

;=====================================================
; USERSPACE
;=====================================================
;-----------------------------------------------------
; cmp_input functions: Compare input with functions
;-----------------------------------------------------

; Main compare string
str_cmp:
    push ax             ; Push used data to stack

.compare_loop:
    lodsb               ; Load next character
    cmp al, [di]        ; Compare bytes

    jne .not_equal      ; jmp if not equal

    cmp al, 0           ; End of string?
    je .equal           ; Jump if string ended and chars are still equal

    inc di              ; Increment di
    jmp .compare_loop   ; Loop

.not_equal:
    pop ax              ; Return data
    clc                 ; Clear flag
    ret
.equal:
    pop ax
    stc                 ; Set carry to show success
    ret

;-----------------------------------------------------
; Help command
;-----------------------------------------------------
; Check if the input is help
cmp_str_help:
    mov si, input_buffer    ; Set registers
    mov di, cmd_help

    call str_cmp            ; Compare the strings
    jnc .not_help           ; Jump if not equal (carry flag not set)
    
    call cmd_run_help       ; Call help command
    
.not_help:
    ret

; Print out list of commands
cmd_run_help:
    mov si, msg_help_la
    call print_string

    mov si, msg_help_lb
    call print_string

    mov si, msg_help_lc
    call print_string

    mov si, msg_help_ld
    call print_string

    ret

;-----------------------------------------------------
; Clear command
;-----------------------------------------------------
; Check if input is clear command
cmp_str_clear:
    mov si, input_buffer    ; Set registers
    mov di, cmd_clear

    call str_cmp            ; Compare strings
    jnc .not_clear          ; Jump if not equal (carry flag not set)
    
    call cmd_run_clear      ; Call clear command
    
.not_clear:
    ret

; Clear the screen
cmd_run_clear:
    mov ax, 0x0003
    int 0x10
    ret

;-----------------------------------------------------
; Shutdown command
;-----------------------------------------------------
; Check if input is shutdown command
cmp_str_shutdown:
    mov si, input_buffer    ; Set registers
    mov di, cmd_shutdown

    call str_cmp            ; Compare strings
    jnc .not_shutdown       ; Jump if not equal (carry flag not set)
    
    call cmd_run_shutdown   ; Call shutdown command
    
.not_shutdown:
    ret

; Shutdown the system using APM
cmd_run_shutdown:
    ; Call BIOS interupt for shutdown
    mov ax, 0x5307
    int 0x15

    ; If APM  didnt work, just hang the systen
    hlt
    jmp hang

;-----------------------------------------------------
; MAIN SYSTEM CLI LOOP
;-----------------------------------------------------
; Get user input, compare to commands
CLI_Main:
    
    mov si, msg_ready
    call print_string

    call get_input          ; Get a line of input and store in input_buffer

    ; Compare input to each command
    call cmp_str_help
    call cmp_str_clear
    call cmp_str_shutdown

    jmp CLI_Main


;=====================================================
; DISK AND FILE MANAGER
;=====================================================




;=====================================================
; KERNEL MAIN
;=====================================================
main:
    ; Setup data segments and stack
    mov ax, cs
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0xFFF0

    ; Main startup messages
    mov si, msg_blank
    call print_string
    
    mov si, msg_bootloader
    call print_string
    call delay

    mov si, msg_kernel_found
    call print_string
    call delay

    mov si, msg_continue
    call print_string

    mov si, msg_graphic_advice
    call print_string
    call get_input

    ; Switch to graphics mode 13h
    mov ah, 0x00
    mov al, 0x13
    int 0x10

    ; Check if we are in graphics mode 13h
    mov ah, 0x0F
    int 0x10
    cmp al, 0x13      ; Mode 13h should return 0x13
    jne .mode_error   ; If not, jump to error handler

    ; Clear the screen (black)
    call clear_screen

    mov al, 4         ; Color
    mov cx, 100       ; X-coordinate
    mov dx, 100       ; Y-coordinate
    call set_pixel
    
    mov al, 2         ; Color
    mov cx, 102       ; X-coordinate
    mov dx, 100       ; Y-coordinate
    call set_pixel

    mov al, 1
    mov cx, 104
    mov dx, 100
    call set_pixel

    ; Wait for input to return to text mode
    xor ah, ah
    int 0x16

    ; Return to text mode
    mov ah, 0x00
    mov al, 0x03
    int 0x10

    mov si, msg_init_complete
    call print_string


    call CLI_Main


    jmp hang

.mode_error:
    mov si, msg_mode_error
    call print_string
    jmp hang

;-----------------------------------------------------
; Hang system
;-----------------------------------------------------
hang:
    hlt
    jmp hang

;-----------------------------------------------------
; Strings & Data Section
;-----------------------------------------------------
msg_blank: db ' ', ENDL, 0                                                                      ; Blank message for new lines
msg_bootloader: db '[ ok  ] Ignis Bootloader found', ENDL, 0                                    ; Bootloader found message
msg_kernel_found: db '[ ok  ] Kernel loaded', ENDL, 0                                           ; Proof kernel loaded
msg_continue: db '[input] Press enter to test keyboard and continue to graphics test', ENDL, 0  ; Graphic test
msg_graphic_advice: db '[  *  ] Press any key to exit the graphics test', ENDL, 0               ; Grpahic test
msg_init_complete: db '[ ok  ] System setup complete', ENDL, 0                                  ; Show system startup complete

msg_mode_error: db '[FAIL ] Graphics mode 13h not set', ENDL, 0                                 ; Error message for graphic mode switch

; USERSPACE STRINGS
; Function name strings
cmd_help: db 'help', 0
cmd_clear: db 'clear', 0
cmd_shutdown: db 'shutdown', 0


msg_ready: db '[READY]', ENDL, 0                                                                ; Use just before CLI input given (added missing comma)

msg_help_la: db ENDL, 'Centinal OS commands:', ENDL, 0                                                ; Messages for the help command
msg_help_lb: db 'help      - Display this', ENDL, 0
msg_help_lc: db 'clear     - Clear screen', ENDL, 0
msg_help_ld: db 'shutdown  - Shutdown system', ENDL, 0

input_buffer: times 100 db 0

times 4096 - ($ - $$) db 0