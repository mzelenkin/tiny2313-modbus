;==========================================================================
; Tiny 2313 Modbus RTU Slave
; 2018 By Mikhail Zelenkin <mzelenkin@mail.ru>
;==========================================================================

.nolist ; Исключаем из листинга строки ниже
.include "tn2313def.inc"
.list


;==========================================================================
; D E F I N I T I O N S
;==========================================================================
.equ        XTAL = 8000000          ; Тактовая частота 8MHz
;.equ        XTAL = 14745600        ; Тактовая частота 14.7456MHz

.equ        USART_RX_BUFFSIZE = 25  ; Размер буфера приема USART
.equ        USART_TX_BUFFSIZE = 25  ; Размер буфера передачи USART
.equ        USART_BAUDRATE = 19200


;==========================================================================
; S R A M   D E F I N I T I O N S
;==========================================================================
.DSEG
.ORG  0X0060

; Приемный буфер
usart_rx_buffer:    .byte USART_RX_BUFFSIZE
usart_rx_count:     .byte 1 ; Ячейка записи - Смещение относительно начала буфера
usart_rx_msg_len:   .byte 1 ; Размер полученного сообщения

; Буфер передачи
usart_tx_buffer:    .byte USART_TX_BUFFSIZE
usart_tx_count:     .byte 1 ; Ячейка для отправки - Смещение относительно начала буфера
usart_tx_msg_len:   .byte 1 ; Размер сообщения для отправки

modbus_addr:        .byte 1; Адрес устройства в сети modbus
count_crc_byte:     .byte 1

; MODBUS
modbus_rx_ok:       .byte 1
mb_input_registers: .byte 4

;==========================================================================
; R E S E T   A N D   I N T E R R U P T   V E C T O R S
;==========================================================================
.CSEG
.ORG $0000

    RJMP    start   ; Reset
    RETI ; INT0 Int vector 1
    RETI ; INT1 Int vector 2
    RETI ; TC1CAPT Int vector 3
    RETI ; TC1COMPA Int vector 4
    RETI ; TC1OVF Int vector 5
    RJMP T0_0VF; TC0OVF Int vector 6
    RJMP RXCIE_Hndl ; USART-RX Int vector 7
    RJMP UDRIE_Hdnl ; USART UDRE Int vector 8
    RJMP TXCIE_Hndl ; USART TX Int vector 9
    RETI ; ANACOMP Int vector 10
    RETI ; PCINT Int vector 11
    RETI ; TC1COMPB Int vector 12
    RETI ; TC0COMPA Int vector 13
    RETI ; TC0COMPB Int vector 14
    RETI ; USI-START Int vector 15
    RETI ; USI-OVERFLOW Int vector 16
    RETI ; EEREADY Int vector 17
    RETI ; WDT-OVERFLOW Int vector 18


; ==============================================
;   M A I N    P R O G R A M
; ==============================================
;
start:
    ; Указатель стека на конец RAM
    LDI     r16, LOW(RAMEND)
    OUT     SPL, r16

; -------------------------------------------
; Настройка портов
; DDRx - регистр направления передачи данных. 
; Этот регистр определяет, является тот или иной вывод порта входом или выходом. 
; Бит в DDRx выставленный в 1 - выход, 0 - вход 
    
    ; Настройка порта B
    LDI     r16, 0xFF
    OUT     DDRB, r16

    ; Настройка порта D
    LDI     r16, 0xFF
    OUT     DDRD, r16

    LDI     r16, 0b00000000
    OUT     PORTD, r16

; -------------------------------------------
; Настройка USART
    LDI     r16, 0x19 ; 19200
    OUT     UBRRL,r16
    LDI     r16, 0
    OUT     UBRRH,r16
    clr     r16
    OUT     UCSRA, r16
    LDI     r16,  (1<<RXEN)|(1<<TXEN)|(1<<RXCIE)|(1<<TXCIE)|(0<<UDRIE)
    OUT     UCSRB,r16
    LDI     r16, (1<<USBS)|(3<<UCSZ0)
    OUT     UCSRC, r16

; -------------------------------------------
; Настройка таймера
    ;IN      R16, TCCR0
    LDI     R16, 0
    OUT     TCCR0, R16

    ; Включаем прерывание
    IN      r16, TIMSK
    ORI     R16, 1 << TOIE0
    OUT     TIMSK, R16

; -------------------------------------------
; Обнуляем ячейки памяти
    CLR     R16
    STS     usart_rx_count, R16
    STS     usart_tx_count, R16
    STS     usart_tx_buffer, R16
    STS     modbus_rx_ok, R16

    LDI     R16, 4
    STS     modbus_addr, R16

    LDI     R16, 0x34
    STS     mb_input_registers, R16
    LDI     R16, 0
    STS     mb_input_registers+1, R16
    LDI     R16, 0x63
    STS     mb_input_registers+2, R16
    LDI     R16, 0x01
    STS     mb_input_registers+3, R16

; -------------------------------------------
; Разрешаем прерывания
    SEI

; -------------------------------------------
; Главный цикл

mainloop:

    LDS     R16, modbus_rx_ok
    CPI     R16, 1
    BRNE    mainloop_1

    ; Обнуляем флажок приема
    CLR     R16
    STS     modbus_rx_ok, R16

    LDI     R16, 0b00000001
    OUT     PORTB, R16

    RCALL   modbus_check

mainloop_1:
    RJMP    mainloop

uart_snt:
        RCALL   usart_tx_enable

uart_snt_lp1:
        SBIS 	UCSRA,UDRE	 ; Пропуск если нет флага готовности
		RJMP	uart_snt_lp1 ; ждем готовности - флага UDRE
 
		OUT	UDR, R16	; шлем байт

uart_snt_lp2:
        SBIS 	UCSRA,UDRE	 ; Пропуск если нет флага готовности
		RJMP	uart_snt_lp2 ; ждем готовности - флага UDRE
        ; Выходим
        RJMP   usart_tx_disable

uart_rcv:	
        LDS     R16, usart_rx_count
        CPI     R16, 0
        BREQ    uart_rcv
 
        CLR     R16
        STS     usart_rx_count, R16

		LDS	    R16, usart_rx_buffer	; байт пришел - забираем.
		RET			; Выходим. Результат в R16

.include "interrupts.inc"

usart_tx_enable:
    ; Переключить трансивер в режим передачи
        IN      R17, PORTD
        ORI     R17, 0b00000100
        OUT     PORTD, R17
        RET

usart_tx_disable:
    ; Переключает трансивер в режим приема
        IN      R17, PORTD
        ANDI    R17, 0b11111011
        OUT     PORTD, R17
        RET

.include "crc16.inc"
.include "modbus.inc"
