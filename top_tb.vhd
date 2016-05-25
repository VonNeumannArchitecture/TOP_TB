----------------------------------------------------------------------------------
-- Company: HS-Mannheim    
-- Engineer: MW and JA
-- 
-- Create Date: 26.04.2016 12:59:13
-- Design Name: 
-- Module Name: RAM_tb - Behavioral
-- Project Name: Von Neumann Rechner in VHDL
-- Target Devices:  Siumlate on 35µ Process
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.STD_LOGIC_TEXTIO.ALL;


-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

library STD;
use STD.TEXTIO.ALL;

entity top_tb is
    Generic (   addrwide  : natural := 16; -- 2^n -> 256 -> n = 8 
                datawide  : natural := 8);
--  Port ( );
end top_tb;

architecture Behavioral of top_tb is

    component RAM is
        Generic (   addrwide  : natural; 
                    datawide  : natural);
         Port ( clk : in STD_LOGIC;  -- RAM clock
                en : in STD_LOGIC;   -- enable / chip select
                rw : in STD_LOGIC;   -- write to memory =0 / read from memory=1
                addrbus : in STD_LOGIC_VECTOR;
                databus : inout STD_LOGIC_VECTOR);
    end component;
    
    component LeitwerkCode is
        Port ( CLK : in STD_LOGIC;
               Datenbus : in STD_LOGIC_VECTOR (7 downto 0);
               CS : out STD_LOGIC;
               RW : out STD_LOGIC;
               Adressbus : out STD_LOGIC_VECTOR (15 downto 0);
               StatusRegister : in STD_LOGIC_VECTOR (3 downto 0);
               Steuersignale : out STD_LOGIC_VECTOR (3 downto 0);
               RESET : in STD_LOGIC;
               Init: in STD_LOGIC_VECTOR(15 downto 0));
    end component;
    
    component ALU
        generic (
            datawidth : integer
        );
        Port ( 
            clk : in STD_LOGIC;
            data : inout STD_LOGIC_VECTOR(datawidth-1 downto 0);
            status : out STD_LOGIC_VECTOR(3 downto 0);
            command : in STD_LOGIC_VECTOR(3 downto 0)
         );
    end component;

    signal clk, clk_en  : std_logic := '0';
    signal ram_clk , global_clk : std_logic; 

    signal en , rw , rw_all, en_all, main_reset: std_logic;
    signal addrbus, addrbus_all : std_logic_vector (addrwide-1 downto 0); 
    signal databus, databus_all : std_logic_vector (datawide-1 downto 0); 
    
    signal status : STD_LOGIC_VECTOR(3 downto 0); 
    signal command : STD_LOGIC_VECTOR(3 downto 0);
   
    type init_state is (reset, fill_mem_1, fill_mem_2, fill_mem_3, fill_mem_4, fill_mem_5, ready, run); 
    signal init : init_state := reset;

begin
    ram1 : RAM 
        generic map( 
            addrwide  => 8,
            datawide  => datawide
        )
        port map(
            clk => ram_clk, 
            en => en, 
            rw => rw,
            addrbus => addrbus(7 downto 0),
            databus => databus 
        );
 
    lw1: LeitwerkCode 
        port map (
            CLK => global_clk, 
            Datenbus => databus_all,
            CS => en_all,
            RW => rw_all,
            Adressbus => addrbus_all,
            StatusRegister => status,
            Steuersignale => command,
            RESET => main_reset,
            Init => x"0000");
        
    alu1 : ALU 
            generic map (
                datawidth => datawide
            )
            port map (
                clk => global_clk,
                data => databus_all,
                status => status,
                command => command 
            );
        
    clk   <= not clk  after 10 ns;  -- 100 MHz
    ram_clk <= clk;
    global_clk <= clk and clk_en; -- enable if initialization is done 
    
    with clk_en select en <=
        en_all when '1',
        'Z' when others;
        
    with clk_en select rw <=
        rw_all when '1',
        'Z' when others;
    
    with clk_en select addrbus <=
        addrbus_all when '1',
        (others => 'Z') when others;
    
    with clk_en select databus <=
        databus_all when '1',
        (others => 'Z')  when others;

    test_proc: process (clk) is
        file read_file: text open read_mode is "i_file.txt";
            
        variable read_line : line;
        variable read_char : character; 
        variable read_vec : std_logic_vector(datawide-1 downto 0); 
        variable read_end : boolean;
            
    begin
        if falling_edge(clk) then 
            case init is
                when reset =>   -- set dfoult values 
                    addrbus <= (others => '0');
                    databus <= (others => '0'); 
                    en <= '1';
                    rw <= '0';
                    init <= fill_mem_1;
                    
                when fill_mem_1 =>  -- read new line
                    readline(read_file, read_line);
                    init <= fill_mem_2;
                    
                when fill_mem_2 =>  -- read first char    
                    read(read_line, read_char, read_end);
                    if read_char = '0' then -- possible hex number (first part)
                        init <= fill_mem_3;
                    elsif read_char = '/' then -- Comment
                        read_end := false;
                    end if; 
                    if not read_end then -- line end or comment
                        if endfile(read_file) then -- file end
                            init <= ready;
                        else 
                            init <= fill_mem_1; -- goto read new line
                        end if; 
                    end if;

                when fill_mem_3 =>  -- read secound char 
                    read(read_line, read_char);
                    if read_char = 'x' then -- possible hex number (secound part)
                        init <= fill_mem_4; -- goto read hex
                    else 
                        init <= fill_mem_2;
                    end if;    
                              
                when fill_mem_4 =>  -- read hex number
                    hread(read_line, read_vec);
                    databus <= read_vec;
                    en <= '0';  -- write to memory
                    init <= fill_mem_5; 
                                   
                when fill_mem_5 =>  -- update counter
                    en <= '1';
                    addrbus <= addrbus + 1;
                    init <= fill_mem_2; 
                    if addrbus = (addrbus'range => '1') then 
                        init <= ready;
                        Report "Memmory full!" severity warning;
                    end if; 
                    
                when ready =>   -- memory init done / reset control signals
                     en <= 'Z';
                     rw <= 'Z';
                     addrbus <= (others => 'Z');
                     databus <= (others => 'Z');
                     clk_en <= '1'; 
                     init <= run;
                     main_reset <= '1';
                     
                when run =>     -- run main simmulation
                    main_reset <= '0';
                    -- Init Done
                    -- simulation code for Running CPU
            end case; 
        end if; 
    end process test_proc;
    
end Behavioral;
