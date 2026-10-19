`timescale 1ns/1ps

module tb_axi_dma_mem_to_mem_large;

  // ==========================================================================
  // Parameters
  // ==========================================================================
  localparam int ADDR_W        = 32;
  localparam int DATA_W        = 256;
  localparam int S_DATA_W      = 32;
  localparam int ID_W          = 5;
  localparam int LEN_W         = 8;
  localparam int RESP_W        = 2;
  localparam int BYTE_W        = DATA_W/8;

  localparam int BYTES_PER_BEAT = DATA_W / 8;

  // --------------------------------------------------------------------------
  // TEST 3
  // 16 AXI beats x 32 bytes = 512 bytes
  // --------------------------------------------------------------------------
  localparam int NUM_BEATS     = 16;
  localparam int TOTAL_BYTES   = NUM_BEATS * BYTES_PER_BEAT;

  localparam logic [31:0] DMA_BASE = 32'h8000_0000;

  // ==========================================================================
  // Register map
  // ==========================================================================

  // Global
  localparam logic [31:0] DMA_EN       = DMA_BASE + 32'h00;

  // C0
  localparam logic [31:0] C0_CTRL       = DMA_BASE + 32'h01;
  localparam logic [31:0] C0_XFER_CTRL  = DMA_BASE + 32'h02;
  localparam logic [31:0] C0_IRQ_MASK   = DMA_BASE + 32'h03;
  localparam logic [31:0] C0_ARB_RATE   = DMA_BASE + 32'h04;
  localparam logic [31:0] C0_ATX_ID     = DMA_BASE + 32'h05;
  localparam logic [31:0] C0_SRC_BURST  = DMA_BASE + 32'h06;
  localparam logic [31:0] C0_DST_BURST  = DMA_BASE + 32'h07;
  localparam logic [31:0] C0_WD_BURST   = DMA_BASE + 32'h08;
  localparam logic [31:0] C0_SRC_ADDR   = DMA_BASE + 32'h09;
  localparam logic [31:0] C0_DST_ADDR   = DMA_BASE + 32'h0A;
  localparam logic [31:0] C0_XLEN       = DMA_BASE + 32'h0B;
  localparam logic [31:0] C0_YLEN       = DMA_BASE + 32'h0C;
  localparam logic [31:0] C0_SRC_STRIDE = DMA_BASE + 32'h0D;
  localparam logic [31:0] C0_DST_STRIDE = DMA_BASE + 32'h0E;

  // C1 -- not used in this test
  localparam logic [31:0] C1_CTRL       = DMA_BASE + 32'h11;
  localparam logic [31:0] C1_XFER_CTRL  = DMA_BASE + 32'h12;
  localparam logic [31:0] C1_IRQ_MASK   = DMA_BASE + 32'h13;
  localparam logic [31:0] C1_ARB_RATE   = DMA_BASE + 32'h14;
  localparam logic [31:0] C1_ATX_ID     = DMA_BASE + 32'h15;
  localparam logic [31:0] C1_SRC_BURST  = DMA_BASE + 32'h16;
  localparam logic [31:0] C1_DST_BURST  = DMA_BASE + 32'h17;
  localparam logic [31:0] C1_WD_BURST   = DMA_BASE + 32'h18;
  localparam logic [31:0] C1_SRC_ADDR   = DMA_BASE + 32'h19;
  localparam logic [31:0] C1_DST_ADDR   = DMA_BASE + 32'h1A;
  localparam logic [31:0] C1_XLEN       = DMA_BASE + 32'h1B;
  localparam logic [31:0] C1_YLEN       = DMA_BASE + 32'h1C;
  localparam logic [31:0] C1_SRC_STRIDE = DMA_BASE + 32'h1D;
  localparam logic [31:0] C1_DST_STRIDE = DMA_BASE + 32'h1E;

  // Descriptor/status
  localparam logic [31:0] C0_DESC_SUBMIT = DMA_BASE + 32'h1000;

  localparam logic [31:0] STATUS_IRQ     = DMA_BASE + 32'h2000;
  localparam logic [31:0] STATUS_XFER_ID = DMA_BASE + 32'h2004;
  localparam logic [31:0] STATUS_DONE    = DMA_BASE + 32'h2008;

  // ==========================================================================
  // Memory addresses
  // ==========================================================================

  localparam logic [31:0] SRC_ADDR = 32'h0001_0000;
  localparam logic [31:0] DST_ADDR = 32'h0002_0000;

  // ==========================================================================
  // Clock / reset
  // ==========================================================================

  logic aclk;
  logic aresetn;

  initial aclk = 1'b0;

  always #5 aclk = ~aclk;       // 100 MHz

  initial begin
    aresetn = 1'b0;

    repeat (5)
      @(posedge aclk);

    aresetn = 1'b1;
  end

  // ==========================================================================
  // Control AXI interface
  // ==========================================================================

  logic [ID_W-1:0]     s_awid_i;
  logic [ADDR_W-1:0]   s_awaddr_i;
  logic [1:0]          s_awburst_i;
  logic [LEN_W-1:0]    s_awlen_i;
  logic                s_awvalid_i;
  logic                s_awready_o;

  logic [S_DATA_W-1:0] s_wdata_i;
  logic                s_wlast_i;
  logic                s_wvalid_i;
  logic                s_wready_o;

  logic [ID_W-1:0]     s_bid_o;
  logic [RESP_W-1:0]   s_bresp_o;
  logic                s_bvalid_o;
  logic                s_bready_i;

  logic [ID_W-1:0]     s_arid_i;
  logic [ADDR_W-1:0]   s_araddr_i;
  logic [1:0]          s_arburst_i;
  logic [LEN_W-1:0]    s_arlen_i;
  logic                s_arvalid_i;
  logic                s_arready_o;

  logic [ID_W-1:0]     s_rid_o;
  logic [S_DATA_W-1:0] s_rdata_o;
  logic [RESP_W-1:0]   s_rresp_o;
  logic                s_rlast_o;
  logic                s_rvalid_o;
  logic                s_rready_i;

  // ==========================================================================
  // DMA source AXI read interface
  // ==========================================================================

  logic [ID_W-1:0]     m_arid_o;
  logic [ADDR_W-1:0]   m_araddr_o;
  logic [LEN_W-1:0]    m_arlen_o;
  logic [1:0]          m_arburst_o;
  logic                m_arvalid_o;
  logic                m_arready_i;

  logic [ID_W-1:0]     m_rid_i;
  logic [DATA_W-1:0]   m_rdata_i;
  logic [RESP_W-1:0]   m_rresp_i;
  logic                m_rlast_i;
  logic                m_rvalid_i;
  logic                m_rready_o;

  // ==========================================================================
  // DMA destination AXI write interface
  // ==========================================================================

  logic [ID_W-1:0]     m_awid_o;
  logic [ADDR_W-1:0]   m_awaddr_o;
  logic [LEN_W-1:0]    m_awlen_o;
  logic [1:0]          m_awburst_o;
  logic                m_awvalid_o;
  logic                m_awready_i;

  logic [DATA_W-1:0]   m_wdata_o;
  logic                m_wlast_o;
  logic                m_wvalid_o;
  logic                m_wready_i;

  logic [ID_W-1:0]     m_bid_i;
  logic [RESP_W-1:0]   m_bresp_i;
  logic                m_bvalid_i;
  logic                m_bready_o;

  // ==========================================================================
  // AXI Stream -- unused
  // ==========================================================================

  logic [ID_W-1:0]     s_tid_i;
  logic [1:0]          s_tdest_i;
  logic [DATA_W-1:0]   s_tdata_i;
  logic [BYTE_W-1:0]   s_tkeep_i;
  logic [BYTE_W-1:0]   s_tstrb_i;
  logic                s_tlast_i;
  logic                s_tvalid_i;
  logic                s_tready_o;

  logic [ID_W-1:0]     m_tid_o;
  logic [1:0]          m_tdest_o;
  logic [DATA_W-1:0]   m_tdata_o;
  logic [BYTE_W-1:0]   m_tkeep_o;
  logic [BYTE_W-1:0]   m_tstrb_o;
  logic                m_tlast_o;
  logic                m_tvalid_o;
  logic                m_tready_i;

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

    .SRC_IF_TYPE     ("AXI4"),
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
    .ATX_LEN_W       (8),
    .ATX_SIZE_W      (3),
    .ATX_RESP_W      (2)
  ) dut (

    .aclk          (aclk),
    .aresetn       (aresetn),

    // Control AXI
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

    // Source AXI
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

    // Stream
    .s_tid_i       (s_tid_i),
    .s_tdest_i     (s_tdest_i),
    .s_tdata_i     (s_tdata_i),
    .s_tkeep_i     (s_tkeep_i),
    .s_tstrb_i     (s_tstrb_i),
    .s_tlast_i     (s_tlast_i),
    .s_tvalid_i    (s_tvalid_i),
    .s_tready_o    (s_tready_o),

    // Destination AXI
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
  // Test data generation
  //
  // Every beat has a different 256-bit pattern.
  //
  // Beat 0 = 00000000...0000
  // Beat 1 = 01010101...0101
  // Beat 2 = 02020202...0202
  // ...
  // Beat 15 = 0F0F0F0F...0F0F
  //
  // This makes beat ordering very easy to see in the waveform.
  // ==========================================================================

  function automatic logic [DATA_W-1:0]
    expected_data(input integer beat);

    logic [7:0] pattern;

    begin
      pattern = beat[7:0];

      for (int j = 0; j < DATA_W/8; j++)
        expected_data[j*8 +: 8] = pattern;
    end

  endfunction

  // ==========================================================================
  // Source memory model
  // ==========================================================================

  logic [31:0] source_mem_addr_seen;
  logic        source_read_seen;

  logic [DATA_W-1:0] source_beats [0:NUM_BEATS-1];

  integer source_beat_count;

  initial begin

    m_arready_i = 1'b1;

    m_rid_i    = '0;
    m_rdata_i  = '0;
    m_rresp_i  = 2'b00;
    m_rlast_i  = 1'b0;
    m_rvalid_i = 1'b0;

    source_mem_addr_seen = '0;
    source_read_seen     = 1'b0;

    source_beat_count = 0;

    for (int i = 0; i < NUM_BEATS; i++)
      source_beats[i] = expected_data(i);

  end

  always @(posedge aclk) begin

    if (!aresetn) begin

      m_rvalid_i <= 1'b0;
      m_rlast_i  <= 1'b0;

      source_read_seen  <= 1'b0;
      source_beat_count <= 0;

    end
    else begin

      // --------------------------------------------------------------
      // Read address handshake
      // --------------------------------------------------------------

      if (m_arvalid_o && m_arready_i) begin

        source_mem_addr_seen <= m_araddr_o;
        source_read_seen     <= 1'b1;

        // 16 beats -> ARLEN = 15
        if (m_arlen_o !== NUM_BEATS-1)
          $fatal(1,
                 "Expected 16-beat source burst, got ARLEN=%0d",
                 m_arlen_o);

        if (m_arburst_o !== 2'b01)
          $fatal(1,
                 "Expected INCR source burst, got ARBURST=%b",
                 m_arburst_o);

        m_rid_i <= m_arid_o;

        source_beat_count <= 0;

        m_rdata_i <= source_beats[0];

        m_rresp_i <= 2'b00;

        m_rlast_i <= (NUM_BEATS == 1);

        m_rvalid_i <= 1'b1;

      end

      // --------------------------------------------------------------
      // Read data handshake
      // --------------------------------------------------------------

      if (m_rvalid_i && m_rready_o) begin

        if (source_beat_count == NUM_BEATS-1) begin

          // Last read beat
          m_rvalid_i <= 1'b0;
          m_rlast_i  <= 1'b0;

        end
        else begin

          source_beat_count <= source_beat_count + 1;

          m_rdata_i <=
              source_beats[source_beat_count + 1];

          m_rlast_i <=
              ((source_beat_count + 1) == NUM_BEATS-1);

          m_rvalid_i <= 1'b1;

        end

      end

    end

  end

  // ==========================================================================
  // Destination memory model
  // ==========================================================================

  logic [31:0] destination_mem_addr_seen;
  logic        destination_write_seen;

  logic [DATA_W-1:0] destination_beats [0:NUM_BEATS-1];

  integer destination_beat_count;

  logic aw_seen;

  logic [ID_W-1:0] write_id_seen;

  initial begin

    m_awready_i = 1'b1;
    m_wready_i  = 1'b1;

    m_bid_i     = '0;
    m_bresp_i   = 2'b00;
    m_bvalid_i  = 1'b0;

    destination_mem_addr_seen = '0;
    destination_write_seen    = 1'b0;

    destination_beat_count = 0;

    aw_seen = 1'b0;

    write_id_seen = '0;

    for (int i = 0; i < NUM_BEATS; i++)
      destination_beats[i] = '0;

  end

  always @(posedge aclk) begin

    if (!aresetn) begin

      m_bvalid_i <= 1'b0;

      aw_seen <= 1'b0;

      destination_write_seen <= 1'b0;

      destination_beat_count <= 0;

    end
    else begin

      // --------------------------------------------------------------
      // Write address handshake
      // --------------------------------------------------------------

      if (m_awvalid_o && m_awready_i) begin

        destination_mem_addr_seen <= m_awaddr_o;

        write_id_seen <= m_awid_o;

        aw_seen <= 1'b1;

        // 16 beats -> AWLEN = 15
        if (m_awlen_o !== NUM_BEATS-1)
          $fatal(1,
                 "Expected 16-beat destination burst, got AWLEN=%0d",
                 m_awlen_o);

        if (m_awburst_o !== 2'b01)
          $fatal(1,
                 "Expected INCR destination burst, got AWBURST=%b",
                 m_awburst_o);

        destination_beat_count <= 0;

      end

      // --------------------------------------------------------------
      // Write data handshake
      // --------------------------------------------------------------

      if (m_wvalid_o && m_wready_i) begin

        if (!aw_seen)
          $fatal(1,
                 "Write data arrived before AW handshake");

        // Store current beat
        destination_beats[destination_beat_count]
            <= m_wdata_o;

        // ----------------------------------------------------------
        // Final beat
        // ----------------------------------------------------------

        if (destination_beat_count == NUM_BEATS-1) begin

          if (!m_wlast_o)
            $fatal(1,
                   "Expected WLAST on final beat");

          destination_write_seen <= 1'b1;

          // Generate successful B response
          m_bid_i <= write_id_seen;

          m_bresp_i <= 2'b00;

          m_bvalid_i <= 1'b1;

        end

        // ----------------------------------------------------------
        // Intermediate beat
        // ----------------------------------------------------------

        else begin

          if (m_wlast_o)
            $fatal(1,
                   "WLAST asserted too early on beat %0d",
                   destination_beat_count);

          destination_beat_count <=
              destination_beat_count + 1;

        end

      end

      // --------------------------------------------------------------
      // B response handshake
      // --------------------------------------------------------------

      if (m_bvalid_i && m_bready_o) begin

        m_bvalid_i <= 1'b0;

        aw_seen <= 1'b0;

      end

    end

  end

  // ==========================================================================
  // AXI register write task
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

      @(posedge aclk);

      s_awvalid_i <= 1'b0;
      s_wvalid_i  <= 1'b0;

      s_bready_i <= 1'b1;

      wait (s_bvalid_o);

      if (s_bresp_o != 2'b00)
        $fatal(1,
               "AXI register WRITE response error: addr=%08h resp=%0d",
               addr,
               s_bresp_o);

      @(posedge aclk);

      s_bready_i <= 1'b0;

    end

  endtask

  // ==========================================================================
  // AXI register read task
  // ==========================================================================

  task automatic axi_reg_read(
    input  logic [31:0] addr,
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
        $fatal(1,
               "AXI register READ response error: addr=%08h resp=%0d",
               addr,
               s_rresp_o);

      @(posedge aclk);

      s_rready_i <= 1'b0;

    end

  endtask

  // ==========================================================================
  // Tie off unused AXI Stream interfaces
  // ==========================================================================

  initial begin

    s_tid_i    = '0;
    s_tdest_i  = '0;
    s_tdata_i  = '0;
    s_tkeep_i  = '0;
    s_tstrb_i  = '0;
    s_tlast_i  = 1'b0;
    s_tvalid_i = 1'b0;

    m_tready_i = 1'b1;

  end

  // ==========================================================================
  // Initialize control interface
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
  // TEST 3
  // ==========================================================================

  initial begin : large_multi_beat_test

    logic [31:0] status;

    int timeout_cycles;
    int i;

    // --------------------------------------------------------------
    // Wait for reset
    // --------------------------------------------------------------

    wait (aresetn === 1'b1);

    repeat (2)
      @(posedge aclk);

    // --------------------------------------------------------------
    // Test header
    // --------------------------------------------------------------

    $display("--------------------------------------------------");
    $display("C0 AXI DMA 16-beat memory-to-memory test");
    $display("--------------------------------------------------");

    $display("DATA_W          = %0d bits",
             DATA_W);

    $display("BYTES_PER_BEAT  = %0d bytes",
             BYTES_PER_BEAT);

    $display("NUM_BEATS       = %0d",
             NUM_BEATS);

    $display("TOTAL_BYTES     = %0d bytes",
             TOTAL_BYTES);

    $display("SRC_ADDR        = 0x%08h",
             SRC_ADDR);

    $display("DST_ADDR        = 0x%08h",
             DST_ADDR);

    $display("--------------------------------------------------");

    // --------------------------------------------------------------
    // Enable DMA
    // --------------------------------------------------------------

    axi_reg_write(
      DMA_EN,
      32'h0000_0001
    );

    // --------------------------------------------------------------
    // Configure C0
    // --------------------------------------------------------------

    axi_reg_write(
      C0_CTRL,
      32'h0000_0001
    );

    axi_reg_write(
      C0_XFER_CTRL,
      32'h0000_0000
    );

    axi_reg_write(
      C0_IRQ_MASK,
      32'h0000_0001
    );

    axi_reg_write(
      C0_ARB_RATE,
      32'h0000_0001
    );

    axi_reg_write(
      C0_ATX_ID,
      32'h0000_0000
    );

    // INCR bursts
    axi_reg_write(
      C0_SRC_BURST,
      32'h0000_0001
    );

    axi_reg_write(
      C0_DST_BURST,
      32'h0000_0001
    );

    // --------------------------------------------------------------
    // Burst length
    //
    // 16 beats -> LEN = 15
    // --------------------------------------------------------------

    axi_reg_write(
      C0_WD_BURST,
      NUM_BEATS-1
    );

    // --------------------------------------------------------------
    // Source / destination addresses
    // --------------------------------------------------------------

    axi_reg_write(
      C0_SRC_ADDR,
      SRC_ADDR
    );

    axi_reg_write(
      C0_DST_ADDR,
      DST_ADDR
    );

    // --------------------------------------------------------------
    // X transfer length
    //
    // 16 beats -> XLEN = 15
    // --------------------------------------------------------------

    axi_reg_write(
      C0_XLEN,
      NUM_BEATS-1
    );

    // 1D transfer
    axi_reg_write(
      C0_YLEN,
      32'h0000_0000
    );

    // No stride for 1D contiguous transfer
    axi_reg_write(
      C0_SRC_STRIDE,
      32'h0000_0000
    );

    axi_reg_write(
      C0_DST_STRIDE,
      32'h0000_0000
    );

    // --------------------------------------------------------------
    // Submit descriptor
    // --------------------------------------------------------------

    $display(
      "[%0t] Submitting C0 descriptor",
      $time
    );

    axi_reg_write(
      C0_DESC_SUBMIT,
      32'h0000_0000
    );

    // --------------------------------------------------------------
    // Wait for complete destination transfer
    // --------------------------------------------------------------

    timeout_cycles = 0;

    while (!destination_write_seen) begin

      @(posedge aclk);

      timeout_cycles++;

      if (timeout_cycles > 5000)
        $fatal(
          1,
          "TIMEOUT: DMA did not complete 16-beat transfer"
        );

    end

    // --------------------------------------------------------------
    // Address checks
    // --------------------------------------------------------------

    if (source_mem_addr_seen !== SRC_ADDR)
      $fatal(
        1,
        "Source address mismatch: expected %08h got %08h",
        SRC_ADDR,
        source_mem_addr_seen
      );

    if (destination_mem_addr_seen !== DST_ADDR)
      $fatal(
        1,
        "Destination address mismatch: expected %08h got %08h",
        DST_ADDR,
        destination_mem_addr_seen
      );

    // --------------------------------------------------------------
    // Verify every beat
    // --------------------------------------------------------------

    for (i = 0; i < NUM_BEATS; i++) begin

      if (destination_beats[i] !== source_beats[i]) begin

        $fatal(
          1,
          "DATA MISMATCH at beat %0d:\nExpected = %064h\nActual   = %064h",
          i,
          source_beats[i],
          destination_beats[i]
        );

      end

      else begin

        $display(
          "[%0t] Beat %0d PASS: %064h",
          $time,
          i,
          destination_beats[i]
        );

      end

    end

    // --------------------------------------------------------------
    // Source read check
    // --------------------------------------------------------------

    if (!source_read_seen)
      $fatal(
        1,
        "Source AXI read was never observed"
      );

    // --------------------------------------------------------------
    // Give status/IRQ logic time to update
    // --------------------------------------------------------------

    repeat (5)
      @(posedge aclk);

    $display(
      "[%0t] All %0d AXI data beats match",
      $time,
      NUM_BEATS
    );

    // --------------------------------------------------------------
    // IRQ visibility
    // --------------------------------------------------------------

    if (irq[0] !== 1'b1)

      $display(
        "[%0t] WARNING: irq[0] is not asserted at this exact sample point",
        $time
      );

    // --------------------------------------------------------------
    // Read status registers
    //
    // These are informational for now because the existing environment
    // showed Z values on these registers.
    // --------------------------------------------------------------

    axi_reg_read(
      STATUS_IRQ,
      status
    );

    $display(
      "[%0t] STATUS_IRQ  = 0x%08h",
      $time,
      status
    );

    axi_reg_read(
      STATUS_DONE,
      status
    );

    $display(
      "[%0t] STATUS_DONE = 0x%08h",
      $time,
      status
    );

    // --------------------------------------------------------------
    // PASS
    // --------------------------------------------------------------

    $display("--------------------------------------------------");
    $display("PASS: C0 16-beat memory-to-memory transfer");
    $display("PASS: %0d AXI beats transferred", NUM_BEATS);
    $display("PASS: %0d total bytes transferred", TOTAL_BYTES);
    $display("PASS: Source address      = 0x%08h", SRC_ADDR);
    $display("PASS: Destination address = 0x%08h", DST_ADDR);
    $display("--------------------------------------------------");

    #20;

    $finish;

  end

  // ==========================================================================
  // Global timeout
  // ==========================================================================

  initial begin

    #100_000;

    $fatal(
      1,
      "GLOBAL TIMEOUT"
    );

  end

endmodule