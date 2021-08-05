;; device definitions
        .include    "m4809def.inc"
        .include    "../libraries/midiserial.inc"

;;  software delay registers
        .def        loopCt = r18
        .def        iloopL = r24
        .def        iloopH = r25
        .equ        maxi = 0x4118

;; midi constants
        .equ        pitch = 0x3C
        .equ        noteon = 0x90
        .equ        noteoff = 0x80

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        .cseg
        .org    0x0000
reset: 
        ldi     r16, Low(RAMEND)        ; init stack pointer
        ldi     r17, High(RAMEND)
        out     CPU_SPL, r16
        out     CPU_SPH, r17
        setup_midi

main:
        rcall   note_on
        rcall   count_1s
        rcall   note_off
        rcall   count_1s
        rjmp    main
        
note_on:
        ldi     r16, noteon
        rcall   tx
        ldi     r16, pitch
        rcall   tx
        ldi     r16, pitch
        rcall   tx
        ret

note_off:
        ldi     r16, noteoff
        rcall   tx
        ldi     r16, pitch
        rcall   tx
        ldi     r16, 0x00
        rcall   tx
        ret

tx:
        lds     r17, USART1_STATUS          ; load uart status
        sbrs    r17, 5                      ; check if empty
        rjmp    tx                          ; loop if not

        sts     USART1_TXDATAL, r16         ; send whatever is in r16
        ret



;; outer count goes in loopCt(r18)
;; inner count init goes in r20 / r21
count_outer:                
        mov     iloopL, r20 ;1
        mov     iloopH, r21 ;1                                                  
        rcall   count_inner ;p=(innergoalclocks-9)/3, t=p-5-(p/loopCt)
        dec     loopCt      ;1             
        brne    count_outer ;1/2                
        ret                 ;4/5
count_inner:                                  ; sleep until iloop(r24/r25) reaches zero
        sbiw    iloopL, 1 ;2            
        brne    count_inner ;1/2
        ret ;4/5

count_1s:
        ldi     loopCt, 0x14
        ldi     r20, Low(maxi)
        ldi     r21, High(maxi)
        rcall   count_outer
        ret
count_200ms:
        ldi     loopCt, 0x04
        ldi     r20, Low(maxi)
        ldi     r21, High(maxi)
        rcall   count_outer
        ret