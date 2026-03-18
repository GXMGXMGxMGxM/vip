module ddr_interface #(
    parameter   FIFO_WR_WIDTH   ='d16,
    parameter   FIFO_RD_WIDTH   ='d16,
    parameter   DDR_ADDR_WIDTH  ='d14,
    parameter   DDR_DATA_WIDTH  ='d16,
    parameter   AXI_DATA_WIDTH  ='d64,      //AXI总线读写数据位宽
    parameter   AXI_ADDR_WIDTH  ='d28,      //AXI总线读写地址位宽(DDR大小为256MB,对应总线地址为28位宽)
    parameter   AXI_AWSIZE      ='b011      //AXI总线一拍传输8字节
)(
    input   wire                        ddr_clk                 , //DDR3时钟, 也就是DDR3 MIG IP核参考时钟
    input   wire                        ddr_rst_n               ,                         
    //用户端 写fifo端口                       
    input   wire                        wr_clk              , //写FIFO写时钟
    input   wire                        wr_rst_n            , //写复位
    input   wire [AXI_ADDR_WIDTH-1:0]   wr_beg_addr         , //写起始地址
    input   wire [AXI_ADDR_WIDTH-1:0]   wr_end_addr         , //写终止地址
    input   wire [7:0]                  wr_burst_len        , //写突发长度
    input   wire                        wr_en               , //写FIFO写请求
    input   wire [FIFO_WR_WIDTH-1:0]    wr_data             , //写FIFO写数据
    //用户端 读fifo端口                       
    input   wire                        rd_clk              , //读FIFO读时钟
    input   wire                        rd_rst_n            , //读复位
    input   wire [AXI_ADDR_WIDTH-1:0]   rd_beg_addr         , //读起始地址
    input   wire [AXI_ADDR_WIDTH-1:0]   rd_end_addr         , //读终止地址
    input   wire [7:0]                  rd_burst_len        , //读突发长度
    input   wire                        rd_en               , //读FIFO读请求
    output  wire [FIFO_RD_WIDTH-1:0]    rd_data             , //读FIFO读数据
    output  wire                        ddr_stable          , //DDR3初始化完成
    //DDR3接口                              
    output  wire [DDR_ADDR_WIDTH-1:0]   ddr3_addr,  
    output  wire [2:0]                  ddr3_ba,
    output  wire                        ddr3_cas_n,
    output  wire                        ddr3_ck_n,
    output  wire                        ddr3_ck_p,
    output  wire                        ddr3_cke,
    output  wire                        ddr3_ras_n,
    output  wire                        ddr3_reset_n,
    output  wire                        ddr3_we_n,
    inout   wire [DDR_DATA_WIDTH-1:0]   ddr3_dq,
    inout   wire [1:0]                  ddr3_dqs_n,
    inout   wire [1:0]                  ddr3_dqs_p,
    output  wire                        ddr3_cs_n,
    output  wire [1:0]                  ddr3_dm,
    output  wire                        ddr3_odt            
);
    
localparam AXI_WSTRB_W   = AXI_DATA_WIDTH >> 3; //axi_wstrb的位宽, AXI_DATA_WIDTH/8

//AXI连线
//AXI4写地址通道
wire [3:0]                  axi_awid      ; 
wire [AXI_ADDR_WIDTH-1:0]   axi_awaddr    ;
wire [7:0]                  axi_awlen     ; //突发传输长度
wire [2:0]                  axi_awsize    ; //突发传输大小(Byte)
wire [1:0]                  axi_awburst   ; //突发类型
wire                        axi_awlock    ; 
wire [3:0]                  axi_awcache   ; 
wire [2:0]                  axi_awprot    ;
wire [3:0]                  axi_awqos     ;
wire                        axi_awvalid   ; //写地址valid
wire                        axi_awready   ; //从机发出的写地址ready

//写数据通道
wire [AXI_DATA_WIDTH-1:0]   axi_wdata     ; //写数据
wire [AXI_WSTRB_W-1:0]      axi_wstrb     ; //写数据有效字节线
wire                        axi_wlast     ; //最后一个数据标志
wire                        axi_wvalid    ; //写数据有效标志
wire                        axi_wready    ; //从机发出的写数据ready
            
