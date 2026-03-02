# Hitachi Memory Simulation

This is my attempt to create a basic logic representation of the Hitachi memory bus/controller we are using.

Documentation: https://www.jameco.com/Jameco/Products/ProdDS/82472.pdf

Known limitations:
- NO same-cycle read from write
- maximal throughput of 8 bits every 6 cycles