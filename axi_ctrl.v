module axi_ctrl#(
    parameter   FIFO_WR_WIDTH   ='d16,
    parameter   FIFO_RD_WIDTH   ='d16,
    parameter   DDR_ADDR_WIDTH  ='d14,
    parameter   DDR_DATA_WIDTH  ='d16,
    parameter   AXI_DATA_WIDTH  ='d64,      //AXI总线读写数据位宽
    parameter   AXI_ADDR_WIDTH  ='d28,      //AXI总线读写地址位宽(DDR大小为256MB,对应总线地址为28位宽)
    parameter   AXI_AWSIZE      ='b011,      //AXI总线一拍传输8字节
    parameter   AXI_WSTRB_W     ='d8
)(
    input   wire                        axi_clk         , //AXI读写主机时钟
    input   wire                        axi_rst_n       ,   
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
    //写AXI主机
    input   wire                        axi_writing         , //AXI主机写正在进行
    input   wire                        axi_wr_ready        , //AXI主机写准备好
    output  reg                         axi_wr_start        , //AXI主机写请求
    output  wire [AXI_DATA_WIDTH-1:0]   axi_wr_data         , //从写FIFO中读取的数据,写入AXI写主机
    output  reg  [AXI_ADDR_WIDTH-1:0]   axi_wr_addr         , //AXI主机写地址
    output  wire [7:0]                  axi_wr_len          , //AXI主机写突发长度
    input   wire                        axi_wr_done         , //AXI主机完成一次写操作           
    //读AXI主机                
    input   wire                        axi_reading         , //AXI主机读正在进行
    input   wire                        axi_rd_ready        , //AXI主机读准备好
    output  reg                         axi_rd_start        , //AXI主机读请求
    input   wire [AXI_DATA_WIDTH-1:0]   axi_rd_data         , //从AXI读主机读到的数据,写入读FIFO
    output  reg  [AXI_ADDR_WIDTH-1:0]   axi_rd_addr         , //AXI主机读地址
    output  wire [7:0]                  axi_rd_len          , //AXI主机读突发长度 
    input   wire                        axi_rd_done           //AXI主机完成一次写操作
);

    //FIFO数据数量计数器   
    wire [10:0]  cnt_wr_fifo_rdport      ;  //写FIFO读端口(对接AXI写主机)数据数量    
    wire [10:0]  cnt_rd_fifo_wrport      ;  //读FIFO写端口(对接AXI读主机)数据数量
    
    wire        rd_fifo_empty           ;  //读FIFO空标志
    wire        rd_fifo_wr_rst_busy     ;  //读FIFO正在初始化,此时先不向SDRAM发出读取请求, 否则将有数据丢失
    
    //真实的读写突发长度
    wire  [7:0] real_wr_len             ;  //真实的写突发长度,是wr_burst_len+1
    wire  [7:0] real_rd_len             ;  //真实的读突发长度,是rd_burst_len+1
    
    //突发地址增量, 每次进行一次连续突发传输地址的增量, 在外边计算, 方便后续复用
    wire  [AXI_ADDR_WIDTH-1:0]  burst_wr_addr_inc;
    wire  [AXI_ADDR_WIDTH-1:0]  burst_rd_addr_inc;
    
       
    //真实的读写突发长度
    assign real_wr_len = wr_burst_len + 8'd1;
    assign real_rd_len = rd_burst_len + 8'd1;
    
    //突发地址增量
    assign burst_wr_addr_inc = real_wr_len * AXI_WSTRB_W;
    assign burst_rd_addr_inc = real_rd_len * AXI_WSTRB_W;
    
    
    //向AXI主机发出的读写突发长度
    assign axi_wr_len = wr_burst_len;
    assign axi_rd_len = rd_burst_len;
    
    
    //AXI读主机开始读标志
    //axi_rd_start
    always@(posedge axi_clk or negedge axi_rst_n) begin
        if(~axi_rst_n) begin
            axi_rd_start <= 1'b0;
        end else if(~axi_rd_ready) begin  //axi_rd_ready低,代表AXI读主机正在进行数据读取, start信号已经被响应
            axi_rd_start <= 1'b0;
        end else if(cnt_rd_fifo_wrport < 512 && axi_rd_ready && ~rd_fifo_wr_rst_busy) begin 
            //读FIFO中的数据存量不足, AXI读主机已经准备好, 且允许读存储器, 读FIFO可以接收数据
            axi_rd_start <= 1'b1;
        end else begin
            axi_rd_start <= axi_rd_start;
        end
    end
    
    //AXI写主机开始写标志
    //axi_wr_start
    always@(posedge axi_clk or negedge axi_rst_n) begin
        if(~axi_rst_n) begin
            axi_wr_start <= 1'b0;
        end else if(~axi_wr_ready) begin  //axi_wr_ready低,代表AXI写主机正在进行数据发送, start信号已经被响应
            axi_wr_start <= 1'b0;
        end else if(cnt_wr_fifo_rdport > real_wr_len && axi_wr_ready) begin 
            //写FIFO中的数据存量足够, AXI写主机已经准备好, 数据不在写FIFO中久留
            axi_wr_start <= 1'b1;
        end else begin
            axi_wr_start <= axi_wr_start;
        end
    end
    
    reg pp_reg;         //乒乓操作寄存器
    wire pp_flag = 1'b0;
    //AXI写地址,更新地址并判断是否可能超限
    //axi_wr_addr
    always@(posedge axi_clk or negedge axi_rst_n) begin
        if(~axi_rst_n) begin
            axi_wr_addr <= wr_beg_addr;  //初始化为起始地址
        end 
        else if(pp_flag) begin
            if(axi_wr_done && (axi_wr_addr >= ((wr_end_addr-wr_beg_addr)*2 + wr_beg_addr - burst_wr_addr_inc))) begin 
                axi_wr_addr <= wr_beg_addr;
            end else if(axi_wr_done) begin
                axi_wr_addr <= axi_wr_addr + burst_wr_addr_inc;  //增加一个burst_len的地址
            end else begin
                axi_wr_addr <= axi_wr_addr;
            end
        end
        else if(!pp_flag)begin
            if(axi_wr_done && (axi_wr_addr >= (wr_end_addr- burst_wr_addr_inc))) begin 
                axi_wr_addr <= wr_beg_addr;
            end else if(axi_wr_done) begin
                axi_wr_addr <= axi_wr_addr + burst_wr_addr_inc;  //增加一个burst_len的地址
            end else begin
                axi_wr_addr <= axi_wr_addr;
            end
        end
    end
            
    always@(posedge axi_clk or negedge axi_rst_n) begin
        if(~axi_rst_n) begin
            pp_reg <= 1'b0;   
        end else if((pp_flag)&&(axi_wr_addr==wr_end_addr)) begin
            pp_reg <= ~pp_reg;
        end else begin
            pp_reg <= pp_reg;
        end
    end

    //AXI读地址
    //axi_rd_addr
    always@(posedge axi_clk or negedge axi_rst_n) begin
        if(~axi_rst_n) begin
            axi_rd_addr <= rd_beg_addr;  //初始化为起始地址
        end
        else if(pp_flag) begin
            if(axi_rd_done && ((axi_rd_addr == (rd_end_addr- burst_rd_addr_inc))||(axi_rd_addr == ((rd_end_addr-rd_beg_addr)*2 + rd_beg_addr- burst_rd_addr_inc))))begin 
                if(pp_reg) begin
                    axi_rd_addr <= rd_beg_addr;
                end else begin
                    axi_rd_addr <= rd_end_addr; 
                end
            end else if(axi_rd_done) begin
                axi_rd_addr <= axi_rd_addr + burst_rd_addr_inc;  //增加一个burst_len的地址
            end else begin
                axi_rd_addr <= axi_rd_addr;
            end
        end
        else if(!pp_flag) begin
            if(axi_rd_done && (axi_rd_addr >= (rd_end_addr - burst_rd_addr_inc))) begin 
                axi_rd_addr <= rd_beg_addr;
            end else if(axi_rd_done) begin
                axi_rd_addr <= axi_rd_addr + burst_rd_addr_inc;  //增加一个burst_len的地址
            end else begin
                axi_rd_addr <= axi_rd_addr;
            end
        end
    end
    

