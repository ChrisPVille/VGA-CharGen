/* vgaCharGen.v
 *
 * Top module for the VGA text generator
 *
 * This generator supports two text update strategies:
 * 1. Update the text only during a vertical retrace (vBlank). This will prevent
 *     any visual artifacts from making it to the display (if a character
 *     happens to get overwritten mid-draw).
 * 2. Update the text at will, accepting there is a very small chance the given
 *     character is being drawn and the write will corrupt it. This corruption
 *     should resolve on the next video frame and is likely acceptable for most
 *     display projects.
 *
 *------------------------------------------------------------------------------
 *
 * Copyright 2017 Christopher Parish
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
module vgaCharGen(
    input rst_p,

    //The pixel_clk can either be the actual pixel clock or an integer multiple
    //thereof, with pixel_clkEn pulsing once per actual pixel interval.  For
    //example, driving 640x480@60Hz could use a 100MHz "pixel_clk" with 25MHz
    //pulses on the pixel_clkEn line.  Alternatively, pixel_clk could be driven
    //at 25Mhz directly and pixel_clkEn permanently tied high.
    input pixel_clk,
    input pixel_clkEn,

    input cpu_clk,
    input[15:0] cpu_addr,
    input cpu_we,
    input cpu_oe,
    input[15:0] cpu_dataIn,
    output[15:0] cpu_dataOut,

    output vBlank,

    output[3:0] VGA_R,
    output[3:0] VGA_G,
    output[3:0] VGA_B,
    output VGA_HS,
    output VGA_VS);

    //Include the appropriate parameters for the selected resolution (don't
    //forget to set the input pixel clock appropriately).
    `include "480.vh" //Load the 640x480 parameters
    //`include "1080.vh" //Load the 1920x1080 parameters

    parameter SINGLE_CYCLE_DESIGN = 1;

    parameter FONT_PAGES = 1;
    parameter FONT_H = 16;
    parameter FONT_W = 8;

    parameter H_TOTAL = H_ACTIVE+H_FP+H_SYN+H_BP;
    parameter V_TOTAL = V_ACTIVE+V_FP+V_SYN+V_BP;

    //I believe Vivado still poops itself with clog2 in a localparam 
    parameter H_WIDTH = $clog2(H_TOTAL);
    parameter V_WIDTH = $clog2(V_TOTAL);
    parameter TEXTADDR_WIDTH = $clog2(N_COL*N_ROW);

    wire[H_WIDTH-1:0] horizPixelPos;
    wire[V_WIDTH-1:0] vertPixelPos;
    wire[15:0] curChar;

    reg[7:0] charAttribute[0:1];

    reg[TEXTADDR_WIDTH-1:0] effectiveCharAddr;
    reg[2:0] glyphHorizCoord[0:1];
    reg[3:0] glyphVertCoord[0:1];

    wire glyphPixel;
    wire[3:0] pixel_r;
    wire[3:0] pixel_g;
    wire[3:0] pixel_b;

    integer i;

    //Compute effective character address and lookup the resulting character
    //This takes a combined 2 cycles.
    //(Time since coordinate update at start: 0 cycles)
    always @(posedge pixel_clk) begin
        effectiveCharAddr <= (vertPixelPos>>4)*N_COL + (horizPixelPos>>3);
    end
    characterRAM #(.SINGLE_CYCLE_RAM(SINGLE_CYCLE_DESIGN),
                   .N_COL(N_COL), .N_ROW(N_ROW),
                   .TEXTADDR_WIDTH(TEXTADDR_WIDTH))
      charRam1 (.cpu_clk(cpu_clk), .cpu_we(cpu_we), .cpu_addr(cpu_addr[TEXTADDR_WIDTH-1:0]),
        .cpu_charIn(cpu_dataIn), .cpu_charOut(cpu_dataOut), .cpu_oe(cpu_oe),
        .vid_clk(pixel_clk), .vid_addr(effectiveCharAddr),
        .vid_charOut(curChar));

    //Use the font ROM to lookup the pixel given by the input character and the
    //pixel position within that character.  As the current character we are
    //operating on took 2 cycles to retrieve in the last step, we need to hold
    //on to the relevant parts of the horiz/vert pixel coordinates for those
    //cycles.
    //This takes 2 cycles.
    //(Time since coordinate update at start: 2 cycles)
    always @(posedge pixel_clk) begin
        glyphHorizCoord[0] <= horizPixelPos[2:0];
        glyphVertCoord[0] <= vertPixelPos[3:0];
        glyphHorizCoord[1] <= glyphHorizCoord[0];
        glyphVertCoord[1] <= glyphVertCoord[0];
    end
    fontROM #(.FONT_PAGES(FONT_PAGES), .FONT_H(FONT_H), .FONT_W(FONT_W))
      fontRom1 (.clk(pixel_clk), .en(1'b1), .page(1'b0), .char(curChar[7:0]),
        .horizPos(glyphHorizCoord[1]), .vertPos(glyphVertCoord[1]),
        .pixel(glyphPixel));

    //The attribute map modifies the glyph pixel into the color signals for the
    //currently requested foreground/background. We need to grab the matching
    //attribute data for our pixel (the attributes being from two cycles ago as
    //the pixel took two cycles to retrieve).
    //This takes 1 cycle.
    //(Time since coordinate update at start: 4 cycle)
    always @(posedge pixel_clk) begin
        charAttribute[0] <= curChar[15:8];
        charAttribute[1] <= charAttribute[0];
    end
    attributeMap
      attrib1 (.clk(pixel_clk), .rst_p(rst_p), .pixel(glyphPixel),
        .attribute(charAttribute[1]), .pixel_r(pixel_r), .pixel_g(pixel_g),
        .pixel_b(pixel_b));

    //Character Address Computation (1 cycle) + Character lookup (1 cycle) +
    //Font ROM Lookup (2 cycle) + Font Attribute Application (1 cycle) =
    //5 clock pipeline delay needed from x/y position output till the colored
    //pixel data is ready.
    vgaEngine #(.EXT_PIPELINE_DELAY(5), .H_ACTIVE(H_ACTIVE), .H_FP(H_FP),
                .H_SYN(H_SYN), .H_BP(H_BP), .H_TOTAL(H_TOTAL),
                .V_ACTIVE(V_ACTIVE), .V_FP(V_FP), .V_SYN(V_SYN), .V_BP(V_BP),
                .V_TOTAL(V_TOTAL), .H_WIDTH(H_WIDTH), .V_WIDTH(V_WIDTH))
      vga1 (.clk(pixel_clk), .rst_p(rst_p), .clk_en(pixel_clkEn),
        .r(pixel_r), .g(pixel_g), .b(pixel_b), .vertBlanking(vBlank),
        .horizPos(horizPixelPos), .vertPos(vertPixelPos), .v_sync(VGA_VS),
        .h_sync(VGA_HS), .redOut(VGA_R), .greenOut(VGA_G), .blueOut(VGA_B));

endmodule
