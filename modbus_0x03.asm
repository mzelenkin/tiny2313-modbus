; Команда чтения аналоговых данных
; ВХОД:
;       r16 - номер функции
;       X - Указатель на таблицу регистров

        ;push    r16
        lds     YL, usart_rx_buffer + 3
        lsl     YL ; Умножаем на 2, т.к. 1 reg = 16 bit
        lds     YH, usart_rx_buffer + 5
        lsl     YH ; Умножаем кол-во запрошенных регистров * 2, т.к. 2 байта на регистра
        
        ; Добавляем смещение 
        ; Номер запрошенного регистра * 2
        clr     r0
	add     XL, YL
	adc     XH, r0

        ; Загружаем в Z адрес на буфер отправки 
        ldi     ZL, LOW(usart_tx_buffer+3)
        ldi     ZH, HIGH(usart_tx_buffer+3)
        
        ; Копируем содержимое YH в R23
        mov     r23,YH

MB03_01:
        ld      r16, X+
        st      Z+,r16
        dec     YH
        tst     YH
        brne    MB03_01

        ; Число байт
        sts     usart_tx_buffer+2 ,r23        
        ; Номер функции
        ldi     r16, 0x04
        ;pop     r16
        sts     usart_tx_buffer+1 ,r16
        ; Modbus ID
        lds     r16, modbus_addr
        sts     usart_tx_buffer ,r16

        subi    r23,-3
        sts     count_crc_byte,r23
        subi    r23,-2     
        sts     usart_tx_msg_len, r23

        ldi     XL, LOW(usart_tx_buffer)
        ldi     XH, HIGH(usart_tx_buffer)
        RCALL   crc16_calc

        st      X+,r18
        st      X, r17

        rjmp    modbus_send