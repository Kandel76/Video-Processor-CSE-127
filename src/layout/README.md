Running DRC on the original OPENIMAGESENSOR file for a 1x1 pixel returns the following rule violations:

# Rule DF.14\_LV: Max distance of substrate tap (PCOMP outside Nwell) from (NCOMP outside Nwell) is 20um.
# Rule CO.6: Metal1 overlap of contact >= 0.005 um.
# Rule CO.11: Contact on field oxide is forbidden.
# Rule nwell\_angle: Requires square angles for all nwell components.

Adding the nescessary COMP and SAB layers directly over NWELL returns additional violations:

SAB RULES
# Rule SB.4: Space from salicide block to contact is 0.15 um.
# Rule SB.6: Salicide block extension beyond related COMP. is 0.22µm.
# Rule SB.7: COMP extension beyond related salicide block. is 0.22µm.
# Rule SB.9: Salicide block extension beyond unsalicided Poly2. is 0.22µm.

COMP RULES
# Rule NP.5di: Extension beyond COMP: For Outside DNWELL, inside Nwell:
  ## (i) For Nwell overlap of Nplus < 0.43um. is 0.16µm.
# Rule NP.5dii: Extension beyond COMP: For Outside DNWELL, inside Nwell:
  ## (ii) For Nwell overlap of Nplus >= 0.43um. is 0.02µm.
# Rule DF.4d\_LV: Min. (Nwell overlap of NCOMP) outside DNWELL. is 0.12µm.
# Rule DF.12: COMP not covered by Nplus or Pplus is forbidden (except those COMP under marking).

Currently slowing working through each violation and altering the .py file to fix them.

Fixes:
# Rule nwell\_angle
Just removed the rounding of corners.

# Rule C0.6
Code was generating contacts on both sides of gate, despite only using and needing one contact.
Fixed by just generating one contact per transistor.

# Rule CO.11
Since COMP has not been added, a contact is just floating in nwell.
There are also contacts over via1/via2 but not over COMP.

# Rule SB.4
Made a small cutout on the SAB where the contact is located on photodiode.
