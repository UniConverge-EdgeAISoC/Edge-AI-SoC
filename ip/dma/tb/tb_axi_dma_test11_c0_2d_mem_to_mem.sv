`timescale 1ns/1ps

module tb_axi_dma;

  // ==========================================================================
  // TEST 11 : C0 2D MEMORY-TO-MEMORY
  //
  // 3 rows x 4 beats/row
  // XLEN   = 3  -> 4 beats per row
  // YLEN   = 2  -> 3 rows total
  // SRC_STRIDE = 0x100 bytes
  // DST_STRIDE = 0x200 bytes
  //
  // Each AXI beat = 256 bits = 32 bytes.
  // Therefore each row contains 4 beats = 128 bytes.
  // The stride is intentionally larger than one row to verify that the
  // transfer splitter inserts the programmed gap between rows.
  // ==========================================================================

  localparam int ADDR_W     = 32;
  localparam int DATA_W     = 256;
  localparam int S_DATA_W   = 32;
  localparam int ID_W       = 5;
  localparam int LEN_W      = 8;
  localparam int RESP_W     = 2;
  localparam int BYTE_W     = DATA_W/8;

  localparam int BYTES_PER_BEAT = DATA_W/8;
  localparam int BEATS_PER_ROW  = 4;
  localparam int NUM_ROWS       = 3;
  localparam int TOTAL_BEATS    = BEATS_PER_ROW * NUM_ROWS;
  localparam int ROW_BYTES      = BEATS_PER_ROW * BYTES_PER_BEAT;

  localparam logic [31:0] DMA_BASE = 32'h8000_0000;

  // Global
  localparam logic [31:0] DMA_EN = DMA_BASE + 32'h00;

  // C0 register map
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

  localparam logic [31:0] C0_DESC_SUBMIT = DMA_BASE + 32'h1000;

  localparam logic [31:0] STATUS_IRQ    = DMA_BASE + 32'h2000;
  localparam logic [31:0] STATUS_XFER_ID= DMA_BASE + 32'h2004;
  localparam logic [31:0] STATUS_DONE   = DMA_BASE + 32'h2008;

  localparam logic [31:0] SRC_ADDR   = 32'h0003_0000;
  localparam logic [31:0] DST_ADDR   = 32'h0004_0000;

  localparam logic [31:0] SRC_STRIDE = 32'h0000_0100;
  localparam logic [31:0] DST_STRIDE = 32'h0000_0200;

  // --------------------------------------------------------------------------
  // Row data
  // --------------------------------------------------------------------------
  logic [DATA_W-1:0] source_data [0:NUM_ROWS-1][0:BEATS_PER_ROW-1];

  // ==========================================================================
  // CLOCK / RESET
  // ==========================================================================

  logic aclk;
  logic aresetn;

  initial aclk = 1'b0;
  always #5 aclk = ~aclk;

  initial begin
    aresetn = 1'b0;
    repeat (5) @(posedge aclk);
    aresetn = 1'b1;
  end

  // ==========================================================================
  // AXI4 CONTROL
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
  // SOURCE AXI4 READ
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
  // DESTINATION AXI4 WRITE
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
  // UNUSED AXI-STREAM SOURCE
  // ==========================================================================

  logic [ID_W-1:0]     s_tid_i;
  logic [1:0]          s_tdest_i;
  logic [DATA_W-1:0]   s_tdata_i;
  logic [BYTE_W-1:0]   s_tkeep_i;
  logic [BYTE_W-1:0]   s_tstrb_i;
  logic                s_tlast_i;
  logic                s_tvalid_i;
  logic                s_tready_o;

  // ==========================================================================
  // UNUSED AXI-STREAM DESTINATION
  // ==========================================================================

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

    .s_tid_i       (s_tid_i),
    .s_tdest_i     (s_tdest_i),
    .s_tdata_i     (s_tdata_i),
    .s_tkeep_i     (s_tkeep_i),
    .s_tstrb_i     (s_tstrb_i),
    .s_tlast_i     (s_tlast_i),
    .s_tvalid_i    (s_tvalid_i),
    .s_tready_o    (s_tready_o),

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
  // AXI CONTROL WRITE
  // Independent AW and W handshakes.
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

      // The AXI control slave has already accepted AW/W. Clear the
      // payloads, then wait for a clocked BVALID response.
      s_awvalid_i <= 1'b0;
      s_wvalid_i  <= 1'b0;
      s_awaddr_i  <= '0;
      s_wdata_i   <= '0;

      s_bready_i <= 1'b1;

      while (!s_bvalid_o)
        @(posedge aclk);

      // Allow combinational BRESP from the AXI control block to settle
      // after BVALID becomes visible.
      #1;

      if (s_bresp_o !== 2'b00) begin
        $fatal(1,
               "TEST 11 FAIL: AXI control write error addr=%08h data=%08h resp=%b",
               addr, data, s_bresp_o);
      end

      @(posedge aclk);
      s_bready_i <= 1'b0;
    end
  endtask

  // ==========================================================================
  // AXI CONTROL READ
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

      if (s_rresp_o !== 2'b00)
        $fatal(1, "TEST 11 FAIL: AXI control read error addr=%08h resp=%b",
               addr, s_rresp_o);

      @(posedge aclk);
      s_rready_i <= 1'b0;
    end
  endtask

  // ==========================================================================
  // SOURCE MEMORY MODEL
  //
  // One AXI read burst corresponds to one row.
  //
  // Expected:
  // Row 0: ARADDR = 0x30000
  // Row 1: ARADDR = 0x30100
  // Row 2: ARADDR = 0x30200
  //
  // ARLEN = 3 for all rows.
  // ==========================================================================

  integer source_row_count;
  integer source_beat_count;
  logic   source_read_active;

  initial begin
    source_row_count   = 0;
    source_beat_count  = 0;
    source_read_active = 1'b0;

    // Row 0
    source_data[0][0] = 256'hA000_A000_A000_A000_A000_A000_A000_A000_A000_A000_A000_A000_A000_A000_A000_A000;
    source_data[0][1] = 256'hA001_A001_A001_A001_A001_A001_A001_A001_A001_A001_A001_A001_A001_A001_A001_A001;
    source_data[0][2] = 256'hA002_A002_A002_A002_A002_A002_A002_A002_A002_A002_A002_A002_A002_A002_A002_A002;
    source_data[0][3] = 256'hA003_A003_A003_A003_A003_A003_A003_A003_A003_A003_A003_A003_A003_A003_A003_A003;

    // Row 1
    source_data[1][0] = 256'hB000_B000_B000_B000_B000_B000_B000_B000_B000_B000_B000_B000_B000_B000_B000_B000;
    source_data[1][1] = 256'hB001_B001_B001_B001_B001_B001_B001_B001_B001_B001_B001_B001_B001_B001_B001_B001;
    source_data[1][2] = 256'hB002_B002_B002_B002_B002_B002_B002_B002_B002_B002_B002_B002_B002_B002_B002_B002;
    source_data[1][3] = 256'hB003_B003_B003_B003_B003_B003_B003_B003_B003_B003_B003_B003_B003_B003_B003_B003;

    // Row 2
    source_data[2][0] = 256'hC000_C000_C000_C000_C000_C000_C000_C000_C000_C000_C000_C000_C000_C000_C000_C000;
    source_data[2][1] = 256'hC001_C001_C001_C001_C001_C001_C001_C001_C001_C001_C001_C001_C001_C001_C001_C001;
    source_data[2][2] = 256'hC002_C002_C002_C002_C002_C002_C002_C002_C002_C002_C002_C002_C002_C002_C002_C002;
    source_data[2][3] = 256'hC003_C003_C003_C003_C003_C003_C003_C003_C003_C003_C003_C003_C003_C003_C003_C003;

    m_arready_i = 1'b1;

    m_rid_i    = '0;
    m_rdata_i  = '0;
    m_rresp_i  = 2'b00;
    m_rlast_i  = 1'b0;
    m_rvalid_i = 1'b0;
  end

  always @(posedge aclk) begin
    if (!aresetn) begin
      m_rvalid_i       <= 1'b0;
      m_rlast_i        <= 1'b0;
      source_row_count <= 0;
      source_beat_count<= 0;
      source_read_active <= 1'b0;
    end
    else begin

      // ------------------------------------------------------------
      // New source burst
      // ------------------------------------------------------------
      if (m_arvalid_o && m_arready_i) begin

        if (source_row_count >= NUM_ROWS)
          $fatal(1, "TEST 11 FAIL: More than %0d source row reads",
                 NUM_ROWS);

        $display("");
        $display("==================================================");
        $display("[%0t] TEST 11 SOURCE AR HANDSHAKE", $time);
        $display("ROW     = %0d", source_row_count);
        $display("ARADDR  = %08h", m_araddr_o);
        $display("ARLEN   = %0d", m_arlen_o);
        $display("ARBURST = %02b", m_arburst_o);
        $display("==================================================");

        if (m_araddr_o !== (SRC_ADDR + source_row_count*SRC_STRIDE))
          $fatal(1,
            "TEST 11 FAIL: Source row %0d address mismatch: expected %08h got %08h",
            source_row_count,
            SRC_ADDR + source_row_count*SRC_STRIDE,
            m_araddr_o);

        if (m_arlen_o !== BEATS_PER_ROW-1)
          $fatal(1,
            "TEST 11 FAIL: Source ARLEN mismatch: expected %0d got %0d",
            BEATS_PER_ROW-1, m_arlen_o);

        if (m_arburst_o !== 2'b01)
          $fatal(1,
            "TEST 11 FAIL: Source ARBURST must be INCR, got %02b",
            m_arburst_o);

        source_beat_count  <= 0;
        source_read_active <= 1'b1;

        m_rid_i    <= m_arid_o;
        m_rdata_i  <= source_data[source_row_count][0];
        m_rresp_i  <= 2'b00;
        m_rlast_i  <= (BEATS_PER_ROW == 1);
        m_rvalid_i <= 1'b1;
      end

      // ------------------------------------------------------------
      // Read data handshakes
      // ------------------------------------------------------------
      if (m_rvalid_i && m_rready_o) begin

        $display("[%0t] SOURCE R: row=%0d beat=%0d data=%064h last=%b",
                 $time, source_row_count, source_beat_count,
                 m_rdata_i, m_rlast_i);

        if (m_rresp_i !== 2'b00)
          $fatal(1, "TEST 11 FAIL: Source RRESP is not OKAY");

        if (source_beat_count == BEATS_PER_ROW-1) begin
          m_rvalid_i       <= 1'b0;
          m_rlast_i        <= 1'b0;
          source_read_active <= 1'b0;
          source_row_count <= source_row_count + 1;
        end
        else begin
          source_beat_count <= source_beat_count + 1;
          m_rdata_i <= source_data[source_row_count][source_beat_count+1];
          m_rlast_i <= ((source_beat_count+1) == BEATS_PER_ROW-1);
        end
      end
    end
  end

  // ==========================================================================
  // DESTINATION MEMORY MODEL
  //
  // AXI AW and W channels are independent.
  // W is accepted even if AW has not arrived yet.
  // This avoids incorrectly assuming AW must precede W.
  // ==========================================================================

  logic aw_seen;
  logic b_pending;
  logic [31:0] current_awaddr;
  logic [LEN_W-1:0] current_awlen;
  logic [1:0] current_awburst;

  logic [DATA_W-1:0] received_data [0:NUM_ROWS-1][0:BEATS_PER_ROW-1];

  integer write_row_count;
  integer write_beat_count;

  logic [DATA_W-1:0] pending_wdata [0:BEATS_PER_ROW-1];
  logic              pending_wlast[0:BEATS_PER_ROW-1];
  integer pending_wcount;
  logic    w_burst_done;

  initial begin
    aw_seen        = 1'b0;
    b_pending      = 1'b0;
    current_awaddr = '0;
    current_awlen  = '0;
    current_awburst= '0;

    write_row_count = 0;
    write_beat_count= 0;

    pending_wcount  = 0;
    w_burst_done    = 1'b0;

    m_awready_i = 1'b1;
    m_wready_i  = 1'b1;

    m_bid_i     = '0;
    m_bresp_i   = 2'b00;
    m_bvalid_i  = 1'b0;

    for (int r = 0; r < NUM_ROWS; r++)
      for (int b = 0; b < BEATS_PER_ROW; b++)
        received_data[r][b] = '0;
  end

  always @(posedge aclk) begin
    if (!aresetn) begin
      aw_seen         <= 1'b0;
      b_pending       <= 1'b0;
      m_bvalid_i      <= 1'b0;
      write_row_count <= 0;
      write_beat_count<= 0;
      pending_wcount  <= 0;
      w_burst_done    <= 1'b0;
    end
    else begin

      // ------------------------------------------------------------
      // AW handshake
      // ------------------------------------------------------------
      if (m_awvalid_o && m_awready_i) begin

        if (write_row_count >= NUM_ROWS)
          $fatal(1, "TEST 11 FAIL: More than %0d destination AW bursts",
                 NUM_ROWS);

        $display("");
        $display("--------------------------------------------------");
        $display("[%0t] TEST 11 DESTINATION AW HANDSHAKE", $time);
        $display("ROW     = %0d", write_row_count);
        $display("AWADDR  = %08h", m_awaddr_o);
        $display("AWLEN   = %0d", m_awlen_o);
        $display("AWBURST = %02b", m_awburst_o);
        $display("--------------------------------------------------");

        if (m_awaddr_o !== (DST_ADDR + write_row_count*DST_STRIDE))
          $fatal(1,
            "TEST 11 FAIL: Destination row %0d address mismatch: expected %08h got %08h",
            write_row_count,
            DST_ADDR + write_row_count*DST_STRIDE,
            m_awaddr_o);

        if (m_awlen_o !== BEATS_PER_ROW-1)
          $fatal(1,
            "TEST 11 FAIL: Destination AWLEN mismatch: expected %0d got %0d",
            BEATS_PER_ROW-1, m_awlen_o);

        if (m_awburst_o !== 2'b01)
          $fatal(1,
            "TEST 11 FAIL: Destination AWBURST must be INCR, got %02b",
            m_awburst_o);

        current_awaddr  <= m_awaddr_o;
        current_awlen   <= m_awlen_o;
        current_awburst <= m_awburst_o;
        aw_seen         <= 1'b1;
      end

      // ------------------------------------------------------------
      // W handshake
      // ------------------------------------------------------------
      if (m_wvalid_o && m_wready_i) begin

        if (pending_wcount >= BEATS_PER_ROW)
          $fatal(1, "TEST 11 FAIL: Too many W beats in one burst");

        pending_wdata[pending_wcount] <= m_wdata_o;
        pending_wlast[pending_wcount] <= m_wlast_o;

        $display("[%0t] DESTINATION W: row=%0d beat=%0d data=%064h last=%b",
                 $time, write_row_count, pending_wcount,
                 m_wdata_o, m_wlast_o);

        if (pending_wcount < BEATS_PER_ROW-1 && m_wlast_o)
          $fatal(1,
            "TEST 11 FAIL: WLAST asserted early at beat %0d",
            pending_wcount);

        if (pending_wcount == BEATS_PER_ROW-1 && !m_wlast_o)
          $fatal(1,
            "TEST 11 FAIL: WLAST missing on final beat");

        if (pending_wcount == BEATS_PER_ROW-1)
          w_burst_done <= 1'b1;

        pending_wcount <= pending_wcount + 1;
      end

      // ------------------------------------------------------------
      // Complete the write burst once AW and all W beats are present.
      // ------------------------------------------------------------
      if (aw_seen && w_burst_done && !b_pending) begin

        if (pending_wcount != BEATS_PER_ROW)
          $fatal(1,
            "TEST 11 FAIL: Expected %0d W beats, got %0d",
            BEATS_PER_ROW, pending_wcount);

        for (int b = 0; b < BEATS_PER_ROW; b++) begin
          received_data[write_row_count][b] <= pending_wdata[b];

          if (pending_wdata[b] !== source_data[write_row_count][b])
            $fatal(1,
              "TEST 11 FAIL: Data mismatch row=%0d beat=%0d expected=%064h got=%064h",
              write_row_count, b,
              source_data[write_row_count][b],
              pending_wdata[b]);
        end

        $display("[%0t] TEST 11: Row %0d destination data verified",
                 $time, write_row_count);

        write_row_count <= write_row_count + 1;

        aw_seen        <= 1'b0;
        w_burst_done   <= 1'b0;
        pending_wcount <= 0;

        m_bvalid_i <= 1'b1;
        b_pending  <= 1'b1;
      end

      // ------------------------------------------------------------
      // AXI B response
      // ------------------------------------------------------------
      if (m_bvalid_i && m_bready_o) begin
        m_bvalid_i <= 1'b0;
        b_pending  <= 1'b0;
      end
    end
  end

  // ==========================================================================
  // UNUSED AXI-STREAM SOURCE/DESTINATION
  // ==========================================================================

  initial begin
    s_tid_i    = '0;
    s_tdest_i  = '0;
    s_tdata_i  = '0;
    s_tkeep_i  = '0;
    s_tstrb_i  = '0;
    s_tlast_i  = 1'b0;
    s_tvalid_i = 1'b0;

    m_tready_i = 1'b0;
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
  // TEST SEQUENCE
  // ==========================================================================

  initial begin : c0_2d_test

    logic [31:0] status;
    int timeout_cycles;
    int i;

    wait (aresetn === 1'b1);
    repeat (2) @(posedge aclk);

    $display("");
    $display("==============================================================");
    $display("                 C0 AXI DMA TEST 11");
    $display("                 2D MEMORY-TO-MEMORY");
    $display("==============================================================");
    $display("SRC_IF_TYPE       = AXI4");
    $display("DST_IF_TYPE       = AXI4");
    $display("DATA_W            = %0d bits", DATA_W);
    $display("BYTES_PER_BEAT    = %0d", BYTES_PER_BEAT);
    $display("BEATS_PER_ROW     = %0d", BEATS_PER_ROW);
    $display("NUM_ROWS          = %0d", NUM_ROWS);
    $display("TOTAL_BEATS       = %0d", TOTAL_BEATS);
    $display("ROW_BYTES         = %0d", ROW_BYTES);
    $display("SRC_ADDR          = %08h", SRC_ADDR);
    $display("DST_ADDR          = %08h", DST_ADDR);
    $display("SRC_STRIDE        = %08h", SRC_STRIDE);
    $display("DST_STRIDE        = %08h", DST_STRIDE);
    $display("XLEN              = %0d", BEATS_PER_ROW-1);
    $display("YLEN              = %0d", NUM_ROWS-1);
    $display("2D MODE           = 1");
    $display("CYCLIC MODE       = 0");
    $display("==============================================================");
    $display("");

    // ------------------------------------------------------------------------
    // Global DMA enable
    // ------------------------------------------------------------------------
    axi_reg_write(DMA_EN, 32'h0000_0001);

    // ------------------------------------------------------------------------
    // C0 enable
    // ------------------------------------------------------------------------
    axi_reg_write(C0_CTRL, 32'h0000_0001);

    // ------------------------------------------------------------------------
    // XFER_CTRL:
    // bit[0] = 1 -> 2D
    // bit[1] = 0 -> non-cyclic
    // ------------------------------------------------------------------------
    axi_reg_write(C0_XFER_CTRL, 32'h0000_0001);

    axi_reg_write(C0_IRQ_MASK,  32'h0000_0001);
    axi_reg_write(C0_ARB_RATE,  32'h0000_0001);
    axi_reg_write(C0_ATX_ID,    32'h0000_0000);

    // INCR bursts
    axi_reg_write(C0_SRC_BURST, 32'h0000_0001);
    axi_reg_write(C0_DST_BURST, 32'h0000_0001);

    // 4 beats per AXI burst -> WD_BURST = 3
    axi_reg_write(C0_WD_BURST, BEATS_PER_ROW-1);

    axi_reg_write(C0_SRC_ADDR, SRC_ADDR);
    axi_reg_write(C0_DST_ADDR, DST_ADDR);

    // 4 beats per row -> XLEN = 3
    axi_reg_write(C0_XLEN, BEATS_PER_ROW-1);

    // 3 rows -> YLEN = 2
    axi_reg_write(C0_YLEN, NUM_ROWS-1);

    // Row-to-row address increments
    axi_reg_write(C0_SRC_STRIDE, SRC_STRIDE);
    axi_reg_write(C0_DST_STRIDE, DST_STRIDE);

    $display("");
    $display("--------------------------------------------------------------");
    $display("TEST 11 CONFIGURATION COMPLETE");
    $display("--------------------------------------------------------------");
    $display("C0_XFER_CTRL = 1 (2D, non-cyclic)");
    $display("C0_XLEN      = %0d", BEATS_PER_ROW-1);
    $display("C0_YLEN      = %0d", NUM_ROWS-1);
    $display("SRC_STRIDE   = %08h", SRC_STRIDE);
    $display("DST_STRIDE   = %08h", DST_STRIDE);
    $display("--------------------------------------------------------------");
    $display("");

    // ------------------------------------------------------------------------
    // Submit one descriptor
    // ------------------------------------------------------------------------
    $display("[%0t] Submitting C0 2D descriptor", $time);
    axi_reg_write(C0_DESC_SUBMIT, 32'h0000_0000);

    // ------------------------------------------------------------------------
    // Wait until all 3 rows have been read and written.
    // ------------------------------------------------------------------------
    timeout_cycles = 0;

    while ((source_row_count < NUM_ROWS) ||
           (write_row_count < NUM_ROWS)) begin

      @(posedge aclk);
      timeout_cycles++;

      if (timeout_cycles > 10000)
        $fatal(1,
          "TEST 11 TIMEOUT: source_rows=%0d/%0d destination_rows=%0d/%0d",
          source_row_count, NUM_ROWS,
          write_row_count, NUM_ROWS);
    end

    // Allow final B response / completion logic to settle.
    repeat (10) @(posedge aclk);

    // ------------------------------------------------------------------------
    // Final data/address checks
    // ------------------------------------------------------------------------
    if (source_row_count !== NUM_ROWS)
      $fatal(1, "TEST 11 FAIL: Expected %0d source rows, got %0d",
             NUM_ROWS, source_row_count);

    if (write_row_count !== NUM_ROWS)
      $fatal(1, "TEST 11 FAIL: Expected %0d destination rows, got %0d",
             NUM_ROWS, write_row_count);

    // Verify stored destination data one more time.
    for (i = 0; i < NUM_ROWS; i++) begin
      for (int j = 0; j < BEATS_PER_ROW; j++) begin
        if (received_data[i][j] !== source_data[i][j])
          $fatal(1,
            "TEST 11 FAIL: Final memory check mismatch row=%0d beat=%0d",
            i, j);
      end
    end

    // ------------------------------------------------------------------------
    // Read status
    // ------------------------------------------------------------------------
    axi_reg_read(STATUS_IRQ, status);
    $display("[%0t] STATUS_IRQ     = %08h", $time, status);

    axi_reg_read(STATUS_XFER_ID, status);
    $display("[%0t] STATUS_XFER_ID = %08h", $time, status);

    axi_reg_read(STATUS_DONE, status);
    $display("[%0t] STATUS_DONE    = %08h", $time, status);

    // ------------------------------------------------------------------------
    // Disable C0 after completion
    // ------------------------------------------------------------------------
    axi_reg_write(C0_CTRL, 32'h0000_0000);

    repeat (10) @(posedge aclk);

    $display("");
    $display("==============================================================");
    $display("              TEST 11 PASS");
    $display("              C0 2D MEMORY-TO-MEMORY");
    $display("==============================================================");
    $display("Rows transferred : %0d", NUM_ROWS);
    $display("Beats per row    : %0d", BEATS_PER_ROW);
    $display("Total beats      : %0d", TOTAL_BEATS);
    $display("Source stride    : 0x%08h", SRC_STRIDE);
    $display("Destination stride: 0x%08h", DST_STRIDE);
    $display("==============================================================");
    $display("");

    $finish;
  end

endmodule
