module ov5640_ddr_hdmi #(
    parameter   FIFO_WR_WIDTH   = 'd16,                 //用户端FIFO写位宽
    parameter   FIFO_RD_WIDTH   = 'd16,                 //用户端FIFO读位宽
    parameter   SYS_CLK_FREQ    = 'd50_000_000,         //系统时钟频率
    parameter   H_PIXEL         = 'd640,                //水平方向像素个数,用于设置SDRAM缓存大小   
    parameter   V_PIXEL         = 'd480,                //垂直方向像素个数,用于设置SDRAM缓存大小
    parameter   DDR_ADDR_WIDTH  = 'd14,                 //DDR地址位宽
    parameter   DDR_DATA_WIDTH  = 'd16,                 //DDR数据位宽
    parameter   WR_BEG_ADDR     = 'd0,                  //写FIFO写起始地址
    parameter   WR_END_ADDR     = H_PIXEL*V_PIXEL*2,    //写FIFO写终止地址 
    parameter   WR_BURST_LEN    = 'd31,                 //写FIFO写突发长度为WR_BURST_LEN+1
    parameter   RD_BEG_ADDR     = 'd0,                  //读FIFO读起始地址
    parameter   RD_END_ADDR     = H_PIXEL*V_PIXEL*2,    //读FIFO读终止地址 
    parameter   RD_BURST_LEN    = 'd31,                 //读FIFO读突发长度为RD_BURST_LEN+1
    parameter   AXI_DATA_WIDTH  = 'd64,                 //AXI总线读写数据位宽
    parameter   AXI_ADDR_WIDTH  = 'd28,                 //AXI总线读写地址位宽(DDR大小为256MB,对应总线地址为28位宽)
    parameter   AXI_AWSIZE      = 'b011                 //AXI总线一拍传输8字节
)(
    input   wire                            sys_clk,  
    input   wire                            sys_rst_n,  

    output  wire                            hdmi_clk_p,
    output  wire                            hdmi_clk_n,
    output  wire    [2:0]                   hdmi_data_p,
    output  wire    [2:0]                   hdmi_data_n,
    output  wire                            hdmi_oe,

    input   wire                            ov5640_pclk,
    input   wire                            ov5640_href,      
    input   wire                            ov5640_vsync,    
    input   wire    [7:0]                   ov5640_data,    
    output  wire                            sccb_scl,
    inout   wire                            sccb_sda,

    output  wire    [DDR_ADDR_WIDTH-1:0]    ddr3_addr,  
    output  wire    [1:0]                   ddr3_ba,
    output  wire                            ddr3_cas_n,
    output  wire                            ddr3_ck_n,
    output  wire                            ddr3_ck_p,
    output  wire                            ddr3_cke,
    output  wire                            ddr3_ras_n,
    output  wire                            ddr3_reset_n,
    output  wire                            ddr3_we_n,
    inout   wire    [DDR_DATA_WIDTH-1:0]    ddr3_dq,
    inout   wire    [1:0]                   ddr3_dqs_n,
    inout   wire    [1:0]                   ddr3_dqs_p,
    output  wire                            ddr3_cs_n,
    output  wire    [1:0]                   ddr3_dm,
    output  wire                            ddr3_odt      
);
assign hdmi_oe = 1'b1;
wire        ddr_clk;
wire        hdmi_clk;
wire        vga_clk;
wire        pll_stable;

clk_gen u_clk_gen(
    .clk_200m   (ddr_clk),     
    .clk_125m   (hdmi_clk),   
    .clk_25m    (vga_clk),   
    .resetn     (sys_rst_n), 
    .locked     (pll_stable),     
    .clk_50m    (sys_clk) 
);
wire    ddr_stable; 
wire    ddr_rst_n;                      
assign  ddr_rst_n = sys_rst_n & pll_stable;     //DDR输入接口的复位信号
wire    sys_init_done;  
assign  sys_init_done = ddr_rst_n & ddr_stable & ov5640_cfg_done;    //其余外设复位信号
  
wire                        ov5640_cfg_done;    //摄像头寄存器配置完成
wire    [FIFO_WR_WIDTH-1:0] fifo_wr_data;       //图像数据RGB565
wire                        fifo_wr_en;         //图像数据有效使能信号

ov5640_top u_ov5640_top(
    .sys_clk         (sys_clk),    
    .sys_rst_n       (sys_rst_n),    
    .sys_init_done   (sys_init_done),       //系统初始化完成(DDR+摄像头+PLL)
    .ov5640_pclk     (ov5640_pclk),         //摄像头像素时钟
    .ov5640_href     (ov5640_href),         //摄像头行同步信号
    .ov5640_vsync    (ov5640_vsync),        //摄像头场同步信号
    .ov5640_data     (ov5640_data),         //摄像头图像数据
    .cfg_done        (ov5640_cfg_done),     
    .sccb_scl        (sccb_scl),    
    .sccb_sda        (sccb_sda),    
    .ov5640_wr_en    (fifo_wr_en),          
    .ov5640_data_out (fifo_wr_data)    
);
wire                     fifo_rd_en;            //读FIFO读请求
wire [FIFO_RD_WIDTH-1:0] fifo_rd_data;          //读FIFO读数据
wire                     hsync;                 //行同步
wire                     vsync;                 //场同步
wire                     rgb_valid;             //输出像素点色彩信息有效信号
wire [15:0]              rgb_out;               //输出像素点色彩信息

