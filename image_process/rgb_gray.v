module rgb_gray #(
    parameter PRE_IMG_DATA_WIDTH = 16,
    parameter IMG_DATA_WIDTH = 8,
    parameter PRE_IMG_WIDTH = 112,
    parameter PRE_IMG_HEIGHT = 112
)(
    input   wire                                clk,
    input   wire                                rst_n,
    input   wire                                rgb_valid_in,
    input   wire    [PRE_IMG_DATA_WIDTH:0]      rgb_data_in,
    output  wire                                gray_valid_out,
    output  wire    [6:0]                       gray_x_out,
    output  wire    [6:0]                       gray_y_out,
    output  wire    [IMG_DATA_WIDTH-1:0]        gray_data_out
);

reg         valid_s1;
reg [7:0]   r8_s1;
reg [7:0]   g8_s1;
reg [7:0]   b8_s1;
reg         valid_s2;
reg [15:0]  r_mul_s2;
reg [15:0]  g_mul_s2;
reg [15:0]  b_mul_s2;
reg         valid_s3;
reg [6:0]   gray_s3;
always @(posedge clk) begin
    if (!rst_n) begin
        valid_s1 <= 'b0;
        r8_s1 <= 'd0;
        g8_s1 <= 'd0;
        b8_s1 <= 'd0;
        valid_s2 <= 'b0;
        r_mul_s2 <= 'd0;
        g_mul_s2 <= 'd0;
        b_mul_s2 <= 'd0;
        valid_s3 <= 'b0;
        gray_s3 <= 'd0;
    end else begin
        // s1: RGB565 -> RGB888 (bit expansion)
        valid_s1 <= rgb_valid_in;
        if (rgb_valid_in) begin
            r8_s1 <= {rgb_data_in[15:11], rgb_data_in[15:13]};
            g8_s1 <= {rgb_data_in[10:5],  rgb_data_in[10:9]};
            b8_s1 <= {rgb_data_in[4:0],   rgb_data_in[4:2]};
        end
        // s2: weighted multiply (Gray = 0.299R + 0.587G + 0.114B)
        valid_s2 <= valid_s1;
        if (valid_s1) begin
            r_mul_s2 <= r8_s1 * 'd77;
            g_mul_s2 <= g8_s1 * 'd150;
            b_mul_s2 <= b8_s1 * 'd29;
        end
        // s3: add and divide by 256, with rounding
        valid_s3 <= valid_s2;
        if (valid_s2) begin
            gray_s3 <= (r_mul_s2 + g_mul_s2 + b_mul_s2 + 'd128) >> 'd9;
        end
    end
end

reg     [6:0]       gray_x;
reg     [6:0]       gray_y;

always @(posedge clk) begin
    if(!rst_n)begin
        gray_x <= 'd0;
    end
    else if(gray_x == PRE_IMG_WIDTH-1)begin
        gray_x <= 'd0;
    end
    else if(valid_s2)begin
        gray_x <= gray_x + 'd1;
    end
end

always @(posedge clk) begin
    if(!rst_n)begin
        gray_y <= 'd0;
    end
    else if((gray_y == PRE_IMG_HEIGHT-1)&&(gray_x == PRE_IMG_WIDTH-1))begin
        gray_y <= 'd0;
    end
    else if(gray_x == PRE_IMG_WIDTH-1)begin
        gray_y <= gray_y + 'd1;
    end
end

assign gray_valid_out = valid_s3;
assign gray_data_out = {1'b0,gray_s3};

assign gray_x_out = gray_x;
assign gray_y_out = gray_y;


endmodule
