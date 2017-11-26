/* vgaEngine.v
 *
 * The VGA engine is responsible for generation of the horizontal and vertical
 * sync signals as well as blanking the output RGB values when in the blanking
 * interval.
 *
 * A vertBlanking signal is provided for coordination of external logic.
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

module vgaEngine (input clk,
                      input rst_p,
                      input clk_en,
                      input[3:0] r,
                      input[3:0] g,
                      input[3:0] b,
                      output vertBlanking,
                      output[9:0] horizPos,
                      output[8:0] vertPos,
                      output reg v_sync,
                      output reg h_sync,
                      output reg[3:0] redOut,
                      output reg[3:0] greenOut,
                      output reg[3:0] blueOut);

    //The actual generation/lookup parts of the display sequence may be slow
    //so we allow the RGB inputs and v/hSync lines to lag a certain amount
    //behind horizPos and vertPos.  This will give whatever RAM or backing
    //pixel store N cycles to actually return the RGB values for the given
    //"current" position.  This parameter is the number of cycles from position
    //output till valid pixel data on the inputs.
    parameter EXT_PIPELINE_DELAY = 0;

    parameter H_ACTIVE = 640;
    parameter H_FP = 16;
    parameter H_BLANK = 96;
    parameter H_BP = 48;
    parameter H_TOTAL = H_ACTIVE+H_FP+H_BLANK+H_BP;
    parameter V_ACTIVE = 480;
    parameter V_FP = 10;
    parameter V_BLANK = 2;
    parameter V_BP = 29;
    parameter V_TOTAL = V_ACTIVE+V_FP+V_BLANK+V_BP;

    integer i;
    reg[9:0] horiz_position_pipeline [0:EXT_PIPELINE_DELAY];
    reg[9:0] vert_position_pipeline [0:EXT_PIPELINE_DELAY];

    wire v_sync_pre;
    wire h_sync_pre;

    assign horizPos = horiz_position_pipeline[0];
    assign vertPos = vert_position_pipeline[0];

    //Counter process, counts from horiz = 0 to horiz = H_TOTAL, then
    //increments the vertical line number. Once vertical position equals
    //V_TOTAL, it too resets to 0.
    always @(posedge clk, posedge rst_p) begin
        if(rst_p) begin
            for(i = 0; i<=EXT_PIPELINE_DELAY; i=i+1) begin
                horiz_position_pipeline[i] <= 0;
                vert_position_pipeline[i] <= 0;
            end
        end else begin

            //Shift our horizontal and vertical positions, keeping pos[0] intact
            for(i = 1; i<=EXT_PIPELINE_DELAY; i=i+1) begin
                horiz_position_pipeline[i] <= horiz_position_pipeline[i-1];
                vert_position_pipeline[i] <= vert_position_pipeline[i-1];
            end

            if (clk_en) begin
                if(horiz_position_pipeline[0] == H_TOTAL-1) begin
                    if(vert_position_pipeline[0] == V_TOTAL-1) begin
                        vert_position_pipeline[0] <= 0;
                    end else begin
                        vert_position_pipeline[0] <= vert_position_pipeline[0] + 1;
                    end
                    horiz_position_pipeline[0] <= 0;
                end else begin
                    horiz_position_pipeline[0] <= horiz_position_pipeline[0] + 1;
                end
            end
        end
    end

    always @(posedge clk) begin
        h_sync <= h_sync_pre;
        v_sync <= v_sync_pre;
    end

    //Sets the h_sync pulse for the duration of H_BLANK after the active period and
    //front porch. Remember, h_sync is active low
    assign h_sync_pre = ~((horiz_position_pipeline[EXT_PIPELINE_DELAY] >= H_ACTIVE+H_FP) &
                          (horiz_position_pipeline[EXT_PIPELINE_DELAY] < H_ACTIVE+H_FP+H_BLANK));

    //Sets the v_sync pulse for the duration of V_BLANK after the active period and
    //front porch.
    assign v_sync_pre = ~((vert_position_pipeline[EXT_PIPELINE_DELAY] >= V_ACTIVE+V_FP) &
                          (vert_position_pipeline[EXT_PIPELINE_DELAY] < V_ACTIVE+V_FP+V_BLANK));

    //Because of the pipeline delay, this signal will start slightly early, but
    //the early assertion still happens inside of the last line's horizontal
    //blanking interval, making it a non issue.
    assign vertBlanking = (vert_position_pipeline[0] >= 480);

    always @(posedge clk) begin
        if(horiz_position_pipeline[EXT_PIPELINE_DELAY] < 640 & vert_position_pipeline[EXT_PIPELINE_DELAY] < 480) begin
            redOut <= r;
            greenOut <= g;
            blueOut <= b;
        end else begin
            //If we are in the blanking area, make sure to enforce blank outputs
            redOut <= 0;
            greenOut <= 0;
            blueOut <= 0;
        end
    end

endmodule