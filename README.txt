ELL782 Assignment 2 - Five-stage pipelined washing-machine microcontroller
Submitted by: Shikhar Verma[2025EEN2020]
==========================================================================

CONTENTS
  washing_pipeline.circ   complete Logisim design (main circuit: washing_pipeline, 24 named subcircuits)
  isa.pdf  architecture.pdf  memory_map.pdf  listing.pdf  pipeline_traces.pdf  validation.pdf
  program.asm / program.hex   washing program and ROM image (Logisim "v2.0 raw", 16-bit words)
  tests/*.asm, tests/*.hex    ROM images used by the six validation groups (see below)

SOFTWARE
  Main file       : washing_pipeline.circ  - for Logisim-Evolution (written by Logisim-Evolution 5.0.0 itself,
                    so it opens without any conversion notice).
  Classic Logisim : logisim_2.7/washing_pipeline.circ is the same design for classic Logisim 2.7.x. The two files
                    differ only in the ROM/RAM parts, whose pin layout is different in Evolution (RAM is configured
                    as "one bidirectional data bus", asynchronous read, rising-edge write).
  Verification    : each file was run cycle by cycle in its own simulator (Logisim-Evolution 5.0.0 headless; Logisim
                    2.7.1 and 2.7.2 headless) against an independent netlist simulator; every output and pipeline
                    probe was identical on every cycle (all 12 validation records, both washing modes; validation.pdf).
  Only gates, splitters, constants, tunnels, pins, the Clock, Register, ROM and RAM parts are used.
  (A Controlled Buffer is used solely as the write driver of the RAM data port.)

LOAD / RUN
  1. Open washing_pipeline.circ. The main circuit "washing_pipeline" shows the block-level design:
     blocks IF, IF_ID, ID, RF, ID_EX, HZ, EX, EX_MEM, MEM, MEM_WB, IO, TMR, SAFE. Double-click a
     block (or select the subcircuit in the explorer pane) to see its gates; nets carry labelled tunnels.
  2. The ROM already contains program.hex (the washing program). To run another ROM (tests/*.hex):
     open the circuit "fetch", right-click the ROM > Load Image... (Evolution: Edit Contents > Open), choose the .hex file.
  3. RESET: set the pin rst = 1 (Poke tool), then set rst = 0. Reset is an asynchronous clear of PC,
     pipeline valid bits, HALTED, actuator latch, DISPLAY, timer and the TRIP latch.
  4. CLOCK: the pin CLK is a Logisim Clock (one rising edge per full cycle). Use Simulate > Ticks Enabled / Auto-Tick
     (Ctrl+K) for a running clock, or the Tick Once / Tick Half Cycle / Tick Full Cycle items to single-step (two
     half-cycle ticks per clock cycle). Set the tick frequency to 8 or 16 Hz for the end-to-end wash.
  5. If Logisim-Evolution is slow on the first load, wait for it; the design has about 1900 tunnels.

INPUT PINS (poke them while the clock is stopped, or between edges)
  START (1 bit)  MODE (2 bit)  DOOR_CLOSED (1 bit)  WATER_LEVEL (8)  TEMP (8)  DRUM_RPM (8)
  Keep an input stable across the clock edge at which a LD samples it (inputs are read in MEM).
OUTPUT PINS / PROBES
  VALVE_IN HEATER MOTOR_EN_CMD (CPU request) MOTOR_EN_ACTUAL (safety-gated) MOTOR_DIR PUMP_OUT
  DOOR_LOCK BUZZER DISPLAY TRIP HALTED PC TIMER_COUNT TIMER_MATCH
  STALL FLUSH IFID_V IDEX_V EXMEM_V MEMWB_V WR_ACT WR_DISPLAY(WR_DISP) WR_TLIM WR_TCTL IFID_IR MEM_ADDR MEM_WDATA

END-TO-END WASH (program.hex)  - validation group 6
  Mode 0 (MODE=0): target 100, wash half-period 10, spin 12.   Mode 1 (MODE=1): target 150, wash 15, spin 20.
  Drain threshold 10. MODE[1] is ignored.
  1. rst pulse; WATER_LEVEL = 0; DOOR_CLOSED = 1; MODE = 0 (or 1); run the clock.  DISPLAY = 0x01.
  2. Set START = 1 and hold it. When DOOR_LOCK rises (START accepted), set START = 0 and change MODE: nothing changes.
  3. Fill (DISPLAY 0x02, VALVE_IN = 1): raise WATER_LEVEL in steps, e.g. mode 0: 30, 60, 90, 99, 102 (overshoot:
     the valve closes at 102 although 100 was skipped); mode 1: 40, 80, 120, 149, 152. Hold each value for >= 12 clocks.
  4. Wash (DISPLAY 0x03): MOTOR_EN_CMD = 1 and MOTOR_EN_ACTUAL = 1, MOTOR_DIR toggles 0,1,0,1 at each timer interval.
  5. Drain (DISPLAY 0x04, PUMP_OUT = 1): lower WATER_LEVEL, e.g. 80, 40, 20, 12, 8 (stops when <= 10).
  6. Spin (DISPLAY 0x05): motor + pump for the spin interval. Finish: all actuators off, DOOR_LOCK = 0, BUZZER = 1,
     DISPLAY = 0xD0, HALTED = 1.

VALIDATION GROUPS (see validation.pdf for inputs / expected / observed)
  1 tests/T1.hex  expect DISPLAY 0x03, 0x2D, 0x09 and exactly two STALL pulses.
  2 tests/T2.hex  VALVE_IN stays 0, WR_ACT never pulses, DISPLAY 0x09 then 0x77 then HALTED. tests/T2B.hex: opcodes 0xE/0xF act as NOP (DISPLAY 0x05).
  3 tests/T3.hex  set WATER_LEVEL = 0x33 first; DISPLAY 0x11, 0x22, 0x40, 0x41, 0x42, 0x33.
  4 tests/T4.hex  DISPLAY 0x10 (MATCH still 0), then COUNT value, then 0x80+COUNT; watch TIMER_COUNT / TIMER_MATCH
    (MATCH rises at COUNT = 5, then after rearm at COUNT = 3). tests/T4B.hex: timer wraps 255->0 with LIMIT = 0 while HALTED.
    tests/T4C.hex: MATCH at COUNT = 255.
  5 tests/T5A.hex  after MOTOR_EN_CMD = 1: set DOOR_CLOSED = 0 -> MOTOR_EN_ACTUAL drops at once (no clock), TRIP = 1 after the next edge;
    DOOR_CLOSED = 1 again: MOTOR_EN_ACTUAL stays 0 while MOTOR_EN_CMD stays 1.
    tests/T5B.hex  software clears the request (DISPLAY 0xE1); reclose the door; pulse START 0->1->0 with the door closed:
    TRIP clears, the motor restarts (DISPLAY 0xE2, MOTOR_EN_ACTUAL = 1). A START edge with the door open does not rearm.
  6 program.hex  as above.

NOTES
  * ROM size 256x16, RAM 128x8 (addresses 0x00-0x7F), peripherals at 0xF0-0xFF (memory_map.pdf).
  * Register file and RAM power up as 0 in Logisim but the programs never rely on that.
