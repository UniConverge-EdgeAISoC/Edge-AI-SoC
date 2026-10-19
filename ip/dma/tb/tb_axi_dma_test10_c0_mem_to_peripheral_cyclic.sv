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

  localparam int BYTES_PER_BEAT = DATA_W/8;

  // Test 10:
  // C0 cyclic memory-to-peripheral transfer
  //
  // Source      : AXI4 memory
  // Destination : AXI-Stream peripheral
  //
  // One cyclic descriptor:
  //     8 beats/cycle
  //     3 cycles observed
  //     24 total AXI-Stream beats
  //
  // The descriptor is submitted ONCE.
  // The DMA must generate one AXI read transaction per cycle.
  // After cycle 3, the TB disables C0 and verifies that no 4th
  // AXI read transaction occurs.

  localparam int BEATS_PER_CYCLE = 8;
  localparam int NUM_CYCLES      = 3;
  localparam int TOTAL_BEATS     = BEATS_PER_CYCLE * NUM_CYCLES;
  localparam int TOTAL_BYTES     = BEATS_PER_CYCLE * BYTES_PER_BEAT;

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
  // UNUSED IN TEST 10
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
  // UNUSED IN TEST 10
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
  // ACTIVE IN TEST 10
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
  // ==========================================================================

  task automatic axi_reg_write(
    input logic [31:0] addr,
    input logic [31:0] data
  );

    bit aw_done;
    bit w_done;

    begin

      aw_done = 1'b0;
      w_done  = 1'b0;

      @(posedge aclk);

      s_awid_i    <= '0;
      s_awaddr_i  <= addr;
      s_awburst_i <= 2'b01;
      s_awlen_i   <= 8'd0;
      s_awvalid_i <= 1'b1;

      s_wdata_i   <= data;
      s_wlast_i   <= 1'b1;
      s_wvalid_i  <= 1'b1;

      while (!(aw_done && w_done)) begin

        @(posedge aclk);

        if (!aw_done && s_awvalid_i && s_awready_o) begin
          aw_done = 1'b1;
          s_awvalid_i <= 1'b0;
        end

        if (!w_done && s_wvalid_i && s_wready_o) begin
          w_done = 1'b1;
          s_wvalid_i <= 1'b0;
        end

      end

      s_awaddr_i <= '0;
      s_wdata_i  <= '0;

      s_bready_i <= 1'b1;

      while (!s_bvalid_o)
        @(posedge aclk);

      if (s_bresp_o !== 2'b00) begin
        $fatal(
          1,
          "[%0t] AXI REG WRITE ERROR: addr=%08h data=%08h BRESP=%b",
          $time, addr, data, s_bresp_o
        );
      end

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

      while (!s_arready_o)
        @(posedge aclk);

      @(posedge aclk);

      s_arvalid_i <= 1'b0;
      s_rready_i  <= 1'b1;

      while (!s_rvalid_o)
        @(posedge aclk);

      data = s_rdata_o;

      if (s_rresp_o !== 2'b00) begin
        $fatal(
          1,
          "[%0t] AXI REG READ ERROR: addr=%08h RRESP=%b",
          $time, addr, s_rresp_o
        );
      end

      @(posedge aclk);

      s_rready_i <= 1'b0;

    end

  endtask

  // ==========================================================================
  // SOURCE MEMORY DATA
  // ==========================================================================

  logic [255:0] source_beats [0:BEATS_PER_CYCLE-1];

  initial begin
    source_beats[0] = TEST_DATA_0;
    source_beats[1] = TEST_DATA_1;
    source_beats[2] = TEST_DATA_2;
    source_beats[3] = TEST_DATA_3;
    source_beats[4] = TEST_DATA_4;
    source_beats[5] = TEST_DATA_5;
    source_beats[6] = TEST_DATA_6;
    source_beats[7] = TEST_DATA_7;
  end

  // ==========================================================================
  // AXI SOURCE MEMORY MODEL
  //
  // One AR transaction = one cyclic transfer/cycle.
  //
  // For every AR:
  //     ARADDR  = 00030000
  //     ARLEN   = 7
  //     ARBURST = 01
  //
  // The same 8-beat source data is returned for every cyclic repetition.
  // ==========================================================================

  integer ar_transaction_count;
  integer r_beat_count;
  integer current_r_beat;

  logic [ID_W-1:0] active_rid;

  initial begin

    ar_transaction_count = 0;
    r_beat_count         = 0;
    current_r_beat       = 0;
    active_rid           = '0;

    m_arready_i = 1'b1;

    m_rid_i     = '0;
    m_rdata_i   = '0;
    m_rresp_i   = 2'b00;
    m_rlast_i   = 1'b0;
    m_rvalid_i  = 1'b0;

  end

  always @(posedge aclk) begin

    if (!aresetn) begin

      ar_transaction_count <= 0;
      r_beat_count         <= 0;
      current_r_beat       <= 0;

      m_rvalid_i <= 1'b0;
      m_rlast_i  <= 1'b0;

    end
    else begin

      // -----------------------------------------------------------------------
      // AR HANDSHAKE
      // -----------------------------------------------------------------------

      if (m_arvalid_o && m_arready_i) begin

        ar_transaction_count <= ar_transaction_count + 1;

        $display("");
        $display("============================================================");
        $display(
          "[%0t] AXI MEMORY: AR TRANSACTION #%0d",
          $time,
          ar_transaction_count + 1
        );
        $display("ARADDR  = %08h", m_araddr_o);
        $display("ARLEN   = %0d", m_arlen_o);
        $display("ARBURST = %02b", m_arburst_o);
        $display("ARID    = %0d", m_arid_o);
        $display("============================================================");

        // Check address.

        if (m_araddr_o !== SRC_ADDR) begin
          $fatal(
            1,
            "[%0t] TEST 10 FAIL: ARADDR expected %08h, got %08h",
            $time, SRC_ADDR, m_araddr_o
          );
        end

        // Check burst length.

        if (m_arlen_o !== BEATS_PER_CYCLE-1) begin
          $fatal(
            1,
            "[%0t] TEST 10 FAIL: ARLEN expected %0d, got %0d",
            $time, BEATS_PER_CYCLE-1, m_arlen_o
          );
        end

        // Check burst type.

        if (m_arburst_o !== 2'b01) begin
          $fatal(
            1,
            "[%0t] TEST 10 FAIL: ARBURST expected 01 (INCR), got %02b",
            $time, m_arburst_o
          );
        end

        // The TB allows exactly NUM_CYCLES read transactions.

        if ((ar_transaction_count + 1) > NUM_CYCLES) begin
          $fatal(
            1,
            "[%0t] TEST 10 FAIL: Unexpected AR transaction #%0d",
            $time, ar_transaction_count + 1
          );
        end

        active_rid     <= m_arid_o;
        current_r_beat <= 0;

        // First R beat.

        m_rid_i    <= m_arid_o;
        m_rdata_i  <= source_beats[0];
        m_rresp_i  <= 2'b00;
        m_rlast_i  <= (BEATS_PER_CYCLE == 1);
        m_rvalid_i <= 1'b1;

      end

      // -----------------------------------------------------------------------
      // R HANDSHAKE
      //
      // RVALID remains asserted until DMA raises RREADY.
      // -----------------------------------------------------------------------

      if (m_rvalid_i && m_rready_o) begin

        r_beat_count <= r_beat_count + 1;

        $display(
          "[%0t] AXI MEMORY: R handshake cycle=%0d beat=%0d data=%064h RLAST=%b",
          $time,
          ar_transaction_count,
          current_r_beat,
          m_rdata_i,
          m_rlast_i
        );

        if (current_r_beat == BEATS_PER_CYCLE-1) begin

          // Last beat of this cyclic transfer.

          if (m_rlast_i !== 1'b1) begin
            $fatal(
              1,
              "[%0t] TEST 10 FAIL: AXI RLAST missing on final beat",
              $time
            );
          end

          m_rvalid_i <= 1'b0;
          m_rlast_i  <= 1'b0;

          current_r_beat <= 0;

        end
        else begin

          if (m_rlast_i !== 1'b0) begin
            $fatal(
              1,
              "[%0t] TEST 10 FAIL: AXI RLAST asserted early on beat %0d",
              $time, current_r_beat
            );
          end

          current_r_beat <= current_r_beat + 1;

          m_rid_i   <= active_rid;
          m_rdata_i <= source_beats[current_r_beat + 1];
          m_rresp_i <= 2'b00;
          m_rlast_i <=
              ((current_r_beat + 1) == BEATS_PER_CYCLE-1);

          m_rvalid_i <= 1'b1;

        end

      end

    end

  end

  // ==========================================================================
  // AXI-STREAM PERIPHERAL MODEL
  //
  // The peripheral is always ready.
  //
  // Every cycle must contain:
  //
  //     beat 0
  //     beat 1
  //     ...
  //     beat 7 + TLAST
  //
  // Then cyclic mode should start the same descriptor again.
  // ==========================================================================

  integer axis_total_beats;
  integer axis_cycle_count;
  integer axis_beat_in_cycle;

  initial begin

    axis_total_beats  = 0;
    axis_cycle_count  = 0;
    axis_beat_in_cycle = 0;

    m_tready_i = 1'b1;

  end

  always @(posedge aclk) begin

    if (!aresetn) begin

      axis_total_beats   <= 0;
      axis_cycle_count   <= 0;
      axis_beat_in_cycle <= 0;

    end
    else begin

      if (m_tvalid_o && m_tready_i) begin

        axis_total_beats <= axis_total_beats + 1;

        $display(
          "[%0t] AXIS PERIPHERAL: cycle=%0d beat=%0d data=%064h TLAST=%b",
          $time,
          axis_cycle_count + 1,
          axis_beat_in_cycle,
          m_tdata_o,
          m_tlast_o
        );

        // ---------------------------------------------------------------------
        // DATA CHECK
        // ---------------------------------------------------------------------

        if (m_tdata_o !== source_beats[axis_beat_in_cycle]) begin

          $fatal(
            1,
            "[%0t] TEST 10 FAIL: DATA mismatch cycle=%0d beat=%0d\nExpected=%064h\nActual  =%064h",
            $time,
            axis_cycle_count + 1,
            axis_beat_in_cycle,
            source_beats[axis_beat_in_cycle],
            m_tdata_o
          );

        end

        // ---------------------------------------------------------------------
        // TLAST CHECK
        // ---------------------------------------------------------------------

        if (axis_beat_in_cycle == BEATS_PER_CYCLE-1) begin

          if (m_tlast_o !== 1'b1) begin

            $fatal(
              1,
              "[%0t] TEST 10 FAIL: TLAST not asserted at end of cycle %0d",
              $time,
              axis_cycle_count + 1
            );

          end

          axis_cycle_count   <= axis_cycle_count + 1;
          axis_beat_in_cycle <= 0;

          $display(
            "[%0t] PASS: AXIS cycle %0d completed",
            $time,
            axis_cycle_count + 1
          );

        end
        else begin

          if (m_tlast_o !== 1'b0) begin

            $fatal(
              1,
              "[%0t] TEST 10 FAIL: TLAST asserted early at cycle=%0d beat=%0d",
              $time,
              axis_cycle_count + 1,
              axis_beat_in_cycle
            );

          end

          axis_beat_in_cycle <= axis_beat_in_cycle + 1;

        end

      end

    end

  end

  // ==========================================================================
  // UNUSED AXI4 DESTINATION WRITE INTERFACE
  // ==========================================================================

  initial begin

    m_awready_i = 1'b0;
    m_wready_i  = 1'b0;

    m_bid_i     = '0;
    m_bresp_i   = 2'b00;
    m_bvalid_i  = 1'b0;

  end

  // ==========================================================================
  // UNUSED AXI-STREAM SOURCE INTERFACE
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
  // INITIALIZE AXI CONTROL
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
  // TEST 10
  //
  // C0 MEMORY -> PERIPHERAL CYCLIC
  //
  // Configuration:
  //
  //     Source       : AXI4 memory
  //     Destination  : AXI-Stream peripheral
  //     Source addr  : 0x00030000
  //     Beats/cycle  : 8
  //     Cycles       : 3
  //     Total beats  : 24
  //     Total bytes  : 768
  //
  // The descriptor is submitted exactly ONCE.
  //
  // Expected:
  //
  //     AR #1 -> 8 beats -> TLAST
  //     AR #2 -> 8 beats -> TLAST
  //     AR #3 -> 8 beats -> TLAST
  //
  // Then C0 is disabled.
  // No AR #4 is allowed.
  // ==========================================================================

  initial begin : c0_memory_to_peripheral_cyclic_test

    logic [31:0] status;
    int timeout_cycles;
    int cycles_before_disable;
    int ar_count_after_disable;

    wait (aresetn === 1'b1);

    repeat (2)
      @(posedge aclk);

    $display("");
    $display("============================================================");
    $display("        C0 AXI DMA TEST 10");
    $display("        CYCLIC MEMORY-TO-PERIPHERAL");
    $display("============================================================");
    $display("SRC_IF_TYPE       = AXI4");
    $display("DST_IF_TYPE       = AXIS");
    $display("DATA_W            = %0d bits", DATA_W);
    $display("BYTES_PER_BEAT    = %0d bytes", BYTES_PER_BEAT);
    $display("BEATS_PER_CYCLE   = %0d", BEATS_PER_CYCLE);
    $display("NUM_CYCLES        = %0d", NUM_CYCLES);
    $display("TOTAL_BEATS       = %0d", TOTAL_BEATS);
    $display("TOTAL_BYTES       = %0d", TOTAL_BYTES);
    $display("SRC_ADDR          = 0x%08h", SRC_ADDR);
    $display("DST_ADDR          = 0x%08h", DST_ADDR);
    $display("CHANNEL           = C0");
    $display("CYCLIC            = ENABLED");
    $display("============================================================");
    $display("");

    // ========================================================================
    // 1. GLOBAL DMA ENABLE
    // ========================================================================

    axi_reg_write(
      DMA_EN,
      32'h0000_0001
    );

    // ========================================================================
    // 2. C0 ENABLE
    // ========================================================================

    axi_reg_write(
      C0_CTRL,
      32'h0000_0001
    );

    // ========================================================================
    // 3. CYCLIC MODE
    //
    // C0_XFER_CTRL[1] = cyclic
    // C0_XFER_CTRL[0] = 2D
    //
    // 2'b10 => cyclic=1, 2D=0
    // ========================================================================

    axi_reg_write(
      C0_XFER_CTRL,
      32'h0000_0002
    );

    // ========================================================================
    // 4. COMPLETION IRQ MASK
    // ========================================================================

    axi_reg_write(
      C0_IRQ_MASK,
      32'h0000_0001
    );

    // ========================================================================
    // 5. ARBITRATION RATE
    // ========================================================================

    axi_reg_write(
      C0_ARB_RATE,
      32'h0000_0001
    );

    // ========================================================================
    // 6. ATX ID
    // ========================================================================

    axi_reg_write(
      C0_ATX_ID,
      32'h0000_0000
    );

    // ========================================================================
    // 7. SOURCE BURST = INCR
    // ========================================================================

    axi_reg_write(
      C0_SRC_BURST,
      32'h0000_0001
    );

    // Destination is AXIS, so destination burst is not used.
    // Program it consistently.

    axi_reg_write(
      C0_DST_BURST,
      32'h0000_0001
    );

    // ========================================================================
    // 8. WORDS PER BURST
    //
    // 8 beats -> register value 7
    // ========================================================================

    axi_reg_write(
      C0_WD_BURST,
      BEATS_PER_CYCLE-1
    );

    // ========================================================================
    // 9. SOURCE ADDRESS
    // ========================================================================

    axi_reg_write(
      C0_SRC_ADDR,
      SRC_ADDR
    );

    // ========================================================================
    // 10. DESTINATION ADDRESS
    //
    // AXIS has no address channel.
    // Keep the descriptor field programmed consistently.
    // ========================================================================

    axi_reg_write(
      C0_DST_ADDR,
      DST_ADDR
    );

    // ========================================================================
    // 11. X LENGTH
    //
    // 8 beats -> XLEN = 7
    // ========================================================================

    axi_reg_write(
      C0_XLEN,
      BEATS_PER_CYCLE-1
    );

    // ========================================================================
    // 12. Y LENGTH = 0
    //
    // 1D transfer.
    // Cyclic repetition comes from XFER_CTRL[1].
    // ========================================================================

    axi_reg_write(
      C0_YLEN,
      32'h0000_0000
    );

    // ========================================================================
    // 13. STRIDES
    // ========================================================================

    axi_reg_write(
      C0_SRC_STRIDE,
      32'h0000_0000
    );

    axi_reg_write(
      C0_DST_STRIDE,
      32'h0000_0000
    );

    // ========================================================================
    // CONFIGURATION SUMMARY
    // ========================================================================

    $display("");
    $display("------------------------------------------------------------");
    $display("TEST 10 CONFIGURATION COMPLETE");
    $display("------------------------------------------------------------");
    $display("C0_CTRL       = 1");
    $display("C0_XFER_CTRL  = 2 (CYCLIC)");
    $display("C0_SRC_ADDR   = %08h", SRC_ADDR);
    $display("C0_XLEN       = %0d", BEATS_PER_CYCLE-1);
    $display("C0_WD_BURST   = %0d", BEATS_PER_CYCLE-1);
    $display("SRC_BURST     = 1 (INCR)");
    $display("BEATS/CYCLE   = %0d", BEATS_PER_CYCLE);
    $display("EXPECTED ARs  = %0d", NUM_CYCLES);
    $display("------------------------------------------------------------");
    $display("");

    // ========================================================================
    // 14. SUBMIT DESCRIPTOR ONCE
    // ========================================================================

    $display("[%0t] TEST 10: Submitting C0 descriptor ONCE", $time);

    axi_reg_write(
      C0_DESC_SUBMIT,
      32'h0000_0000
    );

    $display(
      "[%0t] TEST 10: Descriptor submitted. Cyclic operation expected.",
      $time
    );

    // ========================================================================
    // 15. WAIT UNTIL ALL 3 CYCLES ARE RECEIVED
    // ========================================================================

    timeout_cycles = 0;

    while (axis_cycle_count < NUM_CYCLES) begin

      @(posedge aclk);

      timeout_cycles++;

      if (timeout_cycles > 10000) begin

        $fatal(
          1,
          "[%0t] TEST 10 TIMEOUT: Expected %0d cycles, received %0d",
          $time,
          NUM_CYCLES,
          axis_cycle_count
        );

      end

    end

    // Give the DMA a few clocks to settle after the final TLAST.

    repeat (5)
      @(posedge aclk);

    // ========================================================================
    // 16. CHECK CYCLE COUNT
    // ========================================================================

    if (axis_cycle_count !== NUM_CYCLES) begin

      $fatal(
        1,
        "[%0t] TEST 10 FAIL: Expected %0d cycles, got %0d",
        $time,
        NUM_CYCLES,
        axis_cycle_count
      );

    end

    $display(
      "[%0t] PASS: Cycle count = %0d",
      $time,
      axis_cycle_count
    );

    // ========================================================================
    // 17. CHECK AXI AR TRANSACTION COUNT
    // ========================================================================

    if (ar_transaction_count !== NUM_CYCLES) begin

      $fatal(
        1,
        "[%0t] TEST 10 FAIL: Expected %0d AR transactions, got %0d",
        $time,
        NUM_CYCLES,
        ar_transaction_count
      );

    end

    $display(
      "[%0t] PASS: AXI AR transaction count = %0d",
      $time,
      ar_transaction_count
    );

    // ========================================================================
    // 18. CHECK TOTAL AXIS BEATS
    // ========================================================================

    if (axis_total_beats !== TOTAL_BEATS) begin

      $fatal(
        1,
        "[%0t] TEST 10 FAIL: Expected %0d AXIS beats, got %0d",
        $time,
        TOTAL_BEATS,
        axis_total_beats
      );

    end

    $display(
      "[%0t] PASS: Total AXIS beats = %0d",
      $time,
      axis_total_beats
    );

    // ========================================================================
    // 19. DISABLE C0
    //
    // This is what stops the cyclic repetition.
    // ========================================================================

    cycles_before_disable = axis_cycle_count;

    $display("");
    $display(
      "[%0t] TEST 10: Disabling C0 after %0d cycles",
      $time,
      cycles_before_disable
    );

    axi_reg_write(
      C0_CTRL,
      32'h0000_0000
    );

    // ========================================================================
    // 20. VERIFY THAT CYCLIC TRANSFER REALLY STOPPED
    //
    // Save AR count and wait.
    // There must be no additional AR transaction.
    // ========================================================================

    ar_count_after_disable = ar_transaction_count;

    repeat (100)
      @(posedge aclk);

    if (ar_transaction_count !== ar_count_after_disable) begin

      $fatal(
        1,
        "[%0t] TEST 10 FAIL: DMA generated another AR after C0 disable. Before=%0d After=%0d",
        $time,
        ar_count_after_disable,
        ar_transaction_count
      );

    end

    if (axis_total_beats !== TOTAL_BEATS) begin

      $fatal(
        1,
        "[%0t] TEST 10 FAIL: AXIS beat count changed after C0 disable",
        $time
      );

    end

    $display(
      "[%0t] PASS: No additional AR transaction after C0 disable",
      $time
    );

    // ========================================================================
    // 21. OPTIONAL STATUS READS
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
    // 22. FINAL RESULT
    // ========================================================================

    $display("");
    $display("============================================================");
    $display("PASS: C0 CYCLIC MEMORY-TO-PERIPHERAL TEST 10");
    $display("============================================================");
    $display("PASS: Descriptor submitted only once");
    $display("PASS: Cyclic mode generated %0d cycles", NUM_CYCLES);
    $display("PASS: AXI AR transactions = %0d", ar_transaction_count);
    $display("PASS: AXIS beats           = %0d", axis_total_beats);
    $display("PASS: Data checked for every beat");
    $display("PASS: TLAST checked at every cycle boundary");
    $display("PASS: C0 disabled after cycle %0d", NUM_CYCLES);
    $display("PASS: No additional AR after C0 disable");
    $display("============================================================");
    $display("");

    #20;

    $finish;

  end

  // ==========================================================================
  // GLOBAL TIMEOUT
  // ==========================================================================

  initial begin

    #200_000;

    $fatal(
      1,
      "[%0t] TEST 10 GLOBAL TIMEOUT",
      $time
    );

  end

endmodule
