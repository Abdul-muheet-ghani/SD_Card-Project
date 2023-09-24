
localparam STATE_INIT = 0;
localparam STATE_RESET_CMD = 1;
localparam STATE_SEND_BYTES = 2;
localparam STATE_SEND_BYTES_DATA = 3;
localparam STATE_WAIT_FOR_RECV = 4;
localparam STATE_READ_DATA = 5;
localparam STATE_INIT_CMD = 6;
localparam STATE_CHECK_VERSION = 7;
localparam STATE_APP_COMMAND = 8;
localparam STATE_SEND_SD_START = 9;
localparam STATE_CHECK_INIT = 10;
localparam STATE_SEND_READ_BLOCK = 11;
localparam STATE_SET_BLOCK_LENGTH = 12;
localparam STATE_WRITE_DATA = 13;
localparam STATE_WRITE_DATA_BLOCK = 14;
localparam STATE_CHECK_READ_RESP = 15;
localparam STATE_WAIT_FOR_DATABLOCK = 16;
localparam STATE_READ_BLOCK = 17;
localparam STATE_DATA_READY = 18;
localparam STATE_ERROR = 19;
module toHex(
    input wire clk,
    input wire [3:0] value,
    output reg [7:0] hexChar = "0"
);
    always @(posedge clk) begin
        case (value)
            4'd0: hexChar <= "0"; 
            4'd1: hexChar <= "1"; 
            4'd2: hexChar <= "2"; 
            4'd3: hexChar <= "3"; 
            4'd4: hexChar <= "4"; 
            4'd5: hexChar <= "5"; 
            4'd6: hexChar <= "6"; 
            4'd7: hexChar <= "7"; 
            4'd8: hexChar <= "8"; 
            4'd9: hexChar <= "9"; 
            4'd10: hexChar <= "A"; 
            4'd11: hexChar <= "B"; 
            4'd12: hexChar <= "C"; 
            4'd13: hexChar <= "D"; 
            4'd14: hexChar <= "E"; 
            4'd15: hexChar <= "F"; 
        endcase
    end
endmodule

module spiPhy(
    input wire clk,
    output reg sdClk = 0,
    output reg sdMosi = 1,
    input wire sdMiso,
    output reg sdCs = 1,
    input wire readWrite,
    output reg [7:0] dataOut = 0,
    output reg [7:0] dataIn = 0,
    input wire start,
    output reg ready = 1
);

localparam STATE_IDLE = 0;


reg highSpeed = 0;
reg [7:0] counter = 0;
reg [3:0] state = 0;
reg [7:0] divideCounter = 0;
reg opClk = 0;

reg [47:0] bytesToSend = 0;
reg [5:0] bitsToSend = 0;
reg [39:0] bytesReceived = 0;
reg [7:0] bitsToReceive = 0;

always @(posedge clk) begin
    if (divideCounter == highSpeed ? 8'd8 : 8'd68) begin
        divideCounter <= 0;
        opClk <= ~opClk;
    end
    else
        divideCounter <= divideCounter + 8'd1;
end

