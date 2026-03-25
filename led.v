module led(
    input   wire            clk,
    input   wire            rst_n,
    input   wire            done,
    input   wire    [3:0]   num,
    output  wire    [3:0]   led_display
);

reg [3:0] led;
always @(posedge clk) begin
    if(!rst_n)begin
        led <= 'd0;
    end
    else if(done)begin
        led <= num;
    end
end

assign led_display = led;

endmodule