module pre_process #(
    parameter H_PIXEL = 640,                
    parameter V_PIXEL = 480,                
    parameter PRE_IMG_WIDTH = 112,
    parameter PRE_IMG_HEIGHT = 112,
    parameter PRE_IMG_DATA_WIDTH = 16,
    parameter IMG_WIDTH = 28,
    parameter IMG_HEIGHT = 28,
    parameter IMG_DATA_WIDTH = 8
)(
    input   wire                                    clk,
    input   wire                                    rst_n,
    input   wire    [11:0]                          rgb_x_in,
    input   wire    [11:0]                          rgb_y_in,
    input   wire    [PRE_IMG_DATA_WIDTH-1:0]        rgb_data_in,
    input   wire                                    rgb_valid_in,
    output  wire    [IMG_DATA_WIDTH-1:0]            pool_data_out,
    output  wire                                    pool_valid_out,
    output  wire    [9:0]                           pool_addr_out,
    output  wire                                    cnn_start
);

wire                            valid_in;
wire [PRE_IMG_DATA_WIDTH-1:0]   rgb_in;

assign valid_in = ((rgb_x_in>=((H_PIXEL-PRE_IMG_WIDTH)/2))&&(rgb_x_in<=((H_PIXEL+PRE_IMG_WIDTH)/2))&&
        (rgb_y_in>=((V_PIXEL-PRE_IMG_HEIGHT)/2))&&(rgb_y_in<=((V_PIXEL+PRE_IMG_HEIGHT)/2)))?rgb_valid_in:'b0;
assign rgb_in = rgb_data_in;

wire [IMG_DATA_WIDTH-1:0]  	gray_data_out;
wire                        gray_valid_out;
wire [6:0]                  gray_x_out;
wire [6:0]                  gray_y_out;
rgb_gray u_rgb_gray(
	.clk       	    (clk),
	.rst_n     	    (rst_n),
	.rgb_valid_in  	(valid_in),
	.rgb_data_in  	(rgb_in),
	.gray_valid_out (gray_valid_out),
    .gray_x_out     (gray_x_out),
    .gray_y_out     (gray_y_out),
	.gray_data_out 	(gray_data_out)
);

reg     [IMG_DATA_WIDTH-1:0]    buffer[0:3][0:IMG_WIDTH-1]; 
reg     [IMG_DATA_WIDTH-1:0]    window_00;
reg     [IMG_DATA_WIDTH-1:0]    window_01;
reg     [IMG_DATA_WIDTH-1:0]    window_02;
reg     [IMG_DATA_WIDTH-1:0]    window_03;
reg     [IMG_DATA_WIDTH-1:0]    window_10;
reg     [IMG_DATA_WIDTH-1:0]    window_11;
reg     [IMG_DATA_WIDTH-1:0]    window_12;
reg     [IMG_DATA_WIDTH-1:0]    window_13;
reg     [IMG_DATA_WIDTH-1:0]    window_20;
reg     [IMG_DATA_WIDTH-1:0]    window_21;
reg     [IMG_DATA_WIDTH-1:0]    window_22;
reg     [IMG_DATA_WIDTH-1:0]    window_23;
reg     [IMG_DATA_WIDTH-1:0]    window_30;
reg     [IMG_DATA_WIDTH-1:0]    window_31;
reg     [IMG_DATA_WIDTH-1:0]    window_32;
reg     [IMG_DATA_WIDTH-1:0]    window_33;
reg                             pool_valid_in;

integer i, j;
always @(posedge clk) begin
    if (!rst_n) begin
        pool_valid_in <= 'b0;
        for (j = 0; j < IMG_WIDTH; j = j + 1) begin
            buffer[0][j] <= 'd0;
            buffer[1][j] <= 'd0;
            buffer[2][j] <= 'd0;
            buffer[3][j] <= 'd0;
        end
    end else begin
        if (gray_valid_out) begin
            buffer[gray_y_out % 4][gray_x_out] <= gray_data_out;
            if ((gray_x_out >= 3) && (gray_y_out >= 3) && ((gray_x_out % 4) == 3) && ((gray_y_out % 4) == 3)) begin
                window_00 <= buffer[(gray_y_out-3) % 4][gray_x_out-3];
                window_01 <= buffer[(gray_y_out-3) % 4][gray_x_out-2];
                window_02 <= buffer[(gray_y_out-3) % 4][gray_x_out-1];
                window_03 <= buffer[(gray_y_out-3) % 4][gray_x_out];
                window_10 <= buffer[(gray_y_out-2) % 4][gray_x_out-3];
                window_11 <= buffer[(gray_y_out-2) % 4][gray_x_out-2];
                window_12 <= buffer[(gray_y_out-2) % 4][gray_x_out-1];
                window_13 <= buffer[(gray_y_out-2) % 4][gray_x_out];
                window_20 <= buffer[(gray_y_out-1) % 4][gray_x_out-3];
                window_21 <= buffer[(gray_y_out-1) % 4][gray_x_out-2];
                window_22 <= buffer[(gray_y_out-1) % 4][gray_x_out-1];
                window_23 <= buffer[(gray_y_out-1) % 4][gray_x_out];
                window_30 <= buffer[gray_y_out % 4][gray_x_out-3];
                window_31 <= buffer[gray_y_out % 4][gray_x_out-2];
                window_32 <= buffer[gray_y_out % 4][gray_x_out-1];
                window_33 <= gray_data_out;
                pool_valid_in <= 'b1;
            end 
            else begin
                pool_valid_in <= 'b0;
            end
        end 
        else begin
            pool_valid_in <= 'b0;
        end
    end
end

avrg_pool_4x4 u_avrg_pool_4x4(
	.clk                    (clk),
	.rst_n                  (rst_n),
    .avrg_pool_valid_in   	(pool_valid_in),
	.avrg_pool_data_in_00 	(window_00),
	.avrg_pool_data_in_01 	(window_01),
	.avrg_pool_data_in_02 	(window_02),
	.avrg_pool_data_in_03 	(window_03),
	.avrg_pool_data_in_10 	(window_10),
	.avrg_pool_data_in_11 	(window_11),
	.avrg_pool_data_in_12 	(window_12),
	.avrg_pool_data_in_13 	(window_13),
	.avrg_pool_data_in_20 	(window_20),
	.avrg_pool_data_in_21 	(window_21),
	.avrg_pool_data_in_22 	(window_22),
	.avrg_pool_data_in_23 	(window_23),
	.avrg_pool_data_in_30 	(window_30),
	.avrg_pool_data_in_31 	(window_31),
	.avrg_pool_data_in_32 	(window_32),
	.avrg_pool_data_in_33 	(window_33),
    .avrg_pool_addr_out     (pool_addr_out),
	.avrg_pool_valid_out  	(pool_valid_out),
	.avrg_pool_data_out   	(pool_data_out),
    .cnn_start              (cnn_start)
);



endmodule 
