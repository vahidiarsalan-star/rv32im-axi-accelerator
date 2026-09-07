// Timing constraints for Tang Primer 20K (GW2A-18C / GW2A-LV18PG256C8/I7)
// 27 MHz input clock on pin H11 -> 37.037 ns period
create_clock -name clk -period 37.037 -waveform {0 18.518} [get_ports {clk}]
