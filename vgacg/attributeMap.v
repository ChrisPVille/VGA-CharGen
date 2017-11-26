/* attributeMap.v
 *
 * The attribute map decorates the current input pixel given the EGA/VGA style
 * attribute byte and provides the result to the rest of the video pipeline
 * after 1 cycle.  Look at http://wiki.osdev.org/Text_UI for details.
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

module attributeMap(input clk,
               input rst_p,
               input pixel,
               input[7:0] attribute,
               output reg[3:0] pixel_r,
               output reg[3:0] pixel_g,
               output reg[3:0] pixel_b);

    task setRGB;
        input r, g, b, bright;
        begin
            //Handle "dark grey" special case
            if( (r|g|b) == 0 && bright) begin
                pixel_r <= 4'h3;
                pixel_g <= 4'h3;
                pixel_b <= 4'h3;
            end

            if(b) pixel_b <= bright ? 4'hF : 4'h7;
            if(g) pixel_g <= bright ? 4'hF : 4'h7;
            if(r) pixel_r <= bright ? 4'hF : 4'h7;
        end
    endtask

    always @(posedge clk, posedge rst_p) begin
        if(rst_p) begin
            pixel_r <= 0;
            pixel_g <= 0;
            pixel_b <= 0;
        end else begin
            pixel_r <= 0;
            pixel_g <= 0;
            pixel_b <= 0;

            if(pixel) begin //If "foreground" area
                setRGB(attribute[2],attribute[1],attribute[0],attribute[3]);
            end else begin //If background
                setRGB(attribute[6],attribute[5],attribute[4],attribute[7]);
            end
        end
    end

endmodule
