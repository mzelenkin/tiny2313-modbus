; ==============================================
;   I N T E R R U P T S
; ==============================================
;

RXCIE_Hndl:
    PUSH    R0
    PUSH    R16
    IN      R16, SREG
    PUSH    R16
    PUSH    XL
    PUSH    XH

    ; перезапустим таймер ожидания конца сообщения с делителем 256
    ;IN      R16, TCCR0
    LDI     R16, (1<<CS02)
    OUT     TCCR0, R16
    
    ; В X - адрес буфера
    LDI     XL, LOW(usart_rx_buffer)
    LDI     XH, HIGH(usart_rx_buffer)
    ; Прибавляем к X счетчик принятых байт и получаем указатель на ячейку, в которую должен считаться байт из порта
    CLR     R0
    LDS     R16, usart_rx_count
    ADD     XL, R16
    ADC     XH, r0
    ; Теперь X - указывает на первую свободную ячейку в буфере приема
    ; Заодно увеличивает счетчик принятых байт
    INC     R16
    ; Если принято байт больше чем буфер, обнуляем
    CPI     R16, USART_RX_BUFFSIZE
    BRNE    RXCIE_Hndl_1
    CLR     R16

RXCIE_Hndl_1:
    ; Сохраняем счетчик принятых байт
    STS     usart_rx_count, R16

    ; Забираем принятый байт и сохраняем его в буфер
    IN      R16, UDR
    ST      X, R16

    ; Перезапуск таймера на новое ожидание интервала 3.5 пакета
    LDI     R16, 255 - (32*XTAL) / (256*USART_BAUDRATE)
    OUT     TCNT0, r16

    POP     XH
    POP     XL
    POP     R16
    OUT     SREG, R16
    POP     R16
    POP     R0
    
    RETI


UDRIE_Hdnl:
    PUSH    R0
    PUSH    R16
    IN      R16, SREG
    PUSH    R16
    PUSH    XL
    PUSH    XH

    ; Переключить трансивер в режим передачи
    IN      R17, PORTD
    ORI     R17, 0b00000100
    OUT     PORTD, R17

    LDI	    XL, LOW(usart_tx_buffer)
    LDI	    XH, HIGH(usart_tx_buffer)

    ; Прибавляем к Z счетчик принятых байт и получаем указатель на ячейку, в которую должен считаться байт из порта
    CLR     R0
    LDS     R16, usart_tx_count
    ADD     XL, R16
    ADC     XH, r0
    ; Теперь Z - указывает на следующую ячейку в буфере передачи
    ; Заодно увеличивает счетчик переданных байт
    INC     R16
    ; Если передано байт больше чем буфер, обнуляем и отключаем UDRIE
    LDS     R17, usart_tx_msg_len
    CP      R16, R17
    BRCS    UDRIE_Hdnl_1

    ; Отключаем прерывание UDRIE
    IN      R16, UCSRB
    ANDI    R16, ~(1<<UDRIE)
    OUT     UCSRB, R16

    ; Обнуляем счетчик длинны сообщения
    CLR     R16
    STS     usart_tx_msg_len, R16

UDRIE_Hdnl_1:
    ; Сохраняем счетчик принятых байт
    STS     usart_tx_count, R16

    LD	    R16,X
    OUT	    UDR,R16

    POP     XH
    POP     XL
    POP     R16
    OUT     SREG, R16
    POP     R16
    POP     R0

    RETI


TXCIE_Hndl:
    PUSH    R16
    IN      R16, SREG
    PUSH    R16

    IN      R16, PORTD
    ANDI    R16, 0b11111011
    OUT     PORTD, R16

    POP     R16
    OUT     SREG, R16
    POP     R16

    RETI

T0_0VF:
    PUSH    R16
    IN      R16, SREG
    PUSH    R16

    ; остановим таймер ожидания конца сообщения
    ;IN      R16, TCCR0
    LDI     R16, 0
    OUT     TCCR0, R16

    ; Выставляет флаг принятия пакета MODBUS
    LDI     R16, 1
    STS     modbus_rx_ok, R16

    POP     R16
    OUT     SREG, R16
    POP     R16

    RETI
