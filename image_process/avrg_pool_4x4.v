module avrg_pool_4x4 #(    
    parameter IMG_DATA_WIDTH = 8,
    parameter IMG_WIDTH = 28,
    parameter IMG_HEIGHT = 28
)(
    input   wire                                        clk,
    input   wire                                        rst_n,
    input   wire                                        avrg_pool_valid_in,
    input   wire    signed  [IMG_DATA_WIDTH-1:0]        avrg_pool_data_in_00,
    input   wire    signed  [IMG_DATA_WIDTH-1:0]        avrg_pool_data_in_01,
    input   wire    signed  [IMG_DATA_WIDTH-1:0]        avrg_pool_data_in_02,
    input   wire    signed  [IMG_DATA_WIDTH-1:0]        avrg_pool_data_in_03,
    input   wire    signed  [IMG_DATA_WIDTH-1:0]        avrg_pool_data_in_10,
    input   wire    signed  [IMG_DATA_WIDTH-1:0]        avrg_pool_data_in_11,
    input   wire    signed  [IMG_DATA_WIDTH-1:0]        avrg_pool_data_in_12,
    input   wire    signed  [IMG_DATA_WIDTH-1:0]        avrg_pool_data_in_13,
    input   wire    signed  [IMG_DATA_WIDTH-1:0]        avrg_pool_data_in_20,
    input   wire    signed  [IMG_DATA_WIDTH-1:0]        avrg_pool_data_in_21,
    input   wire    signed  [IMG_DATA_WIDTH-1:0]        avrg_pool_data_in_22,
    input   wire    signed  [IMG_DATA_WIDTH-1:0]        avrg_pool_data_in_23,
    input   wire    signed  [IMG_DATA_WIDTH-1:0]        avrg_pool_data_in_30,
    input   wire    signed  [IMG_DATA_WIDTH-1:0]        avrg_pool_data_in_31,
    input   wire    signed  [IMG_DATA_WIDTH-1:0]        avrg_pool_data_in_32,
    input   wire    signed  [IMG_DATA_WIDTH-1:0]        avrg_pool_data_in_33,
    output  wire            [9:0]                       avrg_pool_addr_out,
    output  wire                                        avrg_pool_valid_out,
    output  wire    signed  [IMG_DATA_WIDTH-1:0]        avrg_pool_data_out,
    output  wire                                        cnn_start
);

reg         [9:0]                   pool_addr;

reg signed  [IMG_DATA_WIDTH-1:0]    data_out;
reg signed  [IMG_DATA_WIDTH:0]      s1_sum_0;
reg signed  [IMG_DATA_WIDTH:0]      s1_sum_1;
reg signed  [IMG_DATA_WIDTH:0]      s1_sum_2;
reg signed  [IMG_DATA_WIDTH:0]      s1_sum_3;
reg signed  [IMG_DATA_WIDTH:0]      s1_sum_4;
reg signed  [IMG_DATA_WIDTH:0]      s1_sum_5;
reg signed  [IMG_DATA_WIDTH:0]      s1_sum_6;
reg signed  [IMG_DATA_WIDTH:0]      s1_sum_7;
reg signed  [IMG_DATA_WIDTH+1:0]    s2_sum_0;
reg signed  [IMG_DATA_WIDTH+1:0]    s2_sum_1;
reg signed  [IMG_DATA_WIDTH+1:0]    s2_sum_2;
reg signed  [IMG_DATA_WIDTH+1:0]    s2_sum_3;
reg signed  [IMG_DATA_WIDTH+2:0]    s3_sum_0;
reg signed  [IMG_DATA_WIDTH+2:0]    s3_sum_1;
reg                                 valid_s1;
reg                                 valid_s2;
reg                                 valid_s3;
reg                                 valid_out;

always @(posedge clk) begin
    if (!rst_n) begin
        s1_sum_0 <= 'sd0;
        s1_sum_1 <= 'sd0;
        s1_sum_2 <= 'sd0;
        s1_sum_3 <= 'sd0;
        s1_sum_4 <= 'sd0;
        s1_sum_5 <= 'sd0;
        s1_sum_6 <= 'sd0;
        s1_sum_7 <= 'sd0;
        s2_sum_0 <= 'sd0;
        s2_sum_1 <= 'sd0;
        s2_sum_2 <= 'sd0;
        s2_sum_3 <= 'sd0;
        s3_sum_0 <= 'sd0;
        s3_sum_1 <= 'sd0;
        valid_s1 <= 'b0;
        valid_s2 <= 'b0;
        valid_s3 <= 'b0;
        valid_out <= 'b0;
        data_out <= 'd0;
    end 
    else begin
        valid_s1 <= avrg_pool_valid_in;
        valid_s2 <= valid_s1;
        valid_s3 <= valid_s2;
        valid_out <= valid_s3;
        if (avrg_pool_valid_in) begin
            s1_sum_0 <= $signed(avrg_pool_data_in_00) + $signed(avrg_pool_data_in_01);
            s1_sum_1 <= $signed(avrg_pool_data_in_02) + $signed(avrg_pool_data_in_03);
            s1_sum_2 <= $signed(avrg_pool_data_in_10) + $signed(avrg_pool_data_in_11);
            s1_sum_3 <= $signed(avrg_pool_data_in_12) + $signed(avrg_pool_data_in_13);
            s1_sum_4 <= $signed(avrg_pool_data_in_20) + $signed(avrg_pool_data_in_21);
            s1_sum_5 <= $signed(avrg_pool_data_in_22) + $signed(avrg_pool_data_in_23);
            s1_sum_6 <= $signed(avrg_pool_data_in_30) + $signed(avrg_pool_data_in_31);
            s1_sum_7 <= $signed(avrg_pool_data_in_32) + $signed(avrg_pool_data_in_33);
        end
        if (valid_s1) begin
            s2_sum_0 <= s1_sum_0 + s1_sum_1;
            s2_sum_1 <= s1_sum_2 + s1_sum_3;
            s2_sum_2 <= s1_sum_4 + s1_sum_5;
            s2_sum_3 <= s1_sum_6 + s1_sum_7;
        end
        if (valid_s2) begin
            s3_sum_0 <= s2_sum_0 + s2_sum_1;
            s3_sum_1 <= s2_sum_2 + s2_sum_3;
        end
        if (valid_s3) begin
            data_out <= (s3_sum_0 + s3_sum_1) >>> 4;
        end
    end
end

always @(posedge clk) begin
    if(!rst_n)begin
        pool_addr <= 'd0;
    end 
    else if(pool_addr == IMG_WIDTH*IMG_HEIGHT-1)begin
        pool_addr <= 'd0;
    end
    else if(valid_s2)begin
        pool_addr <= pool_addr + 'd1;
    end
end

reg start;
always @(posedge clk) begin
    if(!rst_n)begin
        start <= 'b0;
    end 
    else if(valid_s1 && (pool_addr == 'd0))begin
        start <= 'b1;
    end
    else begin
        start <= 'b0;
    end
end

assign cnn_start = start;
assign avrg_pool_addr_out = pool_addr;
assign avrg_pool_valid_out = valid_out;
assign avrg_pool_data_out = data_out;



endmodule
