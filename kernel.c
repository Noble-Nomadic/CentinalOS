void print_char(char c) {
    // BIOS interrupt to write a character to the screen at position 0x0
    asm volatile (
        "mov ah, 0x0e;"   // BIOS teletype output function
        "mov al, %0;"      // Character to print
        "mov bh, 0;"       // Page number
        "mov bl, 0x07;"    // Text attribute (light gray on black)
        "int 0x10;"        // BIOS interrupt for video output
        :
        : "r"(c)
    );
}

void kernel_main() {
    // Print 'K' to the screen
    print_char('K');

    // Infinite loop to prevent the system from exiting
    while (1) {}
}

kernel_main();