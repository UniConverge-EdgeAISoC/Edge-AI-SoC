typedef enum bit [4:0]{
			S_IDLE					= 5'b00001,
			S_ADDR					= 5'b00010,
			S_IDLE_BW_ADDR_DATA		= 5'b00100,
			S_DATA					= 5'b01000,
			S_IDLE_WITH_TXS_PANDING	= 5'b10000
	}state_t;
module spi(
///////////////////// processor(APB) ///////////////////
pclk_i,psel_i,prst_i,paddr_i,pwdata_i,prdata_o,pwrite_i,penable_i,pready_o,
//////////////////// spi ///////////////////////////////
sclk_ref_i,sclk_o,mosi,miso,ssel,intr_o
);

parameter NUM_TXS	 = 8;
parameter ADDR_WIDTH = 8;
parameter DATA_WIDTH = 8;

////////////// FSM-IDLE->WRITE->WAIT->READ->TX_PENDING ////////
//	parameter S_IDLE					= 5'b00001;
//	parameter S_ADDR					= 5'b00010;
//	parameter S_IDLE_BW_ADDR_DATA		= 5'b00100;
//	parameter S_DATA					= 5'b01000;
//	parameter S_IDLE_WITH_TXS_PANDING	= 5'b10000;
///////////////// PROCESSOR I/O-PORTS //////////////////////////
input 		pclk_i,psel_i,prst_i,pwrite_i,penable_i;
input 		[ADDR_WIDTH-1:0]paddr_i;
input 		[DATA_WIDTH-1:0]pwdata_i;
output reg  [DATA_WIDTH-1:0]prdata_o;
output reg 	pready_o;
//////////////// SPI_CTRL I/O-PORTS ////////////////////////////
input 		sclk_ref_i;
output reg 	sclk_o;
output reg 	mosi;
input 		miso;
output reg 	[3:0]ssel;
output reg	intr_o;

///////////////// declarin register ////////////////////////////
reg [ADDR_WIDTH-1:0]addr_regA[NUM_TXS-1:0];
reg [DATA_WIDTH-1:0]data_regA[NUM_TXS-1:0];
reg [DATA_WIDTH-1:0]ctrl_reg;

//////////////// INTERNAL REG_VALUE ////////////////////////////
//reg [4:0]state;
//reg [4:0]n_state;
state_t state,n_state;
reg [3:0]next_tx_idx;
reg [2:0]num_pending_txs;
reg [ADDR_WIDTH-1:0]addr_to_drive;
reg [DATA_WIDTH-1:0]data_to_drive;
reg [DATA_WIDTH-1:0]collect_slave_data;
reg sclk_running_flag;
integer i;
integer count;

//assign state  = n_state;
assign sclk_o = sclk_running_flag ? sclk_ref_i:1'b1;
///////// or /////////
always@(n_state) state=n_state;
//always@(posedge sclk_ref_i)begin
//	if(sclk_running_flag) sclk_o=~sclk_o;
//	else sclk_o = 1; 
//end
//////////////// DESIGN ////////////////////////////////////////
always@(posedge pclk_i)begin
	if(prst_i==1)begin
		pready_o			= 0;
		prdata_o			= 0;
		mosi				= 1;
		ssel				= 4'b0000; 
		state				= S_IDLE;
		next_tx_idx			= 0;
		num_pending_txs 	= 0;
		addr_to_drive		= 0;
		data_to_drive		= 0;
		collect_slave_data 	= 0;
		sclk_running_flag  	= 0;
		count				= 0;
		ctrl_reg			= 0;

		for(i=0;i<NUM_TXS;i=i+1)begin
			addr_regA[i] = 0;
			data_regA[i] = 0;
		end
	end
	else begin
		if(penable_i) begin
			pready_o=1;
			if(pwrite_i) begin
				if(paddr_i>=8'h0 && paddr_i<=8'h7)begin
					addr_regA[paddr_i] = pwdata_i;
				end
				if(paddr_i>=8'h10 && paddr_i<=8'h17)begin
					data_regA[paddr_i-8'h10] = pwdata_i;
				end
				if(paddr_i==8'h20)begin
					ctrl_reg[3:0] = pwdata_i[3:0];
				end
			end
			else begin
				if(paddr_i>=8'h0 && paddr_i<=8'h7)begin
					prdata_o = addr_regA[paddr_i];
				end
				if(paddr_i>=8'h10 && paddr_i<=8'h17)begin
					prdata_o = data_regA[paddr_i-8'h10];
				end
				if(paddr_i==8'h20)begin
					prdata_o = ctrl_reg;
				end
			end
		end
		else pready_o=0;
 	end
end
////////////// FSM-IDLE->WRITE->WAIT->READ->TX_PENDING ////////
always@(posedge sclk_ref_i)begin
if(prst_i==0)begin
		case(state)
			S_IDLE:begin
			sclk_running_flag 	= 0;
				ctrl_reg[7] 	= 0;
				intr_o 			= 0;
				mosi 			= 1;
				//n_state = state;
				if(ctrl_reg[0]==1)begin
					n_state			= S_ADDR;
					num_pending_txs = ctrl_reg[3:1]+1;
					next_tx_idx	  	= ctrl_reg[6:4];
					addr_to_drive	= addr_regA[next_tx_idx];
					data_to_drive 	= data_regA[next_tx_idx];
					count			= 0;
				end
			end
			S_ADDR:begin
			sclk_running_flag 	= 1;
			mosi 	= addr_to_drive[count];
			//$display("mosi_addr_design %0b",mosi);
			count	= count + 1;
				if(count==8)begin
					n_state = S_IDLE_BW_ADDR_DATA;
					count	= 0;
				end
			end
			S_IDLE_BW_ADDR_DATA:begin
			sclk_running_flag = 0;
			count	= count + 1;
			mosi	= 1;
				if(count==4)begin
					n_state = S_DATA;
					count	= 0;
				end
			end
			S_DATA:begin
			sclk_running_flag = 1;
				if(addr_to_drive[7]==1)begin
					mosi = data_to_drive[count];
					//$display("mosi_data_desi %0b",mosi);
				end
				if(addr_to_drive[7]==0)begin
					collect_slave_data[count] = miso;
				end

				count = count + 1;
				if(count==8)begin
				num_pending_txs = num_pending_txs-1;
				ctrl_reg[6:4] 	= ctrl_reg[6:4]+1;
				ctrl_reg[3:1] 	= 0;
				ctrl_reg[0]   	= 0;
				addr_to_drive	= 0;
				data_to_drive	= 0;
				count 			= 0;
					if(num_pending_txs==0)begin
						n_state 	= S_IDLE;
						ctrl_reg[7] = 1;
						intr_o 		= 1;
					end
					else begin
						n_state = S_IDLE_WITH_TXS_PANDING;
					end
				end
			end
			S_IDLE_WITH_TXS_PANDING:begin
			sclk_running_flag = 0;
				count = count + 1;
				if(count==8)begin
					n_state = S_ADDR;
					next_tx_idx	  	= ctrl_reg[6:4];
					addr_to_drive	= addr_regA[next_tx_idx];
					data_to_drive 	= data_regA[next_tx_idx];
					count	= 0;
				end
			end
		endcase
	end
end

endmodule


