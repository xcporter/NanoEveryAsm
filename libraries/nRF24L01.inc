;******************************************************************************************
;*   
;*      Device library for nRF24L01 to be used with arduino nano every
;*      requires m4809def.inc to be available (preferably at highest level of project)
;*
;*      set to pins PE[0:3]--can be adjusted in portmux.
;*      as it is currently set:
;*      PE0 -- MOSI
;*      PE1 -- MISO
;*      PE2 -- SCK 
;*      PE3 -- CSN 
;*      PB1 -- CE (Active high)
;*      PB0 -- IRQ (Active low)
;*
;******************************************************************************************


;;  SPI settings
        .equ        ctlA = 0b00100011       ; master, prescalar 16 (500 kHz), enable
        .equ        ctlB = 0b11000100       ; buffer, no wait, ss disable, mode 0

        .equ        usart_mux = 0x44        ; connect USART3 to the other uC, and USART1 to the pinout tx/rx
        .equ        spi_mux = 0x02          ; connect SPI to pins PE[0:3]

;;  commands
        .equ        R_REGISTER              = 0b00000000    ; [0:4] are for address
        .equ        W_REGISTER              = 0b00100000    ; [0:4] are for address
        .equ        R_RX_PAYLOAD            = 0b01100001
        .equ        W_TX_PAYLOAD            = 0b10100000
        .equ        FLUSH_TX                = 0b11100001
        .equ        FLUSH_RX                = 0b11100010
        .equ        REUSE_TX_PL             = 0b11100011
        .equ        R_RX_PL_WID             = 0b01100000
        .equ        W_ACK_PAYLOAD           = 0b10101000    ; [0:2] are for pipe
        .equ        W_TX_PAYLOAD_NO_ACK     = 0b10110000
        .equ        NOP                     = 0b11111111

.macro start_cmd
        ldi     r16, 0x08
        sts     PORTE_OUTCLR, r16
.endmacro

.macro end_cmd
        ldi     r16, 0x08
        sts     PORTE_OUTSET, r16
.endmacro

.macro rf_spi_setup
        ldi     r17, 0x01                   ; clock prescalar of 2 (clk_per = 8MHz)
        ldi     r16, CPU_CCP_IOREG_gc       ; load io reg signature
        out     CPU_CCP, r16                ; Protected write engage! you have 4 cycles to do your thing   
        sts     CLKCTRL_MCLKCTRLB, r17      ; write prescalar

        ldi     r16, usart_mux              ; route usart to proper ports 
        sts     PORTMUX_USARTROUTEA, r16

        ldi     r16, spi_mux                ; route spi to port E
        sts     PORTMUX_TWISPIROUTEA, r16

        ldi     r16, ctlA                   ; set control A
        sts     SPI0_CTRLA, r16           

        ldi     r16, ctlB                   ; set control B
        sts     SPI0_CTRLB, r16                   

        ldi     r16, 0x08                   ; pin 3 (PORTE)                  
        sts     PORTE_DIRSET, r16           ; set tx pin direction
        sts     PORTE_PIN3CTRL, r16         ; set pullup resistor
        sts     PORTE_OUTSET, r16           ; set high

        ret 
.endmacro




