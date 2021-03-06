`include "vga/vga_palette.v"

module vga_wb8_extram (
        // Wisbhone B4 signals
        input[12:0] I_wb_adr, // 2^13 addresses
        input I_wb_clk,
        input[7:0] I_wb_dat,
        input I_wb_stb,
        input I_wb_we,
        output reg O_wb_ack,
        output reg[7:0] O_wb_dat,

        // reset signal
        input I_reset,

        // signals to external RAM
        output reg[18:0] O_ram_adr,
        output reg O_ram_req = 0,
        input[7:0] I_ram_dat,

        // VGA signals
        input I_vga_clk,
        output reg O_vga_vsync, O_vga_hsync,
        output reg[7:0] O_vga_r,
        output reg[7:0] O_vga_g,
        output reg[7:0] O_vga_b
    );


    localparam h_visible = 640;
    localparam h_front_porch = 16;
    localparam h_pulse = 96;
    localparam h_back_porch = 48;
    localparam v_visible = 480;
    localparam v_front_porch = 10;
    localparam v_pulse = 2;
    localparam v_back_porch = 33;


    reg[9:0] col = 0; // maximum of 1024 columns
    reg[9:0] row = 0; // maximum of 1024 rows
    
    reg col_is_visible = 0;
    reg row_is_visible = 0;

    localparam MODE_OFF = 2'b00;
    localparam MODE_TEXT_40 = 2'b01;
    localparam MODE_GRAPHICS_640 = 2'b10;
    localparam MODE_GRAPHICS_320 = 2'b11;

    reg[1:0] mode = MODE_TEXT_40;

    reg[18:0] ram_base = 128 * 1024;
    reg[18:0] ram_adr = 0;

    reg[18:0] font_base = 256 * 1024;
    reg[7:0] char_byte = 0;
    reg[0:7] font_byte = 0, font_byte2 = 0; // reversed bit order for easier lookup according to column
    reg[7:0] color_byte = 0, color_byte2 = 0;

    reg[6:0] text_col = 0;
    reg[8:0] graphics_col = 0;

    reg[7:0] ram_dat;
    reg ram_fetch = 0;

    reg[7:0] cache [511:0];
    reg[8:0] cache_adr;

    reg[23:0] tmp;

    wire line_double;
    assign line_double = (mode == MODE_GRAPHICS_320);


    reg[3:0] coloridx = 0;
    always @(*) begin
        case(mode)
            MODE_TEXT_40:      coloridx = font_byte[col[4:1]] ? color_byte2[7:4] : color_byte2[3:0];
            MODE_GRAPHICS_640: coloridx = !col[0] ? ram_dat[7:4] : ram_dat[3:0];
            default:           coloridx = 0;
        endcase
    end

    reg[7:0] palette_idx = 0;
    always @(*) begin
        palette_idx = (mode == MODE_GRAPHICS_320) ? ram_dat : {4'h0, coloridx};
    end

    reg[31:0] palette_update;
    reg palette_update_request = 0;
    wire palette_update_ack;
    wire[23:0] palette_rgb;
    vga_palette vga_palette_inst(
        .I_clk(I_vga_clk),
        .I_palette_update(palette_update),
        .I_update_request(palette_update_request),
        .I_palette_idx(palette_idx),
        .O_update_ack(palette_update_ack),
        .O_rgb(palette_rgb)
    );

    always @(*) begin
        if(col_is_visible && row_is_visible) begin
            {O_vga_r, O_vga_g, O_vga_b} <= palette_rgb;
        end else begin
            {O_vga_r, O_vga_g, O_vga_b} <= 24'b0;
        end
    end

    always @(posedge I_vga_clk) begin

        O_ram_req <= 0;

        if(mode == MODE_GRAPHICS_640 || mode == MODE_GRAPHICS_320) begin
            if(row_is_visible && col == (h_front_porch + h_pulse + h_back_porch - 4)) begin
                ram_fetch <= 1;
            end
            if(col == (h_front_porch + h_pulse + h_back_porch + h_visible - 3)) begin
                ram_fetch <= 0;
                // In both MODE_GRAPHICS_320 and MODE_GRAPHICS_640 one line is 320 bytes.
                // In MODE_GRAPHICS_320 each line is output twice, thus only increase
                // memory offset every second line.
                if((row[0] && mode == MODE_GRAPHICS_320) || mode == MODE_GRAPHICS_640) begin
                    ram_adr <= ram_adr + 320;
                    cache_adr <= 0;
                end
            end

            if(ram_fetch && col[0]) begin
                O_ram_req <= !row[0] || !line_double;
                O_ram_adr <= ram_adr + graphics_col;
                graphics_col <= graphics_col + 1;
                cache_adr <= graphics_col[8:0];
            end

            if(col[0]) begin
                ram_dat <= I_ram_dat;
                // in line-doubled mode, retrieve odd-numbered lines from cache
                if(row[0] && line_double) begin
                    ram_dat <= cache[cache_adr];
                end else begin
                    cache[cache_adr] <= I_ram_dat;
                end
            end
        end

        
        if(mode == MODE_TEXT_40) begin
            // 40 column text mode
            if(row_is_visible && col == (h_front_porch + h_pulse + h_back_porch - 15)) begin
                ram_fetch <= 1;
            end
            if(col == (h_front_porch + h_pulse + h_back_porch + h_visible - 15)) begin
                ram_fetch <= 0;
                if(row[3:0] == 15) ram_adr <= ram_adr + 80;
            end

            if(ram_fetch) begin
                if(col[3:0] == 0) begin
                end else if(col[3:0] == 9) begin
                    O_ram_req <= 1;
                    O_ram_adr <= ram_adr + {text_col, 1'b0};
                end else if(col[3:0] == 11) begin
                    char_byte <= I_ram_dat;
                    O_ram_req <= 1;
                    O_ram_adr <= ram_adr + {text_col, 1'b1};
                    text_col <= text_col + 1;
                end else if(col[3:0] == 13) begin
                    color_byte <= I_ram_dat;
                    O_ram_req <= 1;
                    O_ram_adr <= font_base + {char_byte, row[3:1]};
                end else if(col[3:0] == 15) begin
                    font_byte <= I_ram_dat;
                    color_byte2 <= color_byte;
                end
            end
        end

        // generate sync signals
        if(col == h_front_porch - 1) begin
            O_vga_hsync <= 0;
        end

        if(col == h_front_porch + h_pulse - 1) begin
            O_vga_hsync <= 1;
        end

        if(col == h_front_porch + h_pulse + h_back_porch - 1) begin
            col_is_visible <= 1;
        end

        if(row == v_visible + v_front_porch - 1) begin
            O_vga_vsync <= 0;
        end

        if(row == v_visible + v_front_porch + v_pulse - 1) begin
            O_vga_vsync <= 1;
        end


        if(col == h_front_porch + h_pulse + h_back_porch + h_visible - 1) begin
            col <= 0;
            col_is_visible <= 0;
            text_col <= 0;
            graphics_col <= 0;

            if(row == v_visible + v_front_porch + v_pulse + v_back_porch - 1) begin
                // return to first line
                row <= 0;
                row_is_visible <= 1;

                // reset RAM address to start of framebuffer
                ram_adr <= ram_base;
            end else begin
                // progress to next line
                row <= row + 1;
            end

            if(row == v_visible - 1) begin
                row_is_visible <= 0;
            end

        end else begin
            col <= col + 1;
        end


    end
    
    always @(posedge I_wb_clk) begin
        if(I_wb_stb) begin
            if(I_wb_we) begin
                case(I_wb_adr[3:0])
                    // write access to bitmap/text base address
                    4'h0: tmp[7:0] <= I_wb_dat;
                    4'h1: tmp[15:8] <= I_wb_dat;
                    4'h2: tmp[23:16] <= I_wb_dat;
                    4'h3: ram_base <= tmp[18:0];

                    // write access to font base address
                    4'h4: tmp[7:0] <= I_wb_dat;
                    4'h5: tmp[15:8] <= I_wb_dat;
                    4'h6: tmp[23:16] <= I_wb_dat;
                    4'h7: font_base <= tmp[18:0];

                    // write access to update color palette
                    4'h8: palette_update[7:0] <= I_wb_dat; // B component
                    4'h9: palette_update[15:8] <= I_wb_dat; // G component
                    4'hA: palette_update[23:16] <= I_wb_dat; // R component
                    4'hB: begin 
                        palette_update[31:24] <= I_wb_dat; // palette entry index
                        palette_update_request <= !palette_update_ack; // request palette update
                    end

                    // 4'hC current line - read only
                    // 4'hD current line - read only

                    // 4'hE visible line - read only
                    
                    // write access to graphics mode register
                    4'hF: mode <= I_wb_dat[1:0];

                    default: begin end

                endcase
            end else begin
                case(I_wb_adr[3:0])
                    // read access for bitmap/text base address
                    4'h0: O_wb_dat <= ram_base[7:0];
                    4'h1: O_wb_dat <= ram_base[15:8];
                    4'h2: O_wb_dat <= {5'b00000, ram_base[18:16]};
                    4'h3: O_wb_dat <= 8'b0;

                    // read access for font base address
                    4'h4: O_wb_dat <= font_base[7:0];
                    4'h5: O_wb_dat <= font_base[15:8];
                    4'h6: O_wb_dat <= {5'b00000, font_base[18:16]};
                    4'h7: O_wb_dat <= 8'b0;

                    // read access to color palette update (quite useless?)
                    4'h8: O_wb_dat <= palette_update[7:0];
                    4'h9: O_wb_dat <= palette_update[15:8];
                    4'hA: O_wb_dat <= palette_update[23:16];
                    4'hB: O_wb_dat <= palette_update[31:24];

                    // read access to current line
                    4'hC: begin
                        O_wb_dat <= row[7:0];
                        tmp[1:0] <= row[9:8];
                    end
                    4'hD: O_wb_dat <= {{6{1'b0}}, tmp[1:0]};

                    // read access to visible line flag
                    4'hE: O_wb_dat <= {{7{1'b0}}, row_is_visible};

                    // read access to graphics mode register
                    4'hF: O_wb_dat <= {6'b000000, mode};
                endcase
            end
        end

        O_wb_ack <= I_wb_stb;


        if(I_reset) begin
            mode <= MODE_OFF;
        end

    end

endmodule