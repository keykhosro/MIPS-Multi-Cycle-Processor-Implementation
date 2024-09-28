library verilog;
use verilog.vl_types.all;
entity \multi_cycle_mips__tb_basic\ is
    generic(
        end_pc          : integer := 160
    );
    attribute mti_svvh_generic_type : integer;
    attribute mti_svvh_generic_type of end_pc : constant is 1;
end \multi_cycle_mips__tb_basic\;