vga_ctrl u_vga_ctrl(
    .vga_clk     (vga_clk),    
    .sys_rst_n   (sys_init_done),    
    .pix_data    (fifo_rd_data),    //输入像素点色彩信息
    .pix_x       (),                //输出VGA有效显示区域像素点X轴坐标
    .pix_y       (),                //输出VGA有效显示区域像素点Y轴坐标
    .hsync       (hsync),           
    .vsync       (vsync),           
    .pix_data_req(fifo_rd_en),
    .rgb_valid   (rgb_valid),       
    .rgb         (rgb_out)          
);

hdmi_ctrl u_hdmi_ctrl(
    .clk_1x      (vga_clk),   
    .clk_5x      (hdmi_clk),    
    .sys_rst_n   (sys_init_done),    
    .rgb_blue    ({rgb_out[4:0],3'b0}),     
    .rgb_green   ({rgb_out[10:5],2'b0}),    
    .rgb_red     ({rgb_out[15:11],3'b0}),   
    .hsync       (hsync),    
    .vsync       (vsync),    
    .de          (rgb_valid),   
    .hdmi_clk_p  (hdmi_clk_p),
    .hdmi_clk_n  (hdmi_clk_n),   
    .hdmi_r_p    (hdmi_data_p[2]),
    .hdmi_r_n    (hdmi_data_n[2]),    
    .hdmi_g_p    (hdmi_data_p[1]),
    .hdmi_g_n    (hdmi_data_n[1]),    
    .hdmi_b_p    (hdmi_data_p[0]),
    .hdmi_b_n    (hdmi_data_n[0])     
);

ddr_interface #(
    .FIFO_WR_WIDTH  (FIFO_WR_WIDTH), 
    .FIFO_RD_WIDTH  (FIFO_RD_WIDTH),
    .DDR_ADDR_WIDTH (DDR_ADDR_WIDTH),                 
    .DDR_DATA_WIDTH (DDR_DATA_WIDTH), 
    .AXI_DATA_WIDTH (AXI_DATA_WIDTH),
    .AXI_ADDR_WIDTH (AXI_ADDR_WIDTH),                
    .AXI_AWSIZE     (AXI_AWSIZE)
)ddr_interface_inst(
    .ddr_clk             (ddr_clk),  
    .ddr_rst_n           (ddr_rst_n),       
    //用户端 写fifo端口                      
    .wr_clk              (ov5640_pclk),         //写FIFO写时钟
    .wr_rst_n            (ddr_rst_n),          
    .wr_beg_addr         (WR_BEG_ADDR),         //写起始地址
    .wr_end_addr         (WR_END_ADDR),         //写终止地址
    .wr_burst_len        (WR_BURST_LEN),        //写突发长度
    .wr_en               (fifo_wr_en),
    .wr_data             (fifo_wr_data),
    //用户端 读fifo端口                      
    .rd_clk              (vga_clk),             //读FIFO读时钟
    .rd_rst_n            (ddr_rst_n),
    .rd_beg_addr         (RD_BEG_ADDR),         //读起始地址
    .rd_end_addr         (RD_END_ADDR),         //读终止地址
    .rd_burst_len        (RD_BURST_LEN),        //读突发长度
    .rd_en               (fifo_rd_en),          
    .rd_data             (fifo_rd_data), 
    .ddr_stable          (ddr_stable),          //DDR3初始化完成
    //DDR3接口                              
    .ddr3_addr           (ddr3_addr),  
    .ddr3_ba             (ddr3_ba),
    .ddr3_cas_n          (ddr3_cas_n),
    .ddr3_ck_n           (ddr3_ck_n),
    .ddr3_ck_p           (ddr3_ck_p),
    .ddr3_cke            (ddr3_cke),
    .ddr3_ras_n          (ddr3_ras_n),
    .ddr3_reset_n        (ddr3_reset_n),
    .ddr3_we_n           (ddr3_we_n),
    .ddr3_dq             (ddr3_dq),
    .ddr3_dqs_n          (ddr3_dqs_n),
    .ddr3_dqs_p          (ddr3_dqs_p),
    .ddr3_cs_n           (ddr3_cs_n),
    .ddr3_dm             (ddr3_dm),
    .ddr3_odt            (ddr3_odt)
);

endmodule