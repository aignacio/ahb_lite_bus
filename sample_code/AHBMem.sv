import ahb3lite_pkg::*;

module AHBMemoryLite #(
  parameter MEM_DEPTH = 2048, 					// SIZE = 8192 Bytes = 2048 Words
  parameter AHB_DATA_WIDTH  = 32,
  parameter AHB_ADDR_WIDTH  = 32
)(
 	input wire  HCLK,
	input wire  HRESETn,

  input wire  HSEL,
  input wire  [AHB_ADDR_WIDTH-1:0] HADDR,
	input wire  [AHB_DATA_WIDTH-1:0] HWDATA,
	input wire  HWRITE,
	input wire  [2:0] HSIZE,
	input wire  [2:0] HBURST,
	input wire  [3:0] HPROT,
	input wire  [1:0] HTRANS,
	input wire  HMASTLOCK,
	input wire  HREADY,

  output  reg [AHB_DATA_WIDTH-1:0] HRDATA,
	output  reg HREADYOUT,
	output  reg HRESP//,

  //Aux interfaces
  // input mst_HSEL_ext,
  // input [29:0] mst_HADDR_ext,
  // input mst_HREADY_ext,
  // input [31:0] mst_HWDATA_ext
);
  localparam  BIT_WIDTH_ADDR = $clog2(MEM_DEPTH);
  localparam [2:0]  IDDLE   = 3'd000,
                    ADDR_PH = 3'd001,
                    DATA_PH = 3'd010,
                    COM_PH  = 3'd011;

  reg [AHB_DATA_WIDTH-1:0]  sram  [MEM_DEPTH-1:0];
  reg [BIT_WIDTH_ADDR-1:0]  address_sram;
  reg [2:0] state, next_state;

  `ifdef MODEL_TECH
  initial begin
    reg [AHB_DATA_WIDTH-1:0]  temp  [MEM_DEPTH-1:0];
    $readmemh("program.hex", temp);
    for (int i=0; i<MEM_DEPTH; i++) begin
      if (^temp[i] === 1'bx) begin
        // $display ("!X found changed data to 0");
        sram[i] = 32'd0;
      end else begin
        sram[i] = temp[i];
      end
    end
  end
  `endif

  always @ (posedge HCLK or negedge HRESETn) begin
    if (HRESETn == 1'b0) begin
      address_sram  <=  {BIT_WIDTH_ADDR{1'b0}};
      HRDATA <= {AHB_DATA_WIDTH{1'b0}};
    end else begin
      if (state == ADDR_PH) begin
        address_sram  <=  HADDR[BIT_WIDTH_ADDR-1:0];
        HRDATA <= {AHB_DATA_WIDTH{1'b0}};
      end else if (state == DATA_PH) begin
        address_sram  <= HADDR;//{BIT_WIDTH_ADDR{1'b0}};
        if (HWRITE == 1'b0) begin // Read transfer
          HRDATA  <=  sram[address_sram/29'd4];
        end else  begin // Write transfer
          sram[address_sram] <= HWDATA;
          HRDATA <= {AHB_DATA_WIDTH{1'b0}};
        end
      end
    end
  end

  // FSM - AHB Lite Slave

  always @ (posedge HCLK or negedge HRESETn) begin
    if (HRESETn == 1'b0) begin
      state <= IDDLE;
    end else begin
      state <= next_state;
    end
  end

  always @ ( * ) begin
    case (state)
      IDDLE:
        next_state = ADDR_PH;
      ADDR_PH:
        if (HREADY == 1'b1 && HSEL == 1'b1) begin
          next_state = DATA_PH;
        end else begin
          next_state = ADDR_PH;
        end
      DATA_PH:
        if (HREADY == 1'b1 && HSEL == 1'b1) begin
          next_state = DATA_PH;
        end else begin
          next_state = ADDR_PH;
        end
      default:
        next_state = IDDLE;
    endcase
  end

  always @ ( * ) begin
    case (state)
      IDDLE: begin
        HREADYOUT = 1'b1;
        HRESP = HRESP_OKAY;
      end
      ADDR_PH: begin
        HREADYOUT = 1'b1;
        HRESP = HRESP_OKAY;
      end
      DATA_PH: begin
        HREADYOUT = 1'b1;
        HRESP = HRESP_OKAY;
      end
      default: begin
        HREADYOUT = 1'b1;
        HRESP = HRESP_OKAY;
      end
    endcase
  end
endmodule
