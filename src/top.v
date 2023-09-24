
module top
#(
  parameter STARTUP_WAIT = 32'd10000000
)
(
    input wire clk,
    output wire ioSclk,
    output wire ioSdin,
    output wire ioCs,
    output wire ioDc,
    output wire ioReset,
    output wire sdClk,
    output wire sdMosi,
    input wire sdMiso,
    output wire sdCs,
    input wire btn1,
    input wire btn2,
    input uart_rx,
    output uart_tx,
    output reg [5:0] led
);
    wire [9:0] pixelAddress;
    wire [7:0] textPixelData;
    wire [5:0] charAddress;
    reg [7:0] charOutput = "A";

    screen #(STARTUP_WAIT) scr(
        clk, 
        ioSclk, 
        ioSdin, 
        ioCs, 
        ioDc, 
        ioReset, 
        pixelAddress,
        textPixelData
    );

    textEngine te(
        clk,
        pixelAddress,
        textPixelData,
        charAddress,
        charOutput
    );

    wire [7:0] sdCharOutput;

    sdcard sdcard(
        clk,
        sdClk,
        sdMosi,
        sdMiso,
        sdCs,
        charAddress[4:0],
        sdCharOutput,
        uart_rx,
        uart_tx,
        led,
        btn1 ? 1'b1 : 1'b0,
        btn2 ? 1'b1 : 1'b0
    );

    always @(posedge clk) begin
        case (charAddress[5:4])
            2'b00: charOutput <= sdCharOutput; 
            2'b01: charOutput <= sdCharOutput; 
            default: charOutput <= " ";
        endcase
    end
endmodule
