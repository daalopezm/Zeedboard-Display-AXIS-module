`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/18/2024 12:06:35 AM
// Design Name: 
// Module Name: AXIS_screen_oled
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


module AXIS_screen_oled(
    input clk,
    input resetn,
    input [127:0] s_axis_tdata_str1,
    input [127:0] s_axis_tdata_str2,
    input [127:0] s_axis_tdata_str3,
    input [127:0] s_axis_tdata_str4,
    input s_axis_tvalid,
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
    output led
);
    // Internal signals
    reg [127:0] str1, str2, str3, str4;
    reg refresh = 0;
    reg count_update = 0;

    // Handle AXIS transactions
    always @(posedge clk) begin
        
        if (!resetn) begin
            str1 <= s_axis_tdata_str1;
            str2 <= s_axis_tdata_str2;
            str3 <= s_axis_tdata_str3;
            str4 <= s_axis_tdata_str4;
        end 
        if (s_axis_tvalid) begin
            str1 <= s_axis_tdata_str1;
            str2 <= s_axis_tdata_str2;
            str3 <= s_axis_tdata_str3;
            str4 <= s_axis_tdata_str4;
        end
        count_update <= count_update + 1;
    end

    // Instantiate the screen_oled module
    screen_oled u_screen_oled (
        .clk(clk),
        .btnR(btnR),
        .btnC(btnC),
        .btnD(btnD),
        .btnU(btnU),
        .oled_sdin(oled_sdin),
        .oled_sclk(oled_sclk),
        .oled_dc(oled_dc),
        .oled_res(oled_res),
        .oled_vbat(oled_vbat),
        .oled_vdd(oled_vdd),
        .led(led),
        .str1(str1),
        .str2(str2),
        .str3(str3),
        .str4(str4)
    );
endmodule
