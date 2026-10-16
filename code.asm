org 0x7C00 ; from origin of bootloader

jmp start ; goes to start's memory address and executes instructions

message1: db "give a number ", 0x00 ; message followed by null terminator
message2: db "give operation to do (+ or -) ", 0x00
message3: db "give second number ", 0x00

start: ; sets labels so that the cpu can go to that memory and execute the instructions.
       ; in this case, 'jmp start' jumps to this memory address, and executes everything that follows. same thing is done with 'draw:' and 'loop:' and 'return':

    cli ; clear interrupts
     
    xor ax, ax ; xor with register to make all bits of the end result 0
    mov ss, ax ; sets stack segment to 0
    mov sp, 0x7C00 ; sets stack pointer to 0x7C00 so that stack grows down and its location doesn't collide with any in the range 0x7C00 and 0x7E00


    mov ah, 0 ; 0 to tell the bios that a new video display mode needs to be set during 0x10 interrupt
    mov al, 2 ; the parameter for the above mode- to set a 80x25 text mode
    mov dx, 0
    int 0x10 ; interrupt for serial port services
    
    mov di, 0 ; di-> destination index register. by setting it to 0, we're telling the bios that we want to write text from the top-left of the screen.
    mov bp, 0
    mov si, message1 ; moves the address of message to si. si is commonly used in x86 to track the location of string
                     ; in this case, doing this also acts like arguments before moving to the address
    
    call draw ; going to the address draw

    mov bx, 0 ; sets value of bx to 0 so that it can calculate and store the mathematical value

    read:
        mov ah, 0x00 ; waits for user keypress
        int 0x16 ; keyboard interrupt, returns scan code in AH and ascii in AL

        cmp al, 0x0D ; compares if the keypress it equal to the "Enter" key, which has a keycode of 0x0D
        jne continue ; if the keypress is not equal to the "Enter" key (hence not equal to 0x0D), go to continue label
        cmp bp, 1 ; check bp, where we've set a flag to see if both numbers have been inputted from the user, if it is 1
        je final ; if the flag register *does* have 1 in it, meaning it is the second number, go to the label final
        jmp done ; since this is technically the else statement, we are redirecting the else to go to done label
    
    continue: ; the address where we go from inputs to numbers understood by the device
        push ax ; pushed to stack. x86 needs you to send the entire 16-bit thing, which is ax though the data we need is stored in al
        mov ah, 0x0E ; to print character to screen then advances cursor
        int 0x10 ; video services interrupt
        pop ax ; removed from stack

        sub al, 0x30 ; subtracts value of '0' to change to numerical digit
        mov cl, al ; this moves the value in al to cl to have access to the numerical digit in al after al is used later on in the code

        mov ax, bx ; move total into ax
        mov dx, 10 ; set a multiplier of 10 to offset by 1 place to the left
        mul dx ; multiplies and stores in DX:AX  since cx is a 16-bit register
        mov bx, ax ; moves the value in ax back to bx

        xor ax, ax ; replaces all bits in ax with 0 by xor-ing each bit with itself
        mov al, cl ; takes the value transferred to cl in line number 50 and puts it back into al to use 
        add bx, ax ; transfer back from ax to bx (this is needed since 'mul' has a defined destination place- the register ax

        jmp read ; repeat until user presses 'Enter'
    
    done:
        push bx ; sends first number to stack to be retrieved later

        mov si, message2 ; points source index at message2
        call draw ; we use the label draw to print the contents of message2 onto the screen

        mov ah, 0x00 ; bios code to get keypress and stores it in ah
        int 0x16 ; interrupt to pause cpu till keypress is done
        push ax ; the operator is pushed to stack above the first number. in this case, the user doesn't need to click "Enter" because for just 1-character operators, it isn't needed

        mov si, message3 ; points source index at message3
        call draw ; label draw is used to display contents of message3 onto the screen

        mov bx, 0 ; sets bx to zero so that second number can be taken
        mov bp, 1 ; sets bp to 1 to register second number is taken (line 77)
        jmp read ; we go back to the label read to get the second number

    final:
        mov cx, bx ; moves bx to cs to free up space
        pop dx ; takes dx back from stack
        pop bx ; takes bx back from stack

        cmp dl, '+' ; compares dl to addition
        je addition ; if same, then goes to addition label
        cmp dl, '-' ; compares dl to subtraction
        je subtraction ; if same, then goes to subtraction level
        
    
    addition:
        add bx, cx ; adds the values in both registers
        jmp print ; jumps to print label
    
    subtraction:
        sub bx, cx ; subtracts the value in cx from bx and *automatically* goes to print label since it's the next code needing to be executed
        
    print:
        mov ah, 0x0E ; bios to draw characters on screen
        mov al, 0x0D ; shifts screen cursor to top left of display (via carriage return)
        int 0x10 ; shifts cursor back to top left by execution of code in al
        mov al, 0x0A ; 

        int 0x10

        mov cx, 16 ; sets number of digits to 16- so 16 bits will be looked at

    bit:
        shl bx, 1 ; shifts all bits in bx 1 place to the left and puts the leftmost bit in the Carry Flag bit
        jc one ; if the leftmost bit lost is a one (found by jc. for 0, use jnc), goes to label one
    
    zero:
        mov al, '0' ; puts 0 in al to display
        jmp echo ; jump to echo label
    
    one:
        mov al, '1' ; puts 1 in al to display
    
    echo:
        push ax ; push ax to stack
        push bx ; push bx to stack
        push cx ; push cx to stack

        mov ah, 0x0E ; bios code to draw characters on screen
        int 0x10 ; prints text character on screen (either "1" or "0")

        pop cx ; take cx back from stack
        pop bx ; take cx back from stack
        pop ax ; take cx back from stack

        loop bit ; decreases cx by 1. if cx > 0, jump to bit label

        hlt ; halt

draw:
    
    mov ax, 0xB800 ; vga buffer for text begins at 0xB800
    mov es, ax ; copying the address 0xB800 from ax to es.
    ; this can't be done directly because x86 doesn't allow you to move numbers directly into segment registers; a general-purpose register is needed.
    ; the reason for this is that this simplified a lot of conenctions between locations in the 8086 microprocessor, which was easier for the designers and cheaper for the manufacturers.

    mov cx, 0 ; cx is used to keep track of characters

    output_loop:
        mov al, [si] ; al is 8 bit register- we can transfer 1 byte from the address in si to al
                     ; si is already initialized outside like an argument for the label (look at lines 26, 66, 73)

        cmp byte[si], 0 ; comparing to see if null terminator is reached
        je find ; calling find to exit the loop if byte[si] is the null terminator
        
        mov [es:di], al ; we are going to the memory spot on the monitor's screen and copies the character in al to it.

        inc di ; video memory uses 2 bytes- 1 for the value, and the next for color
        mov byte[es:di], 0x07 ; sets color properties of the character- 0x07 is light gray on a black background
        inc di ; increments di register to go to next charater location
        inc si ; increments si to go to next character
        inc cx ; incrementing cx to increase number of characters
        jmp output_loop ; to go back into loop

find:
    mov ah, 0x02 ; function code to set cursor position
    mov bh, 0 ; to set page number of vga
    mov dh, 0 ; to set row to begin with as 0
    mov dl, cl ; cl and cx are tied. since cx is incremented everytime, dl becomes the column number
    int 0x10 ; executes bios video interrupt
    ret ; to exit the loop

times 510 - ($ - $$) db 0 ; boot sector should be 512 bytes long, fills in space between with 0s
; it takes 510 bytes (2 bytes in next 2 lines). so we need to fill everything remaining with 0 by defining that byte to be 0 and doing it [current address - start address or 0x7C00] times
db 0x55 ; to tell computer that it is a valid bootloader
db 0xAA ; to tell computer that it is a valid bootloader