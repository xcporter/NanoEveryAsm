;; device definitions
        .include    "m4809def.inc"
        .include    "usbserial.inc"

;; Setup
        .cseg
        .org    0x0000

        ldi     r16, Low(RAMEND)        ; init stack pointer
        ldi     r17, High(RAMEND)
        out     CPU_SPL, r16
        out     CPU_SPH, r17

        setup_usb
        
main:
        rcall   reset_z
        rcall   rx
        rcall   reset_z
        rcall   tx
        rjmp    main

reset_z:
        ldi     ZL, LOW(INTERNAL_SRAM_START)    ; setup z pointer
        ldi     ZH, HIGH(INTERNAL_SRAM_START)
        ret
check_cr:
        lds     r16, USART3_RXDATAL         ; load next char from serial
        cpi     r16, $0D                    ; check if cr
        ret
write_mem:
        st      Z+, r16
        ret

null_terminate_mem:
        ldi     r16, $00                ; write null terminator
        st      Z+, r16
        ret

read_mem:
        ld      r16, Z+                     ; load next char from memory
        cpi     r16, $00                    ; check if null
        ret

transmit_cr:
        ldi     r16, $0d                    ; send \r
        call    usb_tx_wait
        sts     USART3_TXDATAL, r16             
        ldi     r16, $0a                    ; send \n
        call    usb_tx_wait
        sts     USART3_TXDATAL, r16   
        ret          
rx:     using_usb_rx       check_cr, write_mem, null_terminate_mem

tx:     using_usb_tx       read_mem, $0, transmit_cr


usb_rx_wait: usb_rx_wait
usb_tx_wait: usb_tx_wait


