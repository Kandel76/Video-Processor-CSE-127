MACRO_NAME = "photodiode_layout"

# Offset calculations
OFFSET_X = -0.25
OFFSET_Y = -2.425

# Macro dimensions
WIDTH = 2754.18
HEIGHT = 2059.2

# Array dimensions
NUM_ROWS = 240
NUM_COLS = 321

PIXEL_PITCH_X = 8.58
PIXEL_PITCH_Y = 8.58

# ROW_SELECT (metal1)
ROW_SELECT_X1 = 0.00
ROW_SELECT_X2 = 0.28
ROW_SELECT_Y1 = 0.305
ROW_SELECT_Y2 = 0.555

# RESET (metal1)
RESET_X1 = 0.00
RESET_X2 = 0.28
RESET_Y1 = 8.025
RESET_Y2 = 8.275

# VDD metal1
VDD_M1_X1 = 0.00
VDD_M1_X2 = 0.28
VDD_M1_Y1 = 7.425
VDD_M1_Y2 = 7.675

# VDD metal2
VDD_M2_X1 = 5.855
VDD_M2_X2 = 6.135
VDD_M2_Y1 = 0.00
VDD_M2_Y2 = 0.28

# COLUMN_OUT (metal2)
COLUMN_X1 = 7.845
COLUMN_X2 = 8.125
COLUMN_Y1 = 0.00
COLUMN_Y2 = 0.28

# GND metal3
GND_X1 = 0.28
GND_X2 = 0.56
GND_Y1 = 7.42
GND_Y2 = 8.58

def write_header(f):
    f.write(f"MACRO {MACRO_NAME}\n")
    f.write("  CLASS BLOCK ;\n")
    f.write("  ORIGIN 0 0 ;\n")
    f.write(f"  FOREIGN {MACRO_NAME} ;\n")
    f.write(f"  SIZE {WIDTH} BY {HEIGHT} ;\n")
    f.write("  SYMMETRY X Y ;\n\n")

def tx(x):
    return x - OFFSET_X

def ty(y):
    return y - OFFSET_Y

def write_row_select_pins(f):
    for row in range(NUM_ROWS):
        base_y = row * PIXEL_PITCH_Y

        y1 = base_y + ROW_SELECT_Y1
        y2 = base_y + ROW_SELECT_Y2

        f.write(f"  PIN ROW_SELECT[{row}]\n")
        f.write("    DIRECTION INPUT ;\n")
        f.write("    USE SIGNAL ;\n")
        f.write("    PORT\n")
        f.write("      LAYER Metal1 ;\n")
        f.write(
            f"        RECT {tx(ROW_SELECT_X1):.3f} {ty(y1):.3f} "
            f"{tx(ROW_SELECT_X2):.3f} {ty(y2):.3f} ;\n"
        )
        f.write("    END\n")
        f.write(f"  END ROW_SELECT[{row}]\n\n")


def write_reset_pins(f):
    for row in range(NUM_ROWS):
        base_y = row * PIXEL_PITCH_Y

        y1 = base_y + RESET_Y1
        y2 = base_y + RESET_Y2

        f.write(f"  PIN RESET[{row}]\n")
        f.write("    DIRECTION INPUT ;\n")
        f.write("    USE SIGNAL ;\n")
        f.write("    PORT\n")
        f.write("      LAYER Metal1 ;\n")
        f.write(
            f"        RECT {tx(RESET_X1):.3f} {ty(y1):.3f} "
            f"{tx(RESET_X2):.3f} {ty(y2):.3f} ;\n"
        )
        f.write("    END\n")
        f.write(f"  END RESET[{row}]\n\n")


def write_column_out_pins(f):
    for col in range(NUM_COLS):
        base_x = col * PIXEL_PITCH_X

        x1 = base_x + COLUMN_X1
        x2 = base_x + COLUMN_X2

        f.write(f"  PIN COLUMN_OUT[{col}]\n")
        f.write("    DIRECTION OUTPUT ;\n")
        f.write("    USE SIGNAL ;\n")
        f.write("    PORT\n")
        f.write("      LAYER Metal2 ;\n")
        f.write(
            f"        RECT {tx(x1):.3f} {ty(COLUMN_Y1):.3f} "
            f"{tx(x2):.3f} {ty(COLUMN_Y2):.3f} ;\n"
        )
        f.write("    END\n")
        f.write(f"  END COLUMN_OUT[{col}]\n\n")


