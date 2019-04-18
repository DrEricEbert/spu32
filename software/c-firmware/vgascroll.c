#include <libtinyc.h>
#include <libspu32.h>
#include <stdint.h>

int main() {

    volatile uint32_t* VGA_MEM_BASE = (volatile uint32_t*) 0xFFFF0000;

    uint32_t vgabase = (64*1024);
    int32_t maxoff = (800 * 320);
    int32_t off = 0;
    int32_t dir = 320;

	while(1) {

        *VGA_MEM_BASE = (vgabase + off);
        off += dir;

        if(off == 0 && dir < 0) {
            dir = 320;
        } else if(off >= maxoff && dir > 0) {
            dir = -320;
        }

        if(dir > 0) {
            set_leds_value(0x01);
        } else {
            set_leds_value(0x80);
        }

        for(uint32_t delay = 5000; delay > 0; --delay) {
            uint32_t tmp = *VGA_MEM_BASE;
        }
	}

	return 0;
}
