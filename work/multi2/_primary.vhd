library verilog;
use verilog.vl_types.all;
entity multi2 is
    port(
        clk             : in     vl_logic;
        start           : in     vl_logic;
        A               : in     vl_logic_vector(31 downto 0);
        B               : in     vl_logic_vector(31 downto 0);
        product         : out    vl_logic_vector(63 downto 0);
        ready           : out    vl_logic
    );
end multi2;
