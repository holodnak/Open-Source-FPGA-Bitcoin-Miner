// Hub code for a cluster of miners using async links

// by teknohog

module fpgaminer_top (osc_clk, RxD, TxD);
`ifdef SERIAL_CLK
   parameter comm_clk_frequency = `SERIAL_CLK;
`else
   parameter comm_clk_frequency = 80_000_000;
`endif

   input osc_clk;
   wire hash_clk;
   main_pll pll_blk (osc_clk, hash_clk);

   // Nonce stride for all miners in the cluster, not just this hub.
`ifdef TOTAL_MINERS
   parameter TOTAL_MINERS = `TOTAL_MINERS;
`else
   parameter TOTAL_MINERS = 1;
`endif

   // For local miners
`ifdef LOOP_LOG2
   parameter LOOP_LOG2 = `LOOP_LOG2;
`else
   parameter LOOP_LOG2 = 0;
`endif

   // Miners on the same FPGA with this hub
`ifdef LOCAL_MINERS
   parameter LOCAL_MINERS = `LOCAL_MINERS;
`else
   parameter LOCAL_MINERS = 1;
`endif

   // Make sure each miner has a distinct nonce start. Local miners'
   // starts will range from this to LOCAL_NONCE_START + LOCAL_MINERS - 1.
`ifdef LOCAL_NONCE_START
   parameter LOCAL_NONCE_START = `LOCAL_NONCE_START;
`else
   parameter LOCAL_NONCE_START = 0;
`endif
   
   // It is OK to make extra/unused ports, but TOTAL_MINERS must be
   // correct for the actual number of hashers.
`ifdef EXT_PORTS
   parameter EXT_PORTS = `EXT_PORTS;
`else
   parameter EXT_PORTS = 0;
`endif

   localparam SLAVES = LOCAL_MINERS + EXT_PORTS;

   wire [LOCAL_MINERS-1:0] localminer_rxd;

   // Work distribution is simply copying to all miners, so no logic
   // needed there, simply copy the RxD.
   input 	     RxD;

   output TxD;

   // Results from the input buffers (in serial_hub.v) of each slave
   wire [SLAVES*32-1:0] slave_nonces;
   wire [SLAVES-1:0] 	new_nonces;

   // Using the same transmission code as individual miners from serial.v
   wire 		serial_send;
   wire 		serial_busy;
   wire [31:0] 		golden_nonce;
   serial_transmit #(.comm_clk_frequency(comm_clk_frequency)) sertx (.clk(hash_clk), .TxD(TxD), .send(serial_send), .busy(serial_busy), .word(golden_nonce));

   hub_core #(.SLAVES(SLAVES)) hc (.hash_clk(hash_clk), .new_nonces(new_nonces), .golden_nonce(golden_nonce), .serial_send(serial_send), .serial_busy(serial_busy), .slave_nonces(slave_nonces));

   // Common workdata input for local miners
   wire [255:0] 	midstate, data2;
   wire 		rx_done;
   serial_receive #(.comm_clk_frequency(comm_clk_frequency)) serrx (.clk(hash_clk), .RxD(RxD), .midstate(midstate), .data2(data2), .rx_done(rx_done));

   // Local miners now directly connected
   generate
      genvar 	     i;
      for (i = 0; i < LOCAL_MINERS; i = i + 1)
	begin: for_local_miners
	   miner #(.nonce_stride(TOTAL_MINERS), .nonce_start(LOCAL_NONCE_START+i), .LOOP_LOG2(LOOP_LOG2)) M (.hash_clk(hash_clk), .midstate_vw(midstate), .data2_vw(data2), .nonce_out(slave_nonces[i*32+31:i*32]), .is_golden(new_nonces[i]), .rx_done(rx_done));
	end
   endgenerate

   // External miner ports, results appended to the same
   // slave_nonces/new_nonces as local ones
   /*
   output [EXT_PORTS-1:0] extminer_txd;
   input [EXT_PORTS-1:0]  extminer_rxd;
   assign extminer_txd = {EXT_PORTS{RxD}};
      
   generate
      genvar 		  j;
      for (j = LOCAL_MINERS; j < SLAVES; j = j + 1)
	begin: for_ports
   	   slave_receive #(.comm_clk_frequency(comm_clk_frequency)) slrx (.clk(hash_clk), .RxD(extminer_rxd[j-LOCAL_MINERS]), .nonce(slave_nonces[j*32+31:j*32]), .new_nonce(new_nonces[j]));
	end
   endgenerate
    */
    
endmodule

