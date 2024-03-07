-- cpu.vhd: Simple 8-bit CPU (BrainFuck interpreter)
-- Copyright (C) 2022 Brno University of Technology,
--                    Faculty of Information Technology
-- Author(s): Barta Stepan <xbarta50@stud.fit.vutbr.cz>
--
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

-- ----------------------------------------------------------------------------
--                        Entity declaration
-- ----------------------------------------------------------------------------
entity cpu is
 port (
   CLK   : in std_logic;  -- hodinovy signal
   RESET : in std_logic;  -- asynchronni reset procesoru
   EN    : in std_logic;  -- povoleni cinnosti procesoru
 
   -- synchronni pamet RAM
   DATA_ADDR  : out std_logic_vector(12 downto 0); -- adresa do pameti
   DATA_WDATA : out std_logic_vector(7 downto 0); -- mem[DATA_ADDR] <- DATA_WDATA pokud DATA_EN='1'
   DATA_RDATA : in std_logic_vector(7 downto 0);  -- DATA_RDATA <- ram[DATA_ADDR] pokud DATA_EN='1'
   DATA_RDWR  : out std_logic;                    -- cteni (0) / zapis (1)
   DATA_EN    : out std_logic;                    -- povoleni cinnosti
   
   -- vstupni port
   IN_DATA   : in std_logic_vector(7 downto 0);   -- IN_DATA <- stav klavesnice pokud IN_VLD='1' a IN_REQ='1'
   IN_VLD    : in std_logic;                      -- data platna
   IN_REQ    : out std_logic;                     -- pozadavek na vstup data
   
   -- vystupni port
   OUT_DATA : out  std_logic_vector(7 downto 0);  -- zapisovana data
   OUT_BUSY : in std_logic;                       -- LCD je zaneprazdnen (1), nelze zapisovat
   OUT_WE   : out std_logic                       -- LCD <- OUT_DATA pokud OUT_WE='1' a OUT_BUSY='0'
 );
end cpu;


-- ----------------------------------------------------------------------------
--                      Architecture declaration
-- ----------------------------------------------------------------------------
architecture behavioral of cpu is

  --PC
  signal pc_reg : std_logic_vector (11 downto 0);
  signal pc_inc : std_logic;
  signal pc_dec : std_logic;
  --PC
  --PTR
  signal ptr_reg : std_logic_vector (11 downto 0);
  signal ptr_inc : std_logic;
  signal ptr_dec : std_logic;
  --PTR
  --CNT
  signal cnt_reg : std_logic_vector (11 downto 0);
  signal cnt_inc : std_logic;
  signal cnt_dec : std_logic;
  signal cnt_signal : std_logic;
  --CNT
  --STATES
  type fsm_state is (
    s_start,
    s_fetch,
    s_decode,
    s_program_inc,
    s_program_dec,
    s_pointer_inc,
    s_pointer_dec,
    s_while_start,
    s_while_end,
    s_dowhile_start,
    s_dowhile_end,
    s_write,
    s_get,
    s_null,
    s_program_mx_inc,
    s_program_mx_dec,
    s_program_end_inc,
    s_program_end_dec,
    s_get_done,
    s_wait,
    s_write2,
    s_get_done_done,
    s_while_start1,
    s_while_start2,
    s_while_start3,
    s_while_end2,
    s_while_end3,
    s_while_end4,
    a,
    b,
    s_dowhile_end2,
    s_dowhile_end3,
    s_dowhile_end4,
    c
  );
  signal state : fsm_state := s_start;
  signal nState : fsm_state;
  --STATES

  --MUX 1
  signal mx_select_small : std_logic := '0';
  signal mx_output_small : std_logic_vector (12 downto 0) := (others => '0');
  --MUX
  --MUX 2
  signal mx_select_big : std_logic_vector (1 downto 0) := (others => '0');
  signal mx_output_big : std_logic_vector (7 downto 0) := (others => '0');
  --MUX