//写响应通道         
wire [3:0]                  axi_bid       ;
wire [1:0]                  axi_bresp     ; //响应信号,表征写传输是否成功
wire                        axi_bvalid    ; //响应信号valid标志
wire                        axi_bready    ; //主机响应ready信号

//读地址通道
wire [3:0]                  axi_arid      ; 
wire [AXI_ADDR_WIDTH-1:0]   axi_araddr    ; 
wire [7:0]                  axi_arlen     ; //突发传输长度
wire [2:0]                  axi_arsize    ; //突发传输大小(Byte)
wire [1:0]                  axi_arburst   ; //突发类型
wire                        axi_arlock    ; 
wire [3:0]                  axi_arcache   ; 
wire [2:0]                  axi_arprot    ;
wire [3:0]                  axi_arqos     ;
wire                        axi_arvalid   ; //读地址valid
wire                        axi_arready   ; //从机准备接收读地址

//读数据通道
wire [AXI_DATA_WIDTH-1:0]   axi_rdata     ; //读数据
wire [1:0]                  axi_rresp     ; //收到的读响应
wire                        axi_rlast     ; //最后一个数据标志
wire                        axi_rvalid    ; //读数据有效标志
wire                        axi_rready    ; //主机发出的读数据ready
wire [3:0]                  axi_rid       ;
//输入系统时钟异步复位、同步释放处理
reg                     rst_n_r1      ;
reg                     rst_n_sync    ;

//rst_n_d1、rst_n_sync
always@(posedge ddr_clk or negedge ddr_rst_n) begin
    if(~ddr_rst_n) begin
        rst_n_r1    <= 1'b0;
        rst_n_sync  <= 1'b0;
    end else begin
        rst_n_r1    <= 1'b1;
        rst_n_sync  <= rst_n_r1;
    end
end

wire    axi_clk;
wire    axi_rst;

