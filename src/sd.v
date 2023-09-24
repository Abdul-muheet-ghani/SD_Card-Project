module top_module (
    input wire clk,
    input wire miso, 
    output wire mosi, 
    output wire sck,
    output wire cs
);

    // Inputs for the SPI module
    wire [7:0] data_read;

    reg enable = 0;
    reg [1:0] cmd_index = 0;
    reg highspeed = 0;
    reg [7:0] data_out = 0;
    reg [7:0] data_read_buf = 0;
    wire cmd_done;

    // Instantiate the SPI module
    spi_module my_spi (
        .clk(clk),
        .enable(enable),
        .highspeed(highspeed),
        .cmd_index(cmd_index),
        .miso(miso),
        .mosi(mosi),
        .cs(cs),
        .sck(sck),
        .data_out(data_out),
        .data_read(data_read),
        .cmd_done(cmd_done)
    );

    localparam STATE_INIT = 0;
    localparam STATE_SEND_CLOCK_PULSES = 1;
    localparam STATE_SEND_CMD0 = 2;
    localparam STATE_SEND_CMD8 = 3;
    localparam STATE_SEND_CMD55 = 4;
    localparam STATE_SEND_CMD41 = 5;
    localparam STATE_SEND_CMD58 = 6;
    localparam STATE_SEND_SD_COMMAND = 7;
    localparam STATE_WAIT_FOR_START = 8;
    localparam STATE_WAIT_FOR_COMPLETE = 9;
    localparam STATE_WAIT_FOR_RESPONSE = 10;

    reg [3:0] state = STATE_INIT;
    reg [3:0] returnState = STATE_INIT;
    reg [3:0] sdReturnState = STATE_INIT;
    reg [47:0] sdCommandToSend = 48'h000000000000;
    reg [2:0] byteCounter = 0;

    reg [7:0] dummyClocksCounter = 0;

    // Example control logic (customize as needed)
    always @(posedge clk) begin
        case (state)
            STATE_INIT: begin
                highspeed <= 1'b0;
                cmd_index <= 2'b00;
                state <= STATE_WAIT_FOR_START;
                returnState <= STATE_SEND_CLOCK_PULSES;
            end
            STATE_SEND_CLOCK_PULSES: begin
                dummyClocksCounter <= dummyClocksCounter + 1;
                if (dummyClocksCounter > 100) begin
                    cmd_index <= 2'b01;
                    returnState <= STATE_SEND_CMD0;
                end else begin
                    cmd_index <= 2'b10;
                    returnState <= STATE_SEND_CLOCK_PULSES;
                end
                data_out <= 8'hFF;
                state <= STATE_WAIT_FOR_START;
            end
            STATE_SEND_CMD0: begin
                sdCommandToSend <= 48'h400000000000;
                sdReturnState <= STATE_SEND_CMD8;
                returnState <= STATE_SEND_SD_COMMAND;
                state <= STATE_WAIT_FOR_START;
                cmd_index <= 2'b01;
            end
            STATE_SEND_SD_COMMAND: begin
                byteCounter <= byteCounter + 1;
                cmd_index <= 2'b10;
                if (byteCounter == 6) begin
                    data_out <= 8'hFF;
                    byteCounter <= 0;
                    state <= STATE_WAIT_FOR_START;
                    returnState <= STATE_WAIT_FOR_RESPONSE;
                end else begin
                    data_out <= sdCommandToSend[byteCounter * 8 +: 8];
                    state <= STATE_WAIT_FOR_START;
                    returnState <= STATE_SEND_SD_COMMAND;
                end
            end
            STATE_WAIT_FOR_RESPONSE: begin
                if (data_read_buf[0] == 1'h1) begin
                    returnState <= sdReturnState;
                    cmd_index <= 2'b01;
                end else begin
                    data_out <= 8'hFF;
                    cmd_index <= 2'b10;
                end
                state <= STATE_WAIT_FOR_START;
            end
            STATE_WAIT_FOR_START: begin
                enable <= 1'b1;
                if (~cmd_done) begin
                    state <= STATE_WAIT_FOR_COMPLETE;
                end
            end
            STATE_WAIT_FOR_COMPLETE: begin
                if (cmd_done) begin
                    state <= returnState;
                end
            end
        endcase
    end
endmodule
