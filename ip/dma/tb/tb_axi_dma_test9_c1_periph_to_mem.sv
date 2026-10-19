`timescale 1ns/1ps

module tb_axi_dma;

  // ==========================================================================
  // PARAMETERS
  // ==========================================================================

  localparam int ADDR_W       = 32;
  localparam int DATA_W       = 256;
  localparam int S_DATA_W    = 32;
  localparam int ID_W        = 5;
  localparam int LEN_W       = 8;
  localparam int RESP_W      = 2;
  localparam int BYTE_W      = DATA_W / 8;

  localparam int BYTES_PER_BEAT = DATA_W / 8;

  // Test 9:
  // C1 Peripheral -> Memory
  //
  // 8 x 256-bit AXI-Stream input beats
  // 8 x 256-bit AXI4 output beats
  // Total = 256 bytes

  localparam int NUM_BEATS   = 8;
  localparam int TOTAL_BYTES = NUM_BEATS * BYTES_PER_BEAT;

  // ==========================================================================
  // DMA BASE
  // ==========================================================================

  localparam logic [31:0] DMA_BASE = 32'h8000_0000;

  // ==========================================================================
  // GLOBAL REGISTER
  // ==========================================================================

  localparam logic [31:0] DMA_EN =
      DMA_BASE + 32'h00;

  // ==========================================================================
  // C0 REGISTERS
  // ==========================================================================

  localparam logic [31:0] C0_CTRL =
      DMA_BASE + 32'h01;

  localparam logic [31:0] C0_XFER_CTRL =
      DMA_BASE + 32'h02;

  localparam logic [31:0] C0_IRQ_MASK =
      DMA_BASE + 32'h03;

  localparam logic [31:0] C0_ARB_RATE =
      DMA_BASE + 32'h04;

  localparam logic [31:0] C0_ATX_ID =
      DMA_BASE + 32'h05;

  localparam logic [31:0] C0_SRC_BURST =
      DMA_BASE + 32'h06;

  localparam logic [31:0] C0_DST_BURST =
      DMA_BASE + 32'h07;

  localparam logic [31:0] C0_WD_BURST =
      DMA_BASE + 32'h08;

  localparam logic [31:0] C0_SRC_ADDR =
      DMA_BASE + 32'h09;

  localparam logic [31:0] C0_DST_ADDR =
      DMA_BASE + 32'h0A;

  localparam logic [31:0] C0_XLEN =
      DMA_BASE + 32'h0B;

  localparam logic [31:0] C0_YLEN =
      DMA_BASE + 32'h0C;

  localparam logic [31:0] C0_SRC_STRIDE =
      DMA_BASE + 32'h0D;

  localparam logic [31:0] C0_DST_STRIDE =
      DMA_BASE + 32'h0E;

  // ==========================================================================
  // C1 REGISTERS
  //
  // C1 block is offset from C0 register block.
  // ==========================================================================

  localparam logic [31:0] CH_STRIDE = 32'h10;

  localparam logic [31:0] C1_CTRL =
      C0_CTRL + CH_STRIDE;

  localparam logic [31:0] C1_XFER_CTRL =
      C0_XFER_CTRL + CH_STRIDE;

  localparam logic [31:0] C1_IRQ_MASK =
      C0_IRQ_MASK + CH_STRIDE;

  localparam logic [31:0] C1_ARB_RATE =
      C0_ARB_RATE + CH_STRIDE;

  localparam logic [31:0] C1_ATX_ID =
      C0_ATX_ID + CH_STRIDE;

  localparam logic [31:0] C1_SRC_BURST =
      C0_SRC_BURST + CH_STRIDE;

  localparam logic [31:0] C1_DST_BURST =
      C0_DST_BURST + CH_STRIDE;

  localparam logic [31:0] C1_WD_BURST =
      C0_WD_BURST + CH_STRIDE;

  localparam logic [31:0] C1_SRC_ADDR =
      C0_SRC_ADDR + CH_STRIDE;

  localparam logic [31:0] C1_DST_ADDR =
      C0_DST_ADDR + CH_STRIDE;

  localparam logic [31:0] C1_XLEN =
      C0_XLEN + CH_STRIDE;

  localparam logic [31:0] C1_YLEN =
      C0_YLEN + CH_STRIDE;

  localparam logic [31:0] C1_SRC_STRIDE =
      C0_SRC_STRIDE + CH_STRIDE;

  localparam logic [31:0] C1_DST_STRIDE =
      C0_DST_STRIDE + CH_STRIDE;

  // ==========================================================================
  // DESCRIPTOR SUBMIT
  // ==========================================================================

  localparam logic [31:0] C0_DESC_SUBMIT =
      DMA_BASE + 32'h1000;

  localparam logic [31:0] C1_DESC_SUBMIT =
      C0_DESC_SUBMIT + CH_STRIDE;

  // ==========================================================================
  // STATUS
  // ==========================================================================

  localparam logic [31:0] STATUS_IRQ =
      DMA_BASE + 32'h2000;

  localparam logic [31:0] STATUS_XFER_ID =
      DMA_BASE + 32'h2004;

  localparam logic [31:0] STATUS_DONE =
      DMA_BASE + 32'h2008;

  // ==========================================================================
  // TEST ADDRESSES
  // ==========================================================================

  // Peripheral source has no AXI address.
  //
  // The destination memory address is the important AXI4 address.

  localparam logic [31:0] SRC_ADDR =
      32'h0003_0000;

  localparam logic [31:0] DST_ADDR =
      32'h0004_0000;

  // ==========================================================================
  // PERIPHERAL TEST DATA
  // ==========================================================================

  localparam logic [255:0] TEST_DATA_0 =
      256'h1111111111111111_1111111111111111_1111111111111111_1111111111111111;

  localparam logic [255:0] TEST_DATA_1 =
      256'h2222222222222222_2222222222222222_2222222222222222_2222222222222222;

  localparam logic [255:0] TEST_DATA_2 =
      256'h3333333333333333_3333333333333333_3333333333333333_3333333333333333;

  localparam logic [255:0] TEST_DATA_3 =
      256'h4444444444444444_4444444444444444_4444444444444444_4444444444444444;

  localparam logic [255:0] TEST_DATA_4 =
      256'h5555555555555555_5555555555555555_5555555555555555_5555555555555555;

  localparam logic [255:0] TEST_DATA_5 =
      256'h6666666666666666_6666666666666666_6666666666666666_6666666666666666;

  localparam logic [255:0] TEST_DATA_6 =
      256'h7777777777777777_7777777777777777_7777777777777777_7777777777777777;

  localparam logic [255:0] TEST_DATA_7 =
      256'h8888888888888888_8888888888888888_8888888888888888_8888888888888888;

  // ==========================================================================
  // CLOCK / RESET
  // ==========================================================================

  logic aclk;
  logic aresetn;

  initial begin
    aclk = 1'b0;
  end

  always #5 aclk = ~aclk;

  initial begin

    aresetn = 1'b0;

    repeat (5)
      @(posedge aclk);

    aresetn = 1'b1;

  end

  // ==========================================================================
  // AXI CONTROL INTERFACE
  // ==========================================================================

  logic [ID_W-1:0] s_awid_i;
  logic [ADDR_W-1:0] s_awaddr_i;
  logic [1:0] s_awburst_i;
  logic [LEN_W-1:0] s_awlen_i;
  logic s_awvalid_i;
  logic s_awready_o;

  logic [S_DATA_W-1:0] s_wdata_i;
  logic s_wlast_i;
  logic s_wvalid_i;
  logic s_wready_o;

  logic [ID_W-1:0] s_bid_o;
  logic [RESP_W-1:0] s_bresp_o;
  logic s_bvalid_o;
  logic s_bready_i;

  logic [ID_W-1:0] s_arid_i;
  logic [ADDR_W-1:0] s_araddr_i;
  logic [1:0] s_arburst_i;
  logic [LEN_W-1:0] s_arlen_i;
  logic s_arvalid_i;
  logic s_arready_o;

  logic [ID_W-1:0] s_rid_o;
  logic [S_DATA_W-1:0] s_rdata_o;
  logic [RESP_W-1:0] s_rresp_o;
  logic s_rlast_o;
  logic s_rvalid_o;
  logic s_rready_i;

  // ==========================================================================
  // AXI4 DESTINATION WRITE INTERFACE
  //
  // ACTIVE IN TEST 9
  // ==========================================================================

  logic [ID_W-1:0] m_awid_o;
  logic [ADDR_W-1:0] m_awaddr_o;
  logic [LEN_W-1:0] m_awlen_o;
  logic [1:0] m_awburst_o;
  logic m_awvalid_o;
  logic m_awready_i;

  logic [DATA_W-1:0] m_wdata_o;
  logic m_wlast_o;
  logic m_wvalid_o;
  logic m_wready_i;

  logic [ID_W-1:0] m_bid_i;
  logic [RESP_W-1:0] m_bresp_i;
  logic m_bvalid_i;
  logic m_bready_o;

  // ==========================================================================
  // AXI4 SOURCE READ INTERFACE
  //
  // UNUSED IN TEST 9
  // ==========================================================================

  logic [ID_W-1:0] m_arid_o;
  logic [ADDR_W-1:0] m_araddr_o;
  logic [LEN_W-1:0] m_arlen_o;
  logic [1:0] m_arburst_o;
  logic m_arvalid_o;
  logic m_arready_i;

  logic [ID_W-1:0] m_rid_i;
  logic [DATA_W-1:0] m_rdata_i;
  logic [RESP_W-1:0] m_rresp_i;
  logic m_rlast_i;
  logic m_rvalid_i;
  logic m_rready_o;

  // ==========================================================================
  // AXI-STREAM SOURCE
  //
  // ACTIVE IN TEST 9
  // ==========================================================================

  logic [ID_W-1:0] s_tid_i;
  logic [1:0] s_tdest_i;
  logic [DATA_W-1:0] s_tdata_i;
  logic [BYTE_W-1:0] s_tkeep_i;
  logic [BYTE_W-1:0] s_tstrb_i;
  logic s_tlast_i;
  logic s_tvalid_i;
  logic s_tready_o;

  // ==========================================================================
  // AXI-STREAM DESTINATION
  //
  // UNUSED IN TEST 9
  // ==========================================================================

  logic [ID_W-1:0] m_tid_o;
  logic [1:0] m_tdest_o;
  logic [DATA_W-1:0] m_tdata_o;
  logic [BYTE_W-1:0] m_tkeep_o;
  logic [BYTE_W-1:0] m_tstrb_o;
  logic m_tlast_o;
  logic m_tvalid_o;
  logic m_tready_i;

  logic [1:0] irq;
  logic [1:0] trap;

  // ==========================================================================
  // DUT
  // ==========================================================================

  axi_dma #(

    .DMA_BASE_ADDR   (DMA_BASE),
    .DMA_CHN_NUM     (2),
    .DMA_LENGTH_W    (16),
    .DMA_DESC_DEPTH  (4),
    .DMA_CHN_ARB_W   (3),
    .ROB_EN          (0),

    // ------------------------------------------------------------------------
    // TEST 9:
    //
    // Peripheral / AXIS -> Memory / AXI4
    // ------------------------------------------------------------------------

    .SRC_IF_TYPE     ("AXIS"),
    .SRC_ADDR_W      (32),
    .SRC_TDEST_W     (2),
    .ATX_SRC_DATA_W (256),

    .DST_IF_TYPE     ("AXI4"),
    .DST_ADDR_W      (32),
    .DST_TDEST_W     (2),
    .ATX_DST_DATA_W  (256),

    .S_DATA_W        (32),
    .S_ADDR_W        (32),
    .MST_ID_W        (5),

    .ATX_LEN_W      (8),
    .ATX_SIZE_W     (3),
    .ATX_RESP_W     (2)

  ) dut (

    .aclk          (aclk),
    .aresetn       (aresetn),

    // ------------------------------------------------------------------------
    // AXI CONTROL
    // ------------------------------------------------------------------------

    .s_awid_i      (s_awid_i),
    .s_awaddr_i    (s_awaddr_i),
    .s_awburst_i   (s_awburst_i),
    .s_awlen_i     (s_awlen_i),
    .s_awvalid_i   (s_awvalid_i),
    .s_awready_o   (s_awready_o),

    .s_wdata_i     (s_wdata_i),
    .s_wlast_i     (s_wlast_i),
    .s_wvalid_i    (s_wvalid_i),
    .s_wready_o    (s_wready_o),

    .s_bid_o       (s_bid_o),
    .s_bresp_o     (s_bresp_o),
    .s_bvalid_o    (s_bvalid_o),
    .s_bready_i    (s_bready_i),

    .s_arid_i      (s_arid_i),
    .s_araddr_i    (s_araddr_i),
    .s_arburst_i   (s_arburst_i),
    .s_arlen_i     (s_arlen_i),
    .s_arvalid_i   (s_arvalid_i),
    .s_arready_o   (s_arready_o),

    .s_rid_o       (s_rid_o),
    .s_rdata_o     (s_rdata_o),
    .s_rresp_o     (s_rresp_o),
    .s_rlast_o     (s_rlast_o),
    .s_rvalid_o    (s_rvalid_o),
    .s_rready_i    (s_rready_i),

    // ------------------------------------------------------------------------
    // AXI4 SOURCE READ
    // UNUSED
    // ------------------------------------------------------------------------

    .m_arid_o      (m_arid_o),
    .m_araddr_o    (m_araddr_o),
    .m_arlen_o     (m_arlen_o),
    .m_arburst_o   (m_arburst_o),
    .m_arvalid_o   (m_arvalid_o),
    .m_arready_i   (m_arready_i),

    .m_rid_i       (m_rid_i),
    .m_rdata_i     (m_rdata_i),
    .m_rresp_i     (m_rresp_i),
    .m_rlast_i     (m_rlast_i),
    .m_rvalid_i    (m_rvalid_i),
    .m_rready_o    (m_rready_o),

    // ------------------------------------------------------------------------
    // AXI-STREAM SOURCE
    // ACTIVE
    // ------------------------------------------------------------------------

    .s_tid_i       (s_tid_i),
    .s_tdest_i     (s_tdest_i),
    .s_tdata_i     (s_tdata_i),
    .s_tkeep_i     (s_tkeep_i),
    .s_tstrb_i     (s_tstrb_i),
    .s_tlast_i     (s_tlast_i),
    .s_tvalid_i    (s_tvalid_i),
    .s_tready_o    (s_tready_o),

    // ------------------------------------------------------------------------
    // AXI4 DESTINATION WRITE
    // ACTIVE
    // ------------------------------------------------------------------------

    .m_awid_o      (m_awid_o),
    .m_awaddr_o    (m_awaddr_o),
    .m_awlen_o     (m_awlen_o),
    .m_awburst_o   (m_awburst_o),
    .m_awvalid_o   (m_awvalid_o),
    .m_awready_i   (m_awready_i),

    .m_wdata_o     (m_wdata_o),
    .m_wlast_o     (m_wlast_o),
    .m_wvalid_o    (m_wvalid_o),
    .m_wready_i    (m_wready_i),

    .m_bid_i       (m_bid_i),
    .m_bresp_i     (m_bresp_i),
    .m_bvalid_i    (m_bvalid_i),
    .m_bready_o    (m_bready_o),

    // ------------------------------------------------------------------------
    // UNUSED AXI-STREAM DESTINATION
    // ------------------------------------------------------------------------

    .m_tid_o       (m_tid_o),
    .m_tdest_o     (m_tdest_o),
    .m_tdata_o     (m_tdata_o),
    .m_tkeep_o     (m_tkeep_o),
    .m_tstrb_o     (m_tstrb_o),
    .m_tlast_o     (m_tlast_o),
    .m_tvalid_o    (m_tvalid_o),
    .m_tready_i    (m_tready_i),

    .irq           (irq),
    .trap          (trap)

  );

  // ==========================================================================
  // AXI-LITE REGISTER WRITE
  // ==========================================================================

  task automatic axi_reg_write(
    input logic [31:0] addr,
    input logic [31:0] data
  );

    begin

      @(posedge aclk);

      s_awid_i    <= '0;
      s_awaddr_i  <= addr;
      s_awburst_i <= 2'b01;
      s_awlen_i   <= 8'd0;
      s_awvalid_i <= 1'b1;

      s_wdata_i   <= data;
      s_wlast_i   <= 1'b1;
      s_wvalid_i  <= 1'b1;

      wait (s_awready_o && s_wready_o);

      $display(
        "[%0t] REG WRITE: addr=%08h data=%08h",
        $time,
        addr,
        data
      );

      @(posedge aclk);

      s_awvalid_i <= 1'b0;
      s_wvalid_i  <= 1'b0;

      s_bready_i <= 1'b1;

      wait (s_bvalid_o);

      if (s_bresp_o != 2'b00)

        $fatal(
          1,
          "AXI REG WRITE ERROR: addr=%08h resp=%b",
          addr,
          s_bresp_o
        );

      @(posedge aclk);

      s_bready_i <= 1'b0;

    end

  endtask

  // ==========================================================================
  // AXI-LITE REGISTER READ
  // ==========================================================================

  task automatic axi_reg_read(
    input logic [31:0] addr,
    output logic [31:0] data
  );

    begin

      @(posedge aclk);

      s_arid_i    <= '0;
      s_araddr_i  <= addr;
      s_arburst_i <= 2'b01;
      s_arlen_i   <= 8'd0;
      s_arvalid_i <= 1'b1;

      wait (s_arready_o);

      @(posedge aclk);

      s_arvalid_i <= 1'b0;

      s_rready_i <= 1'b1;

      wait (s_rvalid_o);

      data = s_rdata_o;

      if (s_rresp_o != 2'b00)

        $fatal(
          1,
          "AXI REG READ ERROR: addr=%08h resp=%b",
          addr,
          s_rresp_o
        );

      @(posedge aclk);

      s_rready_i <= 1'b0;

    end

  endtask

  // ==========================================================================
  // AXI-STREAM PERIPHERAL SOURCE
  //
  // Peripheral -> DMA
  //
  // This model sends exactly 8 beats.
  // ==========================================================================

  logic [255:0] peripheral_source_data [0:NUM_BEATS-1];

  integer axis_beat_index;

  logic axis_transfer_started;
  logic axis_transfer_done;

  initial begin

    peripheral_source_data[0] = TEST_DATA_0;
    peripheral_source_data[1] = TEST_DATA_1;
    peripheral_source_data[2] = TEST_DATA_2;
    peripheral_source_data[3] = TEST_DATA_3;
    peripheral_source_data[4] = TEST_DATA_4;
    peripheral_source_data[5] = TEST_DATA_5;
    peripheral_source_data[6] = TEST_DATA_6;
    peripheral_source_data[7] = TEST_DATA_7;

    axis_beat_index      = 0;
    axis_transfer_started = 1'b0;
    axis_transfer_done    = 1'b0;

    s_tid_i    = '0;
    s_tdest_i  = '0;

    s_tdata_i  = '0;

    s_tkeep_i  = {BYTE_W{1'b1}};
    s_tstrb_i  = {BYTE_W{1'b1}};

    s_tlast_i  = 1'b0;
    s_tvalid_i = 1'b0;

  end

  // ==========================================================================
  // AXI-STREAM SOURCE DRIVER
  // ==========================================================================

  always @(posedge aclk) begin

    if (!aresetn) begin

      axis_beat_index       <= 0;
      axis_transfer_started <= 1'b0;
      axis_transfer_done    <= 1'b0;

      s_tvalid_i <= 1'b0;
      s_tlast_i  <= 1'b0;
      s_tdata_i  <= '0;

    end

    else begin

      // -----------------------------------------------------------------------
      // Start sending data once DMA asserts TREADY.
      // -----------------------------------------------------------------------

      if (!axis_transfer_started &&
          !axis_transfer_done) begin

        if (s_tready_o) begin

          axis_transfer_started <= 1'b1;

          s_tvalid_i <= 1'b1;

          s_tdata_i <=
              peripheral_source_data[0];

          s_tlast_i <=
              (NUM_BEATS == 1);

          $display(
            "[%0t] TEST 9: Peripheral starts AXIS transfer",
            $time
          );

        end

      end

      // -----------------------------------------------------------------------
      // AXI-STREAM handshake
      // -----------------------------------------------------------------------

      if (s_tvalid_i && s_tready_o) begin

        $display(
          "[%0t] AXIS SOURCE HANDSHAKE: beat=%0d data=%064h TLAST=%b",
          $time,
          axis_beat_index,
          s_tdata_i,
          s_tlast_i
        );

        // ---------------------------------------------------------------------
        // Final beat
        // ---------------------------------------------------------------------

        if (axis_beat_index == NUM_BEATS-1) begin

          s_tvalid_i <= 1'b0;
          s_tlast_i  <= 1'b0;

          axis_transfer_done <= 1'b1;

        end

        // ---------------------------------------------------------------------
        // Next beat
        // ---------------------------------------------------------------------

        else begin

          axis_beat_index <=
              axis_beat_index + 1;

          s_tdata_i <=
              peripheral_source_data[axis_beat_index + 1];

          s_tlast_i <=
              ((axis_beat_index + 1) == NUM_BEATS-1);

          s_tvalid_i <= 1'b1;

        end

      end

    end

  end

  // ==========================================================================
  // AXI4 DESTINATION MEMORY MODEL
  //
  // DMA -> Memory
  //
  // AW channel followed by W channel.
  // ==========================================================================

  logic [255:0] destination_memory [0:NUM_BEATS-1];

  logic destination_aw_seen;
  logic destination_write_done;

  integer destination_beat_count;

  logic [31:0] destination_awaddr_seen;

  logic [7:0] destination_awlen_seen;

  logic [1:0] destination_awburst_seen;

  initial begin

    destination_aw_seen   = 1'b0;
    destination_write_done = 1'b0;

    destination_beat_count = 0;

    destination_awaddr_seen  = '0;
    destination_awlen_seen   = '0;
    destination_awburst_seen = '0;

    m_awready_i = 1'b1;
    m_wready_i  = 1'b1;

    m_bid_i     = '0;
    m_bresp_i   = 2'b00;
    m_bvalid_i  = 1'b0;

    for (int i = 0; i < NUM_BEATS; i++)
      destination_memory[i] = '0;

  end

  // ==========================================================================
  // AXI4 DESTINATION MEMORY
  // ==========================================================================

  always @(posedge aclk) begin

    if (!aresetn) begin

      destination_aw_seen    <= 1'b0;
      destination_write_done <= 1'b0;

      destination_beat_count <= 0;

      destination_awaddr_seen  <= '0;
      destination_awlen_seen   <= '0;
      destination_awburst_seen <= '0;

      m_bvalid_i <= 1'b0;

    end

    else begin

      // ======================================================================
      // WRITE ADDRESS CHANNEL
      // ======================================================================

      if (m_awvalid_o && m_awready_i) begin

        destination_aw_seen <= 1'b1;

        destination_awaddr_seen  <= m_awaddr_o;
        destination_awlen_seen   <= m_awlen_o;
        destination_awburst_seen <= m_awburst_o;

        $display("");
        $display("==================================================");
        $display("[%0t] TEST 9 AXI4 AW HANDSHAKE", $time);
        $display("AWADDR  = %08h", m_awaddr_o);
        $display("AWLEN   = %02h", m_awlen_o);
        $display("AWBURST = %02b", m_awburst_o);
        $display("==================================================");
        $display("");

        // ----------------------------------------------------------------------
        // Address check
        // ----------------------------------------------------------------------

        if (m_awaddr_o !== DST_ADDR)

          $fatal(
            1,
            "TEST 9 FAIL: AXI AWADDR mismatch: expected %08h got %08h",
            DST_ADDR,
            m_awaddr_o
          );

        // ----------------------------------------------------------------------
        // Burst length
        // ----------------------------------------------------------------------

        if (m_awlen_o !== NUM_BEATS-1)

          $fatal(
            1,
            "TEST 9 FAIL: AXI AWLEN mismatch: expected %0d got %0d",
            NUM_BEATS-1,
            m_awlen_o
          );

        // ----------------------------------------------------------------------
        // Burst type
        // ----------------------------------------------------------------------

        if (m_awburst_o !== 2'b01)

          $fatal(
            1,
            "TEST 9 FAIL: AXI AWBURST mismatch: expected 01 got %02b",
            m_awburst_o
          );

      end

      // ======================================================================
      // WRITE DATA CHANNEL
      // ======================================================================

      if (m_wvalid_o && m_wready_i) begin

        $display(
          "[%0t] AXI W HANDSHAKE: beat=%0d data=%064h WLAST=%b",
          $time,
          destination_beat_count,
          m_wdata_o,
          m_wlast_o
        );

        // ----------------------------------------------------------------------
        // Make sure AW occurred first
        // ----------------------------------------------------------------------

      /*  if (!destination_aw_seen)

          $fatal(
            1,
            "TEST 9 FAIL: Write data arrived before AW handshake"
          ); */

        // ----------------------------------------------------------------------
        // Store data
        // ----------------------------------------------------------------------

        if (destination_beat_count < NUM_BEATS)

          destination_memory[destination_beat_count]
              <= m_wdata_o;

        else

          $fatal(
            1,
            "TEST 9 FAIL: More W beats than expected"
          );

        // ----------------------------------------------------------------------
        // WLAST check
        // ----------------------------------------------------------------------

        if (destination_beat_count == NUM_BEATS-1) begin

          if (!m_wlast_o)

            $fatal(
              1,
              "TEST 9 FAIL: WLAST not asserted on final beat"
            );

          destination_write_done <= 1'b1;

          // --------------------------------------------------------------
          // Return AXI OKAY response
          // --------------------------------------------------------------

          m_bid_i   <= m_awid_o;
          m_bresp_i <= 2'b00;

          m_bvalid_i <= 1'b1;

        end

        else begin

          if (m_wlast_o)

            $fatal(
              1,
              "TEST 9 FAIL: WLAST asserted early at beat %0d",
              destination_beat_count
            );

          destination_beat_count <=
              destination_beat_count + 1;

        end

      end

      // ======================================================================
      // WRITE RESPONSE
      // ======================================================================

      if (m_bvalid_i && m_bready_o) begin

        $display(
          "[%0t] AXI B HANDSHAKE: BRESP=%02b",
          $time,
          m_bresp_i
        );

        m_bvalid_i <= 1'b0;

      end

    end

  end

  // ==========================================================================
  // UNUSED AXI4 SOURCE READ INTERFACE
  // ==========================================================================

  initial begin

    m_arready_i = 1'b0;

    m_rid_i    = '0;
    m_rdata_i  = '0;
    m_rresp_i  = 2'b00;
    m_rlast_i  = 1'b0;
    m_rvalid_i = 1'b0;

  end

  // ==========================================================================
  // UNUSED AXI-STREAM DESTINATION
  // ==========================================================================

  initial begin

    m_tready_i = 1'b0;

  end

  // ==========================================================================
  // AXI CONTROL INITIALIZATION
  // ==========================================================================

  initial begin

    s_awid_i    = '0;
    s_awaddr_i  = '0;
    s_awburst_i = 2'b01;
    s_awlen_i   = '0;
    s_awvalid_i = 1'b0;

    s_wdata_i   = '0;
    s_wlast_i   = 1'b0;
    s_wvalid_i  = 1'b0;

    s_bready_i  = 1'b0;

    s_arid_i    = '0;
    s_araddr_i  = '0;
    s_arburst_i = 2'b01;
    s_arlen_i   = '0;
    s_arvalid_i = 1'b0;

    s_rready_i  = 1'b0;

  end

  // ==========================================================================
  // TEST 9
  //
  // C1 PERIPHERAL -> MEMORY
  // ==========================================================================

  initial begin : c1_peripheral_to_memory_test

    logic [31:0] status;

    int timeout_cycles;
    int i;

    wait (aresetn === 1'b1);

    repeat (2)
      @(posedge aclk);

    $display("");
    $display("==================================================");
    $display("        C1 AXI DMA TEST 9");
    $display("        %0d-BEAT PERIPHERAL-TO-MEMORY",
             NUM_BEATS);
    $display("==================================================");
    $display("SRC_IF_TYPE      = AXIS");
    $display("DST_IF_TYPE      = AXI4");
    $display("DATA_W           = %0d bits", DATA_W);
    $display("BYTES_PER_BEAT   = %0d bytes", BYTES_PER_BEAT);
    $display("NUM_BEATS        = %0d", NUM_BEATS);
    $display("TOTAL_BYTES      = %0d bytes", TOTAL_BYTES);
    $display("DST_ADDR         = 0x%08h", DST_ADDR);
    $display("CHANNEL          = C1");
    $display("==================================================");
    $display("");

    // ========================================================================
    // GLOBAL DMA ENABLE
    // ========================================================================

    axi_reg_write(
      DMA_EN,
      32'h0000_0001
    );

    // ========================================================================
    // C1 ENABLE
    // ========================================================================

    axi_reg_write(
      C1_CTRL,
      32'h0000_0001
    );

    // ========================================================================
    // 1D NON-CYCLIC TRANSFER
    // ========================================================================

    axi_reg_write(
      C1_XFER_CTRL,
      32'h0000_0000
    );

    // ========================================================================
    // IRQ ENABLE
    // ========================================================================

    axi_reg_write(
      C1_IRQ_MASK,
      32'h0000_0001
    );

    // ========================================================================
    // ARBITRATION
    // ========================================================================

    axi_reg_write(
      C1_ARB_RATE,
      32'h0000_0001
    );

    // ========================================================================
    // C1 ID
    // ========================================================================

    axi_reg_write(
      C1_ATX_ID,
      32'h0000_0001
    );

    // ========================================================================
    // SOURCE BURST
    //
    // Source is AXI-Stream, so there is no AXI AR burst.
    // Program consistently with previous tests.
    // ========================================================================

    axi_reg_write(
      C1_SRC_BURST,
      32'h0000_0001
    );

    // ========================================================================
    // DESTINATION BURST
    //
    // Destination is AXI4.
    // ========================================================================

    axi_reg_write(
      C1_DST_BURST,
      32'h0000_0001
    );

    // ========================================================================
    // WRITE DATA BURST
    //
    // 8 beats -> 7
    // ========================================================================

    axi_reg_write(
      C1_WD_BURST,
      NUM_BEATS-1
    );

    // ========================================================================
    // SOURCE ADDRESS
    //
    // AXI-Stream has no address.
    // Keep the descriptor field programmed.
    // ========================================================================

    axi_reg_write(
      C1_SRC_ADDR,
      SRC_ADDR
    );

    // ========================================================================
    // DESTINATION ADDRESS
    //
    // THIS IS THE IMPORTANT ADDRESS FOR TEST 9.
    //
    // Expected:
    //
    //     m_awaddr_o = 00040000
    // ========================================================================

    axi_reg_write(
      C1_DST_ADDR,
      DST_ADDR
    );

    // ========================================================================
    // X LENGTH
    //
    // 8 beats -> 7
    // ========================================================================

    axi_reg_write(
      C1_XLEN,
      NUM_BEATS-1
    );

    // ========================================================================
    // Y LENGTH
    // ========================================================================

    axi_reg_write(
      C1_YLEN,
      32'h0000_0000
    );

    // ========================================================================
    // SOURCE STRIDE
    // ========================================================================

    axi_reg_write(
      C1_SRC_STRIDE,
      32'h0000_0000
    );

    // ========================================================================
    // DESTINATION STRIDE
    // ========================================================================

    axi_reg_write(
      C1_DST_STRIDE,
      32'h0000_0000
    );

    // ========================================================================
    // CONFIGURATION SUMMARY
    // ========================================================================

    $display("");
    $display("--------------------------------------------------");
    $display("TEST 9 CONFIGURATION COMPLETE");
    $display("--------------------------------------------------");
    $display("CHANNEL     = C1");
    $display("SOURCE      = AXI-STREAM PERIPHERAL");
    $display("DESTINATION = AXI4 MEMORY");
    $display("DST_ADDR    = %08h", DST_ADDR);
    $display("XLEN        = %08h", NUM_BEATS-1);
    $display("WD_BURST    = %08h", NUM_BEATS-1);
    $display("--------------------------------------------------");
    $display("");

    // ========================================================================
    // SUBMIT C1 DESCRIPTOR
    // ========================================================================

    $display(
      "[%0t] Submitting C1 descriptor",
      $time
    );

    axi_reg_write(
      C1_DESC_SUBMIT,
      32'h0000_0000
    );

    // ========================================================================
    // WAIT FOR AXIS SOURCE TO SEND ALL BEATS
    // ========================================================================

    timeout_cycles = 0;

    while (!axis_transfer_done) begin

      @(posedge aclk);

      timeout_cycles++;

      if (timeout_cycles > 5000)

        $fatal(
          1,
          "TEST 9 TIMEOUT: AXI-Stream peripheral did not complete transfer"
        );

    end

    // ========================================================================
    // WAIT FOR DESTINATION WRITE TO COMPLETE
    // ========================================================================

    timeout_cycles = 0;

    while (!destination_write_done) begin

      @(posedge aclk);

      timeout_cycles++;

      if (timeout_cycles > 5000)

        $fatal(
          1,
          "TEST 9 TIMEOUT: C1 did not complete destination AXI write"
        );

    end

    // ========================================================================
    // VERIFY AW TRANSACTION
    // ========================================================================

    if (!destination_aw_seen)

      $fatal(
        1,
        "TEST 9 FAIL: No AXI AW transaction observed"
      );

    if (destination_awaddr_seen !== DST_ADDR)

      $fatal(
        1,
        "TEST 9 FAIL: Destination address mismatch"
      );

    if (destination_awlen_seen !== NUM_BEATS-1)

      $fatal(
        1,
        "TEST 9 FAIL: Destination AWLEN mismatch"
      );

    if (destination_awburst_seen !== 2'b01)

      $fatal(
        1,
        "TEST 9 FAIL: Destination AWBURST mismatch"
      );

    // ========================================================================
    // VERIFY DATA
    // ========================================================================

    for (i = 0; i < NUM_BEATS; i++) begin

      if (destination_memory[i] !== peripheral_source_data[i]) begin

        $fatal(
          1,
          "TEST 9 DATA MISMATCH at beat %0d:\nExpected = %064h\nActual   = %064h",
          i,
          peripheral_source_data[i],
          destination_memory[i]
        );

      end

      else begin

        $display(
          "[%0t] TEST 9 Beat %0d PASS: %064h",
          $time,
          i,
          destination_memory[i]
        );

      end

    end

    // ========================================================================
    // ALLOW STATUS TO UPDATE
    // ========================================================================

    repeat (5)
      @(posedge aclk);

    // ========================================================================
    // STATUS
    // ========================================================================

    axi_reg_read(
      STATUS_IRQ,
      status
    );

    $display(
      "[%0t] STATUS_IRQ     = 0x%08h",
      $time,
      status
    );

    axi_reg_read(
      STATUS_XFER_ID,
      status
    );

    $display(
      "[%0t] STATUS_XFER_ID = 0x%08h",
      $time,
      status
    );

    axi_reg_read(
      STATUS_DONE,
      status
    );

    $display(
      "[%0t] STATUS_DONE    = 0x%08h",
      $time,
      status
    );

    // ========================================================================
    // PASS
    // ========================================================================

    $display("");
    $display("==================================================");
    $display("PASS: C1 %0d-beat peripheral-to-memory transfer",
             NUM_BEATS);
    $display("PASS: AXI-Stream source -> AXI4 destination");
    $display("PASS: Destination address = 0x%08h",
             DST_ADDR);
    $display("PASS: %0d AXI-Stream beats received by DMA",
             NUM_BEATS);
    $display("PASS: %0d AXI4 write beats generated",
             NUM_BEATS);
    $display("PASS: %0d total bytes transferred",
             TOTAL_BYTES);
    $display("PASS: Channel = C1");
    $display("==================================================");
    $display("");

    #20;

    $finish;

  end

  // ==========================================================================
  // GLOBAL TIMEOUT
  // ==========================================================================

  initial begin

    #100_000;

    $fatal(
      1,
      "TEST 9 GLOBAL TIMEOUT"
    );

  end

endmodule