// axi_ddr_ctrl模块
axi_ddr_ctrl #(
    .FIFO_WR_WIDTH  (FIFO_WR_WIDTH),  
    .FIFO_RD_WIDTH  (FIFO_RD_WIDTH),
    .DDR_ADDR_WIDTH (DDR_ADDR_WIDTH),                 
    .DDR_DATA_WIDTH (DDR_DATA_WIDTH), 
    .AXI_DATA_WIDTH (AXI_DATA_WIDTH),
    .AXI_ADDR_WIDTH (AXI_ADDR_WIDTH),                
    .AXI_AWSIZE     (AXI_AWSIZE),
    .AXI_WSTRB_W    (AXI_WSTRB_W) 
)u_axi_ddr_ctrl(
    .axi_clk         (axi_clk          ), //AXI读写主机时钟
    .axi_rst_n       (~axi_rst         ), 
    //用户端    
    .wr_clk          (wr_clk           ), //写FIFO写时钟
    .wr_rst_n        (wr_rst_n         ), //写复位
    .wr_beg_addr     (wr_beg_addr      ), //写起始地址
    .wr_end_addr     (wr_end_addr      ), //写终止地址
    .wr_burst_len    (wr_burst_len     ), //写突发长度
    .wr_en           (wr_en            ), //写FIFO写请求
    .wr_data         (wr_data          ), //写FIFO写数据 
    .rd_clk          (rd_clk           ), //读FIFO读时钟
    .rd_rst_n        (rd_rst_n         ), //读复位
    .rd_beg_addr     (rd_beg_addr      ), //读起始地址
    .rd_end_addr     (rd_end_addr      ), //读终止地址
    .rd_burst_len    (rd_burst_len     ), //读突发长度
    .rd_en           (rd_en            ), //读FIFO读请求
    .rd_data         (rd_data          ), //读FIFO读数据
    
    //AXI总线
    //AXI4写地址通道
    .m_axi_awid      (axi_awid         ), 
    .m_axi_awaddr    (axi_awaddr       ),
    .m_axi_awlen     (axi_awlen        ), //突发传输长度
    .m_axi_awsize    (axi_awsize       ), //突发传输大小(Byte)
    .m_axi_awburst   (axi_awburst      ), //突发类型
    .m_axi_awlock    (axi_awlock       ), 
    .m_axi_awcache   (axi_awcache      ), 
    .m_axi_awprot    (axi_awprot       ),
    .m_axi_awqos     (axi_awqos        ),
    .m_axi_awvalid   (axi_awvalid      ), //写地址valid
    .m_axi_awready   (axi_awready      ), //从机发出的写地址ready
    
    //写数据通道
    .m_axi_wdata     (axi_wdata        ), //写数据
    .m_axi_wstrb     (axi_wstrb        ), //写数据有效字节线
    .m_axi_wlast     (axi_wlast        ), //最后一个数据标志
    .m_axi_wvalid    (axi_wvalid       ), //写数据有效标志
    .m_axi_wready    (axi_wready       ), //从机发出的写数据ready
    
    //写响应通道
    .m_axi_bid       (axi_bid          ),
    .m_axi_bresp     (axi_bresp        ), //响应信号,表征写传输是否成功
    .m_axi_bvalid    (axi_bvalid       ), //响应信号valid标志
    .m_axi_bready    (axi_bready       ), //主机响应ready信号
    
    //AXI4读地址通道
    .m_axi_arid      (axi_arid         ), 
    .m_axi_araddr    (axi_araddr       ),
    .m_axi_arlen     (axi_arlen        ), //突发传输长度
    .m_axi_arsize    (axi_arsize       ), //突发传输大小(Byte)
    .m_axi_arburst   (axi_arburst      ), //突发类型
    .m_axi_arlock    (axi_arlock       ), 
    .m_axi_arcache   (axi_arcache      ), 
    .m_axi_arprot    (axi_arprot       ),
    .m_axi_arqos     (axi_arqos        ),
    .m_axi_arvalid   (axi_arvalid      ), //读地址valid
    .m_axi_arready   (axi_arready      ), //从机准备接收读地址
    
    //读数据通道
    .m_axi_rdata     (axi_rdata        ), //读数据
    .m_axi_rresp     (axi_rresp        ), //收到的读响应
    .m_axi_rlast     (axi_rlast        ), //最后一个数据标志
    .m_axi_rvalid    (axi_rvalid       ), //读数据有效标志
    .m_axi_rready    (axi_rready       )  //主机发出的读数据ready
);
    
    
// Vivado MIG IP核
axi_ddr3 axi_ddr3_mig (
    // DDR3存储器接口
    .ddr3_addr              (ddr3_addr          ),  // output [13:0]    ddr3_addr
    .ddr3_ba                (ddr3_ba            ),  // output [2:0]     ddr3_ba
    .ddr3_cas_n             (ddr3_cas_n         ),  // output           ddr3_cas_n
    .ddr3_ck_n              (ddr3_ck_n          ),  // output [0:0]     ddr3_ck_n
    .ddr3_ck_p              (ddr3_ck_p          ),  // output [0:0]     ddr3_ck_p
    .ddr3_cke               (ddr3_cke           ),  // output [0:0]     ddr3_cke
    .ddr3_ras_n             (ddr3_ras_n         ),  // output           ddr3_ras_n
    .ddr3_reset_n           (ddr3_reset_n       ),  // output           ddr3_reset_n
    .ddr3_we_n              (ddr3_we_n          ),  // output           ddr3_we_n
    .ddr3_dq                (ddr3_dq            ),  // inout [15:0]     ddr3_dq
    .ddr3_dqs_n             (ddr3_dqs_n         ),  // inout [1:0]      ddr3_dqs_n
    .ddr3_dqs_p             (ddr3_dqs_p         ),  // inout [1:0]      ddr3_dqs_p
    .init_calib_complete    (ddr_stable         ),  // output           ddr_stable
    .ddr3_cs_n              (ddr3_cs_n          ),  // output [0:0]     ddr3_cs_n
    .ddr3_dm                (ddr3_dm            ),  // output [1:0]     ddr3_dm
    .ddr3_odt               (ddr3_odt           ),  // output [0:0]     ddr3_odt
    // 用户接口
    .ui_clk                 (axi_clk            ),  // output           axi_clk
    .ui_clk_sync_rst        (axi_rst            ),  // output           axi_rst
    .mmcm_locked            (                   ),  // output           mmcm_locked
    .aresetn                (rst_n_sync         ),  // input            aresetn
    .app_sr_req             (1'b0               ),  // input            app_sr_req
    .app_ref_req            (1'b0               ),  // input            app_ref_req
    .app_zq_req             (1'b0               ),  // input            app_zq_req
    .app_sr_active          (                   ),  // output           app_sr_active
    .app_ref_ack            (                   ),  // output           app_ref_ack
    .app_zq_ack             (                   ),  // output           app_zq_ack
    // AXI写地址通道
    .s_axi_awid             (axi_awid           ),  // input [3:0]      s_axi_awid
    .s_axi_awaddr           (axi_awaddr         ),  // input [27:0]     s_axi_awaddr
    .s_axi_awlen            (axi_awlen          ),  // input [7:0]      s_axi_awlen
    .s_axi_awsize           (axi_awsize         ),  // input [2:0]      s_axi_awsize
    .s_axi_awburst          (axi_awburst        ),  // input [1:0]      s_axi_awburst
    .s_axi_awlock           (axi_awlock         ),  // input [0:0]      s_axi_awlock
    .s_axi_awcache          (axi_awcache        ),  // input [3:0]      s_axi_awcache
    .s_axi_awprot           (axi_awprot         ),  // input [2:0]      s_axi_awprot
    .s_axi_awqos            (axi_awqos          ),  // input [3:0]      s_axi_awqos
    .s_axi_awvalid          (axi_awvalid        ),  // input            s_axi_awvalid
    .s_axi_awready          (axi_awready        ),  // output           s_axi_awready
    // AXI写数据通道
    .s_axi_wdata            (axi_wdata          ),  // input [AXI_DATA_WIDTH-1:0]s_axi_wdata
    .s_axi_wstrb            (axi_wstrb          ),  // input [AXI_WSTRB_W-1:0]   s_axi_wstrb
    .s_axi_wlast            (axi_wlast          ),  // input                     s_axi_wlast
    .s_axi_wvalid           (axi_wvalid         ),  // input                     s_axi_wvalid
    .s_axi_wready           (axi_wready         ),  // output                    s_axi_wready
    // AXI写响应通道        
    .s_axi_bid              (axi_bid            ),  // output [3:0]              s_axi_bid
    .s_axi_bresp            (axi_bresp          ),  // output [1:0]              s_axi_bresp
    .s_axi_bvalid           (axi_bvalid         ),  // output                    s_axi_bvalid
    .s_axi_bready           (axi_bready         ),  // input                     s_axi_bready
    // AXI读地址通道        
    .s_axi_arid             (axi_arid           ),  // input [3:0]                  s_axi_arid
    .s_axi_araddr           (axi_araddr         ),  // input [27:0]                 s_axi_araddr
    .s_axi_arlen            (axi_arlen          ),  // input [7:0]                  s_axi_arlen
    .s_axi_arsize           (axi_arsize         ),  // input [2:0]                  s_axi_arsize
    .s_axi_arburst          (axi_arburst        ),  // input [1:0]                  s_axi_arburst
    .s_axi_arlock           (axi_arlock         ),  // input [0:0]                  s_axi_arlock
    .s_axi_arcache          (axi_arcache        ),  // input [3:0]                  s_axi_arcache
    .s_axi_arprot           (axi_arprot         ),  // input [2:0]                  s_axi_arprot
    .s_axi_arqos            (axi_arqos          ),  // input [3:0]                  s_axi_arqos
    .s_axi_arvalid          (axi_arvalid        ),  // input                        s_axi_arvalid
    .s_axi_arready          (axi_arready        ),  // output                       s_axi_arready
    // AXI读数据通道
    .s_axi_rid              (axi_rid            ),  // output [3:0]                 s_axi_rid
    .s_axi_rdata            (axi_rdata          ),  // output [AXI_DATA_WIDTH-1:0]  s_axi_rdata
    .s_axi_rresp            (axi_rresp          ),  // output [1:0]                 s_axi_rresp
    .s_axi_rlast            (axi_rlast          ),  // output                       s_axi_rlast
    .s_axi_rvalid           (axi_rvalid         ),  // output                       s_axi_rvalid
    .s_axi_rready           (axi_rready         ),  // input                        s_axi_rready
    // AXI从机系统时钟
    .sys_clk_i              (ddr_clk            ),
    // 参考时钟
    .clk_ref_i              (ddr_clk            ),
    .sys_rst                (rst_n_sync         )   
);
    
endmodule
