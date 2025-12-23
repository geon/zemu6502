resetEntryPoint:
        SEI             ; Disable interrupts
        CLD             ; Clear decimal flag
        LDX #$FF        ; Reset stack
        TXS             ; ($01FF)

clearRam:
        LDX #4
        STX $01
        STA $00
        TAY
-:
        STA $00,Y
        CMP $01
        BEQ +

        INY
        BNE -
        INY
        INX
        INC $01
        BPL -

+:
