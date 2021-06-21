//  Arcade: New Rally-X
//
//  Original implimentation and port to MiSTer by MiSTer-X 2019
//============================================================================

module emu
(
	//Master input clock
	input         CLK_50M,

	//Async reset from top-level module.
	//Can be used as initial reset.
	input         RESET,

	//Must be passed to hps_io module
	inout  [45:0] HPS_BUS,

	//Base video clock. Usually equals to CLK_SYS.
	output        CLK_VIDEO,

	//Multiple resolutions are supported using different CE_PIXEL rates.
	//Must be based on CLK_VIDEO
	output        CE_PIXEL,

	//Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
	//if VIDEO_ARX[12] or VIDEO_ARY[12] is set then [11:0] contains scaled size instead of aspect ratio.
	output [12:0] VIDEO_ARX,
	output [12:0] VIDEO_ARY,

	output  [7:0] VGA_R,
	output  [7:0] VGA_G,
	output  [7:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,
	output        VGA_DE,    // = ~(VBlank | HBlank)
	output        VGA_F1,
	output [1:0]  VGA_SL,
	output        VGA_SCALER, // Force VGA scaler

	input  [11:0] HDMI_WIDTH,
	input  [11:0] HDMI_HEIGHT,

`ifdef MISTER_FB
	// Use framebuffer in DDRAM (USE_FB=1 in qsf)
	// FB_FORMAT:
	//    [2:0] : 011=8bpp(palette) 100=16bpp 101=24bpp 110=32bpp
	//    [3]   : 0=16bits 565 1=16bits 1555
	//    [4]   : 0=RGB  1=BGR (for 16/24/32 modes)
	//
	// FB_STRIDE either 0 (rounded to 256 bytes) or multiple of pixel size (in bytes)
	output        FB_EN,
	output  [4:0] FB_FORMAT,
	output [11:0] FB_WIDTH,
	output [11:0] FB_HEIGHT,
	output [31:0] FB_BASE,
	output [13:0] FB_STRIDE,
	input         FB_VBL,
	input         FB_LL,
	output        FB_FORCE_BLANK,

`ifdef MISTER_FB_PALETTE
	// Palette control for 8bit modes.
	// Ignored for other video modes.
	output        FB_PAL_CLK,
	output  [7:0] FB_PAL_ADDR,
	output [23:0] FB_PAL_DOUT,
	input  [23:0] FB_PAL_DIN,
	output        FB_PAL_WR,
`endif
`endif

	output        LED_USER,  // 1 - ON, 0 - OFF.

	// b[1]: 0 - LED status is system status OR'd with b[0]
	//       1 - LED status is controled solely by b[0]
	// hint: supply 2'b00 to let the system control the LED.
	output  [1:0] LED_POWER,
	output  [1:0] LED_DISK,

	// I/O board button press simulation (active high)
	// b[1]: user button
	// b[0]: osd button
	output  [1:0] BUTTONS,

	input         CLK_AUDIO, // 24.576 MHz
	output [15:0] AUDIO_L,
	output [15:0] AUDIO_R,
	output        AUDIO_S,   // 1 - signed audio samples, 0 - unsigned
	output  [1:0] AUDIO_MIX, // 0 - no mix, 1 - 25%, 2 - 50%, 3 - 100% (mono)

	//ADC
	inout   [3:0] ADC_BUS,

	//SD-SPI
	output        SD_SCK,
	output        SD_MOSI,
	input         SD_MISO,
	output        SD_CS,
	input         SD_CD,

	//High latency DDR3 RAM interface
	//Use for non-critical time purposes
	output        DDRAM_CLK,
	input         DDRAM_BUSY,
	output  [7:0] DDRAM_BURSTCNT,
	output [28:0] DDRAM_ADDR,
	input  [63:0] DDRAM_DOUT,
	input         DDRAM_DOUT_READY,
	output        DDRAM_RD,
	output [63:0] DDRAM_DIN,
	output  [7:0] DDRAM_BE,
	output        DDRAM_WE,

	//SDRAM interface with lower latency
	output        SDRAM_CLK,
	output        SDRAM_CKE,
	output [12:0] SDRAM_A,
	output  [1:0] SDRAM_BA,
	inout  [15:0] SDRAM_DQ,
	output        SDRAM_DQML,
	output        SDRAM_DQMH,
	output        SDRAM_nCS,
	output        SDRAM_nCAS,
	output        SDRAM_nRAS,
	output        SDRAM_nWE,

`ifdef MISTER_DUAL_SDRAM
	//Secondary SDRAM
	//Set all output SDRAM_* signals to Z ASAP if SDRAM2_EN is 0
	input         SDRAM2_EN,
	output        SDRAM2_CLK,
	output [12:0] SDRAM2_A,
	output  [1:0] SDRAM2_BA,
	inout  [15:0] SDRAM2_DQ,
	output        SDRAM2_nCS,
	output        SDRAM2_nCAS,
	output        SDRAM2_nRAS,
	output        SDRAM2_nWE,
`endif

	input         UART_CTS,
	output        UART_RTS,
	input         UART_RXD,
	output        UART_TXD,
	output        UART_DTR,
	input         UART_DSR,

	// Open-drain User port.
	// 0 - D+/RX
	// 1 - D-/TX
	// 2..6 - USR2..USR6
	// Set USER_OUT to 1 to read from USER_IN.
	output	USER_OSD,
	output  [1:0] USER_MODE,
	input	[7:0] USER_IN,
	output	[7:0] USER_OUT,
	input         OSD_STATUS
);

///////// Default values for ports not used in this core /////////

assign ADC_BUS  = 'Z;
wire         CLK_JOY = CLK_50M;         //Assign clock between 40-50Mhz
wire   [2:0] JOY_FLAG  = {status[30],status[31],status[29]}; //Assign 3 bits of status (31:29) o (63:61)
wire         JOY_CLK, JOY_LOAD, JOY_SPLIT, JOY_MDSEL;
wire   [5:0] JOY_MDIN  = JOY_FLAG[2] ? {USER_IN[6],USER_IN[3],USER_IN[5],USER_IN[7],USER_IN[1],USER_IN[2]} : '1;
wire         JOY_DATA  = JOY_FLAG[1] ? USER_IN[5] : '1;
assign       USER_OUT  = JOY_FLAG[2] ? {3'b111,JOY_SPLIT,3'b111,JOY_MDSEL} : JOY_FLAG[1] ? {6'b111111,JOY_CLK,JOY_LOAD} : '1;
assign       USER_MODE = JOY_FLAG[2:1] ;
assign       USER_OSD  = joydb_1[10] & joydb_1[6]; // A�adir esto para OSD
assign {UART_RTS, UART_TXD, UART_DTR} = 0;
assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;
assign {SDRAM_DQ, SDRAM_A, SDRAM_BA, SDRAM_CLK, SDRAM_CKE, SDRAM_DQML, SDRAM_DQMH, SDRAM_nWE, SDRAM_nCAS, SDRAM_nRAS, SDRAM_nCS} = 'Z;
assign {DDRAM_CLK, DDRAM_BURSTCNT, DDRAM_ADDR, DDRAM_DIN, DDRAM_BE, DDRAM_RD, DDRAM_WE} = '0;  

assign VGA_F1 = 0;
assign VGA_SCALER = 0;


assign LED_USER  = ioctl_download;
assign BUTTONS   = 0;
assign AUDIO_MIX = 0;

assign LED_DISK  = 0;
assign LED_POWER = 0;

wire [1:0] ar = status[17:16];

assign VIDEO_ARX = (!ar) ?  8'd4  : (ar - 1'd1);
assign VIDEO_ARY = (!ar) ?  8'd3  : 12'd0;

`include "build_id.v" 
localparam CONF_STR = {
	"A.NRALLYX;;",

	"H0OGH,Aspect ratio,Original,Full Screen,[ARC1],[ARC2];",
	"OUV,UserIO Joystick,Off,DB9MD,DB15 ;",
	"OT,UserIO Players, 1 Player,2 Players;",
"-;",
	//"OE,Cabinet,Upright,Cocktail;",
	"O8A,Difficulty,M1,M2,M3,M4,M5,M6,M7,M8;",
	"OBC,Bonus Life,M1,M2,M3,Nothing;",
	"OF,Service Mode,Off,On;",
"-;",
	"P1,Pause options;",
	"P1OP,Pause when OSD is open,On,Off;",
	"P1OQ,Dim video after 10s,On,Off;",
	"-;",
	"R0,Reset;",
	"J1,Smoke,Start 1P,Start 2P,Coin,Pause;",
	"V,v",`BUILD_DATE
};


