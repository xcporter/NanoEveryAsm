;******************************************************************************************
;*   
;*      Heimdallr
;*           Minimalist interpreter               
;* 
;*      Author: Alexander Porter (2021)
;*
;*      Z - Program constants
;*      X - Buffer pointer (2k)
;*      Y - User memory (begins at SRAM_START + 0x7D0)
;*
;*
;* 
;******************************************************************************************

;; device definitions
        .include    "m4809def.inc"
        .include    "../../libraries/usbserial.inc"

        .equ        user_memory_start = (INTERNAL_SRAM_START + 0x7D0)

;; Setup
        .cseg
        .org    0x0000

        ldi     r16, Low(RAMEND)        ; init stack pointer
        ldi     r17, High(RAMEND)
        out     CPU_SPL, r16
        out     CPU_SPH, r17

        setup_usb

;;  Main ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
main: 
        rcall   reset_buffer_pt
        rcall   rx
        rcall   do                          ; engage interpreter
        rjmp    main  

;;  Command Definitions & Interpreter Flow ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
do: 
        rcall   reset_buffer_pt
        ld      r16, X+
        rjmp   command_lookup

do_read:
        ld      r16, X                  ; load next term from buffer
        cpi     r16, 0x35
        breq    break_fail                         
        rcall   transmit_ok
        ret
do_write:
        ldi     r16, 'B'                    
        call    usb_tx_wait
        sts     USART3_TXDATAL, r16
        rcall   transmit_ok
        ret
do_exec:
        ldi     r16, 'C'                    
        call    usb_tx_wait
        sts     USART3_TXDATAL, r16
        rcall   transmit_ok
        ret
do_buffer_exec:
        ldi     r16, 'D'                    
        call    usb_tx_wait
        sts     USART3_TXDATAL, r16
        rcall   transmit_ok
        ret
do_debug:
        ldi     r16, 'E'                    
        call    usb_tx_wait
        sts     USART3_TXDATAL, r16
        rcall   transmit_ok
        ret

;;  Command Execution ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
command_lookup:
        ldi     ZL, Low(2*commands)
        ldi     ZH, High(2*commands)
        rcall   lookup_loop

command_dispatch:  
        ldi     ZL, Low(2*cmd_addr)         ; get address from command code
        ldi     ZH, High(2*cmd_addr)
        ldi     r17, 0x02                   ; multiply by two (word addressed)
        mul     r16, r17
        add     ZL, r0                      ; displace address
        adc     ZH, r1
        sbiw    ZL, 0x02                    ; account for previous offset 

        lpm     r16, Z+                     ; load address into Z pointer
        lpm     r17, Z

        mov     ZL, r16
        mov     ZH, r17
        ijmp 

;;  Interpreter Utilities ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

;       Interpreter loop definitions (added to using_usb_rx macro)
before_each_rx:
        lds     r16, USART3_RXDATAL         ; load next char from serial
        cpi     r16, $0D                    ; check if cr
        ret
on_each_rx:
        st      X+, r16                     ; store and increment recieved char
        cpi     r16, $7F                    ; check if backspace
        breq    do_backspace
        rcall   usb_tx_wait                 ; echo back each character typed in tty
        sts     USART3_TXDATAL, r16   
        ret  
on_rx_end:
        ldi     r16, $00                    ; write null terminator
        st      X+, r16                      
        ret

;       Transmission utilities
do_backspace:
        sbiw    XL, 2                       ; decrement x pointer by 1 char
        ldi     r16, $08                    ; send backspace
        call    usb_tx_wait
        sts     USART3_TXDATAL, r16 
        ldi     r16, $20                    ; send space
        call    usb_tx_wait
        sts     USART3_TXDATAL, r16 
        ldi     r16, $08                    ; send backspace
        call    usb_tx_wait
        sts     USART3_TXDATAL, r16
        ret

transmit_cr:
        ldi     r16, $0d                    ; send \r
        call    usb_tx_wait
        sts     USART3_TXDATAL, r16             
        ldi     r16, $0a                    ; send \n
        call    usb_tx_wait
        sts     USART3_TXDATAL, r16   
        ret 

transmit_ok:
        ldi     ZL, LOW(2*msg_ok)
        ldi     ZH, HIGH(2*msg_ok)
        rcall   tx_pgm
        ret
        

;       convert char to index-- first: load address of table into Z
lookup_loop:
        mov     r17, r16                ; setup for compare
        mov     r18, ZL                 ; setup for finding displacement
        mov     r19, ZH

        rcall   read_pgm
        breq    break_not_found         ; break if command not found
        cpse    r16, r17
        rjmp    lookup_loop

        sub     ZL, r18
        sbc     ZH, r19
        mov     r16, ZL
        ret

; break subroutines: send error and exit back to main loop ~~~~~~~~~~~~~~~~
break_fail:
        pop     r16                             ; cancel lookup, ret now refers to the main->do call
        ldi     ZL, LOW(2*msg_err)
        ldi     ZH, HIGH(2*msg_err)
        rcall   tx_pgm
        ret

break_not_found:
        pop     r16                             ; cancel lookup, ret now refers to the main->do call
        ldi     ZL, LOW(2*msg_not_found)
        ldi     ZH, HIGH(2*msg_not_found)
        rcall   tx_pgm
        ret

;;  Buffer utilities ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
reset_buffer_pt:
        ldi     XL, LOW(INTERNAL_SRAM_START)    ; setup z pointer
        ldi     XH, HIGH(INTERNAL_SRAM_START)
        ret

buffer_dump:
        rcall   reset_buffer_pt
        rcall   transmit_cr
        rcall   tx_sram
        rcall   transmit_ok
        ret


;;  Memory utilities ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
read_pgm:
        lpm     r16, Z+                     ; load next Z from memory
        cpi     r16, $00                    ; check if null
        ret

read_sram:
        ld      r16, X+                     ; load next char from memory
        cpi     r16, $00                    ; check if null
        ret

;;  Conversion utilities ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
to_num:
        ldi     r17, 0x30                   ; ascii offset
        add     r16, r17
        ret


;;  Transmission loops ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    ;   main rx loop
rx:     using_usb_rx        before_each_rx, on_each_rx, on_rx_end
    ;   Send from program mem starting at Z pointer until $00 reached
tx_pgm:   using_usb_tx        read_pgm, $0, $0
    ;   Send from sram starting at X pointer until $00 reached
tx_sram:   using_usb_tx        read_sram, $0, $0

;;  Transmission wait ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
usb_rx_wait: usb_rx_wait
usb_tx_wait: usb_tx_wait

;;  Command bindings ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
;;  @   read
;;  !   store
;;  ~   execute
;;  $   execute buffer contents
;;  #   debug (subcommand)
commands:    .db     "@!~$#",$00
cmd_addr:    .dw     do_read, do_write, do_exec, do_buffer_exec, do_debug

;;  Debug bindings ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
;;  *   dump sram
;;  u   dump user memory
;;  s   dump return stack
;;  b   dump buffer
;;  r   dump registers
debug:       .db     "*usbr",$00

;; Message Constants ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
msg_ok:     .db     " ok",$0d,$0a,$00
msg_err:    .db     " error",$0d,$0a,$00
msg_not_found:    .db     " command not found",$0d,$0a,$00

msg_invalid:    .db     " invalid syntax",$0d,$0a,$00