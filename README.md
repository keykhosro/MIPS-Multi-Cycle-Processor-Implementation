# MIPS-Multi-Cycle-Processor-Implementation
This project involves the implementation of a MIPS multi-cycle processor using Verilog. The processor is designed to execute a set of MIPS instructions in multiple clock cycles, optimizing for minimal cycle count per instruction.

## Description:
This project involves the implementation of a MIPS multi-cycle processor using Verilog. The processor is designed to execute a set of MIPS instructions in multiple clock cycles, optimizing for minimal cycle count per instruction.

# Key Features:
1. Implementation of a multi-cycle MIPS processor in Verilog
2. Support for both basic and advanced MIPS instructions
3. Optimized control unit for efficient instruction execution
4. Custom multiplier unit integration
5. Comprehensive test bench for processor verification

# Implemented Instructions:
- R-format: add, sub, addu, subu, and, or, xor, nor, slt, sltu, jr, jalr, multu, mfhi, mflo
- I-format: beq, bne, lw, sw, addi, addiu, slti, sltiu, andi, ori, xori, lui
- J-format: j, jal

# Project Structure:
1. `src/`: Contains Verilog source files
   - `mips_processor.v`: Main processor module
   - `control_unit.v`: Control unit implementation
   - `datapath.v`: Datapath components
   - `alu.v`: ALU implementation
   - `multiplier.v`: Custom multiplier unit
2. `testbench/`: Contains test bench files
   - `tb_mips_processor.v`: Main test bench file
3. `hex_files/`: Contains test program hex files
   - `basic.hex`: Basic instruction test program
   - `advance.hex`: Advanced instruction test program
   - `isort32.hex`: Integer sorting test program


# Testing:
The processor was tested using three provided hex files:
1. basic.hex: Tests basic instructions
2. advance.hex: Tests advanced instructions
3. isort32.hex: Implements an integer sorting algorithm

Each test file was simulated using the provided test bench, and the results were verified against expected outputs.

# Tools Used:
- Verilog HDL for implementation
- Xilinx ISE for synthesis and simulation
- MARS MIPS simulator for generating test hex files and result verification

# Performance:
- Clock Period: 2.5 ns
- Instructions execute in the minimum number of clock cycles possible