////////////////////   CLOCKS   ///////////////////

wire clk_hdmi;
wire clk_24M;
wire clk_sys = clk_24M;

pll pll
(
	.rst(0),
	.refclk(CLK_50M),
	.outclk_0(clk_hdmi),
	.outclk_1(clk_24M)
);

///////////////////////////////////////////////////

wire [31:0] status;
wire  [1:0] buttons;
wire        forced_scandoubler;
wire [21:0] gamma_bus;

wire				ioctl_download;
wire				ioctl_upload;
wire				ioctl_wr;
wire	[7:0]		ioctl_index;
wire	[24:0]	ioctl_addr;
wire	[7:0]		ioctl_din;
wire	[7:0]		ioctl_dout;

wire [15:0] joystk1_USB, joystk2_USB;

// CO S2 S1 F1 U D L R 
wire [31:0] joystk1 = joydb_1ena ? {joydb_1[11]|(joydb_1[10]&joydb_1[5]),joydb_1[9],joydb_1[10],joydb_1[4:0]} : joystk1_USB;
wire [31:0] joystk2 = joydb_2ena ? {joydb_2[11]|(joydb_2[10]&joydb_2[5]),joydb_2[10],joydb_2[9],joydb_2[4:0]} : joydb_1ena ? joystk1_USB : joystk2_USB;

