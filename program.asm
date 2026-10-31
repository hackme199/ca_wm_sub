; ELL782 Assignment 2 - washing machine control program
; ACT bits: 0 VALVE 1 HEATER 2 MOTOR_EN 3 MOTOR_DIR 4 PUMP 5 LOCK 6 BUZZER
; Mode 0 (MODE[1:0]=x0): target 100, wash half-period 10, spin 12
; Mode 1 (MODE[1:0]=x1): target 150, wash half-period 15, spin 20
; Drain threshold 10 (both modes). MODE[1] is ignored (documented).

start:
    LDI R6, 0xF4
    LDI R0, 0x00        ; all actuators off
    ST  R0, [R6]
    LDI R6, 0xF5
    LDI R0, 0x01        ; DISPLAY = idle
    ST  R0, [R6]
    LDI R6, 0xF8
    LDI R0, 0x00        ; timer disabled, no clear
    ST  R0, [R6]
    LDI R6, 0xF7
    LDI R0, 0x00        ; LIMIT = 0 (compare off)
    ST  R0, [R6]
wait_start:
    LDI R6, 0xF0
    LD  R1, [R6]           ; IN_CTRL sample (START b0, MODE b2:1, DOOR b3)
    LDI R0, 0x09
    AND R0, R1             ; keep START and DOOR_CLOSED
    LDI R2, 0x09
    SUB R0, R2             ; zero only when both are 1
    BNEZ R0, wait_start
    LDI R0, 0x02           ; MODE snapshot taken from the SAME sample as START
    AND R1, R0             ; R1 = MODE[0]<<1
    BNEZ R1, mode1
mode0:
    LDI R3, 100
    LDI R4, 10
    LDI R5, 12
    JMP latched
mode1:
    LDI R3, 150
    LDI R4, 15
    LDI R5, 20
latched:
    LDI R6, 0xF4
    LDI R0, 0x20        ; DOOR_LOCK requested
    ST  R0, [R6]
    LDI R6, 0xF5
    LDI R0, 0x02        ; DISPLAY = fill
    ST  R0, [R6]
    LDI R6, 0xF4
    LDI R0, 0x21        ; lock + VALVE_IN
    ST  R0, [R6]
fill_loop:
    LDI R6, 0xF1
    LD  R2, [R6]           ; level
    SLTU R2, R3            ; R2 = level < target (unsigned)
    BNEZ R2, fill_loop     ; keep filling; overshoot (99 -> 102) exits
    LDI R6, 0xF4
    LDI R0, 0x20        ; close valve, lock stays
    ST  R0, [R6]
    LDI R6, 0xF5
    LDI R0, 0x03        ; DISPLAY = wash
    ST  R0, [R6]
    LDI R7, 4              ; four half-periods: fwd, rev, fwd, rev
    LDI R1, 0x24           ; ACT word: lock + motor, forward
wash_phase:
    LDI R6, 0xF4
    ST  R1, [R6]           ; motor on in current direction
    LDI R6, 0xF7
    ST  R4, [R6]           ; LIMIT = wash half-period
    LDI R6, 0xF8
    LDI R0, 0x03        ; EN|CLR: clear COUNT and MATCH, start counting
    ST  R0, [R6]
wash_wait:
    LDI R6, 0xF9
    LD  R0, [R6]           ; MATCH
    BEQZ R0, wash_wait
    LDI R0, 0x24
    SUB R0, R1             ; 0 if currently forward
    BEQZ R0, to_rev
    LDI R1, 0x24           ; was reverse -> forward
    JMP tog_done
to_rev:
    LDI R1, 0x2C           ; was forward -> reverse
tog_done:
    ADDI R7, 0xFF          ; R7 -= 1
    BNEZ R7, wash_phase
    LDI R6, 0xF4
    LDI R0, 0x20        ; motor off, lock stays
    ST  R0, [R6]
    LDI R6, 0xF5
    LDI R0, 0x04        ; DISPLAY = drain
    ST  R0, [R6]
    LDI R6, 0xF4
    LDI R0, 0x30        ; lock + PUMP_OUT
    ST  R0, [R6]
drain_loop:
    LDI R6, 0xF1
    LD  R2, [R6]           ; level
    LDI R0, 10             ; drain threshold
    SLTU R0, R2            ; R0 = threshold < level (unsigned)
    BNEZ R0, drain_loop    ; still above threshold
    LDI R6, 0xF5
    LDI R0, 0x05        ; DISPLAY = spin
    ST  R0, [R6]
    LDI R6, 0xF7
    ST  R5, [R6]           ; LIMIT = spin interval
    LDI R6, 0xF8
    LDI R0, 0x03        ; rearm: clear COUNT/MATCH, enable
    ST  R0, [R6]
    LDI R6, 0xF4
    LDI R0, 0x34        ; lock + PUMP_OUT + MOTOR_EN (spin)
    ST  R0, [R6]
spin_wait:
    LDI R6, 0xF9
    LD  R0, [R6]           ; MATCH
    BEQZ R0, spin_wait
    LDI R6, 0xF4
    LDI R0, 0x20        ; all actuators off, lock still held
    ST  R0, [R6]
    LDI R6, 0xF4
    LDI R0, 0x40        ; motor off -> unlock; BUZZER on
    ST  R0, [R6]
    LDI R6, 0xF5
    LDI R0, 0xD0        ; DISPLAY = done
    ST  R0, [R6]
    HALT
