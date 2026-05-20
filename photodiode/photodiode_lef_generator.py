WIDTH = 2754.18
HEIGHT = 2059.2

PIXEL_PITCH_X = 8.58
PIXEL_PITCH_Y = 8.58

NUM_ROWS = 240
NUM_COLS = 321

# Row signal geometry
ROW_SELECT_Y1 = 0.305
ROW_SELECT_Y2 = 0.555

RESET_Y1 = 7.425
RESET_Y2 = 7.675

VDD_Y1 = 8.025
VDD_Y2 = 8.275

# Column signal geometry
COLUMN_X1 = 7.845
COLUMN_X2 = 8.125

OUTPUT_FILE = "PIXEL_ARRAY.lef"

def write_header(f):
    f.write("VERSION 5.8 ;\n")
    f.write('BUSBITCHARS "[]" ;\n')
    f.write("DIVIDERCHAR \"/\" ;\n\n")

    f.write("MACRO PIXEL_ARRAY\n")
    f.write("  CLASS BLOCK ;\n")
    f.write("  FOREIGN PIXEL_ARRAY 0 0 ;\n")
    f.write("  ORIGIN 0 0 ;\n")
    f.write(f"  SIZE {WIDTH} BY {HEIGHT} ;\n\n")


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
            f"        RECT 0 {y1:.3f} {WIDTH:.3f} {y2:.3f} ;\n"
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
            f"        RECT 0 {y1:.3f} {WIDTH:.3f} {y2:.3f} ;\n"
        )
        f.write("    END\n")
        f.write(f"  END RESET[{row}]\n\n")


def write_vdd_pins(f):
    for row in range(NUM_ROWS):
        base_y = row * PIXEL_PITCH_Y

        y1 = base_y + VDD_Y1
        y2 = base_y + VDD_Y2

        f.write(f"  PIN VDD[{row}]\n")
        f.write("    DIRECTION INOUT ;\n")
        f.write("    USE POWER ;\n")
        f.write("    PORT\n")
        f.write("      LAYER Metal1 ;\n")
        f.write(
            f"        RECT 0 {y1:.3f} {WIDTH:.3f} {y2:.3f} ;\n"
        )
        f.write("    END\n")
        f.write(f"  END VDD[{row}]\n\n")

def write_column_output_pins(f):
    for col in range(NUM_COLS):
        base_x = col * PIXEL_PITCH_X

        x1 = base_x + COLUMN_X1
        x2 = base_x + COLUMN_X2

        f.write(f"  PIN COLUMN_OUTPUT[{col}]\n")
        f.write("    DIRECTION OUTPUT ;\n")
        f.write("    USE SIGNAL ;\n")
        f.write("    PORT\n")
        f.write("      LAYER Metal2 ;\n")
        f.write(
            f"        RECT {x1:.3f} 0 {x2:.3f} {HEIGHT:.3f} ;\n"
        )
        f.write("    END\n")
        f.write(f"  END COLUMN_OUTPUT[{col}]\n\n")


def write_footer(f):
    f.write("END PIXEL_ARRAY\n")


with open(OUTPUT_FILE, "w") as f:
    write_header(f)
    write_row_select_pins(f)
    write_reset_pins(f)
    write_vdd_pins(f)
    write_column_output_pins(f)
    write_footer(f)

print(f"Generated {OUTPUT_FILE}")
