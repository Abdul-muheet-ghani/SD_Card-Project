module spi_module (
    input wire clk,
    input wire enable,
    input wire highspeed,
    input wire [1:0] cmd_index,
    input wire miso,
    output reg mosi = 1'b0,
    output reg cs = 1'b1,
    output reg sck = 1'b0,
    input wire [7:0] data_out,
    output reg [7:0] data_read,
    output reg cmd_done = 1'b0
);

    // Internal state encoding
    localparam IDLE = 3'b000, START = 3'b001, STOP = 3'b010, TRANSFER = 3'b011, DONE = 3'b100;
    reg [2:0] state = IDLE;
    
    // Internal registers
    reg [3:0] bit_counter = 4'b0;
    reg [7:0] data_out_reg = 8'b0;

    // Clock divider logic
    reg [6:0] clk_div_counter = 7'b0;
    reg spi_clk_reg = 1'b0;

    always @(posedge clk) begin
        if (highspeed) begin
            clk_div_counter <= 7'b0;
            spi_clk_reg <= clk;
        end else begin
            if (clk_div_counter < 80 - 1) begin
                clk_div_counter <= clk_div_counter + 1;
            end else begin
                clk_div_counter <= 7'b0;
                spi_clk_reg <= ~spi_clk_reg;
            end
        end
    end

    always @(posedge spi_clk_reg) begin
        case (state)
            IDLE: begin
                if (enable) begin
                    cmd_done <= 1'b0;
                    sck <= 1'b0; // Set SCK low in IDLE state
                    state <= cmd_index + 1;
                    bit_counter <= 4'h8;
                    data_out_reg <= data_out;
                end
            end
            START: begin
                cs <= 1'b0; // Set CS low
                state <= DONE;
            end
            STOP: begin
                cs <= 1'b1; // Set CS high
                state <= DONE;
            end
            TRANSFER: begin
                if (bit_counter == 4'h0) begin
                    state <= DONE;
                end else begin
                    if (~sck) begin
                        // Write on falling edge of SCK
                        mosi <= data_out_reg[7];
                        data_out_reg <= {data_out_reg[6:0], 1'b0};
                    end else begin
                        // Read on rising edge of SCK
                        data_read <= {data_read[6:0], miso};
                        bit_counter <= bit_counter - 1;
                    end
                    sck <= ~sck; // Toggle SCK during TRANSFER state
                end
            end
            DONE: begin
                cmd_done <= 1'b1;
                if (!enable) begin
                    state <= IDLE;
                end
            end
            default: begin
                state <= IDLE;
            end
        endcase
    end
endmodule
