`timescale 1ns / 1ps

module process(
	input clk,				// clock 
	input [23:0] in_pix,	// valoarea pixelului de pe pozitia [in_row, in_col] din imaginea de intrare (R 23:16; G 15:8; B 7:0)
	output reg [5:0] row, col, 	// selecteaza un rand si o coloana din imagine
	output reg out_we, 			// activeaza scrierea pentru imaginea de iesire (write enable)
	output reg [23:0] out_pix,	// valoarea pixelului care va fi scrisa in imaginea de iesire pe pozitia [out_row, out_col] (R 23:16; G 15:8; B 7:0)
	output reg mirror_done,		// semnaleaza terminarea actiunii de oglindire (activ pe 1)
	output reg gray_done,		// semnaleaza terminarea actiunii de transformare in grayscale (activ pe 1)
	output reg filter_done);	// semnaleaza terminarea actiunii de aplicare a filtrului de sharpness (activ pe 1)

	// definirea starilor
	`define IDLE 6'd0
	`define MIRROR_TAKE_UP 6'd1
	`define MIRROR_TAKE_DOWN 6'd2
	`define MIRROR_REPL_UP 6'd3
	`define MIRROR_INCREMENT 6'd4
	`define MIRROR_DONE 6'd5
	`define GRAY_INIT 6'd6
	`define GRAY_CHANGE 6'd7
	`define GRAY_INCREMENT 6'd8
	`define GRAY_DONE 6'd9
	`define FILTER_INIT 6'd10
	`define FILTER_ASSIGN_OLD_VALUES 6'd11
	`define FILTER_INCREMENT_OLD 6'd12
	`define FILTER_ASSIGN_FLAGS 6'd13
	`define FILTER_PROCESS_NEW_PIXEL 6'd14
	`define FILTER_GO_UL 6'd15
	`define FILTER_GO_UM 6'd16
	`define FILTER_GO_UR 6'd17
	`define FILTER_GO_ML 6'd18
	`define FILTER_GO_MR 6'd19
	`define FILTER_GO_LL 6'd20
	`define FILTER_GO_LM 6'd21
	`define FILTER_GO_LR 6'd22
	`define FILTER_DETERMINE_SUM 6'd23
	`define FILTER_UPDATE_VALUE 6'd24
	`define FILTER_INCREMENT 6'd25
	`define FILTER_CLEAN_OLD_VALUES 6'd26
	`define FILTER_INCREMENT_CLEAN_OLD 6'd27
	`define FILTER_DONE 6'd28
	// simplificarea apelarii canalelor individuale de culoare
	`define R in_pix[23:16]
	`define G in_pix[15:8]
	`define B in_pix[7:0]
	`define R_o out_pix[23:16]
	`define G_o out_pix[15:8]
	`define B_o out_pix[7:0]
	
	reg[5:0] state = `IDLE;
	
	// declararea variabilelor auxiliare pentru oglindire
	reg [23:0] up_pix, down_pix;
	// declararea variabilelor auxiliare pentru filtru
	integer sum;
	// marcheaza daca elementul de pe pozitia corespunzatoare face parte din imagine
	reg [0:0] ul; // upper left
	reg [0:0] um; // upper mid
	reg [0:0] ur; // upper right
	reg [0:0] ml; // middle left
	reg [0:0] mr; // middle right
	reg [0:0] ll; // lower left
	reg [0:0] lm; // lower mid
	reg [0:0] lr; // lower right
	// pastreaza randul si coloana elementului central
	reg[5:0] col_curr, row_curr;
	
	// implementarea automatului
	always @(posedge clk) begin
		case (state)
			`IDLE: begin
				row <= 0;
            col <= 0;
            out_we <= 0;
				mirror_done <= 0;
				gray_done <= 0;
				filter_done <= 0;
				state <= `MIRROR_TAKE_UP;
			end
			
			`MIRROR_TAKE_UP: begin
				up_pix <= in_pix;
				row <= 63 - row;
				state <= `MIRROR_TAKE_DOWN;
			end
			
			`MIRROR_TAKE_DOWN: begin
				//ii si atribuie pixelului de jos valoarea noua
				down_pix <= in_pix;
				out_pix <= up_pix;
				out_we <= 1;
				state <= `MIRROR_REPL_UP;
			end
			
			`MIRROR_REPL_UP: begin
				row <= 63 - row;
				out_pix <= down_pix;
				state <= `MIRROR_INCREMENT;	
			end
			
			`MIRROR_INCREMENT: begin
				out_we <= 0;
				if(col == 63 && row == 31)
					state <= `MIRROR_DONE;
				else
					if(row == 31) begin
						col <= col + 1;
						row <= 0;
						state <= `MIRROR_TAKE_UP;
					end 
					else begin
						row <= row + 1;
						state <= `MIRROR_TAKE_UP;
					end
			end
			
		   `MIRROR_DONE: begin
				mirror_done <= 1;
				state <= `GRAY_INIT;
         end
			
			`GRAY_INIT: begin
				row <= 0;
            col <= 0;
				state <= `GRAY_CHANGE;
			end
			
			`GRAY_CHANGE: begin
				`R_o <= 0;
				`B_o <= 0;
				// formula oropsita pt media intre min si max (vezi README.pdf)
				`G_o <= (((`R<`G)?((`R<`B)?`R:`B):((`G<`B)?`G:`B)) + ((`R>`G)?((`R>`B)?`R:`B):((`G>`B)?`G:`B))) / 2;
				out_we <= 1;
				state <= `GRAY_INCREMENT;
			end
			
			`GRAY_INCREMENT: begin
				out_we <= 0;
				if(col == 63 && row == 63)
					state <= `GRAY_DONE;
				else
					if(row == 63) begin
						col <= col + 1;
						row <= 0;
						state <= `GRAY_CHANGE;
					end 
					else begin
						row <= row + 1;
						state <= `GRAY_CHANGE;
					end
			end
			
			`GRAY_DONE: begin
				gray_done <= 1;
				state <= `FILTER_INIT;
         end
			
			`FILTER_INIT: begin
				row <= 0;
            col <= 0;
				state <= `FILTER_ASSIGN_OLD_VALUES;
			end
			
			`FILTER_ASSIGN_OLD_VALUES: begin
				`R_o <= `G;
				`G_o <= `G;
				`B_o <= `B;
				out_we <= 1;
				state <= `FILTER_INCREMENT_OLD;
			end
			
			`FILTER_INCREMENT_OLD: begin
				out_we <= 0;
				if(col == 63 && row == 63) begin
					col <= 0;
					row <= 0;
					state <= `FILTER_ASSIGN_FLAGS;
				end
				else
					if(col == 63) begin
						row <= row + 1;
						col <= 0;
						state <= `FILTER_ASSIGN_OLD_VALUES;
					end 
					else begin
						col <= col + 1;
						state <= `FILTER_ASSIGN_OLD_VALUES;
					end
			end
			
			`FILTER_ASSIGN_FLAGS: begin
				sum <= 0;
				ul <= 1;
				um <= 1;
				ur <= 1;
				ml <= 1;
				mr <= 1;
				ll <= 1;
				lm <= 1;
				lr <= 1;
				// seteaza 0 pozitia fiecarui element din filtru care iese din limitele imaginii  
				if (row == 0) begin
					ul <= 0;
					um <= 0;
					ur <= 0;
				end
				else
					if (row == 63) begin
						ll <= 0;
						lm <= 0;
						lr <= 0;
					end
				if (col == 0) begin
					ul <= 0;
					ml <= 0;
					ll <= 0;
				end
				else
					if (col == 63) begin
						ur <= 0;
						mr <= 0;
						lr <= 0;
					end
				state <= `FILTER_PROCESS_NEW_PIXEL;
			end
			
			`FILTER_PROCESS_NEW_PIXEL: begin
				col_curr <= col;
				row_curr <= row;
				sum <= 9 * `R;
				state <= `FILTER_GO_UL;
			end
			
			`FILTER_GO_UL: begin
				if (ul) begin
					row <= row_curr - 1;
					col <= col_curr - 1;
				end
				state <= `FILTER_GO_UM;
			end
			
			`FILTER_GO_UM: begin
				sum = sum - ul * `R;
				if (um) begin
					row <= row_curr - 1;
					col <= col_curr;
				end
				state <= `FILTER_GO_UR;
			end
			
			`FILTER_GO_UR: begin
				sum = sum - um * `R;
				if (ur) begin
					row <= row_curr - 1;
					col <= col_curr + 1;
				end
				state <= `FILTER_GO_ML;
			end
			
			`FILTER_GO_ML: begin
				sum = sum - ur * `R;
				if (ml) begin
					row <= row_curr;
					col <= col_curr - 1;
				end
				state <= `FILTER_GO_MR;
			end
			
			`FILTER_GO_MR: begin
				sum = sum - ml * `R;
				if (mr) begin
					row <= row_curr;
					col <= col_curr + 1;
				end
				state <= `FILTER_GO_LL;
			end
			
			`FILTER_GO_LL: begin
				sum = sum - mr * `R;
				if (ll) begin
					row <= row_curr + 1;
					col <= col_curr - 1;
				end
				state <= `FILTER_GO_LM;
			end
			
			`FILTER_GO_LM: begin
				sum = sum - ll * `R;
				if (lm) begin
					row <= row_curr + 1;
					col <= col_curr;
				end
				state <= `FILTER_GO_LR;
			end
			
			`FILTER_GO_LR: begin
				sum = sum - lm * `R;
				if (lr) begin
					row <= row_curr + 1;
					col <= col_curr + 1;
				end
				state <= `FILTER_DETERMINE_SUM;
			end
			
			`FILTER_DETERMINE_SUM: begin
				sum <= sum - lr * `R;
				state <= `FILTER_UPDATE_VALUE;
				row <= row_curr;
				col <= col_curr;
			end
			
			`FILTER_UPDATE_VALUE: begin
				out_we = 1;
				if (sum <= 0) begin
					`R_o <= `R;
					`G_o <= 0;
					`B_o <= `B;
				end
				else begin
					if (sum >= 255) begin
						`R_o <= `R;
						`G_o <= 255;
						`B_o <= `B;
					end
					else begin
						`R_o <= `R;
						`G_o <= sum;
						`B_o <= `B;
					end
				end
				state <= `FILTER_INCREMENT;
			end
			
			`FILTER_INCREMENT: begin
				out_we = 0;
				if(col == 63 && row == 63) begin
					state <= `FILTER_CLEAN_OLD_VALUES;
					row <= 0;
					col <= 0;
				end
				else
					if(col == 63) begin
						row <= row + 1;
						col <= 0;
						state <= `FILTER_ASSIGN_FLAGS;
					end 
					else begin
						col <= col + 1;
						state <= `FILTER_ASSIGN_FLAGS;
					end
			end
			
			`FILTER_CLEAN_OLD_VALUES: begin
				`R_o <= 0;
				`G_o <= `G;
				`B_o <= 0;
				out_we <= 1;
				state <= `FILTER_INCREMENT_CLEAN_OLD;
			end
			
			`FILTER_INCREMENT_CLEAN_OLD: begin
				out_we <= 0;
				if(col == 63 && row == 63) begin
					col <= 0;
					row <= 0;
					state <= `FILTER_DONE;
				end
				else
					if(col == 63) begin
						row <= row + 1;
						col <= 0;
						state <= `FILTER_CLEAN_OLD_VALUES;
					end 
					else begin
						col <= col + 1;
						state <= `FILTER_CLEAN_OLD_VALUES;
					end
			end
			
			`FILTER_DONE: begin
				out_we <= 0;
				filter_done <= 1;
				state <= `FILTER_DONE;
         end
         default: state <= `IDLE;
      endcase
	end
	
endmodule