always @(posedge opClk) begin
    case (state)
        STATE_IDLE: begin
            sdCs <= 1;
            sdMosi <= 1;
            sdClk <= ~sdClk;
            if (counter == 8'd150) begin
                if (start) begin
                    counter <= 0;
                    state <= STATE_RESET_CMD;
                    ready <= 0;
                end
            end
            else begin
                counter <= counter + 8'd1;
            end
        end
        STATE_SEND_BYTES: begin
            if (counter >= 8'd16 && sdClk == 0) begin
                sdCs <= 0;
                counter <= 0;
                state <= STATE_SEND_BYTES_DATA;
            end
            else begin
                sdCs <= 1;
                sdMosi <= 1;
                sdClk <= counter[0];
                counter <= counter + 8'd1;
            end
        end
        STATE_SEND_BYTES_DATA: begin
            if (sdClk == 0) begin
                sdMosi <= bytesToSend[47];
                sdClk <= 1;
                bytesToSend <= {bytesToSend[46:0], 1'b0};
            end
            else begin
                sdClk <= 0;
                bitsToSend <= bitsToSend - 6'd1;
                if (bitsToSend == 6'd1) begin
                    state <= STATE_WAIT_FOR_RECV;
                    counter <= 0;
                end
            end
        end
        STATE_WAIT_FOR_RECV: begin
            sdMosi <= 1;
            counter <= counter + 8'd1;
            if (counter[6]) begin
                state <= errorReturnState;
            end
            else 
            if (sdMiso == 0 && sdClk == 0) begin
                state <= STATE_READ_DATA;
                counter <= 8'd0;
            end else begin
                sdClk <= ~sdClk;
            end
        end
        STATE_READ_DATA: begin
            if (sdClk == 0) begin 
                sdClk <= 1;
            end
            else begin
                bytesReceived <= {bytesReceived[38:0], sdMiso};
                sdClk <= 0;
                bitsToReceive <= bitsToReceive - 8'd1;
                if (bitsToReceive == 8'd1) begin
                    state <= returnState;
                end
            end
        end
    endcase
end

endmodule

module sdcard(
    input wire clk,
    output reg sdClk = 0,
    output reg sdMosi = 1,
    input wire sdMiso,
    output reg sdCs = 1,
    input wire [4:0] charAddress,
    output reg [7:0] charOutput = "S",
    input uart_rx,
    output uart_tx,
    output reg [5:0] led,
    input wire btn1,
    input wire btn2
);



reg [5:0] state = 0;
reg [5:0] returnState = 0;
reg [5:0] errorReturnState = STATE_ERROR;
reg [47:0] bytesToSend = 0;
reg [5:0] bitsToSend = 0;
reg [39:0] bytesReceived = 0;
reg [7:0] bitsToReceive = 0;
reg [7:0] counter = 0;
reg [8:0] counter_data_send;

reg [6:0] byteNumber = 0;
reg [6:0] addressStepper = 0;
reg [31:0] memory1[127:0];// [0:15];

integer  i;
initial begin
    for (i = 0; i < 128; i = i + 1) begin
        memory1[i] = 32'd0;
    end
end

always @(posedge clk)begin 
    testMemory[0] <= memory1[0][7:0];
    testMemory[1] <= memory1[1][7:0];
    testMemory[2] <= memory1[2][7:0];
    testMemory[3] <= memory1[3][7:0];
    testMemory[4] <= memory1[4][7:0];
    testMemory[5] <= memory1[5][7:0];
    testMemory[6] <= memory1[6][7:0];
    testMemory[7] <= memory1[7][7:0];
    testMemory[8] <= memory1[8][7:0];
    testMemory[9] <= memory1[9][7:0];
    testMemory[10] <=memory1[10][7:0];
    testMemory[11] <=memory1[11][7:0];
end

always @(posedge clk) begin
    if (~btn1) begin
        state <= STATE_INIT;
        counter <= 0;
    end else begin
        case (state)
            STATE_INIT: begin
                sdCs <= 1;
                sdMosi <= 1;
                errorReturnState <= STATE_ERROR;
                sdClk <= ~sdClk;
                if (counter == 8'hFF) begin
                    counter <= 0;
                    state <= STATE_RESET_CMD;
                end
                else begin
                    counter <= counter + 8'd1;
                end
            end 
            STATE_RESET_CMD: begin
                bytesToSend <= {
                    8'h40, // CMD0 init
                    32'h00000000, // no arg
                    8'h95  // CRC
                };
                bitsToSend <= 6'd48;
                state <= STATE_SEND_BYTES;
                // sdCs <= 0;
                sdClk <= 0;
                counter <= 0;
                returnState <= STATE_INIT_CMD;
                bitsToReceive <= 8'd8;
            end
            STATE_SEND_BYTES: begin
                if (counter >= 8'd16 && sdClk == 0) begin
                    sdCs <= 0;
                    counter <= 0;
                    state <= STATE_SEND_BYTES_DATA;
                end
                else begin
                    sdCs <= 1;
                    sdMosi <= 1;
                    sdClk <= counter[0];
                    counter <= counter + 8'd1;
                end
            end
            STATE_SEND_BYTES_DATA: begin
                if (sdClk == 0) begin
                    sdMosi <= bytesToSend[47];
                    sdClk <= 1;
                    bytesToSend <= {bytesToSend[46:0], 1'b0};
                end
                else begin
                    sdClk <= 0;
                    bitsToSend <= bitsToSend - 6'd1;
                    if (bitsToSend == 6'd1) begin
                        state <= STATE_WAIT_FOR_RECV;
                        counter <= 0;
                    end
                end
            end
            STATE_WAIT_FOR_RECV: begin
                sdMosi <= 1;
                counter <= counter + 8'd1;
                if (counter[6]) begin
                    state <= errorReturnState;
                end
                else 
                if (sdMiso == 0 && sdClk == 0) begin
                    state <= STATE_READ_DATA;
                    counter <= 8'd0;
                end else begin
                    sdClk <= ~sdClk;
                end
            end
            STATE_READ_DATA: begin
                if (sdClk == 0) begin 
                    sdClk <= 1;
                end
                else begin
                    bytesReceived <= {bytesReceived[38:0], sdMiso};
                    sdClk <= 0;
                    bitsToReceive <= bitsToReceive - 8'd1;
                    if (bitsToReceive == 8'd1) begin
                        state <= returnState;
                    end
                end
            end
            STATE_INIT_CMD: begin
                counter <= 0;
                if (bytesReceived[7:0] == 8'd1) begin
                    bytesToSend <= {
                        8'h48, // CMD8 init
                        20'h00000, // reserved
                        4'b0001, // 2.7 - 3.6 V
                        8'b10101010, // check pattern
                        8'h87  // CRC
                    };
                    bitsToSend <= 6'd48;
                    state <= STATE_SEND_BYTES;
                    // sdCs <= 0;
                    sdClk <= 0;
                    returnState <= STATE_CHECK_VERSION;
                    bitsToReceive <= 8'd40;
                end
                else begin
                    state <= STATE_INIT;
                end
            end
            STATE_CHECK_VERSION: begin
                if (bytesReceived[39:32] == 8'd1) begin
                    state <= STATE_APP_COMMAND;
                end
            end
            STATE_APP_COMMAND: begin
                bytesToSend <= {
                    8'h77, // CMD55 init
                    32'h00000000, // reserved
                    8'h01  // CRC
                };
                bitsToSend <= 6'd48;
                state <= STATE_SEND_BYTES;
                sdClk <= 0;
                returnState <= STATE_SEND_SD_START;
                bitsToReceive <= 8'd8;
            end
            STATE_SEND_SD_START: begin
                if (bytesReceived[7:0] == 8'd1) begin
                    bytesToSend <= {
                        8'h69, // CMD41 init
                        32'h40000000, // reserved
                        8'h01  // CRC
                    };
                    bitsToSend <= 6'd48;
                    state <= STATE_SEND_BYTES;
                    sdClk <= 0;
                    returnState <= STATE_CHECK_INIT;
                    bitsToReceive <= 8'd8;
                end
            end
            STATE_CHECK_INIT: begin
                if (bytesReceived[7:0] == 8'd0) begin
                    state <= STATE_SET_BLOCK_LENGTH;
                end
                else if (bytesReceived[7:0] == 8'd1) begin
                    state <= STATE_APP_COMMAND;
                end
            end
            STATE_SET_BLOCK_LENGTH: begin
                bytesToSend <= {
                    8'h50, // CMD16 set write block
                    32'h00000200, // address 0
                    8'h00  // CRC
                };
                bitsToSend <= 6'd48;
                state <= STATE_SEND_BYTES;
                sdClk <= 0;
                returnState <= STATE_WRITE_DATA;
                bitsToReceive <= 8'd8;
                byteNumber <= 0;
            end
            STATE_WRITE_DATA: begin
                bytesToSend <= {
                    8'h58, // CMD24 write block
                    32'h00000000, // address 0
                    8'h00  // CRC
                };
                bitsToSend <= 6'd48;
                state <= STATE_SEND_BYTES;
                sdClk <= 0;
                returnState <= STATE_WRITE_DATA_BLOCK;
                bitsToReceive <= 8'd8;
                byteNumber <= 0;
            end
            STATE_WRITE_DATA_BLOCK: begin
                if(counter_data_send == 0 || counter_data_send == 513) begin
                    bytesToSend <= {
                        8'hFE // key token
                    };
                    bitsToSend <= 6'd8;
                    state <= STATE_WRITE_DATA_BLOCK;
                    sdClk <= 0;
                end
                else if(counter_data_send > 0 && counter_data_send < 512)begin
                    bytesToSend <= {
                        8'h61 // key token
                    };
                    bitsToSend <= 6'd8;
                    state <= STATE_WRITE_DATA_BLOCK;
                    sdClk <= 0;
                end
                else begin
                    returnState <= STATE_SEND_READ_BLOCK;
                    bitsToReceive <= 8'd8;
                    byteNumber <= 0; 
                    counter_data_send = 0;
                end
                counter_data_send = counter_data_send + 1;
            end
            STATE_SEND_READ_BLOCK: begin
                bytesToSend <= {
                    8'h51, // CMD17 read block
                    32'h00000000, // address 0
                    8'h01  // CRC
                };
                bitsToSend <= 6'd48;
                state <= STATE_SEND_BYTES;
                sdClk <= 0;
                returnState <= STATE_CHECK_READ_RESP;
                bitsToReceive <= 8'd8;
                byteNumber <= 0;
            end 
            STATE_CHECK_READ_RESP: begin
                if (bytesReceived[7:0] == 8'd0) begin
                    state <= STATE_WAIT_FOR_DATABLOCK;
                end
            end
            STATE_WAIT_FOR_DATABLOCK: begin
                state <= STATE_READ_DATA;
                if (bytesReceived[7:0] == 8'b11111110) begin
                    returnState <= STATE_READ_BLOCK;
                    byteNumber <= 0;
                    bitsToReceive <= 8'd32;
                end else begin
                    returnState <= STATE_WAIT_FOR_DATABLOCK;
                    bitsToReceive <= 8'd8;
                end
            end
            STATE_READ_BLOCK: begin
                memory1[byteNumber] <= bytesReceived[31:0];
                if (byteNumber == 7'd127) begin
                    //CRC
                    returnState <= STATE_DATA_READY;
                    bitsToReceive <= 8'd16;
                    state <= STATE_READ_DATA;
                end
                else begin
                    returnState <= STATE_READ_BLOCK;
                    byteNumber <= byteNumber + 7'd1;
                    bitsToReceive <= 8'd32;
                    state <= STATE_READ_DATA;
                end
            end
            STATE_DATA_READY: begin
                byteNumber <= 0;
            end
        endcase   
    end 
end

reg [7:0] byteToShow = 0;
reg lastBtnPress = 0;
wire [7:0] char2;
reg [31:0] dataBuffer = 0;
toHex t2(clk, charAddress[0] ? byteToShow[3:0] : byteToShow[7:4], char2);

always @(posedge clk) begin
    if (~btn2 && lastBtnPress) begin
        addressStepper <= addressStepper + 7'd1;
    end
    lastBtnPress <= btn2;
    if (state == STATE_ERROR) begin
        case (charAddress[3:0])
            4'd0: charOutput <= "S";
            4'd1: charOutput <= "D";
            4'd3: charOutput <= "E";
            4'd4: charOutput <= "R";
            4'd5: charOutput <= "R";
            4'd6: charOutput <= "O";
            4'd7: charOutput <= "R";
            default: charOutput <= " ";
        endcase
    end
    else if (state == STATE_DATA_READY) begin
        dataBuffer <= memory1[addressStepper[6:0]];
        if (charAddress[4]) begin
            case (charAddress[3:0])
                4'd0: charOutput <= "b";
                4'd1: charOutput <= addressStepper[6] ? "1" : "0";
                4'd2: charOutput <= addressStepper[5] ? "1" : "0";
                4'd3: charOutput <= addressStepper[4] ? "1" : "0";
                4'd4: charOutput <= addressStepper[3] ? "1" : "0";
                4'd5: charOutput <= addressStepper[2] ? "1" : "0";
                4'd6: charOutput <= addressStepper[1] ? "1" : "0";
                4'd7: charOutput <= addressStepper[0] ? "1" : "0";
                default: charOutput <= " ";
            endcase
        end else begin
            case (charAddress[3:0])
                4'd0: charOutput <= ~btn2 ? "B" : "D";
                4'd1: charOutput <= "a";
                4'd2: charOutput <= "t";
                4'd3: charOutput <= "a";
                4'd4: charOutput <= ":";
                4'd5: charOutput <= " ";
                4'd6,
                4'd7: begin
                    byteToShow <= dataBuffer[24+:8];
                    charOutput <= char2;
                end
                4'd8,
                4'd9: begin
                    byteToShow <= dataBuffer[16+:8];
                    charOutput <= char2;
                end
                4'd10,
                4'd11: begin
                    byteToShow <= dataBuffer[8+:8];
                    charOutput <= char2;
                end
                4'd12,
                4'd13: begin
                    byteToShow <= dataBuffer[0+:8];
                    charOutput <= char2;
                end

                default: charOutput <= " ";
            endcase
        end
    end
    else begin
        case (charAddress[3:0])
            4'd0: charOutput <= "S";
            4'd1: charOutput <= state[5] ? "1" : "0";
            4'd2: charOutput <= state[4] ? "1" : "0";
            4'd3: charOutput <= state[3] ? "1" : "0";
            4'd4: charOutput <= state[2] ? "1" : "0";
            4'd5: charOutput <= state[1] ? "1" : "0";
            4'd6: charOutput <= state[0] ? "1" : "0";
            default: charOutput <= " ";
        endcase
    end
end

/////////////////////////////////////////////////////////////

localparam DELAY_FRAMES = 234;
localparam HALF_DELAY_WAIT = (DELAY_FRAMES / 2);

reg [3:0] rxState = 0;
reg [12:0] rxCounter = 0;
reg [7:0] dataIn = 0;
reg [2:0] rxBitNumber = 0;
reg byteReady = 0;

localparam RX_STATE_IDLE = 0;
localparam RX_STATE_START_BIT = 1;
localparam RX_STATE_READ_WAIT = 2;
localparam RX_STATE_READ = 3;
localparam RX_STATE_STOP_BIT = 5;

always @(posedge clk) begin
    case (rxState)
        RX_STATE_IDLE: begin
            if (uart_rx == 0) begin
                rxState <= RX_STATE_START_BIT;
                rxCounter <= 1;
                rxBitNumber <= 0;
                byteReady <= 0;
            end
        end 
        RX_STATE_START_BIT: begin
            if (rxCounter == HALF_DELAY_WAIT) begin
                rxState <= RX_STATE_READ_WAIT;
                rxCounter <= 1;
            end else 
                rxCounter <= rxCounter + 1;
        end
        RX_STATE_READ_WAIT: begin
            rxCounter <= rxCounter + 1;
            if ((rxCounter + 1) == DELAY_FRAMES) begin
                rxState <= RX_STATE_READ;
            end
        end
        RX_STATE_READ: begin
            rxCounter <= 1;
            dataIn <= {uart_rx, dataIn[7:1]};
            rxBitNumber <= rxBitNumber + 1;
            if (rxBitNumber == 3'b111)
                rxState <= RX_STATE_STOP_BIT;
            else
                rxState <= RX_STATE_READ_WAIT;
        end
        RX_STATE_STOP_BIT: begin
            rxCounter <= rxCounter + 1;
            if ((rxCounter + 1) == DELAY_FRAMES) begin
                rxState <= RX_STATE_IDLE;
                rxCounter <= 0;
                byteReady <= 1;
            end
        end
    endcase
end

always @(posedge clk) begin
    if (byteReady) begin
        led <= ~dataIn[5:0];
    end
end

reg [3:0] txState = 0;
reg [24:0] txCounter = 0;
reg [7:0] dataOut = 0;
reg txPinRegister = 1;
reg [2:0] txBitNumber = 0;
reg [3:0] txByteCounter = 0;

assign uart_tx = txPinRegister;

localparam MEMORY_LENGTH = 12;
reg [7:0] testMemory [MEMORY_LENGTH-1:0];

localparam TX_STATE_IDLE = 0;
localparam TX_STATE_START_BIT = 1;
localparam TX_STATE_WRITE = 2;
localparam TX_STATE_STOP_BIT = 3;
localparam TX_STATE_DEBOUNCE = 4;

always @(posedge clk) begin
    case (txState)
        TX_STATE_IDLE: begin
            if (btn1 == 0) begin
                txState <= TX_STATE_START_BIT;
                txCounter <= 0;
                txByteCounter <= 0;
            end
            else begin
                txPinRegister <= 1;
            end
        end 
        TX_STATE_START_BIT: begin
            txPinRegister <= 0;
            if ((txCounter + 1) == DELAY_FRAMES) begin
                txState <= TX_STATE_WRITE;
                dataOut <= testMemory[txByteCounter];
                txBitNumber <= 0;
                txCounter <= 0;
            end else 
                txCounter <= txCounter + 1;
        end
        TX_STATE_WRITE: begin
            txPinRegister <= dataOut[txBitNumber];
            if ((txCounter + 1) == DELAY_FRAMES) begin
                if (txBitNumber == 3'b111) begin
                    txState <= TX_STATE_STOP_BIT;
                end else begin
                    txState <= TX_STATE_WRITE;
                    txBitNumber <= txBitNumber + 1;
                end
                txCounter <= 0;
            end else 
                txCounter <= txCounter + 1;
        end
        TX_STATE_STOP_BIT: begin
            txPinRegister <= 1;
            if ((txCounter + 1) == DELAY_FRAMES) begin
                if (txByteCounter == MEMORY_LENGTH - 1) begin
                    txState <= TX_STATE_DEBOUNCE;
                end else begin
                    txByteCounter <= txByteCounter + 1;
                    txState <= TX_STATE_START_BIT;
                end
                txCounter <= 0;
            end else 
                txCounter <= txCounter + 1;
        end
        TX_STATE_DEBOUNCE: begin
            if (txCounter == 23'b111111111111111111) begin
                if (btn1 == 1) 
                    txState <= TX_STATE_IDLE;
            end else
                txCounter <= txCounter + 1;
        end
    endcase      
end
endmodule
