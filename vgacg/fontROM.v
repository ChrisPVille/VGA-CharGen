/* fontRom.v
 *
 * The Font ROM is essentially one big lookup RAM taking the ASCII character
 * 'char' along with the requested x,y position in the glyph and delivering
 * the resulting pixel.
 *
 * A default ROM is included, but can be easily swapped out,
 * (see exampleFontROM.bin).
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

module fontROM(input clk,
               input en,
               input[3:0] page,
               input[7:0] char,
               input[2:0] horizPos,
               input[3:0] vertPos,
               output pixel);

    parameter FONT_PAGES = 1;
    parameter FONT_H = 16;
    parameter FONT_W = 8;

    reg[FONT_W-1:0] ram[0:256*FONT_PAGES*FONT_H-1]; //(pageCount*4096)x8 RAM

    //Reverse the endianness of our glyph as we want to push out the MSB first
    reg[0:FONT_W-1] curGlyph;
    wire[11:0] effectiveLinearAddr;

    //We need to delay the horizPosition by one cycle as the vertical position
    //is used to compute the ROM address, with the result taking one cycle to
    //generate.
    reg[2:0] delayedHorizPos;

    //It looks like Vivado won't infer block RAM/ROM without a write
    //enable signal, even if it's tied to 0 and the write is 0.
    wire we;
    assign we = 0;

    assign effectiveLinearAddr = (page*256*FONT_H)+(char*FONT_H)+vertPos;

    //Return bit 'horizPos' of the current character
    assign pixel = curGlyph[delayedHorizPos];

    always @(posedge clk) begin
        delayedHorizPos <= horizPos;
    end

    always @(posedge clk) begin
        if(en) begin
            if(we) begin
                ram[effectiveLinearAddr] <= 0;
            end
            curGlyph <= ram[effectiveLinearAddr];
        end
    end

    initial begin
        //Vivado will happily synthesize the Font ROM with a completely missing
        //initialization binary, emitting only a warning that it can't find the
        //file.  As a result, a default font is provided as a good old list of
        //assignments.  If you want to override the font, provide your own via
        //$readmem .

        `include "isoFont.vh"

        //Be sure to use forward slashes '/', even on Windows
        //$readmemb("/path/to/font.bin", ram);
    end

endmodule