def write_vdd_pin(f):
    f.write("  PIN VDD\n")
    f.write("    DIRECTION INOUT ;\n")
    f.write("    USE POWER ;\n")

    # Metal1 ports (left edge)
    for row in range(NUM_ROWS):
        base_y = row * PIXEL_PITCH_Y

        y1 = base_y + VDD_M1_Y1
        y2 = base_y + VDD_M1_Y2

        f.write("    PORT\n")
        f.write("      LAYER Metal1 ;\n")
        f.write(
            f"        RECT {tx(VDD_M1_X1):.3f} {ty(y1):.3f} "
            f"{tx(VDD_M1_X2):.3f} {ty(y2):.3f} ;\n"
        )
        f.write("    END\n")

    # Metal2 ports (bottom edge)
    for col in range(NUM_COLS):
        base_x = col * PIXEL_PITCH_X

        x1 = base_x + VDD_M2_X1
        x2 = base_x + VDD_M2_X2

        f.write("    PORT\n")
        f.write("      LAYER Metal2 ;\n")
        f.write(
            f"        RECT {tx(x1):.3f} {ty(VDD_M2_Y1):.3f} "
            f"{tx(x2):.3f} {ty(VDD_M2_Y2):.3f} ;\n"
        )
        f.write("    END\n")

    f.write("  END VDD\n\n")


def write_gnd_pin(f):
    f.write("  PIN GND\n")
    f.write("    DIRECTION INOUT ;\n")
    f.write("    USE GROUND ;\n")

    for row in range(NUM_ROWS):
        base_y = row * PIXEL_PITCH_Y

        y1 = base_y + GND_Y1
        y2 = base_y + GND_Y2

        f.write("    PORT\n")
        f.write("      LAYER Metal3 ;\n")
        f.write(
            f"        RECT {tx(GND_X1):.3f} {ty(y1):.3f} "
            f"{tx(GND_X2):.3f} {ty(y2):.3f} ;\n"
        )
        f.write("    END\n")

    f.write("  END GND\n\n")


def write_obs(f):
    f.write("  OBS\n")

    for layer in ["Metal1", "Metal2", "Metal3", "Metal4", "Metal5"]:
        f.write(f"    LAYER {layer} ;\n")
        f.write(
            f"      RECT 0.03 -2.145 "
            f"{tx(WIDTH-0.28):.3f} {ty(HEIGHT-0.28):.3f} ;\n"
        )

    f.write("  END\n\n")


def write_footer(f):
    f.write(f"END {MACRO_NAME}\n")

def write_spice():
    with open(f"{MACRO_NAME}.spice", "w") as f:
        f.write(f"* Auto-generated black-box SPICE for {MACRO_NAME}\n\n")

        # Start subckt
        f.write(f".SUBCKT {MACRO_NAME}")

        # Power pins
        f.write(" VDD GND")

        # Row select pins
        for row in range(NUM_ROWS):
            f.write(f" ROW_SELECT[{row}]")

        # Reset pins
        for row in range(NUM_ROWS):
            f.write(f" RESET[{row}]")

        # Column outputs
        for col in range(NUM_COLS):
            f.write(f" COLUMN_OUT[{col}]")

        f.write("\n\n")

        # Optional dummy element so some simulators don't complain
        f.write("* Black box macro\n")

        f.write(f"\n.ENDS {MACRO_NAME}\n")


def main():
    with open(f"{MACRO_NAME}.lef", "w") as f:
        write_header(f)
        write_row_select_pins(f)
        write_reset_pins(f)
        write_column_out_pins(f)
        write_vdd_pin(f)
        write_gnd_pin(f)
        write_obs(f)
        write_footer(f)

    write_spice()

    print(f"Generated {MACRO_NAME}.lef")
    print(f"Generate {MACRO_NAME}.spice")


if __name__ == "__main__":
    main()
