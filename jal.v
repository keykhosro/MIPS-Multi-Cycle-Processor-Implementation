
`timescale 1ns/100ps

   `define ADD  4'b0000
   `define SUB  4'b0001
   `define SLT  4'b0010
   `define SLTU 4'b0011
   `define AND  4'b0100
   `define OR   4'b0101
   `define XOR  4'b0110
   `define NOR  4'b0111
   `define LUI  4'b1011
   `define SUBU  4'b1001
   `define ADDU  4'b1000

module multi_cycle_mips(

   input clk,
   input reset,

   // Memory Ports
   output  [31:0] mem_addr,
   input   [31:0] mem_read_data,
   output  [31:0] mem_write_data,
   output         mem_read,
   output         mem_write
);

   // Data Path Registers
   reg MRE, MWE;
   reg [31:0] A, B, PC, IR, MDR, MAR;

   // Data Path Control Lines, donot forget, regs are not always regs !!
   reg setMRE, clrMRE, setMWE, clrMWE;
   reg Awrt, Bwrt, RFwrt, PCwrt, IRwrt, MDRwrt, MARwrt, start;

   // Memory Ports Binding
   assign mem_addr = MAR;
   assign mem_read = MRE;
   assign mem_write = MWE;
   assign mem_write_data = B;

   // Mux & ALU Control Lines
   reg [3:0] aluOp;
   reg [2:0] MemtoReg;
   reg [1:0] aluSelB, RegDst, IorD, pcsrc;
   reg SgnExt, aluSelA;

   // Wiring
   wire aluZero, ready;
   wire [31:0] aluResult, rfRD1, rfRD2;
   wire [63:0] Product;

   // Clocked Registers
   always @( posedge clk ) begin
      if( reset )
         PC <= #0.1 32'h00000000;
      else if( PCwrt )
         PC <= #0.1 (pcsrc == 2'b00) ? aluResult :
                    (pcsrc == 2'b01) ? {PC[31:28],IR[25:0],2'b00} :
                    (pcsrc == 2'b10) ? A : 32'bx ;

      if( Awrt ) A <= #0.1 rfRD1;
      if( Bwrt ) B <= #0.1 rfRD2;

      if( MARwrt ) MAR <= #0.1 (IorD == 2'b00) ? PC :
                               (IorD == 2'b01) ? aluResult :
                               (IorD == 2'b10) ? {PC[31:28],IR[25:0],2'b00} : A ;

      if( IRwrt ) IR <= #0.1 mem_read_data;
      if( MDRwrt ) MDR <= #0.1 mem_read_data;

      if( reset | clrMRE ) MRE <= #0.1 1'b0;
         else if( setMRE ) MRE <= #0.1 1'b1;

      if( reset | clrMWE ) MWE <= #0.1 1'b0;
         else if( setMWE ) MWE <= #0.1 1'b1;
   end

   // Register File
   reg_file rf(
      .clk( clk ),
      .write( RFwrt ),

      .RR1( IR[25:21] ),
      .RR2( IR[20:16] ),
      .RD1( rfRD1 ),
      .RD2( rfRD2 ),

      .WR( (RegDst == 2'b00) ? IR[20:16] :
           (RegDst == 2'b01) ? IR[15:11] :
           (RegDst == 2'b10) ? 5'b11111  : 5'bx ),
      .WD( (MemtoReg == 3'b000) ? aluResult :
           (MemtoReg == 3'b001) ? MDR :
           (MemtoReg == 3'b010) ? Product[31:0] :
           (MemtoReg == 3'b011) ? Product[63:32] : PC )
   );

   // Sign/Zero Extension
   wire [31:0] SZout = SgnExt ? {{16{IR[15]}}, IR[15:0]} : {16'h0000, IR[15:0]};

   // ALU-A Mux
   wire [31:0] aluA = aluSelA ? A : PC;

   // ALU-B Mux
   reg [31:0] aluB;
   always @(*)
   case (aluSelB)
      2'b00: aluB = B;
      2'b01: aluB = 32'h4;
      2'b10: aluB = SZout;
      2'b11: aluB = SZout << 2;
   endcase

   my_alu alu(
      .A( aluA ),
      .B( aluB ),
      .Op( aluOp ),

      .X( aluResult ),
      .Z( aluZero )
   );

   multiplier my_multiplier(
      .clk( clk ),
      .start( start ),
      .A( A ),
      .B( B ),
   
      .Product( Product ),
      .ready( ready )
   );

   
   // Controller State Registers
   reg [4:0] state, nxt_state;

   // State Names & Numbers
   localparam
      RESET = 0, FETCH1 = 1, FETCH2 = 2, FETCH3 = 3, DECODE = 4,
      EX_ALU_R = 7, ALU_I = 8,
      LW_1 = 11, LW_2 = 12, LW_3 = 13, LW_4 = 14, LW_5 = 15,
      SW_1 = 21, SW_2 = 22, SW_3 = 23,
      BRA_1 = 25, BRA_2 = 26,
      MULTU_1 = 17, MULTU_2 = 18, MF = 19,
      J = 5, JR = 6, JAL = 9, JALR = 10, JAL2 = 27, JALR2 = 28;

   // State Clocked Register
   always @(posedge clk)
      if(reset)
         state <= #0.1 RESET;
      else
         state <= #0.1 nxt_state;

   task PrepareFetch;
      begin
         IorD = 2'b00;
         setMRE = 1;
         MARwrt = 1;
         nxt_state = FETCH1;
      end
   endtask

   // State Machine Body Starts Here
   always @( * ) begin

      nxt_state = 'bx;

      aluOp = 'bx; SgnExt = 'bx;
      aluSelA = 'bx; aluSelB = 'bx;
      MemtoReg = 'bx; RegDst = 'bx;
      pcsrc = 'bx;

      PCwrt = 0; start = 0;
      Awrt = 0; Bwrt = 0;
      RFwrt = 0; IRwrt = 0;
      MDRwrt = 0; MARwrt = 0;
      setMRE = 0; clrMRE = 0;
      setMWE = 0; clrMWE = 0;

      case(state)

         RESET:
            PrepareFetch;

         FETCH1:
            nxt_state = FETCH2;

         FETCH2:
            nxt_state = FETCH3;

         FETCH3: begin
            IRwrt = 1;
            PCwrt = 1;
            pcsrc = 2'b00;
            clrMRE = 1;
            aluSelA = 0;
            aluSelB = 2'b01;
            aluOp = `ADD;
            nxt_state = DECODE;
         end

         DECODE: begin
            Awrt = 1;
            Bwrt = 1;
            case( IR[31:26] )
               6'b000_000:             // R-format
                  case( IR[5:3] )
                     3'b000: ;
                     3'b001:
                     case ( IR[2:0] )
                        3'b000: nxt_state = JR;
                        3'b001: nxt_state = JALR;
                     endcase
                     3'b010: nxt_state = MF;
                     3'b011: nxt_state = MULTU_1;
                     3'b100: nxt_state = EX_ALU_R;
                     3'b101: nxt_state = EX_ALU_R;
                     3'b110: ;
                     3'b111: ;
                  endcase

               6'b001_000,             // addi
               6'b001_001,             // addiu
               6'b001_010,             // slti
               6'b001_011,             // sltiu
               6'b001_100,             // andi
               6'b001_101,             // ori
               6'b001_110,             // xori
               6'b001_111:             // lui
                  nxt_state = ALU_I;

               6'b100_011:
                  nxt_state = LW_1;

               6'b101_011:
                  nxt_state = SW_1;

               6'b000_010:
                  nxt_state = J;

               6'b000_011:
                  nxt_state = JAL;

               6'b000_100,
               6'b000_101:
                  nxt_state = BRA_1;
                  
                         

            endcase
         end
     EX_ALU_R: begin
            case(IR[5:0])
              6'b100000 :
              begin
                   
                aluSelA = 1'b1;
                aluSelB=  2'b00;
                aluOp = `ADD; 
                RegDst= 2'b01;
                MemtoReg=3'b000;
                RFwrt=  1'b1;
                PrepareFetch;
              
              end
              
              6'b100010:
              begin
                aluSelA = 1'b1;
                
                aluSelB=  2'b00;
                aluOp = `SUB;
                RegDst= 1'b1;
                MemtoReg=3'b000;
                RFwrt=  1'b1;
                PrepareFetch;
              end
              
              6'b 100001:
              begin
                   
                aluSelA = 1'b1;
                aluSelB=  2'b00;
                aluOp = `ADDU; 
                RegDst= 2'b01;
                MemtoReg=3'b000;
                RFwrt=  1'b1;
                PrepareFetch;
              end
              6'b 100011:
              begin
                aluSelA = 1'b1;
                
                aluSelB=  2'b00;
                aluOp = `SUBU;
                RegDst= 2'b01;
                MemtoReg=3'b000;
                RFwrt=  1'b1;
                PrepareFetch;
              end
              6'b 100100:
              begin
                aluSelA = 1'b1;
                
                aluSelB=  2'b00;
                aluOp = `AND;
                RegDst= 2'b01;
                MemtoReg=3'b000;
                RFwrt=  1'b1;
                PrepareFetch;
              end
              6'b 100101:
              begin
                aluSelA = 1'b1;
                
                aluSelB=  2'b00;
                aluOp = `OR;
                RegDst= 2'b01;
                MemtoReg=3'b000;
                RFwrt=  1'b1;
                PrepareFetch;
              end
              6'b 100110:
              begin
                aluSelA = 1'b1;
                
                aluSelB=  2'b00;
                aluOp = `XOR;
                RegDst= 2'b01;
                MemtoReg=3'b000;
                RFwrt=  1'b1;
                PrepareFetch;
              end
              6'b 100111:
              begin
                aluSelA = 1'b1;
               
                aluSelB=  2'b00;
                 aluOp = `NOR;
                RegDst= 2'b01;
                MemtoReg=3'b000;
                RFwrt=  1'b1;
                PrepareFetch;
              end

              6'b 101010:
              begin
                aluSelA = 1'b1;
                
                aluSelB=  2'b00;
                aluOp = `SLT;
                RegDst= 2'b01;
                MemtoReg=3'b000;
                RFwrt=  1'b1;
                PrepareFetch;
              end

              6'b 101011:
              begin
                aluSelA = 1'b1;
                
                aluSelB=  2'b00;
                aluOp = `SLTU;
                RegDst= 2'b01;
                MemtoReg=3'b000;
                RFwrt=  1'b1;
                PrepareFetch;
              end











         endcase
end





         ALU_I: begin
            case(IR[31:26])
              
              6'b001000:
              begin
                SgnExt=1'b1;
                aluSelA = 1'b1;
                aluSelB=  2'b10;
                aluOp = `ADD;
                RegDst= 2'b00;
                MemtoReg=3'b000;
                RFwrt=  1'b1;
                PrepareFetch;
                
              end
              
            
              6'b001001:
              begin
                SgnExt=1'b0;
                aluSelA = 1'b1;
                aluSelB=  2'b10;
                aluOp = `ADDU;
                RegDst= 2'b00;
                MemtoReg=3'b000;
                RFwrt=  1'b1;
                PrepareFetch;
                
              end  

              6'b001100:
              begin
                SgnExt=1'b0;
                aluSelA = 1'b1;
                aluSelB=  2'b10;
                aluOp = `AND;
                RegDst= 2'b00;
                MemtoReg=3'b000;
                RFwrt=  1'b1;
                PrepareFetch;
                
              end                
              
              6'b001101:
              begin
                SgnExt=1'b0;
                aluSelA = 1'b1;
                aluSelB=  2'b10;
                aluOp = `OR;
                RegDst= 2'b00;
                MemtoReg=3'b000;
                RFwrt=  1'b1;
                PrepareFetch;
                
              end  
              
               6'b001110:
              begin
                SgnExt=1'b0;
                aluSelA = 1'b1;
                aluSelB=  2'b10;
                aluOp = `XOR;
                RegDst= 2'b00;
                MemtoReg=3'b000;
                RFwrt=  1'b1;
                PrepareFetch;
                
              end  
              
              
              6'b001010:
              begin
                SgnExt=1'b1;
                aluSelA = 1'b1;
                aluSelB=  2'b10;
                aluOp = `SLT;
                RegDst= 2'b00;
                MemtoReg=3'b000;
                RFwrt=  1'b1;
                PrepareFetch;
                
              end  
              
              6'b001011:
              begin
                SgnExt=1'b0;
                aluSelA = 1'b1;
                aluSelB=  2'b10;
                aluOp = `SLTU;
                RegDst= 2'b00;
                MemtoReg=3'b000;
                RFwrt=  1'b1;
                PrepareFetch;
                
              end  
              
              
              6'b001111:
              begin
                
                SgnExt=1'b0;
                aluSelA = 1'b1;
                aluSelB=  2'b10;
                aluOp = `LUI;
                  RegDst= 2'b00;
                MemtoReg=3'b000;
                RFwrt=  1'b1;
                PrepareFetch;
                
              end
              ////////////////////
              
              
              
            endcase


end







         LW_1: begin
              SgnExt=1'b1;
          aluSelA = 1'b1;
          aluSelB=  2'b10;
          aluOp = `ADD;
          setMRE=1'b1;
          IorD=2'b01;
          MARwrt=1'b1; 
            nxt_state = LW_2;
         end

         LW_2: begin
            nxt_state = LW_3;
         end

         LW_3: begin
            nxt_state = LW_4;
         end

         LW_4: begin
            MDRwrt = 1;
            nxt_state = LW_5;
         end

         LW_5: begin
            RegDst = 2'b00;
            MemtoReg = 3'b001;
            RFwrt = 1'b1;
            PrepareFetch;
         end

         SW_1: begin
              SgnExt=1'b1;
          aluSelA = 1'b1;
          aluSelB=  2'b10;
          aluOp = `ADD;
          
          IorD=2'b01;            
          MARwrt=1'b1;  
            
            nxt_state = SW_2;
         end

         SW_2: begin
            setMWE = 1;
            nxt_state = SW_3;
         end

         SW_3: begin
            clrMWE = 1;
            PrepareFetch;
         end

         BRA_1: begin
              
          aluSelA = 1'b1;
          aluSelB=  2'b00;
          aluOp = `SUB;
          nxt_state=BRA_2;
          if(aluZero^IR[26])
            nxt_state=BRA_2;
          else
            PrepareFetch;
         end

         BRA_2: begin
              SgnExt=1'b1;
           aluSelA = 1'b0;
          aluSelB=  2'b11;
          aluOp = `ADD;
          
          PCwrt=1'b1;    
        pcsrc=2'b00;
        IorD=2'b01;
         setMRE = 1'b1;
         MARwrt = 1'b1; 
            nxt_state = FETCH1;
         end

         MULTU_1: begin
            start = 1'b1;
            nxt_state = MULTU_2;
         end

         MULTU_2: begin
            if ( ready==1 ) PrepareFetch;
            else nxt_state = MULTU_2;
         end

         MF: begin
            RegDst = 2'b01;
            RFwrt = 1;
            if ( IR[1] ) MemtoReg = 3'b010;
            else MemtoReg = 3'b011;
            PrepareFetch;
         end

         J: begin
            PCwrt = 1;
            pcsrc = 2'b01;
            IorD = 2'b10;
            setMRE = 1;
            MARwrt = 1;
            nxt_state = FETCH1;
         end

         JR: begin
            PCwrt = 1;
            pcsrc = 2'b10;
            IorD = 2'b11;
            setMRE = 1;
            MARwrt = 1;
            nxt_state = FETCH1;
         end

         JAL: begin
           aluSelA = 0;
            aluSelB = 2'b01;
            aluOp = `ADD;
            RegDst = 2'b10;
            MemtoReg = 3'b000;
            RFwrt = 1;
            
           nxt_state = JAL2;

         end

        JAL2:
        begin
          
              PCwrt = 1;
            pcsrc = 2'b01;
            IorD = 2'b10;
            setMRE = 1;
            MARwrt = 1;
            nxt_state = FETCH1;
          
          
        end

         JALR: begin
           
            aluSelA = 0;
            aluSelB = 2'b01;
            aluOp = `ADD;
            RegDst = 2'b10;
            MemtoReg = 3'b000;
            RFwrt = 1;
            
           nxt_state = JALR2;
           
         end
           JALR2:
           begin

            PCwrt = 1'b1;
            pcsrc = 2'b10;
            IorD = 2'b11;
            setMRE = 1;
            MARwrt = 1;
            nxt_state = FETCH1;
         end


      endcase

   end

endmodule

//==============================================================================


module my_alu(
   input [3:0] Op,
   input [31:0] A,
   input [31:0] B,

   output [31:0] X,
   output        Z
);

   wire sub = Op != `ADD;

   wire [31:0] bb = sub ? ~B : B;

   wire [32:0] sum = A + bb + sub;

   wire sltu = ! sum[32];       

   wire v = sub ?                                   // v refers to overflow ///
        ( A[31] != B[31] && A[31] != sum[31] )
      : ( A[31] == B[31] && A[31] != sum[31] );

   wire slt = v ^ sum[31];        
   wire [32:0] An , Bn;
   assign An={1'b 0,A[31:0]};
   assign Bn={1'b 0,B[31:0]};
   wire [33:0] sumun=An+Bn ;
   
   wire [33:0] subun = An - Bn;      //////////////
   
   reg [31:0] x;

   always @( * )
      case( Op )
         `ADD : x = sum;
         `SUB : x = sum;
         `SLT : x = slt;
         `SLTU: x = sltu;
         `AND : x =   A & B;
         `OR  : x =   A | B;
         `NOR : x = ~(A | B);
         `XOR : x =   A ^ B;
         `ADDU : x = sumun[31:0];
         `SUBU : x = subun[31:0];
         `LUI : x= B<<16;
         
         
         default : x = 32'hxxxxxxxx;
      endcase

   assign #2 X = x;
   assign #2 Z = x == 32'h00000000;

endmodule

//==============================================================================

module reg_file(
   input clk,
   input write,
   input [4:0] WR,
   input [31:0] WD,
   input [4:0] RR1,
   input [4:0] RR2,
   output [31:0] RD1,
   output [31:0] RD2
);

   reg [31:0] rf_data [0:31];

   assign #2 RD1 = rf_data[ RR1 ];
   assign #2 RD2 = rf_data[ RR2 ];

   always @( posedge clk ) begin
      if ( write )
         rf_data[ WR ] <= WD;

      rf_data[0] <= 32'h00000000;
   end

endmodule

//==============================================================================

module multi2(input clk,input start,input [31:0] A,input [31:0] B,output reg [63:0] product,output ready );

wire [32:0] adderout;
reg [5:0] counter;
wire allow;
wire [31:0] almulti;
assign allow=product[0];
assign almulti=allow?A:0;
assign adderout=almulti+product[63:32];
assign ready=counter[5];
always@(posedge clk)
begin
if(start)
begin
counter = 6'b000000;
product = {32'h00000000,B};
end
else if(! ready)
begin
counter=counter+1;
product=product>>1;
product [63:31] =adderout;
end
end
endmodule



//==============================================================================
