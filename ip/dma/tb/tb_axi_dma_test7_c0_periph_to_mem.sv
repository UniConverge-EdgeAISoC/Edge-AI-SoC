`timescale 1ns/1ps

module tb_axi_dma;

  // ==========================================================================
  // Parameters
  // ==========================================================================

  localparam int ADDR_W = 32;
  localparam int DATA_W = 256;
  localparam int S_DATA_W = 32;
  localparam int ID_W = 5;
  localparam int LEN_W = 8;
  localparam int RESP_W = 2;
  localparam int BYTE_W = DATA_W / 8;

  // 256 bits = 32 bytes per AXI beat
  localparam int BYTES_PER_BEAT = DATA_W / 8;

  // Test 7:
  // C0 peripheral-to-memory
  // 8 AXI-Stream beats
  localparam int NUM_BEATS = 8;
  localparam int TOTAL_BYTES = NUM_BEATS * BYTES_PER_BEAT;

  localparam logic [31:0] DMA_BASE = 32'h8000_0000;

  // ==========================================================================
  // DMA Register Map
  // ==========================================================================

  // Global
  localparam logic [31:0] DMA_EN = DMA_BASE + 32'h00;

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

  // C1
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

  localparam logic [31:0] C0_DESC_SUBMIT = DMA_BASE + 32'h1000;
  localparam logic [31:0] C1_DESC_SUBMIT = DMA_BASE + 32'h1010;

  localparam logic [31:0] STATUS_IRQ     = DMA_BASE + 32'h2000;
  localparam logic [31:0] STATUS_XFER_ID = DMA_BASE + 32'h2004;
  localparam logic [31:0] STATUS_DONE    = DMA_BASE + 32'h2008;

  // ==========================================================================
  // Test Addresses
  // ==========================================================================

  localparam logic [31:0] SRC_ADDR = 32'h0003_0000;
  localparam logic [31:0] DST_ADDR = 32'h0004_0000;

  // ==========================================================================
  // Test Data
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
  // Clock / Reset
  // ==========================================================================

  logic aclk;
  logic aresetn;

  initial
    aclk = 1'b0;

  always #5 aclk = ~aclk;

  initial begin
    aresetn = 1'b0;

    repeat (5)
      @(posedge aclk);

    aresetn = 1'b1;
  end


  // ==========================================================================
  // AXI4 Slave Control Interface
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
  // DMA AXI4 Source Read Interface
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
  // DMA AXI4 Destination Write Interface
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
  // AXI-Stream Interfaces
  // ==========================================================================

  logic [ID_W-1:0] s_tid_i;
  logic [1:0] s_tdest_i;
  logic [DATA_W-1:0] s_tdata_i;
  logic [BYTE_W-1:0] s_tkeep_i;
  logic [BYTE_W-1:0] s_tstrb_i;
  logic s_tlast_i;
  logic s_tvalid_i;
  logic s_tready_o;

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

    .SRC_IF_TYPE     ("AXIS"),
    .SRC_ADDR_W      (32),
    .SRC_TDEST_W     (2),
    .ATX_SRC_DATA_W (256),

    .DST_IF_TYPE     ("AXI4"),
    .DST_ADDR_W     (32),
    .DST_TDEST_W    (2),
    .ATX_DST_DATA_W (256),

    .S_DATA_W        (32),
    .S_ADDR_W        (32),
    .MST_ID_W        (5),
    .ATX_LEN_W       (8),
    .ATX_SIZE_W      (3),
    .ATX_RESP_W      (2)
  ) dut (

    .aclk          (aclk),
    .aresetn       (aresetn),

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

    .s_tid_i       (s_tid_i),
    .s_tdest_i     (s_tdest_i),
    .s_tdata_i     (s_tdata_i),
    .s_tkeep_i     (s_tkeep_i),
    .s_tstrb_i     (s_tstrb_i),
    .s_tlast_i     (s_tlast_i),
    .s_tvalid_i    (s_tvalid_i),
    .s_tready_o    (s_tready_o),

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
  // AXI4 Register Write BFM
  // ==========================================================================

  task automatic axi_reg_write(
    input logic [31:0] addr,
    input logic [31:0] data
  );

    begin

      @(posedge aclk);

      s_awid_i     <= '0;
      s_awaddr_i   <= addr;
      s_awburst_i  <= 2'b01;
      s_awlen_i    <= 8'd0;
      s_awvalid_i  <= 1'b1;

      s_wdata_i    <= data;
      s_wlast_i    <= 1'b1;
      s_wvalid_i   <= 1'b1;

      wait (s_awready_o && s_wready_o);

      @(posedge aclk);

      s_awvalid_i <= 1'b0;
      s_wvalid_i  <= 1'b0;

      s_bready_i <= 1'b1;

      wait (s_bvalid_o);

      if (s_bresp_o != 2'b00) begin

        $fatal(
          1,
          "AXI register WRITE response error: addr=%08h resp=%0d",
          addr,
          s_bresp_o
        );

      end

      @(posedge aclk);

      s_bready_i <= 1'b0;

    end

  endtask


  // ==========================================================================
  // AXI4 Register Read BFM
  // ==========================================================================

  task automatic axi_reg_read(
    input logic [31:0] addr,
    output logic [31:0] data
  );

    begin

      @(posedge aclk);

      s_arid_i     <= '0;
      s_araddr_i   <= addr;
      s_arburst_i  <= 2'b01;
      s_arlen_i    <= 8'd0;
      s_arvalid_i  <= 1'b1;

      wait (s_arready_o);

      @(posedge aclk);

      s_arvalid_i <= 1'b0;

      s_rready_i <= 1'b1;

      wait (s_rvalid_o);

      data = s_rdata_o;

      if (s_rresp_o != 2'b00) begin

        $fatal(
          1,
          "AXI register READ response error: addr=%08h resp=%0d",
          addr,
          s_rresp_o
        );

      end

      @(posedge aclk);

      s_rready_i <= 1'b0;

    end

  endtask


  // ==========================================================================
  // AXI-Stream Peripheral Source Model
  // ==========================================================================

  logic source_stream_seen;

  integer source_stream_beat_count;

  logic [255:0] source_beats [0:NUM_BEATS-1];


  initial begin

    source_beats[0] = TEST_DATA_0;
    source_beats[1] = TEST_DATA_1;
    source_beats[2] = TEST_DATA_2;
    source_beats[3] = TEST_DATA_3;
    source_beats[4] = TEST_DATA_4;
    source_beats[5] = TEST_DATA_5;
    source_beats[6] = TEST_DATA_6;
    source_beats[7] = TEST_DATA_7;

    source_stream_seen = 1'b0;

    source_stream_beat_count = 0;

    // Source AXI4 read interface unused in AXIS mode.
    m_arready_i = 1'b1;

    m_rid_i = '0;
    m_rdata_i = '0;
    m_rresp_i = 2'b00;
    m_rlast_i = 1'b0;
    m_rvalid_i = 1'b0;

  end


  initial begin : axis_source_bfm

    int beat;

    wait (aresetn === 1'b1);

    repeat (2)
      @(posedge aclk);

    // Wait until DMA is ready to receive source stream.
    wait (s_tready_o === 1'b1);

    for (beat = 0; beat < NUM_BEATS; beat++) begin

      s_tdata_i <= source_beats[beat];

      s_tkeep_i <= '1;
      s_tstrb_i <= '1;

      s_tid_i <= '0;
      s_tdest_i <= '0;

      s_tlast_i <= (beat == NUM_BEATS-1);

      s_tvalid_i <= 1'b1;

      // VALID remains asserted until READY.
      while (1) begin

        @(posedge aclk);

        if (s_tvalid_i && s_tready_o)
          break;

      end

      source_stream_seen = 1'b1;

      source_stream_beat_count = beat + 1;

      $display(
        "[%0t] AXIS beat %0d transferred: DATA=%064h TLAST=%0b",
        $time,
        beat,
        source_beats[beat],
        (beat == NUM_BEATS-1)
      );

    end

    @(posedge aclk);

    s_tvalid_i <= 1'b0;
    s_tlast_i  <= 1'b0;
    s_tkeep_i  <= '0;
    s_tstrb_i  <= '0;

  end


  // ==========================================================================
  // Destination AXI4 Memory Model
  //
  // IMPORTANT:
  //
  // AXI4 AW and W channels are independent.
  //
  // Therefore:
  //
  //      AW -> W
  //
  //      W  -> AW
  //
  //      AW + W same cycle
  //
  // are all legal.
  //
  // This model therefore DOES NOT require AW to arrive before W.
  // ==========================================================================

  logic [31:0] destination_mem_addr_seen;

  logic destination_write_seen;

  logic [255:0] destination_beats [0:NUM_BEATS-1];

  integer destination_beat_count;

  logic aw_seen;

  logic write_data_done;

  logic [ID_W-1:0] write_id_seen;


  initial begin

    m_awready_i = 1'b1;

    m_wready_i = 1'b1;

    m_bid_i = '0;

    m_bresp_i = 2'b00;

    m_bvalid_i = 1'b0;

    destination_mem_addr_seen = '0;

    destination_write_seen = 1'b0;

    destination_beat_count = 0;

    aw_seen = 1'b0;

    write_data_done = 1'b0;

    write_id_seen = '0;

    for (int i = 0; i < NUM_BEATS; i++)
      destination_beats[i] = '0;

  end


  always @(posedge aclk) begin

    if (!aresetn) begin

      m_bvalid_i <= 1'b0;

      aw_seen <= 1'b0;

      write_data_done <= 1'b0;

      destination_write_seen <= 1'b0;

      destination_beat_count <= 0;

      destination_mem_addr_seen <= '0;

      write_id_seen <= '0;

    end

    else begin

      // ======================================================================
      // AW CHANNEL
      //
      // AW can arrive before W or after W.
      // ======================================================================

      if (m_awvalid_o && m_awready_i) begin

        $display(
          "[%0t] AXI DEST: AW handshake: ADDR=%08h ID=%0d LEN=%0d BURST=%b",
          $time,
          m_awaddr_o,
          m_awid_o,
          m_awlen_o,
          m_awburst_o
        );

        destination_mem_addr_seen <= m_awaddr_o;

        write_id_seen <= m_awid_o;

        aw_seen <= 1'b1;


        // --------------------------------------------------------------------
        // Check burst length
        // --------------------------------------------------------------------

        if (m_awlen_o !== NUM_BEATS-1) begin

          $fatal(
            1,
            "Expected 8-beat destination burst, got AWLEN=%0d",
            m_awlen_o
          );

        end


        // --------------------------------------------------------------------
        // Check burst type
        // --------------------------------------------------------------------

        if (m_awburst_o !== 2'b01) begin

          $fatal(
            1,
            "Expected INCR destination burst, got AWBURST=%b",
            m_awburst_o
          );

        end


        // IMPORTANT:
        //
        // Do NOT reset destination_beat_count here.
        //
        // W may have arrived before AW.
        //
        // If we reset the counter here, previously captured W beats
        // would be corrupted.
        //
      end


      // ======================================================================
      // W CHANNEL
      //
      // W is independent of AW.
      //
      // Therefore we accept W even if aw_seen == 0.
      // ======================================================================

      if (m_wvalid_o && m_wready_i) begin

        // --------------------------------------------------------------------
        // Protect array bounds
        // --------------------------------------------------------------------

        if (destination_beat_count >= NUM_BEATS) begin

          $fatal(
            1,
            "Received more than %0d WDATA beats",
            NUM_BEATS
          );

        end


        // --------------------------------------------------------------------
        // Capture WDATA
        // --------------------------------------------------------------------

        destination_beats[destination_beat_count] <= m_wdata_o;


        $display(
          "[%0t] AXI DEST: W handshake: BEAT=%0d DATA=%064h WLAST=%0b AW_SEEN=%0b",
          $time,
          destination_beat_count,
          m_wdata_o,
          m_wlast_o,
          aw_seen
        );


        // --------------------------------------------------------------------
        // Check WLAST
        // --------------------------------------------------------------------

        if (destination_beat_count == NUM_BEATS-1) begin

          if (!m_wlast_o) begin

            $fatal(
              1,
              "Expected WLAST on final write beat"
            );

          end


          write_data_done <= 1'b1;

          destination_write_seen <= 1'b1;


          // ------------------------------------------------------------------
          // IMPORTANT:
          //
          // B response can only be generated when both AW and complete W
          // transaction are available.
          //
          // If AW already arrived, generate B now.
          //
          // If AW has not arrived yet, wait for AW.
          // ------------------------------------------------------------------

          if (aw_seen) begin

            m_bid_i <= write_id_seen;

            m_bresp_i <= 2'b00;

            m_bvalid_i <= 1'b1;

          end

        end

        else begin

          // WLAST must not occur before final beat.

          if (m_wlast_o) begin

            $fatal(
              1,
              "WLAST asserted too early on write beat %0d",
              destination_beat_count
            );

          end


          destination_beat_count <=
              destination_beat_count + 1;

        end

      end


      // ======================================================================
      // AW arrived AFTER final W beat
      //
      // This handles the legal:
      //
      //      W0 W1 ... W7
      //                   |
      //                  AW
      //
      // case.
      // ======================================================================

      if (m_awvalid_o &&
          m_awready_i &&
          write_data_done &&
          !m_bvalid_i) begin

        m_bid_i <= m_awid_o;

        m_bresp_i <= 2'b00;

        m_bvalid_i <= 1'b1;

      end


      // ======================================================================
      // B CHANNEL
      // ======================================================================

      if (m_bvalid_i && m_bready_o) begin

        $display(
          "[%0t] AXI DEST: B handshake: BID=%0d BRESP=%b",
          $time,
          m_bid_i,
          m_bresp_i
        );

        m_bvalid_i <= 1'b0;

        aw_seen <= 1'b0;

      end

    end

  end


  // ==========================================================================
  // Unused Destination AXI-Stream Interface
  // ==========================================================================

  initial begin

    m_tready_i = 1'b1;

    s_tid_i = '0;
    s_tdest_i = '0;
    s_tdata_i = '0;
    s_tkeep_i = '0;
    s_tstrb_i = '0;
    s_tlast_i = 1'b0;
    s_tvalid_i = 1'b0;

  end


  // ==========================================================================
  // Initialize AXI Control Interface
  // ==========================================================================

  initial begin

    s_awid_i = '0;
    s_awaddr_i = '0;
    s_awburst_i = 2'b01;
    s_awlen_i = '0;
    s_awvalid_i = 1'b0;

    s_wdata_i = '0;
    s_wlast_i = 1'b0;
    s_wvalid_i = 1'b0;

    s_bready_i = 1'b0;

    s_arid_i = '0;
    s_araddr_i = '0;
    s_arburst_i = 2'b01;
    s_arlen_i = '0;
    s_arvalid_i = 1'b0;

    s_rready_i = 1'b0;

  end


  // ==========================================================================
  // MAIN TEST 7
  //
  // C0 Multi-beat Peripheral-to-Memory
  //
  //       AXI-Stream Peripheral
  //                |
  //                | 8 x 256-bit
  //                v
  //             DMA C0
  //                |
  //                | AXI4
  //                v
  //          Destination Memory
  //
  // Total = 8 x 32 bytes = 256 bytes
  // ==========================================================================

  initial begin : c0_periph_to_mem_test

    logic [31:0] status;

    int timeout_cycles;

    int i;


    wait (aresetn === 1'b1);

    repeat (2)
      @(posedge aclk);


    // ------------------------------------------------------------------------
    // Test Header
    // ------------------------------------------------------------------------

    $display("");
    $display("--------------------------------------------------");
    $display("C0 AXI DMA TEST 7");
    $display("8-beat peripheral-to-memory transfer");
    $display("--------------------------------------------------");

    $display("SRC_IF_TYPE      = AXIS");
    $display("DST_IF_TYPE      = AXI4");
    $display("DATA_W           = %0d bits", DATA_W);
    $display("BYTES_PER_BEAT   = %0d bytes", BYTES_PER_BEAT);
    $display("NUM_BEATS        = %0d", NUM_BEATS);
    $display("TOTAL_BYTES      = %0d bytes", TOTAL_BYTES);
    $display("DST_ADDR         = 0x%08h", DST_ADDR);
    $display("CHANNEL          = C0");

    $display("--------------------------------------------------");


    // ------------------------------------------------------------------------
    // Global DMA Enable
    // ------------------------------------------------------------------------

    axi_reg_write(
      DMA_EN,
      32'h0000_0001
    );


    // ------------------------------------------------------------------------
    // C0 Configuration
    // ------------------------------------------------------------------------

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


    // Destination AXI4 INCR burst.

    axi_reg_write(
      C0_DST_BURST,
      32'h0000_0001
    );


    // Source burst configuration is irrelevant for AXIS source,
    // but keep register defined.

    axi_reg_write(
      C0_SRC_BURST,
      32'h0000_0001
    );


    // 8 beats => AXI LEN = 7.

    axi_reg_write(
      C0_WD_BURST,
      NUM_BEATS-1
    );


    // Source address field.

    axi_reg_write(
      C0_SRC_ADDR,
      SRC_ADDR
    );


    // Destination address.

    axi_reg_write(
      C0_DST_ADDR,
      DST_ADDR
    );


    // 8 transfer units.

    axi_reg_write(
      C0_XLEN,
      NUM_BEATS-1
    );


    axi_reg_write(
      C0_YLEN,
      32'h0000_0000
    );


    axi_reg_write(
      C0_SRC_STRIDE,
      32'h0000_0000
    );


    axi_reg_write(
      C0_DST_STRIDE,
      32'h0000_0000
    );


    // ------------------------------------------------------------------------
    // Submit Descriptor
    // ------------------------------------------------------------------------

    $display(
      "[%0t] Submitting C0 descriptor",
      $time
    );

    axi_reg_write(
      C0_DESC_SUBMIT,
      32'h0000_0000
    );


    // ------------------------------------------------------------------------
    // Wait for all source AXI-Stream beats
    // ------------------------------------------------------------------------

    timeout_cycles = 0;

    while (source_stream_beat_count < NUM_BEATS) begin

      @(posedge aclk);

      timeout_cycles++;

      if (timeout_cycles > 5000) begin

        $fatal(
          1,
          "TIMEOUT: DMA C0 did not consume %0d AXI-Stream source beats",
          NUM_BEATS
        );

      end

    end


    $display(
      "[%0t] All %0d AXI-Stream source beats accepted by DMA",
      $time,
      NUM_BEATS
    );


    // ------------------------------------------------------------------------
    // Wait for Destination Write
    // ------------------------------------------------------------------------

    timeout_cycles = 0;

    while (!destination_write_seen) begin

      @(posedge aclk);

      timeout_cycles++;

      if (timeout_cycles > 5000) begin

        $fatal(
          1,
          "TIMEOUT: DMA C0 did not complete %0d-beat destination write",
          NUM_BEATS
        );

      end

    end


    // ------------------------------------------------------------------------
    // Destination Address Check
    // ------------------------------------------------------------------------

    if (destination_mem_addr_seen !== DST_ADDR) begin

      $fatal(
        1,
        "C0 destination address mismatch: expected %08h got %08h",
        DST_ADDR,
        destination_mem_addr_seen
      );

    end
    else begin

      $display(
        "[%0t] Destination address PASS: %08h",
        $time,
        destination_mem_addr_seen
      );

    end


    // ------------------------------------------------------------------------
    // Data Checks
    // ------------------------------------------------------------------------

    for (i = 0; i < NUM_BEATS; i++) begin

      if (destination_beats[i] !== source_beats[i]) begin

        $fatal(
          1,
          "C0 DATA MISMATCH at beat %0d:\nExpected = %064h\nActual   = %064h",
          i,
          source_beats[i],
          destination_beats[i]
        );

      end
      else begin

        $display(
          "[%0t] C0 Beat %0d PASS: %064h",
          $time,
          i,
          destination_beats[i]
        );

      end

    end


    // ------------------------------------------------------------------------
    // Source Protocol Checks
    // ------------------------------------------------------------------------

    if (!source_stream_seen) begin

      $fatal(
        1,
        "C0 AXI-Stream source was never accepted by DMA"
      );

    end


    if (source_stream_beat_count !== NUM_BEATS) begin

      $fatal(
        1,
        "C0 unexpected AXI-Stream beat count: %0d",
        source_stream_beat_count
      );

    end


    // ------------------------------------------------------------------------
    // Destination Beat Count
    // ------------------------------------------------------------------------

    if (destination_beat_count !== NUM_BEATS-1) begin

      $fatal(
        1,
        "C0 unexpected destination beat count: %0d",
        destination_beat_count
      );

    end


    // ------------------------------------------------------------------------
    // Allow Completion Logic to Update
    // ------------------------------------------------------------------------

    repeat (5)
      @(posedge aclk);


    // ------------------------------------------------------------------------
    // IRQ Check
    // ------------------------------------------------------------------------

    if (irq[0] !== 1'b1) begin

      $display(
        "[%0t] WARNING: irq[0] is not asserted at this exact sample point",
        $time
      );

    end
    else begin

      $display(
        "[%0t] C0 completion IRQ asserted",
        $time
      );

    end


    // ------------------------------------------------------------------------
    // Status Registers
    // ------------------------------------------------------------------------

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


    // ------------------------------------------------------------------------
    // PASS
    // ------------------------------------------------------------------------

    $display("");
    $display("--------------------------------------------------");
    $display(
      "PASS: C0 %0d-beat peripheral-to-memory transfer",
      NUM_BEATS
    );
    $display("PASS: AXI-Stream source -> AXI4 destination");
    $display(
      "PASS: %0d AXI-Stream beats accepted",
      NUM_BEATS
    );
    $display(
      "PASS: %0d total bytes transferred",
      TOTAL_BYTES
    );
    $display(
      "PASS: Destination address = 0x%08h",
      DST_ADDR
    );
    $display("PASS: Channel = C0");
    $display("--------------------------------------------------");


    #20;

    $finish;

  end


  // ==========================================================================
  // Global Timeout
  // ==========================================================================

  initial begin

    #100_000;

    $fatal(
      1,
      "GLOBAL TIMEOUT"
    );

  end

endmodule