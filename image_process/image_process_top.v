module image_process_top#(
    parameter H_PIXEL = 640, 
    parameter V_PIXEL = 480,                 
    parameter PRE_IMG_WIDTH = 112,
    parameter PRE_IMG_HEIGHT = 112,
    parameter PRE_IMG_DATA_WIDTH = 16,
    parameter IMG_WIDTH = 28,
    parameter IMG_HEIGHT = 28,
    parameter IMG_DATA_WIDTH = 8
)(
    input   wire                                clk,
    input   wire                                rst_n,
    input   wire   [11:0]                       rgb_x_in,
    input   wire   [11:0]                       rgb_y_in,
    input   wire   [PRE_IMG_DATA_WIDTH-1:0]     rgb_data_in,
    input   wire                                rgb_valid_in,
    output  wire                                cnn_done,
    output  wire   [3:0]                        num
);

wire [IMG_DATA_WIDTH-1:0]     	pool_data_out;
wire                          	pool_valid_out;
wire [9:0]                    	pool_addr_out;
wire                            cnn_start;
pre_process u_pre_process(
	.clk            	(clk),
	.rst_n          	(rst_n),
	.rgb_x_in       	(rgb_x_in),
	.rgb_y_in       	(rgb_y_in),
	.rgb_data_in    	(rgb_data_in),
	.rgb_valid_in   	(rgb_valid_in),
	.pool_data_out  	(pool_data_out),
	.pool_valid_out 	(pool_valid_out),
	.pool_addr_out     	(pool_addr_out),
    .cnn_start          (cnn_start)
);

wire [IMG_DATA_WIDTH-1:0] 	pred_confidence;

cnn_top u_cnn_top(
	.clk             	(clk),
	.rst             	(!rst_n),
	.start           	(cnn_start),
	.pixel_data      	(pool_data_out),
	.pixel_valid     	(pool_valid_out),
	.pixel_addr      	(pool_addr_out),
	.done            	(cnn_done),
	.pred_digit      	(num),
	.pred_confidence 	(pred_confidence)
);

endmodule