wire [15:0] joydb_1 = JOY_FLAG[2] ? JOYDB9MD_1 : JOY_FLAG[1] ? JOYDB15_1 : '0;
wire [15:0] joydb_2 = JOY_FLAG[2] ? JOYDB9MD_2 : JOY_FLAG[1] ? JOYDB15_2 : '0;
wire        joydb_1ena = |JOY_FLAG[2:1]              ;
wire        joydb_2ena = |JOY_FLAG[2:1] & JOY_FLAG[0];

//----BA 9876543210
//----MS ZYXCBAUDLR
reg [15:0] JOYDB9MD_1,JOYDB9MD_2;
joy_db9md joy_db9md
(
  .clk       ( CLK_JOY    ), //40-50MHz
  .joy_split ( JOY_SPLIT  ),
  .joy_mdsel ( JOY_MDSEL  ),
  .joy_in    ( JOY_MDIN   ),
  .joystick1 ( JOYDB9MD_1 ),
  .joystick2 ( JOYDB9MD_2 )	  
);

//----BA 9876543210
//----LS FEDCBAUDLR
reg [15:0] JOYDB15_1,JOYDB15_2;
joy_db15 joy_db15
(
  .clk       ( CLK_JOY   ), //48MHz
  .JOY_CLK   ( JOY_CLK   ),
  .JOY_DATA  ( JOY_DATA  ),
  .JOY_LOAD  ( JOY_LOAD  ),
  .joystick1 ( JOYDB15_1 ),
  .joystick2 ( JOYDB15_2 )	  
);

hps_io #(.STRLEN($size(CONF_STR)>>3)) hps_io
(
	.clk_sys(clk_sys),
	.HPS_BUS(HPS_BUS),

	.conf_str(CONF_STR),

	.buttons(buttons),
	.status(status),
	.forced_scandoubler(forced_scandoubler),
	.gamma_bus(gamma_bus),

	.ioctl_download(ioctl_download),
	.ioctl_upload(ioctl_upload),
	.ioctl_wr(ioctl_wr),
	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_dout),
	.ioctl_din(ioctl_din),
	.ioctl_index(ioctl_index),

	.joystick_0(joystk1_USB),
	.joystick_1(joystk2_USB),
	.joy_raw(joydb_1[5:0]),
);


wire bCabinet  = 1'b0;	// (upright only)

wire m_up2     = joystk2[3];
wire m_down2   = joystk2[2];
wire m_left2   = joystk2[1];
wire m_right2  = joystk2[0];
wire m_trig2   = joystk2[4];

wire m_start1  = joystk1[5] | joystk2[5] ;
wire m_start2  = joystk1[6] | joystk2[6] ;

