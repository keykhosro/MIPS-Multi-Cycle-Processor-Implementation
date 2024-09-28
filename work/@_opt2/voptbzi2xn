library verilog;
use verilog.vl_types.all;
entity multi_cycle_mips is
    port(
        clk             : in     vl_logic;
        reset           : in     vl_logic;
        mem_addr        : out    vl_logic_vector(31 downto 0);
        mem_read_data   : in     vl_logic_vector(31 downto 0);
        mem_write_data  : out    vl_logic_vector(31 downto 0);
        mem_read        : out    vl_logic;
        mem_write       : out    vl_logic
    );
end multi_cycle_mips;
