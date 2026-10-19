`include"spi.sv"
`timescale 1ns/1ps

typedef enum bit [2:0]{
		IDLE = 3'b001,
		ADDR = 3'b010,
		DATA = 3'b100 }tb_state;

module tb;
parameter NUM_TXS=8;
parameter ADDR_WIDTH=8;
parameter DATA_WIDTH=8;
////////// FSM-MISO idle->addr->data ////////////
//parameter S_IDLE = 3'b001;
//parameter S_ADDR = 3'b010;
//parameter S_DATA = 3'b100;

reg  pclk_i,psel_i,prst_i,pwrite_i,penable_i;
reg  [ADDR_WIDTH-1:0]paddr_i;
reg  [DATA_WIDTH-1:0]pwdata_i;
wire [DATA_WIDTH-1:0]prdata_o;
wire pready_o;

reg  sclk_ref_i;
wire sclk_o;
wire mosi;
reg	 miso;
wire [3:0]ssel;
wire intr_o;

//////////// INTERNAL_CONNECTIONS ////////////
tb_state state,n_state;
reg [ADDR_WIDTH-1:0]addr_collected;
reg [DATA_WIDTH-1:0]data_collected;
reg [DATA_WIDTH-1:0]data_to_drive;
reg [DATA_WIDTH-2:0]tx_data;
reg [ADDR_WIDTH-1:0]mem[128-1:0];
integer i;
integer count;

spi dut(.*);
/////////// or ////////////    
/*spi dut(
		//processor(APB)
		.pclk_i(pclk_i),
		.psel_i(psel_i),
		.prst_i(prst_i),
		.paddr_i(paddr_i),
		.pwdata_i(pwdata_i),
		.prdata_o(prdata_o),
		.pwrite_i(pwrite_i),
		.penable_i(penable_i),
		.pready_o(pready_o),
		//spi
		.sclk_o(sclk_o),
		.mosi(mosi),
		.miso(miso),
		.ssel(ssel),
		.intr_o(intr_o)
);*/

initial begin
pclk_i=0;
forever#5 pclk_i=~pclk_i;
end

initial begin
sclk_ref_i=1;
forever#1 sclk_ref_i=~sclk_ref_i;
end

initial begin
////////////////// WRITE-READ ////////////////////////
//  seed=09876542;//098765432;
//  reset();
//	write();
//	read();
//	#500;$finish;
///////////////// WR_RD,CTRL_REG_TASK ////////////////
	reset();
	write_addr_dataA();
	read();
	#300;
	write_ctrl_reg(3'h0);
	#100;
	write_ctrl_reg(3'h4);
	#500;
	#1000;$finish;
//////////////////////////////////////////////////////
end

////////// FSM-MISO idle->addr->data ////////////
always@(n_state) state = n_state;
always@(posedge sclk_o)begin
if(prst_i==0)begin
	case(state)
		IDLE:begin
			n_state			= ADDR;
			count			= 0;
			addr_collected 	= 0;
			data_collected 	= 0;
		end
		ADDR:begin
		miso	= 1;
		addr_collected[count] = mosi;
		count = count + 1;
			if(count==8)begin
				if(addr_collected[7]==0)begin
					data_to_drive=mem[addr_collected[6:0]];
					$display("data_to_drive %0h",data_to_drive);
				end
				n_state = DATA;
				count	= 0;
			end
		end
		DATA:begin
			if(addr_collected[7]) data_collected[count]=mosi;
			else miso = data_to_drive[count];
				$display("mosi_data_to_drive %0h",miso);
			data_collected[count] = mosi;
			count = count + 1;
			if(count==8)begin
				if(addr_collected[7]==1)begin
					tx_data 		= addr_collected[6:0];
					mem[tx_data]	= data_collected;
				end

			$display("data i mem %p",mem);	
			n_state			= ADDR;
			count 			= 0;
			addr_collected	= 0;
			data_collected	= 0;
			end
		end
	endcase
end
end
//////////////// REST_ALL_SIGNAL_TASK ///////////
task reset();
begin
	prst_i			= 1;
	penable_i		= 0;
	psel_i			= 0;
	pwrite_i		= 0;
	pwdata_i		= 0;
	paddr_i			= 0;
 	miso          	= 1;
	state			= IDLE;
	n_state			= IDLE;
	addr_collected	= 0;
	data_collected	= 0;
	count			= 0;
	@(posedge pclk_i);
	prst_i=0;
end
endtask

//////////////// WRITE_ADDR_DATA_TASK ///////////
task write_addr_dataA();
begin
	//addr_regA
	for(i=0;i<NUM_TXS;i=i+1)begin
	    @(posedge pclk_i);
		paddr_i     =i;
		pwrite_i	=1;
		pwdata_i    =8'hd3+i;
		penable_i	=1;
		wait(pready_o==1);
	
		@(posedge pclk_i);
	   	paddr_i		=0;
		pwrite_i	=0;
		pwdata_i	=0;
		penable_i	=0;
	end
	//data_regA
	for(i=0;i<NUM_TXS;i=i+1)begin
	    @(posedge pclk_i);
		paddr_i     =8'h10+i;
		pwrite_i	=1;
		pwdata_i    =8'h43+i;
		penable_i	=1;
		wait(pready_o==1);
	
		@(posedge pclk_i);
	   	paddr_i		=0;
		pwrite_i	=0;
		pwdata_i	=0;
		penable_i	=0;
	end	
end
endtask
//////////////// CTRL_REG_TASK /////////////////
task write_ctrl_reg(input [2:0]num_tx);
begin
		//ctrl_reg
	    @(posedge pclk_i);
		paddr_i			= 8'h20;
		pwrite_i		= 1;
		//pwdata_i		= {4'h0,num_tx,1'b1};
		pwdata_i[7:4]	= 4'h0;
		pwdata_i[3:1]	= num_tx;
		pwdata_i[0]		= 1;
		penable_i		= 1;
		wait(pready_o==1);
	
		@(posedge pclk_i);
	   	paddr_i		=0;
		pwrite_i	=0;
		pwdata_i	=0;
		penable_i	=0;

end
endtask

////////////// WRITE TASK ///////////////////////
task write();
begin
	//addr_regA
	for(i=0;i<NUM_TXS;i=i+1)begin
	    @(posedge pclk_i);
		paddr_i     =i;
		pwrite_i	=1;
		pwdata_i    =8'hd3+i;
		penable_i	=1;
		wait(pready_o==1);
	
		@(posedge pclk_i);
	   	paddr_i		=0;
		pwrite_i	=0;
		pwdata_i	=0;
		penable_i	=0;
	end
	//data_regA
	for(i=0;i<NUM_TXS;i=i+1)begin
	    @(posedge pclk_i);
		paddr_i     =8'h10+i;
		pwrite_i	=1;
		pwdata_i    =8'h46+i;
		penable_i	=1;
		wait(pready_o==1);
	
		@(posedge pclk_i);
	   	paddr_i		=0;
		pwrite_i	=0;
		pwdata_i	=0;
		penable_i	=0;
	end	
		@(posedge pclk_i);
		paddr_i     =8'h20;
		pwrite_i	=1;
		pwdata_i    ={4'h0,3'h5,1'b1};
		penable_i	=1;
		wait(pready_o==1);
	
		@(posedge pclk_i);
	   	paddr_i		=0;
		pwrite_i	=0;
		pwdata_i	=0;
		penable_i	=0;
end
endtask

///////////////// READ_TASK /////////////////////
task read();
begin
	//addr_regA
	for(i=0;i<NUM_TXS;i=i+1)begin
	    @(posedge pclk_i);
		paddr_i     =i;
		pwrite_i	=0;
		penable_i	=1;
		wait(pready_o==1);
	
		@(posedge pclk_i);
	   	paddr_i		=0;
		penable_i	=0;
	end
	//data_regA
	for(i=0;i<NUM_TXS;i=i+1)begin
	    @(posedge pclk_i);
		paddr_i     =8'h10+i;
		pwrite_i	=0;
		penable_i	=1;
		wait(pready_o==1);
	
		@(posedge pclk_i);
	   	paddr_i		=0;
		penable_i	=0;
	end
	//ctrl_reg
		@(posedge pclk_i);
		paddr_i     =8'h20;
		pwrite_i	=0;
		penable_i	=1;
		wait(pready_o==1);
	
		@(posedge pclk_i);
	   	paddr_i		=0;
		penable_i	=0;	
end
endtask

endmodule


