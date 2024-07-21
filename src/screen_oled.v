`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/18/2024 12:01:21 AM
// Design Name: 
// Module Name: screen_oled
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module screen_oled(
    input clk,
    input btnR, // CPU Reset Button turns the display on and off
    input btnC, // Center DPad Button turns every pixel on the display on or resets to previous state
    input btnD, // Upper DPad Button updates the delay to the contents of the local memory
    input btnU, // Bottom DPad Button clears the display
    output oled_sdin,
    output oled_sclk,
    output oled_dc,
    output oled_res,
    output oled_vbat,
    output oled_vdd,
    // output oled_cs, // used in Pmod OLED implementation
    output [7:0] led,
    // New string inputs
    input [127:0] str1,
    input [127:0] str2,
    input [127:0] str3,
    input [127:0] str4
);
    // State machine codes
    localparam Idle       = 0;
    localparam Init       = 1;
    localparam Active     = 2;
    localparam Done       = 3;
    localparam FullDisp   = 4;
    localparam Write      = 5;
    localparam WriteWait  = 6;
    localparam UpdateWait = 7;

    // Lengths of the strings
    localparam str1len = 16;
    localparam str2len = 16;
    localparam str3len = 16;
    localparam str4len = 16;
    
    localparam AUTO_START = 1; // determines whether the OLED will be automatically initialized when the board is programmed

    // State machine registers.
    reg [2:0] state = (AUTO_START == 1) ? Init : Idle;
    reg [5:0] count = 0; // loop index variable
    reg once = 0; // bool to see if we have set up local pixel memory in this session

    // OLED control signals
    // Command start signals, assert high to start command
    reg update_start = 0; // update OLED display over SPI
    reg disp_on_start = AUTO_START; // turn the OLED display on
    reg disp_off_start = 0; // turn the OLED display off
    reg toggle_disp_start = 0; // turns on every pixel on the OLED, or returns the display to before each pixel was turned on
    reg write_start = 0; // writes a character bitmap into local memory
    // Data signals for OLED controls
    reg update_clear = 0; // when asserted high, an update command clears the display, instead of filling from memory
    reg [8:0] write_base_addr = 0; // location to write character to, two most significant bits are row position, 0 is topmost. bottom seven bits are X position, addressed by pixel x position.
    reg [7:0] write_ascii_data = 0; // ASCII value of character to write to memory
    // Active high command ready signals, appropriate start commands are ignored when these are not asserted high
    
    reg [127:0] str_1, str_2, str_3, str_4;
    
    reg refresh = 1;
    reg count_update = 0;
    
    wire disp_on_ready;
    wire disp_off_ready;
    wire toggle_disp_ready;
    wire update_ready;
    wire write_ready;

    // Debounced button signals used for state transitions
    wire rst; // CPU RESET BUTTON turns the display on and off, on display_on, local memory is filled from string parameters
    wire dBtnC; // Center DPad Button tied to toggle_disp command 
    wire dBtnU; // Upper DPad Button tied to update without clear
    wire dBtnD; // Bottom DPad Button tied to update with clear
    
    // Instantiate OLED controller
    OLEDCtrl m_OLEDCtrl (
        .clk                (clk),              
        .write_start        (write_start),      
        .write_ascii_data   (write_ascii_data), 
        .write_base_addr    (write_base_addr),  
        .write_ready        (write_ready),      
        .update_start       (update_start),     
        .update_ready       (update_ready),     
        .update_clear       (update_clear),    
        .disp_on_start      (disp_on_start),    
        .disp_on_ready      (disp_on_ready),    
        .disp_off_start     (disp_off_start),   
        .disp_off_ready     (disp_off_ready),   
        .toggle_disp_start  (toggle_disp_start),
        .toggle_disp_ready  (toggle_disp_ready),
        .SDIN               (oled_sdin),        
        .SCLK               (oled_sclk),        
        .DC                 (oled_dc),        
        .RES                (oled_res),        
        .VBAT               (oled_vbat),        
        .VDD                (oled_vdd)
    );
    // assign oled_cs = 1'b0;

    always @(write_base_addr)
        case (write_base_addr[8:7])//select string as [y]
        0: write_ascii_data <= 8'hff & (str_1 >> ({3'b0, (str1len - 1 - write_base_addr[6:3])} << 3));//index string parameters as str[x]
        1: write_ascii_data <= 8'hff & (str_2 >> ({3'b0, (str2len - 1 - write_base_addr[6:3])} << 3));
        2: write_ascii_data <= 8'hff & (str_3 >> ({3'b0, (str3len - 1 - write_base_addr[6:3])} << 3));
        3: write_ascii_data <= 8'hff & (str_4 >> ({3'b0, (str4len - 1 - write_base_addr[6:3])} << 3));
        endcase
        
    // Debouncers ensure single state machine loop per button press. noisy signals cause possibility of multiple "positive edges" per press.
    debouncer #(
        .COUNT_MAX(65535),
        .COUNT_WIDTH(16)
    ) get_dBtnC (
        .clk(clk),
        .A(btnC),
        .B(dBtnC)
    );
    debouncer #(
        .COUNT_MAX(65535),
        .COUNT_WIDTH(16)
    ) get_dBtnU (
        .clk(clk),
        .A(btnU),
        .B(dBtnU)
    );
    debouncer #(
        .COUNT_MAX(65535),
        .COUNT_WIDTH(16)
    ) get_dBtnD (
        .clk(clk),
        .A(btnD),
        .B(dBtnD)
    );
    debouncer #(
        .COUNT_MAX(65535),
        .COUNT_WIDTH(16)
    ) get_rst (
        .clk(clk),
        .A(btnR),
        .B(rst)
    );

    assign led = update_ready; // display whether btnU, BtnD controls are available
    assign init_done = disp_off_ready | toggle_disp_ready | write_ready | update_ready; // parse ready signals for clarity
    assign init_ready = disp_on_ready;
    //assign dBtnU = btnU;
   
    always @(posedge clk)
        case (state)
            Idle: begin
                if (rst == 1'b1 && init_ready == 1'b1) begin
                    disp_on_start <= 1'b1;
                    state <= Init;
                end
                once <= 0;
            end
            Init: begin
                disp_on_start <= 1'b0;
                if (rst == 1'b0 && init_done == 1'b1)
                    state <= Active;
            end
            Active: begin // hold until ready, then accept input
                str_1 <= str1;
                str_2 <= str2;
                str_3 <= str3;
                str_4 <= str4;
                if (rst && disp_off_ready) begin
                    disp_off_start <= 1'b1;
                    state <= Done;
                end else if (once == 0 && write_ready) begin
                    write_start <= 1'b1;
                    write_base_addr <= 'b0;
                    state <= WriteWait;
                end else if (once == 1 && dBtnU == 1) begin
                    once <= 0;
                    update_start <= 1'b1;
                    update_clear <= 1'b0;                    
                    state <= UpdateWait; 
                end else if (once == 1 && refresh == 1) begin
                    once <= 0;
                    update_start <= 1'b1;
                    update_clear <= 1'b0;                    
                    state <= UpdateWait;                    
                end else if (once == 1 && dBtnD == 1) begin
                    update_start <= 1'b1;
                    update_clear <= 1'b1;
                    state <= UpdateWait;
                end else if (dBtnC == 1'b1 && toggle_disp_ready == 1'b1) begin
                    toggle_disp_start <= 1'b1;
                    state <= FullDisp;
                end
            end
            Write: begin
                write_start <= 1'b1;
                write_base_addr <= write_base_addr + 9'h8;
                // write_ascii_data updated with write_base_addr
                state <= WriteWait;
            end
            WriteWait: begin
                write_start <= 1'b0;
                if (write_ready == 1'b1)
                    if (write_base_addr == 9'h1f8) begin
                        once <= 1;
                        state <= Active;
                    end else begin
                        state <= Write;
                    end
            end
            UpdateWait: begin
                update_start <= 0;
                if (dBtnU == 0 && init_done == 1'b1)
                    state <= Active;
            end
            Done: begin
                disp_off_start <= 1'b0;
                if (rst == 1'b0 && init_ready == 1'b1)
                    state <= Idle;
            end
            FullDisp: begin
                toggle_disp_start <= 1'b0;
                if (dBtnC == 1'b0 && init_done == 1'b1)
                    state <= Active;
            end
            default: state <= Idle;
        endcase
        
    always @(posedge clk)
        if (count_update >= 10000000 - 1) begin
            count_update <= 0;
            refresh <= ~refresh;
        end else begin
            count_update <= count_update + 1;
        end
endmodule
