/* characterRAM.v
 *
 * The character RAM stores ASCII characters and associated color/intensity
 * information for use by the video engine.  To allow easy interfacing with a
 * variety of systems, simple dual-ported RAM is inferred with an asynchronous
 * read port (read fall-through) for same-cycle access.  The use of asynchronous
 * ports excludes the use of block-ram, but allows use of single-cycle CPU
 * designs. This can be trivially modified for pipelined access (and thus block
 * ram inference).
 *
 * As this memory bridges the external (w_clk) and internal video clock domains
 * (the r_* ports), care normally has to be taken to avoid writing (from the cpu
 * domain) to an address being read by the video domain.  For Xilinx and Altera
 * parts, it is guaranteed that a read/write collision will not result in damage
 * or permanent corruption.  The read data may be corrupted, but the write will
 * succeed and subsequent reads will contain the desired value.
 *
 * That means there are two text update strategies:
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

module characterRAM #(

    parameter TEXTADDR_WIDTH = 12,
    parameter N_COL = 80,
    parameter N_ROW = 30)

   (input cpu_clk,
    input vid_clk,
    input cpu_we,
    input cpu_oe,
    input[TEXTADDR_WIDTH-1:0] cpu_addr,
    input[TEXTADDR_WIDTH-1:0] vid_addr,
    input[15:0] cpu_charIn,
    output[15:0] cpu_charOut,
    output reg[15:0] vid_charOut);

    reg[15:0] ram[0:(N_COL*N_ROW)-1]; //2400x16 character RAM

    always @(posedge cpu_clk) begin
        if(cpu_we) begin
            ram[cpu_addr] <= cpu_charIn;
        end
    end

    //The use of asynchronous fall-through reads on the CPU port prevents
    //inferring block-ram. This is unfortunate but necessary for single cycle
    //CPU designs.
    assign cpu_charOut = cpu_oe ? ram[cpu_addr] : 16'b0;

    always @(posedge vid_clk) begin
        vid_charOut <= ram[vid_addr];
    end

    //Initial test pattern
    integer i;
    initial begin
        for(i = 0; i < (N_COL*N_ROW); i = i+1)
            ram[i] = {i[7:0],i[7:0]}; //Should wrap at 255
    end

endmodule
