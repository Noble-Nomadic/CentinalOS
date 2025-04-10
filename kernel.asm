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


;-----------------------------------------------------
; DISK DRIVER
;-----------------------------------------------------
; 500 Sectors of the floppy disk are padded with 0s
; and are reserved for files. Data can be directly
; read and wrote by user commands. Instead of using
; directories and filenames, each file is assigned an
; ID of 0-499

;-----------------------------------------------------
; Print buffer content (Only printable ASCII characters)
;-----------------------------------------------------
print_buffer:
    ; Print each byte in the buffer
    mov cx, 512              ; We want to print 512 bytes (size of a sector)
    lea si, [buffer]         ; Load address of the buffer into SI

.print_next_byte:
    mov al, [si]             ; Load current byte from buffer into AL
    cmp al, 0                ; If the byte is zero, stop (null-terminated string check)
    je .done
    cmp al, 32               ; Check if the byte is a printable ASCII character (space = 32)
    jl .skip_print           ; If less than 32, it's not printable, skip it
    cmp al, 126              ; Check if the byte is within the printable ASCII range (tilde = 126)
    jg .skip_print           ; If greater than 126, skip it
    call print_char          ; Print the character (call print_char function)

.skip_print:
    inc si                   ; Move to the next byte
    loop .print_next_byte    ; Loop for 512 bytes (sector size)

.done:
    ret

;-----------------------------------------------------
; Print character function (used by print_buffer)
;-----------------------------------------------------
print_char:
    mov ah, 0x0E             ; Teletype output function
    mov bh, 0                ; Page number
    mov bl, 0x07             ; Text attribute (light gray on black)
    int 0x10                 ; Call BIOS interrupt to print the character
    ret



; ID to CHS converter
sectorID_to_CHS:
    push ax                 ; Push used data to stack
    push dx
    push cx

    mov cx, 18              ; Sectors per track
    xor dx, dx
    div cx                  ; AX / 18 -> AX = track, DX = sector offset 0-17

    mov cl, dl              ; Sector number
    inc cl

    mov dx, 0
    mov cx, 2
    div cx                  ; AX / 2 -> AX = cylinder, DX = head

    mov ch, al              ; Cylinder
    mov dh, dl              ; Head

    pop cx
    pop dx
    pop ax

    ret

;-----------------------------------------------------
; Read a sector from the disk (e.g., first sector)
;-----------------------------------------------------
read_sector:
    mov ah, 0x02          ; Read sector function
    mov al, 0x01          ; Number of sectors to read (1 sector)
    mov ch, 0x00          ; Cylinder 0
    mov cl, 0x01          ; Sector 1
    mov dh, 0x00          ; Head 0
    mov dl, 0x80          ; Drive 0 (floppy)
    lea bx, [buffer]      ; Buffer to store the data
    int 0x13              ; Call BIOS disk interrupt

    jc  .disk_error       ; If carry flag is set, read failed
    ret

.disk_error:
    mov si, err_disk_op
    call print_string
    jmp hang


;-----------------------------------------------------
; Write a sector to the disk
;-----------------------------------------------------
write_sector:
    mov ah, 0x03          ; Write sector function
    mov al, 0x01          ; Number of sectors to write (1 sector)
    mov ch, 0x00          ; Cylinder 0
    mov cl, 0x01          ; Sector 1
    mov dh, 0x00          ; Head 0
    mov dl, 0x80          ; Drive 0 (floppy)
    lea bx, [buffer]      ; Buffer containing data to write
    int 0x13              ; Call BIOS disk interrupt

    jc  .disk_error       ; If carry flag is set, write failed
    ret

.disk_error:
    mov si, err_disk_op
    call print_string
    jmp hang




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

    ; Set the cmd_success flag to 1 to show success of command
    mov byte [cmd_success], 1

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

    ; Set the cmd_success flag to 1 to show success of command
    mov byte [cmd_success], 1

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

    ; Set the cmd_success flag to 1 to show success of command
    mov byte [cmd_success], 1

    ; Call BIOS interupt for shutdown
    ;mov ax, 0x5307
    ;int 0x15

    ; If APM  didnt work, just hang the systen
    jmp hang

;-----------------------------------------------------
; MAIN SYSTEM CLI LOOP
;-----------------------------------------------------
; Get user input, compare to commands
CLI_Main:

    ; Set the cmd_success flag to 0
    mov byte [cmd_success], 0

    
    mov si, msg_ready
    call print_string

    call get_input          ; Get a line of input and store in input_buffer

    ; Compare input to each command
    call cmp_str_help
    call cmp_str_clear
    call cmp_str_shutdown

    ; Check if a function was run
    cmp byte [cmd_success], 0
    jne .continue_CLI

    mov si, fal_invalid_cmd
    call print_string

.continue_CLI:
    jmp CLI_Main




;=====================================================
; KERNEL MAIN
;=====================================================
main:
    ; Setup data segments and stack
    push cs           ; Save current segment
    pop ds            ; DS = CS
    push cs           ; Save current segment
    pop es            ; ES = CS
    mov ss, ax        ; Set SS to the same as DS
    mov sp, 0xFFF0    ; Set stack pointer

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

    ; Draw some test pixels
    mov al, 4         ; Color red
    mov cx, 100       ; X
    mov dx, 100       ; Y
    call set_pixel

    mov al, 2         ; Color green
    mov cx, 102
    mov dx, 100
    call set_pixel

    mov al, 1         ; Color blue
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

    ; Start CLI
    call CLI_Main

    jmp hang

.mode_error:
    mov si, err_graphics_mode
    call print_string
    jmp hang

hang:
    mov si, err_system_hang
    call print_string

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
msg_disk_read: db  '[ ok  ] Disk sector read: ', ENDL, 0                                         ; Disk read result message
msg_disk_write: db ENDL, '[ ok  ] Disk sector written', ENDL, 0                                       ; Disk write confirmation

; USERSPACE STRINGS
; Commands
; Function name strings
cmd_help: db 'help', 0
cmd_clear: db 'clear', 0
cmd_shutdown: db 'shutdown', 0



msg_ready: db '[READY]', ENDL, 0                                                                ; Use just before CLI input given (added missing comma)

msg_help_la: db ENDL, 'Centinal OS commands:', ENDL, 0                                          ; Messages for the help command
msg_help_lb: db 'help      - Display this', ENDL, 0
msg_help_lc: db 'clear     - Clear screen', ENDL, 0
msg_help_ld: db 'shutdown  - Shutdown system', ENDL, 0


; ERROR MESSAGES
; Fails: small errors or issues with operations
fal_invalid_cmd: db ENDL, '[FAIL ] Invalid command', ENDL, 0

; Fatal errors: occurs when system enters a hang
err_disk_op: db ENDL, '[FATAL] Disk operation failed', ENDL, 0
err_system_hang: db ENDL, '[FATAL] ENTERING SYSTEM HANG', 0
err_graphics_mode: db '[FATAL] Graphics mode 13h not set', ENDL, 0                              ; Error message for graphic mode switch

; Main variables
input_buffer: times 100 db 0                                                                    ; Input buffer for getting user input
cmd_success: db 0                                                                               ; Check if a command was executed in the CLI
buffer: times 512 db 0                                                                          ; Define a buffer to hold one sector (512 bytes)

times 4096 - ($ - $$) db 0