begin
  --PC
  pc: process (CLK, RESET, pc_inc, pc_dec) is
    begin
      if RESET = '1' then
        pc_reg <= (others => '0');
      elsif rising_edge(CLK) then
          if pc_inc = '1' then
            pc_reg <= pc_reg + 1;
          elsif pc_dec = '1' then
            pc_reg <= pc_reg - 1;
          end if;
      end if;
    end process;
  --PTR
  ptr: process (CLK, RESET, ptr_inc, ptr_dec) is
    begin
      if RESET = '1' then
        ptr_reg <= (others => '0');
      elsif rising_edge(CLK) then
          if ptr_inc = '1' then
            ptr_reg <= ptr_reg + 1;
          elsif ptr_dec = '1' then
            ptr_reg <= ptr_reg - 1;
          end if;
      end if;
    end process;      
  --CNT
  cnt: process (CLK, RESET, cnt_inc, cnt_dec, cnt_signal) is
    begin
      if RESET = '1' then
        cnt_reg <= (others => '0');
      elsif rising_edge(CLK) then
          if cnt_inc = '1' then
            cnt_reg <= cnt_reg + 1;
          elsif cnt_dec = '1' then
            cnt_reg <= cnt_reg - 1;
          elsif cnt_signal = '1' then
            cnt_reg <= "000000000001";
          end if;
      end if;
    end process;

  mux_small: process (CLK, RESET, mx_select_small) is
    begin
      if RESET = '1' then
        mx_output_small <= (others => '0');
      elsif rising_edge(CLK) then
        case mx_select_small is
          when '0' =>
            mx_output_small <= '0' & pc_reg;
          when '1' =>
            mx_output_small <= '1' & ptr_reg;
          when others =>
            mx_output_small <= (others => '0');
          end case;
      end if;
    end process;
    DATA_ADDR <= mx_output_small;     

  mux_big: process (CLK, RESET, mx_select_big) is
    begin
      if RESET = '1' then
        mx_output_big <= (others => '0');
      elsif rising_edge(CLK) then
        case mx_select_big is
          when "00" =>
            mx_output_big <= IN_DATA;
          when "01" =>
            mx_output_big <= DATA_RDATA + 1;
          when "10" =>
            mx_output_big <= DATA_RDATA - 1;
          when others =>
            mx_output_big <= (others => '0');
        end case;
      end if;
    end process;
    DATA_WDATA <= mx_output_big;

  state_logic: process (CLK, RESET, EN) is
    begin
      if RESET = '1' then
        state <= s_start;
      elsif rising_edge(CLK) then
        if EN = '1' then
          state <= nState;
        end if;
      end if;
    end process;
  
  fsm: process (state, OUT_BUSY, IN_VLD, DATA_RDATA, EN) is--counter by mel asi jeste byt 47:20
    begin
      pc_inc <= '0';
      pc_dec <= '0';
      ptr_inc <= '0';
      ptr_dec <= '0';
      cnt_inc <= '0';
      cnt_dec <= '0';
      cnt_signal <= '0';

      DATA_EN <= '0';
      OUT_WE <= '0';
      IN_REQ <= '0';
      DATA_RDWR <= '0';


      mx_select_small <= '0';
      mx_select_big <= "00";

      case state is
        when s_start =>
          nState <= s_fetch;
        when s_fetch =>
        mx_select_small <= '1';
          DATA_EN <= '1';
          nState <= s_decode;
        when s_decode =>
          case DATA_RDATA is
            when x"3E" =>
              nState <= s_pointer_inc;
            when x"3C" =>
              nState <= s_pointer_dec;
            when x"2B" =>
            mx_select_small <= '1';
              nState <= s_program_inc;
            when x"2D" =>
            mx_select_small <= '1';
              nState <= s_program_dec;
            when x"5B" =>
            mx_select_small <= '1';
            DATA_EN <= '1';
            DATA_RDWR <= '0';
              nState <= s_while_start;
            when x"5D" =>
            mx_select_small <= '1';
            DATA_EN <= '1';
            DATA_RDWR <= '0';
              nState <= s_while_end;
            when x"28" =>
            mx_select_small <= '1';
            DATA_EN <= '1';
            DATA_RDWR <= '0';
              nState <= s_dowhile_start;
            when x"29" =>
            mx_select_small <= '1';
            DATA_EN <= '1';
            DATA_RDWR <= '0';
              nState <= s_dowhile_end;
            when x"2E" =>
              mx_select_small <= '1';
              nState <= s_write;
            when x"2C" =>
            mx_select_small <= '1';
              nState <= s_get;
            when x"00" =>
              nState <= s_null;
            when others =>
              pc_inc <= '1';
              nState <= s_wait;
            end case;

        when s_pointer_inc =>
          pc_inc <= '1';
          ptr_inc <= '1';
          nState <= s_wait;
        when s_pointer_dec =>
          pc_inc <= '1';
          ptr_dec <= '1';
          nState <= s_wait;

        when s_program_inc => 
          mx_select_small <= '1';
          DATA_EN <= '1';
          DATA_RDWR <= '0';
          nState <= s_program_mx_inc;
        when s_program_mx_inc =>
          mx_select_small <= '1';
          mx_select_big <= "01";
          nState <= s_program_end_inc;
        when s_program_end_inc =>
          mx_select_small <= '1';
          DATA_EN <= '1';
          DATA_RDWR <= '1';
          pc_inc <= '1';
          nState <= s_wait;
        
        when s_wait =>
          nState <= s_fetch;

        when s_program_dec =>
          mx_select_small <= '1';
          DATA_EN <= '1';
          DATA_RDWR <= '0';
          nState <= s_program_mx_dec;
        when s_program_mx_dec =>
          mx_select_small <= '1';
          mx_select_big <= "10";
          nState <= s_program_end_dec;
        when s_program_end_dec =>
          mx_select_small <= '1';
          DATA_EN <= '1';
          DATA_RDWR <= '1';
          pc_inc <= '1';
          nState <= s_wait;
        --------------------------
        when s_while_start =>
        mx_select_small <= '1';
          DATA_EN <= '1';
          pc_inc <= '1'; 
          DATA_RDWR <= '0';
          nState <= s_while_start1;

        when s_while_start1 =>
        mx_select_small <= '1';
            if DATA_RDATA = "00000000" then
              cnt_signal <= '1';
              DATA_EN <= '1';
              nState <= s_while_start2;
            else
              nState <= s_wait;
            end if;

        when s_while_start2 =>
            if cnt_reg = "000000000000" then
              nState <= s_wait;
            else
            mx_select_small <= '0';
              nState <= s_while_start3;
            end if;

        when s_while_start3 =>
        mx_select_small <= '0';
              if DATA_RDATA = x"5B" then
                cnt_inc <= '1';
              elsif DATA_RDATA = x"5D" then
                cnt_dec <= '1';
              end if;
            pc_inc <= '1';
            DATA_EN <= '1';
            nState <= s_while_start2;

        when s_while_end =>
          if DATA_RDATA = "00000000" then
            pc_inc <= '1';
            nState <= s_wait;
          else
            cnt_signal <= '1';
            pc_dec <= '1';
            nState <= a;
          end if;
        
        when a =>
            nState <= s_while_end2;

      
        when s_while_end2 =>
        if cnt_reg /= "000000000000" then
          DATA_RDWR <= '0';
          DATA_EN <= '1';
          mx_select_small <= '0';
          nState <= s_while_end3;
        else
          nState <= s_wait;
        end if;
        
        
        when s_while_end3 =>
        mx_select_small <= '0';
              if DATA_RDATA = x"5D" then
                cnt_inc <= '1';
              elsif DATA_RDATA = x"5B" then
                cnt_dec <= '1';
              end if;
              nState <= s_while_end4;
        
        when s_while_end4 =>
          if cnt_reg = "000000000000" then
            pc_inc <= '1';
          else
            pc_dec <= '1'; 
          end if;
          nState <= a;

        when s_dowhile_start =>
          pc_inc <= '1';
          nState <= s_wait;

        when s_dowhile_end =>
        if DATA_RDATA = "00000000" then
          pc_inc <= '1';
          nState <= s_wait;
        else
          cnt_signal <= '1';
          pc_dec <= '1';
          nState <= b;
        end if;

        when b =>
          nState <= s_dowhile_end2;

          when s_dowhile_end2 =>
          if cnt_reg /= "000000000000" then
            DATA_RDWR <= '0';
            DATA_EN <= '1';
            mx_select_small <= '0';
            nState <= s_dowhile_end3;
          else
            nState <= s_wait;
          end if;

          when s_dowhile_end3 =>
          mx_select_small <= '0';
                if DATA_RDATA = x"29" then
                  cnt_inc <= '1';
                elsif DATA_RDATA = x"28" then
                  cnt_dec <= '1';
                end if;
                nState <= c;

          when c =>
            nState <= s_dowhile_end4;


          when s_dowhile_end4 =>
          if cnt_reg = "000000000000" then
            pc_inc <= '1';
          else
            pc_dec <= '1'; 
          end if;
          nState <= b;

        when s_write =>
              mx_select_small <= '1';
              DATA_EN <= '1';
              DATA_RDWR <= '0';
              nState <= s_write2;
        when s_write2 =>
              if OUT_BUSY = '1' then
                mx_select_small <= '1';
                DATA_EN <= '1';
                DATA_RDWR <= '0';
                nState <= s_write2;
              else
                OUT_WE <= '1';
                OUT_DATA <= DATA_RDATA;
                pc_inc <= '1';
                nState <= s_wait;
              end if;

        when s_get =>
        mx_select_small <= '1';
              IN_REQ <= '1';
              mx_select_big <= "00";
              nState <= s_get_done;
        when s_get_done =>
        mx_select_small <= '1';
              if IN_VLD /= '1' then
                IN_REQ <= '1';
                mx_select_big <= "00";
                nState <= s_get_done;
              else
                nState <= s_get_done_done;
              end if;
        when s_get_done_done =>
          DATA_EN <= '1';
          DATA_RDWR <= '1';
          pc_inc <= '1';
          nState <= s_wait;

        when s_null =>
          nState <= s_null;
      end case;
    end process;
end behavioral;

