{ The display memory: the EGA framebuffer and the CGA and Tandy display banks. }
{$I COMPILER.INC}
unit C_VIDEO;

interface

const
  { visible EGA framebuffer (planar, mode 0Dh) }
  EGA_VIDEO_SEG = $A000;
  { the VGA framebuffer (mode 13h): linear, a byte a pixel, 320 bytes a scanline }
  VGA_VIDEO_SEG = $A000;
  VGA_ROW_BYTES = 320;
  { CGA even rows / Tandy bank 0 }
  GFX_BANK0_SEG = $B800;
  { CGA odd rows / Tandy bank 1 }
  GFX_BANK1_SEG = $BA00;
  { Tandy bank 2 }
  GFX_BANK2_SEG = $BC00;
  { Tandy bank 3 }
  GFX_BANK3_SEG = $BE00;

implementation

end.