wire m_up1     = joystk1[3] | (bCabinet ? 1'b0 : m_up2);
wire m_down1   = joystk1[2] | (bCabinet ? 1'b0 : m_down2);
wire m_left1   = joystk1[1] | (bCabinet ? 1'b0 : m_left2);
wire m_right1  = joystk1[0] | (bCabinet ? 1'b0 : m_right2);
wire m_trig1   = joystk1[4] | (bCabinet ? 1'b0 : m_trig2);

wire m_coin1   = joystk1[7];
wire m_coin2   = joystk2[7];
wire m_pause   = joystk1[8] | joystk2[8];

// PAUSE SYSTEM
wire				pause_cpu;
wire [11:0]		rgb_out;
pause #(4,4,4,24) pause (
	.*,
	.reset(iRST),
	.user_button(m_pause),
	.pause_request(hs_pause),
	.options(~status[26:25])
);

///////////////////////////////////////////////////

wire hblank, vblank;
wire ce_vid;
wire hs, vs;
wire [3:0] r,g,b;

reg ce_pix;
always @(posedge clk_hdmi) begin
	reg old_clk;
	old_clk <= ce_vid;
	ce_pix  <= old_clk & ~ce_vid;
end

arcade_video #(288,12) arcade_video
(
	.*,

	.clk_video(clk_hdmi),

	.RGB_in(rgb_out),
	.HBlank(hblank),
	.VBlank(vblank),
	.HSync(~hs),
	.VSync(~vs),

	.fx(0)
);

wire			PCLK;
wire  [8:0] HPOS,VPOS;
wire [11:0] POUT;
HVGEN hvgen
(
	.HPOS(HPOS),.VPOS(VPOS),.PCLK(PCLK),.iRGB(POUT),
	.oRGB({b,g,r}),.HBLK(hblank),.VBLK(vblank),.HSYN(hs),.VSYN(vs)
);
assign ce_vid = PCLK;


wire [15:0] AOUT;
assign AUDIO_L = AOUT;
assign AUDIO_R = AUDIO_L;
assign AUDIO_S = 0; // unsigned PCM


///////////////////////////////////////////////////

wire			rom_download = ioctl_download & !ioctl_index;
wire			iRST  = RESET | status[0] | buttons[1] | rom_download;

wire  [7:0] iDSW  = ~{ 2'b00, status[10:8], status[12:11], status[15] };
wire  [7:0] iCTR1 = ~{ m_coin1, m_start1, m_up1, m_down1, m_right1, m_left1, m_trig1, 1'b0 };
wire  [7:0] iCTR2 = ~{ m_coin2, m_start2, m_up2, m_down2, m_right2, m_left2, m_trig2, bCabinet };

wire  [7:0] oPIX;
wire  [7:0] oSND;

fpga_NRX GameCore ( 
	.RESET(iRST),.CLK24M(clk_24M),
	.HP(HPOS),.VP(VPOS),.PCLK(PCLK),
	.POUT(oPIX),.SND(oSND),
	.DSW(iDSW),.CTR1(iCTR1),.CTR2(iCTR2),
	
	.ROMCL(clk_sys),.ROMAD(ioctl_addr),.ROMDT(ioctl_dout),.ROMEN(ioctl_wr & rom_download),

	.pause(pause_cpu),

	.hs_address(hs_address),
	.hs_data_in(hs_data_in),
	.hs_data_out(ioctl_din),
	.hs_write(hs_write),
	.hs_access(hs_access)
);

// HISCORE SYSTEM
wire [15:0]hs_address;
wire [7:0]hs_data_in;
wire hs_write;
wire hs_access;
wire hs_pause;

hiscore #(
	.HS_ADDRESSWIDTH(16),
	.HS_SCOREWIDTH(5),
	.CFG_ADDRESSWIDTH(2),
	.CFG_LENGTHWIDTH(2)
) hi (
	.clk(clk_sys),
	.reset(iRST),
	.ioctl_upload(ioctl_upload),
	.ioctl_download(ioctl_download),
	.ioctl_wr(ioctl_wr),
	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_dout),
	.ioctl_din(ioctl_din),
	.ioctl_index(ioctl_index),
	.ram_address(hs_address),
	.data_to_ram(hs_data_in),
	.ram_write(hs_write),
	.ram_access(hs_access),
	.pause_cpu(hs_pause)
);

assign POUT = {oPIX[7:6],2'b00,oPIX[5:3],1'b0,oPIX[2:0],1'b0};
assign AOUT = {oSND,8'h0};

endmodule


module HVGEN
(
	output  [8:0]		HPOS,
	output  [8:0]		VPOS,
	input 				PCLK,
	input	 [11:0]		iRGB,

	output reg [11:0]	oRGB,
	output reg			HBLK = 1,
	output reg			VBLK = 1,
	output reg			HSYN = 1,
	output reg			VSYN = 1
);

reg [8:0] hcnt = 0;
reg [8:0] vcnt = 0;

assign HPOS = hcnt;
assign VPOS = vcnt;

always @(posedge PCLK) begin
	case (hcnt)
		288: begin HBLK <= 1; hcnt <= hcnt+1; end
		311: begin HSYN <= 0; hcnt <= hcnt+1; end
		342: begin HSYN <= 1; hcnt <= 471;    end
		511: begin HBLK <= 0; hcnt <= 0;
			case (vcnt)
				223: begin VBLK <= 1; vcnt <= vcnt+1; end
				226: begin VSYN <= 0; vcnt <= vcnt+1; end
				233: begin VSYN <= 1; vcnt <= 483;	  end
				511: begin VBLK <= 0; vcnt <= 0;		  end
				default: vcnt <= vcnt+1;
			endcase
		end
		default: hcnt <= hcnt+1;
	endcase
	oRGB <= (HBLK|VBLK) ? 12'h0 : iRGB;
end

endmodule

