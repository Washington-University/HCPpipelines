#--------------------------------------
#@# SubCort Seg Thu Apr 19 19:18:26 CDT 2012

 mri_ca_label -align -nobigventricles norm.mgz transforms/talairach.m3z /usr/local/bin/freesurfer/average//RB_all_2008-03-26.gca aseg.auto_noCCseg.mgz 


 mri_cc -aseg aseg.auto_noCCseg.mgz -o aseg.auto.mgz -lta /media/myelin/brainmappers/MyelinMapping_Project/Templates/ChimpYerkes29/mri/transforms/cc_up.lta ChimpYerkes29 

#--------------------------------------
#@# Merge ASeg Thu Apr 19 19:32:37 CDT 2012

 cp aseg.auto.mgz aseg.mgz 

