`timescale 1ns/1ps

module tb_axi_dma;

  // ==========================================================================
  // PARAMETERS
  // ==========================================================================

  localparam int ADDR_W = 32;
  localparam int DATA_W = 256;
  localparam int S_DATA_W = 32;
  localparam int ID_W = 5;
  localparam int LEN_W = 8;
  localparam int RESP_W = 2;
  localparam int BYTE_W = DATA_W/8;

  // 256 bits = 32 bytes per AXI beat
  localparam int BYTES_PER_BEAT = DATA_W/8;

  // Test 8:
  // C0 multi-beat memory-to-peripheral transfer
  //
  // Source      : AXI4 memory
  // Destination : AXI-Stream peripheral
  //
  // 8 x 256-bit beats = 256 bytes

  localparam int NUM_BEATS = 8;
  localparam int TOTAL_BYTES = NUM_BEATS * BYTES_PER_BEAT;

  // ==========================================================================
  // DMA BASE ADDRESS
  // ==========================================================================

  localparam logic [31:0] DMA_BASE = 32'h8000_0000;

  // ==========================================================================
  // GLOBAL
  // ==========================================================================

  localparam logic [31:0] DMA_EN =
      DMA_BASE + 32'h00;

  // ==========================================================================
  // C0 REGISTER MAP
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
  // DESCRIPTOR / STATUS
  // ==========================================================================

  localparam logic [31:0] C0_DESC_SUBMIT =
      DMA_BASE + 32'h1000;

  localparam logic [31:0] STATUS_IRQ =
      DMA_BASE + 32'h2000;

  localparam logic [31:0] STATUS_XFER_ID =
      DMA_BASE + 32'h2004;

  localparam logic [31:0] STATUS_DONE =
      DMA_BASE + 32'h2008;

  // ==========================================================================
  // TEST ADDRESSES
  // ==========================================================================

  localparam logic [31:0] SRC_ADDR =
      32'h0003_0000;

  localparam logic [31:0] DST_ADDR =
      32'h0004_0000;

  // ==========================================================================
  // TEST DATA
  // ==========================================================================

  localparam logic [255:0] TEST_DATA_0 =
      256'h1010101010101010_1010101010101010_1010101010101010_1010101010101010;

  localparam logic [255:0] TEST_DATA_1 =
      256'h2020202020202020_2020202020202020_2020202020202020_2020202020202020;

  localparam logic [255:0] TEST_DATA_2 =
      256'h3030303030303030_3030303030303030_3030303030303030_3030303030303030;

  localparam logic [255:0] TEST_DATA_3 =
      256'h4040404040404040_4040404040404040_4040404040404040_4040404040404040;

  localparam logic [255:0] TEST_DATA_4 =
      256'h5050505050505050_5050505050505050_5050505050505050_5050505050505050;

  localparam logic [255:0] TEST_DATA_5 =
      256'h6060606060606060_6060606060606060_6060606060606060_6060606060606060;

  localparam logic [255:0] TEST_DATA_6 =
      256'h7070707070707070_7070707070707070_7070707070707070_7070707070707070;

  localparam logic [255:0] TEST_DATA_7 =
      256'h8080808080808080_8080808080808080_8080808080808080_8080808080808080;

  // ==========================================================================
  // CLOCK / RESET
  // ==========================================================================

  logic aclk;
  logic aresetn;

  initial begin
    aclk = 1'b0;
  end

  always #5 aclk = ~aclk;       // 100 MHz

  initial begin

    aresetn = 1'b0;

    repeat (5)
      @(posedge aclk);

    aresetn = 1'b1;

  end

  // ==========================================================================
  // AXI4 CONTROL INTERFACE
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
  // DMA SOURCE AXI4 READ INTERFACE
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
  // DMA DESTINATION AXI4 WRITE INTERFACE
  //
  // UNUSED IN TEST 8
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
  // AXI-STREAM SOURCE
  //
  // UNUSED IN TEST 8
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
  // ACTIVE IN TEST 8
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

    // ------------------------------------------------------------
    // TEST 8:
    // MEMORY -> PERIPHERAL
    // ------------------------------------------------------------

    .SRC_IF_TYPE     ("AXI4"),
    .SRC_ADDR_W      (32),
    .SRC_TDEST_W     (2),
    .ATX_SRC_DATA_W (256),

    .DST_IF_TYPE     ("AXIS"),
    .DST_ADDR_W      (32),
    .DST_TDEST_W     (2),
    .ATX_DST_DATA_W  (256),

    .S_DATA_W        (32),
    .S_ADDR_W        (32),
    .MST_ID_W        (5),

    .ATX_LEN_W       (8),
    .ATX_SIZE_W      (3),
    .ATX_RESP_W      (2)

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
    // SOURCE AXI4
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
    // UNUSED AXI-STREAM SOURCE
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
    // UNUSED AXI4 WRITE DESTINATION
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
    // ACTIVE AXI-STREAM DESTINATION
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
  // AXI4 CONTROL WRITE TASK
  //
  // This is intentionally kept in the same form as the working Test 7 BFM.
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

      $display("[%0t] REG WRITE: addr=%08h data=%08h",
               $time,
               addr,
               data);

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
  // AXI4 CONTROL READ TASK
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
  // SOURCE AXI4 MEMORY MODEL
  //
  // DMA is expected to generate:
  //
  //   ARADDR  = 00030000
  //   ARLEN   = 07
  //   ARBURST = 01
  //
  // Then the memory model returns 8 x 256-bit beats.
  // ==========================================================================

  logic [255:0] source_beats [0:NUM_BEATS-1];

  logic source_read_seen;

  logic [31:0] source_mem_addr_seen;

  integer source_beat_count;

  initial begin

    source_beats[0] = TEST_DATA_0;
    source_beats[1] = TEST_DATA_1;
    source_beats[2] = TEST_DATA_2;
    source_beats[3] = TEST_DATA_3;
    source_beats[4] = TEST_DATA_4;
    source_beats[5] = TEST_DATA_5;
    source_beats[6] = TEST_DATA_6;
    source_beats[7] = TEST_DATA_7;

    source_read_seen     = 1'b0;
    source_mem_addr_seen = '0;

    source_beat_count = 0;

    // Source AXI memory always ready to accept AR.
    m_arready_i = 1'b1;

    m_rid_i    = '0;
    m_rdata_i  = '0;
    m_rresp_i  = 2'b00;
    m_rlast_i  = 1'b0;
    m_rvalid_i = 1'b0;

  end

  always @(posedge aclk) begin

    if (!aresetn) begin

      m_rvalid_i <= 1'b0;
      m_rlast_i  <= 1'b0;

      source_read_seen     <= 1'b0;
      source_mem_addr_seen <= '0;

      source_beat_count <= 0;

    end

    else begin

      // ======================================================================
      // AXI READ ADDRESS HANDSHAKE
      // ======================================================================

      if (m_arvalid_o && m_arready_i) begin

        $display("");
        $display("==================================================");
        $display("[%0t] TEST 8 SOURCE AXI AR HANDSHAKE", $time);
        $display("ARADDR  = %08h", m_araddr_o);
        $display("ARLEN   = %02h", m_arlen_o);
        $display("ARBURST = %02b", m_arburst_o);
        $display("==================================================");
        $display("");

        source_read_seen     <= 1'b1;
        source_mem_addr_seen <= m_araddr_o;

        // --------------------------------------------------------------------
        // CHECK SOURCE ADDRESS
        // --------------------------------------------------------------------

        if (m_araddr_o !== SRC_ADDR)

          $fatal(
            1,
            "TEST 8 FAIL: Source AXI ARADDR mismatch: expected %08h got %08h",
            SRC_ADDR,
            m_araddr_o
          );

        // --------------------------------------------------------------------
        // CHECK BURST LENGTH
        // --------------------------------------------------------------------

        if (m_arlen_o !== NUM_BEATS-1)

          $fatal(
            1,
            "TEST 8 FAIL: Source AXI ARLEN mismatch: expected %0d got %0d",
            NUM_BEATS-1,
            m_arlen_o
          );

        // --------------------------------------------------------------------
        // CHECK BURST TYPE
        // --------------------------------------------------------------------

        if (m_arburst_o !== 2'b01)

          $fatal(
            1,
            "TEST 8 FAIL: Source AXI ARBURST mismatch: expected INCR got %02b",
            m_arburst_o
          );

        // --------------------------------------------------------------------
        // Start returning source data
        // --------------------------------------------------------------------

        m_rid_i <= m_arid_o;

        source_beat_count <= 0;

        m_rdata_i <= source_beats[0];

        m_rresp_i <= 2'b00;

        m_rlast_i <= (NUM_BEATS == 1);

        m_rvalid_i <= 1'b1;

      end

      // ======================================================================
      // AXI READ DATA HANDSHAKE
      // ======================================================================

      if (m_rvalid_i && m_rready_o) begin

        $display(
          "[%0t] SOURCE R HANDSHAKE: beat=%0d data=%064h last=%b",
          $time,
          source_beat_count,
          m_rdata_i,
          m_rlast_i
        );

        if (source_beat_count == NUM_BEATS-1) begin

          // Final beat
          m_rvalid_i <= 1'b0;
          m_rlast_i  <= 1'b0;

        end

        else begin

          source_beat_count <=
              source_beat_count + 1;

          m_rdata_i <=
              source_beats[source_beat_count + 1];

          m_rresp_i <= 2'b00;

          m_rlast_i <=
              ((source_beat_count + 1) == NUM_BEATS-1);

          m_rvalid_i <= 1'b1;

        end

      end

    end

  end

  // ==========================================================================
  // DESTINATION AXI-STREAM PERIPHERAL MODEL
  //
  // This is the ACTIVE peripheral interface for Test 8.
  //
  // DMA -> m_tdata_o -> peripheral
  //
  // The peripheral asserts TREADY continuously.
  // ==========================================================================

  logic peripheral_seen;

  integer peripheral_beat_count;

  logic [255:0] peripheral_beats [0:NUM_BEATS-1];

  initial begin

    peripheral_seen       = 1'b0;
    peripheral_beat_count = 0;

    // Peripheral is always ready.
    m_tready_i = 1'b1;

    for (int i = 0; i < NUM_BEATS; i++)
      peripheral_beats[i] = '0;

  end

  always @(posedge aclk) begin

    if (!aresetn) begin

      peripheral_seen       <= 1'b0;
      peripheral_beat_count <= 0;

    end

    else begin

      // ======================================================================
      // AXI-STREAM TRANSFER
      // ======================================================================

      if (m_tvalid_o && m_tready_i) begin

        peripheral_seen <= 1'b1;

        peripheral_beats[peripheral_beat_count]
            <= m_tdata_o;

        $display(
          "[%0t] TEST 8 AXIS PERIPHERAL RECEIVED beat=%0d data=%064h TLAST=%b",
          $time,
          peripheral_beat_count,
          m_tdata_o,
          m_tlast_o
        );

        // --------------------------------------------------------------------
        // TLAST check
        // --------------------------------------------------------------------

        if (peripheral_beat_count == NUM_BEATS-1) begin

          if (!m_tlast_o)

            $fatal(
              1,
              "TEST 8 FAIL: AXIS TLAST not asserted on final beat"
            );

        end

        else begin

          if (m_tlast_o)

            $fatal(
              1,
              "TEST 8 FAIL: AXIS TLAST asserted early on beat %0d",
              peripheral_beat_count
            );

          peripheral_beat_count <=
              peripheral_beat_count + 1;

        end

      end

    end

  end

  // ==========================================================================
  // UNUSED AXI4 DESTINATION WRITE MODEL
  //
  // Memory-to-peripheral means AXI write channel is NOT used.
  // ==========================================================================

  initial begin

    m_awready_i = 1'b0;
    m_wready_i  = 1'b0;

    m_bid_i     = '0;
    m_bresp_i   = 2'b00;
    m_bvalid_i  = 1'b0;

  end

  // ==========================================================================
  // UNUSED AXI-STREAM SOURCE
  // ==========================================================================

  initial begin

    s_tid_i    = '0;
    s_tdest_i  = '0;
    s_tdata_i  = '0;
    s_tkeep_i  = '0;
    s_tstrb_i  = '0;
    s_tlast_i  = 1'b0;
    s_tvalid_i = 1'b0;

  end

  // ==========================================================================
  // INITIALIZE CONTROL AXI
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
  // TEST 8
  //
  // C0 MEMORY -> PERIPHERAL
  //
  // Source:
  //     AXI4 memory
  //     00030000
  //
  // Destination:
  //     AXI-Stream peripheral
  //
  // Transfer:
  //     8 x 256-bit beats
  //     32 bytes/beat
  //     256 bytes total
  // ==========================================================================

  initial begin : c0_memory_to_peripheral_test

    logic [31:0] status;

    int timeout_cycles;
    int i;

    wait (aresetn === 1'b1);

    repeat (2)
      @(posedge aclk);

    $display("");
    $display("==================================================");
    $display("        C0 AXI DMA TEST 8");
    $display("        8-BEAT MEMORY-TO-PERIPHERAL");
    $display("==================================================");
    $display("SRC_IF_TYPE      = AXI4");
    $display("DST_IF_TYPE      = AXIS");
    $display("DATA_W           = %0d bits", DATA_W);
    $display("BYTES_PER_BEAT   = %0d bytes", BYTES_PER_BEAT);
    $display("NUM_BEATS        = %0d", NUM_BEATS);
    $display("TOTAL_BYTES      = %0d bytes", TOTAL_BYTES);
    $display("SRC_ADDR         = 0x%08h", SRC_ADDR);
    $display("DST_ADDR         = 0x%08h", DST_ADDR);
    $display("CHANNEL          = C0");
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
    // C0 ENABLE
    // ========================================================================

    axi_reg_write(
      C0_CTRL,
      32'h0000_0001
    );

    // ========================================================================
    // 1D NON-CYCLIC TRANSFER
    // ========================================================================

    axi_reg_write(
      C0_XFER_CTRL,
      32'h0000_0000
    );

    // ========================================================================
    // IRQ ENABLE
    // ========================================================================

    axi_reg_write(
      C0_IRQ_MASK,
      32'h0000_0001
    );

    // ========================================================================
    // ARBITRATION
    // ========================================================================

    axi_reg_write(
      C0_ARB_RATE,
      32'h0000_0001
    );

    // ========================================================================
    // C0 ID
    // ========================================================================

    axi_reg_write(
      C0_ATX_ID,
      32'h0000_0000
    );

    // ========================================================================
    // SOURCE AXI4 BURST
    //
    // AXI4 source is active in Test 8.
    // INCR = 2'b01 / register value 1
    // ========================================================================

    axi_reg_write(
      C0_SRC_BURST,
      32'h0000_0001
    );

    // ========================================================================
    // DESTINATION BURST
    //
    // Destination is AXI-Stream, so this is not consumed by an AXI AW
    // transaction. We nevertheless program it consistently.
    // ========================================================================

    axi_reg_write(
      C0_DST_BURST,
      32'h0000_0001
    );

    // ========================================================================
    // WRITE DATA BURST / TRANSFER LENGTH
    //
    // 8 beats -> LEN = 7
    // ========================================================================

    axi_reg_write(
      C0_WD_BURST,
      NUM_BEATS-1
    );

    // ========================================================================
    // SOURCE ADDRESS
    //
    // THIS IS THE CRITICAL VALUE FOR TEST 8.
    //
    // Expected AXI ARADDR:
    //
    //     m_araddr_o = 00030000
    // ========================================================================

    axi_reg_write(
      C0_SRC_ADDR,
      SRC_ADDR
    );

    // ========================================================================
    // DESTINATION ADDRESS
    //
    // AXI-Stream does not have an address channel, but the descriptor still
    // contains the destination-address field.
    // ========================================================================

    axi_reg_write(
      C0_DST_ADDR,
      DST_ADDR
    );

    // ========================================================================
    // X LENGTH
    //
    // 8 beats -> XLEN = 7
    // ========================================================================

    axi_reg_write(
      C0_XLEN,
      NUM_BEATS-1
    );

    // ========================================================================
    // Y LENGTH = 0
    //
    // 1D transfer
    // ========================================================================

    axi_reg_write(
      C0_YLEN,
      32'h0000_0000
    );

    // ========================================================================
    // SOURCE STRIDE
    // ========================================================================

    axi_reg_write(
      C0_SRC_STRIDE,
      32'h0000_0000
    );

    // ========================================================================
    // DESTINATION STRIDE
    // ========================================================================

    axi_reg_write(
      C0_DST_STRIDE,
      32'h0000_0000
    );

    // ========================================================================
    // CONFIGURATION SUMMARY
    // ========================================================================

    $display("");
    $display("--------------------------------------------------");
    $display("TEST 8 CONFIGURATION COMPLETE");
    $display("--------------------------------------------------");
    $display("C0_SRC_ADDR = %08h", SRC_ADDR);
    $display("C0_DST_ADDR = %08h", DST_ADDR);
    $display("C0_XLEN     = %08h", NUM_BEATS-1);
    $display("C0_WD_BURST = %08h", NUM_BEATS-1);
    $display("SRC_BURST   = 00000001");
    $display("DST_BURST   = 00000001");
    $display("SRC_IF      = AXI4");
    $display("DST_IF      = AXIS");
    $display("--------------------------------------------------");
    $display("");

    // ========================================================================
    // SUBMIT C0 DESCRIPTOR
    // ========================================================================

    $display("[%0t] Submitting C0 descriptor", $time);

    axi_reg_write(
      C0_DESC_SUBMIT,
      32'h0000_0000
    );

    // ========================================================================
    // WAIT FOR ALL 8 PERIPHERAL BEATS
    // ========================================================================

    timeout_cycles = 0;

    while (peripheral_beat_count < NUM_BEATS) begin

      @(posedge aclk);

      timeout_cycles++;

      if (timeout_cycles > 5000)

        $fatal(
          1,
          "TEST 8 TIMEOUT: DMA did not send %0d AXI-Stream beats to peripheral",
          NUM_BEATS
        );

    end

    // ========================================================================
    // SOURCE READ MUST HAVE OCCURRED
    // ========================================================================

    if (!source_read_seen)

      $fatal(
        1,
        "TEST 8 FAIL: DMA never generated an AXI4 source read"
      );

    // ========================================================================
    // SOURCE ADDRESS CHECK
    // ========================================================================

    if (source_mem_addr_seen !== SRC_ADDR)

      $fatal(
        1,
        "TEST 8 FAIL: Source address mismatch: expected %08h got %08h",
        SRC_ADDR,
        source_mem_addr_seen
      );

    // ========================================================================
    // PERIPHERAL BEAT COUNT
    // ========================================================================

    if (peripheral_beat_count !== NUM_BEATS)

      $fatal(
        1,
        "TEST 8 FAIL: Expected %0d peripheral beats, received %0d",
        NUM_BEATS,
        peripheral_beat_count
      );

    // ========================================================================
    // DATA CHECK
    // ========================================================================

    for (i = 0; i < NUM_BEATS; i++) begin

      if (peripheral_beats[i] !== source_beats[i]) begin

        $fatal(
          1,
          "TEST 8 DATA MISMATCH at beat %0d:\nExpected = %064h\nActual   = %064h",
          i,
          source_beats[i],
          peripheral_beats[i]
        );

      end

      else begin

        $display(
          "[%0t] TEST 8 Beat %0d PASS: %064h",
          $time,
          i,
          peripheral_beats[i]
        );

      end

    end

    // ========================================================================
    // ALLOW COMPLETION STATUS / IRQ TO UPDATE
    // ========================================================================

    repeat (5)
      @(posedge aclk);

    if (irq[0] !== 1'b1)

      $display(
        "[%0t] WARNING: irq[0] is not asserted at this exact sample point",
        $time
      );

    else

      $display(
        "[%0t] C0 completion IRQ asserted",
        $time
      );

    // ========================================================================
    // STATUS READS
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
    $display("PASS: C0 %0d-beat memory-to-peripheral transfer",
             NUM_BEATS);
    $display("PASS: AXI4 source -> AXI-Stream destination");
    $display("PASS: Source address = 0x%08h", SRC_ADDR);
    $display("PASS: %0d AXI4 source beats read", NUM_BEATS);
    $display("PASS: %0d AXI-Stream peripheral beats received",
             NUM_BEATS);
    $display("PASS: %0d total bytes transferred", TOTAL_BYTES);
    $display("PASS: Channel = C0");
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
      "TEST 8 GLOBAL TIMEOUT"
    );

  end

endmodule
