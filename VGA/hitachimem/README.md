# Hitachi Memory Simulation

This is an RTL interface for the off-chip memory chip we are using, the HITACHI HM62256LP-70

Documentation: https://www.jameco.com/Jameco/Products/ProdDS/82472.pdf

Known limitations:
- NO same-cycle read from write
- maximal throughput of 8 bits every 6 cycles
