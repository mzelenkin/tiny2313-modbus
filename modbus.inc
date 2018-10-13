modbus_check:
    LDS     R16, usart_rx_buffer
    LDS     R17, modbus_addr
    CP      R16, R17
    BRNE    modbus_err_addr

    LDS     R19, usart_rx_count
    SUBI    R19, 2 ; Уменьшаем на длинну CRC (2 байта)
    STS     count_crc_byte, R19

    LDI     XL, LOW(usart_rx_buffer)
    LDI     XH, HIGH(usart_rx_buffer)

    RCALL   crc16_calc

    LDI     XL, LOW(usart_rx_buffer)
    LDI     XH, HIGH(usart_rx_buffer)

    CLR     R0
    LDS     R16, count_crc_byte
    ADD     XL, R16
    ADC     XH, R0

    LD      R20, X+
    LD      R19, X
    CP      R17, R19
    BRNE    crc_error
    CP      R18, R20
    BRNE    crc_error

    ; Если CRC OK
    ; Загружаем в Z - адрес таблицы переходов
    LDI     ZL, LOW(modbus_funcs_tbl)
    LDI     ZH, HIGH(modbus_funcs_tbl)
    ; В R16 - номер функции
    LDS     R16, usart_rx_buffer+1
    LSL     R16     ; r16 * 2
    ; Прибавляем номер функции к адресу начала таблицы
    CLR     R0
    ADD     ZL, R16
    ADC     ZH, R0

    LDI     R17, 0x01
    IJMP

; Адрес пакета не совпадает с адресом нашего устройства
modbus_err_addr:
    ;LDI     R17, 8
    ;RJMP    error_func
    RJMP    modbus_exit
crc_error:
    LDI     R17, 3
    RJMP    error_func
    RJMP    modbus_exit

error_func:
    LDI     R16, 0x03
    STS     count_crc_byte, R16

    ;LDI     R16, 0x01   ; Код ошибки Illegal Function
    ;STS     usart_tx_buffer+2, R16
    STS     usart_tx_buffer+2, R17
    ; error
    LDS     R16, usart_rx_buffer+1
    ORI     R16, 0x80
    STS     usart_tx_buffer+1, R16

    ; Modbus Addr
    LDS     R16, modbus_addr
    STS     usart_tx_buffer, R16

    ; X - указывает на байты для CRC
    LDI     XL, LOW(usart_tx_buffer)
    LDI     XH, HIGH(usart_tx_buffer)
    RCALL   crc16_calc

    STS     usart_tx_buffer+3, R18
    STS     usart_tx_buffer+4, r17

    ; Длинна пакета 5 байт
    LDI     R16, 5
    STS     usart_tx_msg_len, R16
   
modbus_send:
    RCALL   modbus_clear_rx_buff

    ; Включаем прерывание UDRIE
    IN      R16, UCSRB
    ORI     R16, (1<<UDRIE)
    OUT     UCSRB, R16

    RET

modbus_exit:
modbus_clear_rx_buff:
; Очистка буфера
    LDI     XL, LOW(usart_rx_buffer)
    LDI     XH, HIGH(usart_rx_buffer)
    CLR     R0
    LDI     R16, USART_RX_BUFFSIZE

modbus_clrbuff1:
    ST      X+, R0
    SUBI    R16, 1
    BRNE    modbus_clrbuff1

    CLR     R0
    STS     usart_rx_count, R0

    RET


modbus_funcs_tbl:
    RJMP    error_func
    RJMP    error_func
    RJMP    error_func
    RJMP    error_func
    RJMP    modbus_0x04
    RJMP    error_func
    RJMP    error_func
    RJMP    error_func
    RJMP    error_func
    RJMP    error_func
    RJMP    error_func
    RJMP    error_func
    RJMP    error_func
    RJMP    error_func
    RJMP    error_func
    RJMP    error_func
    RJMP    error_func
    RJMP    error_func
    RJMP    error_func


modbus_0x04:
    ; Адрес таблицы регистров
    LDI     XL, LOW(mb_input_registers)
    LDI     XH, HIGH(mb_input_registers)
    LDI     R16, 0x04

    .include "modbus_0x03.asm"