//写FIFO, 待写入SDRAM的数据先暂存于此
//使用FIFO IP核
wr_fifo wr_fifo_inst (
    .rst                (~axi_rst_n         ),  
    .wr_clk             (wr_clk             ),   
    .rd_clk             (axi_clk            ),  //读端口时钟是AXI主机时钟, AXI写主机读取数据
    .din                (wr_data            ),  
    .wr_en              (wr_en              ),  
    .rd_en              (axi_writing        ),  //axi_master_wr正在写时,从写FIFO中不断读出数据
    .dout               (axi_wr_data        ),  //读出的数据作为AXI写主机的输入数据
    .full               (                   ),  
    .almost_full        (                   ),  
    .empty              (                   ),  
    .almost_empty       (                   ),  
    .rd_data_count      (cnt_wr_fifo_rdport ),  //写FIFO读端口(对接AXI写主机)数据数量
    .wr_data_count      (                   ),  
    .wr_rst_busy        (                   ),  
    .rd_rst_busy        (                   )   
);
//读FIFO, 从SDRAM中读出的数据先暂存于此
//使用FIFO IP核
rd_fifo rd_fifo_inst (
    .rst                (~axi_rst_n         ),  //读复位时需要复位读FIFO
    .wr_clk             (axi_clk            ),  //写端口时钟是AXI主机时钟, 从axi_master_rd模块写入数据
    .rd_clk             (rd_clk             ),  //读端口时钟
    .din                (axi_rd_data        ),  //从axi_master_rd模块写入数据
    .wr_en              (axi_reading        ),  //axi_master_rd正在读时,FIFO也在写入
    .rd_en              (rd_en              ),  //读FIFO读使能
    .dout               (rd_data            ),  //读FIFO读取的数据
    .full               (                   ),  
    .almost_full        (                   ),  
    .empty              (rd_fifo_empty      ),  
    .almost_empty       (                   ),  
    .rd_data_count      (                   ),  
    .wr_data_count      (cnt_rd_fifo_wrport ),  //读FIFO写端口(对接AXI读主机)数据数量
    .wr_rst_busy        (rd_fifo_wr_rst_busy),     
    .rd_rst_busy        (                   )      
);
    
endmodule
