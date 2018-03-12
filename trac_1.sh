#!/bin/bash

list=$1
N=`wc ${1} | awk '{print $1}'`
threads=128
#threadsX2=$((${threads}*2))

fto=/lus/theta-fs0/projects/AD_Brain_Imaging/anal/FTO
code=/lus/theta-fs0/projects/AD_Brain_Imaging/anal/FTO/code_fto
data=/lus/theta-fs0/projects/AD_Brain_Imaging/anal/FTO/DTIdata

CMD_batch=${code}/cmd1.batch.trac.${list}
rm -rf $CMD_batch

#######################################################################################################
cat<<EOC >$CMD_batch
#!/bin/bash
#COBALT -t 00:10:00
#COBALT -n $N
#COBALT --attrs mcdram=cache:numa=quad:ssds=required:ssd_size=40 
#COBALT -A AD_Brain_Imaging
#COBALT -M jiook.cha@nyspi.columbia.edu
#COBALT ATP_ENABLED=1
echo start............................................
#export n_nodes=\$COBALT_JOBSIZE
#export n_mpi_ranks_per_node=1
#export n_mpi_ranks=1
#export n_openmp_threads_per_rank=64
#export n_hyperthreads_per_core=4
EOC

#######################################################################################################
i=1
for s in `cat \${code}/\$list`
            
do
#s=`echo $SUBJECT | egrep -o '[0-9]{8}'`
CMD=/lus/theta-fs0/projects/AD_Brain_Imaging/anal/FTO/code_fto/job/cmd1.trac.t${threads}.${s}
rm -rf $CMD

LOG=/lus/theta-fs0/projects/AD_Brain_Imaging/anal/FTO/code_fto/job/log.cmd1.t${threads}.${s}
rm -rf $LOG

#CMD_sub=/lus/theta-fs0/projects/AD_Brain_Imaging/anal/HBN/code_hbn_alcf/job/cmd1_sub.trac.${s}
#rm -rf $CMD_sub


SUBJECT=${s}
#echo ${SUBJECT}

cat<<EOC >$CMD
#!/bin/bash
source ~/.bashrc
workingdir=${data}/${s}/mrtrix
mkdir -p \$workingdir
#rm -rf \$workingdir/*

cd \$workingdir

mkdir -p /local/scratch/${s}
mkdir -p /local/scratch/${s}/mrtrix

echo current folder is \`pwd\`
ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS=$threads
#%% 1. setup %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
cp -f ../dti.nii.gz ./dti.nii.gz
cp -f ../dti.bval ./dti.bval
cp -f ../dti.bvec ./dti.bvec
#%% 2. DWI processing2-converting nifti to mif%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
rm -rf *nii
# 1. mrconvert
#if [ ! -e mr_dwi.mif.gz ];then
    echo mrconvert
    time mrconvert dti.nii.gz -force mr_dwi.mif.gz -fslgrad dti.bvec dti.bval \
            -datatype float32 -stride 0,0,0,1 -nthreads ${threads} 
sleep 0.1
    #pigz --fast -b 1280 -force mr_dwi.mif
#fi
# 2. denoising (time:1m)
#if [ ! -e mr_dwi_denoised.mif.gz ];then
    echo dwidenoise
    time dwidenoise mr_dwi.mif.gz -force mr_dwi_denoised.mif.gz -nthreads ${threads} 
 sleep 0.1
   #pigz --fast -b 1280 -force mr_dwi_denoised.mif
#fi
# 3. gibss ringing (time:0.5m)
#if [ ! -e mr_dwi_denoised_gibbs.mif.gz ];then
    echo mrdegibss
    time mrdegibbs mr_dwi_denoised.mif.gz mr_dwi_denoised_gibbs.mif.gz -force -nthreads ${threads} 
sleep 0.1
    #pigz --fast -b 1280 -force mr_dwi_denoised_gibbs.mif
#fi
# 4. dwipreproc -eddy current (time:33m)
#if [ ! -e mr_dwi_denoised_gibbs_crop_preproc.mif.gz ];then
    #mrcat dwi_fmap_AP.nii.gz dwi_fmap_PA.nii.gz b0s.mif.gz -force -axis 3 -nthreads ${threads} 
    #pigz --fast -b 1280 -force b0s.mif
    
 #   dim2=\`mrinfo mr_dwi_denoised_gibbs.mif.gz | grep "x 81 x"\`
 #   str=\${dim2}str
 #   if [ "\${str}" = str ];then echo "##########nocropping needed###########"
#		cp b0s.mif.gz b0s_crop.mif.gz
#		cp mr_dwi_denoised_gibbs.mif.gz mr_dwi_denoised_gibbs_crop.mif.gz 
#    else mrcrop b0s.mif.gz b0s_crop.mif.gz -axis 2 1 80 -force -quiet -nthreads ${threads}
#sleep 0.1
#         mrcrop mr_dwi_denoised_gibbs.mif.gz mr_dwi_denoised_gibbs_crop.mif.gz -axis 2 1 80 -nthreads ${threads}
#sleep 0.1
#    fi 

    time dwipreproc mr_dwi_denoised_gibbs.mif.gz mr_dwi_denoised_gibbs_preproc.mif.gz \
	-pe_dir AP \
	-rpe_none \
	-eddy_options " --repol " \
	-nthreads ${threads} \
	-nocleanup -force 
 
 sleep 0.1
 
  #pigz --fast -b 1280 -f mr_dwi_denoised_gibbs_crop_preproc.mif
##########-readout_time 0.0691181 \#############??????????????????????????????\
#fi
# 5. mask 
#if [ ! -e mr_eroded_mask.mif.gz ]; then
     dwiextract mr_dwi_denoised_gibbs_preproc.mif.gz - -bzero -nthreads ${threads} | mrmath - mean \
                -force mr_meanb0_nonbiascorr.mif.gz -axis 3 -quiet -nthreads ${threads} 
sleep 0.1
     #pigz --fast -b 1280 -f mr_meanb0_nonbiascorr.mif
     mrconvert mr_meanb0_nonbiascorr.mif.gz mr_meanb0_nonbiascorr.nii.gz -force -quiet -nthreads ${threads}
sleep 0.1
     #pigz --fast -b 1280 -f mr_meanb0_nonbiascorr.nii
     bet2 mr_meanb0_nonbiascorr mr_meanb0_nonbiascorr_bet2 -m -f 0.1 -v
sleep 0.1
     
     dwi2mask mr_dwi_denoised_gibbs_preproc.mif.gz mr_dwi_mask.mif.gz -force -nthreads ${threads} 
            #pigz --fast -b 1280 -f mr_dwi_mask.mif
            
     dwi2mask mr_dwi_denoised_gibbs_preproc.mif.gz - -nthreads ${threads} -quiet | maskfilter - erode \
     -npass 3 -force mr_eroded_mask.mif.gz -quiet -nthreads ${threads}
sleep 0.1
            #pigz --fast -b 1280 -f mr_eroded_mask.mif
#fi
#%% 6. bias field correction (time: 0.5m)
#if [ ! -e mr_dwi_denoised_gibbs_crop_preproc_biasCorr.mif.gz ]; then
     echo dwibiascorrect
     time dwibiascorrect mr_dwi_denoised_gibbs_preproc.mif.gz -force mr_dwi_denoised_gibbs_preproc_biasCorr.mif.gz \
     	-ants -nthreads ${threads} -mask mr_meanb0_nonbiascorr_bet2_mask.nii.gz 
sleep 0.1
            #pigz --fast -b 1280 -f mr_dwi_denoised_gibbs_crop_preproc_biasCorr.mif
     mrconvert mr_meanb0_nonbiascorr_bet2_mask.nii.gz mr_meanb0_nonbiascorr_bet2_mask.mif.gz -force -nthreads ${threads}
sleep 0.1
            #pigz --fast -b 1280 -f mr_meanb0_nonbiascorr_bet2_mask.mif
#fi
#%% 7. generating b0 %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
#if [ ! -e mr_meanb0.mif.gz ];then
     dwiextract mr_dwi_denoised_gibbs_preproc_biasCorr.mif.gz - -bzero -quiet -nthreads ${threads} | mrmath - mean \
     	-force mr_meanb0.mif.gz -axis 3 -quiet -nthreads ${threads} 
sleep 0.1
     mrconvert mr_meanb0.mif.gz mr_meanb0.nii.gz -force -quiet -nthreads ${threads}
  sleep 0.1
   
     bet2 mr_meanb0 mr_meanb0_bet -m -f 0.2
sleep 0.1
     
     mrresize mr_meanb0_bet.nii.gz -voxel 1.25 mr_meanb0_bet_upsample125.nii.gz \
     	-force -interp sinc -nthreads ${threads} -quiet
sleep 0.1
     mrresize mr_meanb0_bet_mask.nii.gz -voxel 1.25 mr_meanb0_bet_mask_upsample125.nii.gz \
     	-force -interp sinc -nthreads ${threads} -quiet
sleep 0.1
     
     #&& pigz --fast -b 1280 -f mr_meanb0.mif
#fi
#% make sure to use "DILATED MASK" for FOD generation
#if [ ! -e mr_dilate_mask.mif.gz ];then
#    dwi2mask mr_dwi_denoised_gibbs_crop_preproc_biasCorr.mif - -nthreads 256 
#fi
#%% 8. upsampling %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
for im in mr_dwi_denoised_gibbs_preproc_biasCorr mr_meanb0_nonbiascorr_bet2_mask mr_meanb0;
do 
     	mrresize \${im}.mif.gz -voxel 1.25 -force \${im}_upsample125.mif.gz -interp sinc -nthreads ${threads} -quiet
sleep 0.1
done
#% make sure to use "DILATED MASK" for FOD generation
#if [ ! -e mr_dilate_mask.mif.gz ];then
    dwi2mask mr_dwi_denoised_gibbs_preproc_biasCorr_upsample125.mif.gz - -quiet -nthreads ${threads} | \
    maskfilter - dilate -npass 3 mr_dilate_mask_upsample125.mif.gz -force -quiet -nthreads ${threads} 
            #&& pigz --fast -b 1280 -f mr_dilate_mask_upsample125.mif
sleep 0.1
    
    dwi2mask mr_dwi_denoised_gibbs_preproc_biasCorr_upsample125.mif.gz mr_mask_upsample125.mif.gz \
    	-nthreads ${threads} -force 
            #pigz --fast -b 1280 -f mr_mask_upsample125.mif
sleep 0.1
    
    mrconvert mr_dwi_denoised_gibbs_preproc_biasCorr_upsample125.mif.gz \
            mr_dwi_denoised_gibbs_preproc_biasCorr_upsample125.nii.gz -force -nthreads ${threads}
sleep 0.1
    
    bet2 mr_dwi_denoised_gibbs_preproc_biasCorr_upsample125 \
            mr_dwi_denoised_gibbs_preproc_biasCorr_upsample125_bet2 -m -f 0.2 -v
sleep 0.1
#fi
##########################################################################################################################################
##################Preparation for 5TT using freesurfer APARC+ASEG ############################################################
echo ***** NOW 5TTGEN *****
SUBJECT=${s}
workingdir2=/lus/theta-fs0/projects/AD_Brain_Imaging/anal/HBN/fs/${s}/freesurfer/mri
workingdir2=/lus/theta-fs0/projects/AD_Brain_Imaging/anal/FTO/DTIdata/${s}/WMtrack
#workingdir3=/lus/theta-fs0/projects/AD_Brain_Imaging/anal/HBN/fs/${s}/anat
#cd /lus/theta-fs0/projects/AD_Brain_Imaging/anal/adni/fs/\${SUBJECT}/dmri2
#mkdir xfm
### flirt 
echo *****NOW GENERATING ANAT2DIFF.FLT.MAT *****
mrconvert \$workingdir2/brain.mgz brain.nii.gz -stride -1,2,3 -force
sleep 0.1
mrconvert \$workingdir2/aparc+aseg.mgz aparc+aseg.nii.gz -stride -1,2,3 -force
sleep 0.1
mrconvert \$workingdir2/aparc.a2009s+aseg.mgz aparc.a2009s+aseg.nii.gz -stride -1,2,3 -force
sleep 0.1
#mrconvert \$workingdir2/brain.mgz brain_anat_orig.nii.gz && orientLAS brain_anat_orig.nii.gz brain_anat.nii.gz 
#mrconvert mr_meanb0_upsample125.mif.gz mr_meanb0_upsample125.nii.gz -nthreads ${threads} -force && \
#            bet2 mr_meanb0_upsample125 mr_meanb0_upsample125_brain -v
#1. rigid transformation
flirt -in brain -ref mr_meanb0_bet -out brain2diff_flt_dof6 -omat brain2diff_dof6.flt.mat -v -dof 6
sleep 0.1
#2. ants nonlinear warping
/lus/theta-fs0/projects/AD_Brain_Imaging/anal/FTO/code_fto/antswarp \
	brain2diff_flt_dof6 mr_meanb0_bet
sleep 0.1
#3. 5ttgen
time 5ttgen freesurfer aparc+aseg.nii.gz 5tt_freesurfer.nii.gz -nocrop -sgm_amyg_hipp -force -nthreads ${threads} 
sleep 0.1

#4. registering 5ttgen into meanb0-linear
flirt -in 5tt_freesurfer -ref mr_meanb0_bet -out 5tt_freesurfer_diff_flt_dof6 \
	-applyxfm -init brain2diff_dof6.flt.mat -v -interp nearestneighbour
sleep 0.1
#4. registering 5ttgen into meanb0-nonlinear
fslsplit 5tt_freesurfer_diff_flt_dof6.nii.gz tmp_5tt -t 
sleep 0.1
for i in `seq 0 4`;
do
WarpImageMultiTransform 3 tmp_5tt000${i}.nii.gz tmp_5tt000${i}_warped.nii.gz --use-NN \
	-R mr_meanb0_bet.nii.gz brain2diff_flt_dof62mr_meanb0_bet_synantsWarp.nii.gz brain2diff_flt_dof62mr_meanb0_bet_synantsAffine.txt	    
sleep 0.1
done 
fslmerge -t 5tt_freesurfer_diff_flt_dof6_warped_synant `imglob tmp_5tt000*_warped.nii.gz`
#upsample to 1.25
sleep 0.1
mrresize 5tt_freesurfer_diff_flt_dof6_warped_synant.nii.gz -voxel 1.25 5tt_freesurfer_diff_flt_dof6_warped_synant_upsample125.nii.gz \
	-force -nthreads ${threads} -interp nearest
sleep 0.1
ln -sf 5tt_freesurfer_diff_flt_dof6_warped_synant_upsample125.nii.gz 5tt_diff_upsample125.nii.gz
sleep 0.1
#5. also registering aparc/aseg files
#5-1. flirt rigid
flirt -in aparc+aseg -ref mr_meanb0_bet -out aparc+aseg_diff_flt_dof6 \
	-applyxfm -init brain2diff_dof6.flt.mat -v -interp nearestneighbour
sleep 0.1
flirt -in aparc.a2009s+aseg -ref mr_meanb0_bet -out aparc.a2009s+aseg_diff_flt_dof6 \
	-applyxfm -init brain2diff_dof6.flt.mat -v -interp nearestneighbour
sleep 0.1
#5-2. antswarp
WarpImageMultiTransform 3 aparc+aseg_diff_flt_dof6.nii.gz aparc+aseg_diff_flt_dof6_warped_synant.nii.gz --use-NN \
	-R mr_meanb0_bet.nii.gz brain2diff_flt_dof62mr_meanb0_bet_synantsWarp.nii.gz brain2diff_flt_dof62mr_meanb0_bet_synantsAffine.txt	    
sleep 0.1
WarpImageMultiTransform 3 aparc.a2009s+aseg_diff_flt_dof6.nii.gz aparc.a2009s+aseg_diff_flt_dof6_warped_synant.nii.gz --use-NN \
	-R mr_meanb0_bet.nii.gz brain2diff_flt_dof62mr_meanb0_bet_synantsWarp.nii.gz brain2diff_flt_dof62mr_meanb0_bet_synantsAffine.txt
sleep 0.1
#5-3 upsample them
mrresize aparc+aseg_diff_flt_dof6_warped_synant.nii.gz -voxel 1.25 aparc+aseg_diff_flt_dof6_warped_synant_upsample125.nii.gz \
	-force -nthreads ${threads} -interp nearest
sleep 0.1
mrresize aparc.a2009s+aseg_diff_flt_dof6_warped_synant.nii.gz -voxel 1.25 aparc.a2009s+aseg_diff_flt_dof6_warped_synant_upsample125.nii.gz \
	-force -nthreads ${threads} -interp nearest
sleep 0.1
#5tt2gmwmi and label 
5tt2gmwmi 5tt_diff_upsample125.nii.gz -force 5tt_diff_upsample125_gmwmi_mask.mif.gz -force -nthreads ${threads}
sleep 0.1
labelconvert aparc+aseg_diff_flt_dof6_warped_synant_upsample125.nii.gz $FREESURFER_HOME/FreeSurferColorLUT.txt \
	/lus/theta-fs0/projects/AD_Brain_Imaging/app/mrtrix3/share/mrtrix3/labelconvert/fs_default.txt \
	nodes_aparc+aseg.mif.gz -force
sleep 0.1
labelconvert aparc.a2009s+aseg_diff_flt_dof6_warped_synant_upsample125.nii.gz $FREESURFER_HOME/FreeSurferColorLUT.txt \
	/lus/theta-fs0/projects/AD_Brain_Imaging/app/mrtrix3/share/mrtrix3/labelconvert/fs_default.txt \
	nodes_aparc+aseg.mif.gz -force	
sleep 0.1
#flirt -in brain_anat -ref mr_meanb0_nonbiascorr_bet2 -out brain_anat2diff -omat anat2diff.flt.mat -v
### 5TTGEN#########################################
#echo ***** NOW 5TTGEN *****
#mri_convert \$workingdir3/*_T1w.nii.gz T1.nii.gz && orientLAS T1.nii.gz T1_flip.nii.gz
#cp \$workingdir3/*_T1w.nii.gz T1.nii.gz
#flirt -in T1 -out T1_2diff_upsample125_flt.nii.gz -ref mr_meanb0_upsample125_brain.nii -applyxfm -init anat2diff_upsample125.flt.mat -v
### APARC+ASEG to diff
#for im in aparc+aseg aparc.a2009s+aseg
#do
#   echo ****NOW CONVERTING MGZ TO NII
#   mri_convert \$workingdir2/\${im}.mgz \${im}.nii.gz
   
#   echo ****FLIPING FOR FSL
#   orientLAS \${im}.nii \${im}_flip.nii.gz
   
#   echo ****NOW FLIRTING
#   flirt -in \${im}_flip -out \${im}_2_diff_upsample125_flt -ref mr_meanb0_upsample125_brain \
#            -applyxfm -init anat2diff_upsample125.flt.mat -interp nearestneighbour -v 
#done
#5ttgen fsl brain_anat.nii.gz 5tt_from_brain_anat_test.nii.gz -nocrop 
#echo 5ttgen
#time 5ttgen freesurfer aparc+aseg_flip.nii.gz 5tt_freesurfer.nii.gz -nocrop -sgm_amyg_hipp -force -nthreads ${threads} 
#            sleep 0.1
#flirt -in 5tt_freesurfer -ref mr_meanb0_nonbiascorr_bet2 -out 5tt_freesurfer2diff \
#    -applyxfm -init anat2diff.flt.mat -interp nearestneighbour
#flirt -in 5tt_freesurfer -ref mr_meanb0_upsample125_brain -out 5tt_freesurfer2diff_upsample125 \
#    -applyxfm -init anat2diff_upsample125.flt.mat -interp nearestneighbour
#            sleep 0.1
#mrconvert 5tt_freesurfer2diff_upsample125.nii.gz 5tt_freesurfer2diff_upsample125.mif.gz -force -nthreads ${threads} 
#            sleep 0.1
#cp 5tt_freesurfer2diff.nii.gz 5tt2.nii.gz
#sleep 0.2
#cp 5tt_freesurfer2diff.mif.gz 5tt2.mif.gz
#sleep 0.2
##########################################################################################################################################
##########################################################################################################################################
#%% 9. dwi2response-subject level %%%%%%%%%%%  (time: 10m)
#if [ ! -e response_wm.txt ]; then
    echo dwi2response 
#    time dwi2response msmt_5tt mr_dwi_denoised_gibbs_crop_preproc_biasCorr.mif.gz 5tt_freesurfer2diff.nii.gz \
#            response_wm.txt response_gm.txt response_csf.txt \
#            -voxels response_voxels.mif.gz -force -nthreads 256
#fi
time dwi2response dhollander mr_dwi_denoised_gibbs_preproc_biasCorr.mif.gz \
            response_wm.txt response_gm.txt response_csf.txt \
            -voxels response_voxels.mif.gz -force -nthreads ${threads}
#%% FOD%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
### FOD estimation (time: 3m)
#if [ ! -e WM_FODs_upsample125.mif.gz ];then 
   echo dwi2fod
   time dwi2fod msmt_csd mr_dwi_denoised_gibbs_preproc_biasCorr_upsample125.mif.gz \
            response_wm.txt \
            WM_FODs_upsample125.mif.gz \
            response_gm.txt gm.mif.gz \
             response_csf.txt csf.mif.gz \
            -mask mr_dwi_denoised_gibbs_preproc_biasCorr_upsample125_bet2_mask.nii.gz \
            -force -nthreads ${threads} 
#fi
#if [ ! -e tissueRGB.mif.gz ]; then
   mrconvert WM_FODs_upsample125.mif.gz - -coord 3 0 -nthreads ${threads} -quiet | mrcat csf.mif.gz gm.mif.gz - tissueRGB.mif.gz -axis 3 \
            -nthreads ${threads} 
#fi
### this is crucial to make the FODs comparable across subjects### (time: 1m)
echo mtnorm
time mtnormalise WM_FODs_upsample125.mif.gz WM_FODs_upsample125_norm.mif.gz gm.mif.gz gm_norm.mif.gz csf.mif.gz csf_norm.mif.gz \
        -mask mr_dwi_denoised_gibbs_preproc_biasCorr_upsample125_bet2_mask.nii.gz -nthreads ${threads} 
    
mrconvert mr_dwi_denoised_gibbs_preproc_biasCorr_upsample125.mif.gz mr_dwi_denoised_gibbs_preproc_biasCorr_upsample125.nii.gz \
            -force -nthreads ${threads}
            
mrconvert mr_dilate_mask_upsample125.mif.gz mr_dilate_mask_upsample125.nii.gz -force -nthreads ${threads} 
dtifit -k mr_dwi_denoised_gibbs_preproc_biasCorr_upsample125.nii.gz -o dtifit \
    -m mr_dwi_denoised_gibbs_preproc_biasCorr_upsample125_bet2_mask.nii.gz -r dti.bvec -b dti.bval -V
######################################################################################################################################
######################################################################################################################################
######################################################################################################################################
######################################################################################################################################
######################################################################################################################################
######################################################################################################################################
###tckgen and connectome (time for 1M = 
#  time tckgen WM_FODs_upsample125_norm.mif.gz mr_track_20M_${s}.tck -act 5tt_freesurfer2diff_upsample125.mif.gz \
#            -backtrack -crop_at_gmwmi -seed_dynamic WM_FODs_upsample125_norm.mif.gz -angle 22.5 -maxlength 250 -minlength 10 \
#            -power 1.0 -select 20M -force -nthreads ${threads} && echo 'tckgen done'**********
#  tcksift -act 5tt_freesurfer2diff_upsample125.mif mr_track_20M_${s}.tck WM_FODs.mif mr_track_10M_SIFT_${s}.tck \
#            -term_number 10M -force -nthreads ${threads} && echo 'sift done'*******
## FA, MD, MO, AD (L1), RD (L2+L3/2)            
#tcksample mr_track_10M_SIFT.tck dtifit_FA.nii mr_track_10M_SIFT_mean_FA.csv -stat_tck mean -force -nthreads ${threads}
#tcksample mr_track_10M_SIFT.tck dtifit_MD.nii mr_track_10M_SIFT_mean_MD.csv -stat_tck mean -force -nthreads ${threads}
#tcksample mr_track_10M_SIFT.tck dtifit_MO.nii mr_track_10M_SIFT_mean_MO.csv -stat_tck mean -force -nthreads ${threads}
#tcksample mr_track_10M_SIFT.tck dtifit_L1.nii mr_track_10M_SIFT_mean_AD.csv -stat_tck mean -force -nthreads ${threads}
#            fslmaths dtifit_L2 -add dtifit_L3 -div 2 dtifit_RD
#tcksample mr_track_10M_SIFT.tck dtifit_RD.nii mr_track_10M_SIFT_mean_RD.csv -stat_tck mean -force -nthreads ${threads}
#### tck2connectome
#for im in aparc+aseg aparc.a2009s+aseg
#do
#tck2connectome -force -zero_diagonal -nthreads ${threads} \
#            mr_track_10M_SIFT_${s}.tck nodes_\${im}.mif mr_sift_10M_connectome_\${im}_count.csv
            
#tck2connectome -force -zero_diagonal -scale_length -stat_edge mean mr_track_10M_SIFT_${s}.tck nodes_\${im}.mif \
#            mr_sift_10M_connectome_\${im}_length.csv -nthreads ${threads} 
#tck2connectome -force -zero_diagonal -stat_edge mean -scale_file mr_track_10M_SIFT_mean_FA.csv -nthreads ${threads} \
#            mr_track_10M_SIFT_${s}.tck nodes_\${im}.mif.gz mr_sift_10M_connectome_\${im}_FA.csv
#tck2connectome -force -zero_diagonal -stat_edge mean -scale_file mr_track_10M_SIFT_mean_MD.csv -nthreads ${threads} \
#            mr_track_10M_SIFT_${s}.tck nodes_\${im}.mif.gz mr_sift_10M_connectome_\${im}_MD.csv
            
#tck2connectome -force -zero_diagonal -stat_edge mean -scale_file mr_track_10M_SIFT_mean_MO.csv -nthreads ${threads} \
#            mr_track_10M_SIFT_${s}.tck nodes_\${im}.mif.gz mr_sift_10M_connectome_\${im}_MO.csv
#tck2connectome -force -zero_diagonal -stat_edge mean -scale_file mr_track_10M_SIFT_mean_AD.csv -nthreads ${threads} \
#            mr_track_10M_SIFT_${s}.tck nodes_\${im}.mif.gz mr_sift_10M_connectome_\${im}_AD.csv
            
#tck2connectome -force -zero_diagonal -stat_edge mean -scale_file mr_track_10M_SIFT_mean_RD.csv -nthreads ${threads} \
#            mr_track_10M_SIFT_${s}.tck nodes_\${im}.mif.gz mr_sift_10M_connectome_\${im}_RD.csv
######################################################################################################################################
######################################################################################################################################
######################################################################################################################################
######################################################################################################################################
######################################################################################################################################
######################################################################################################################################
     
            
done
#### COPY ALL THE FILES TO SCRATCH ####
cp -rfv ../mrtrix /lus/theta-fs0/projects/AD_Brain_Imaging/anal/FTO/DTIdata/${s}/
#######################################################################
# pigz#
#pigz --best -b 1280 -f -T -p ${threads} *mif
#pigz --best -b 1280 -f -T -p ${threads} *nii
#cp -rfv \$ssd /lus/theta-fs0/projects/AD_Brain_Imaging/anal/HBN/fs/${s}
echo "I THINK EVERYTHING IS DONE BY NOW"
EOC

################################################## END OF CMD##########################################################
chmod +x $CMD

####################################################################
#cat<<EOA >$CMD_
##!/bin/bash
#COBALT -t 60
#COBALT -n 1
#COBALT --attrs mcdram=cache:numa=quad
#COBALT -A AD_Brain_Imaging
#echo start............................................
#export n_nodes=$COBALT_JOBSIZE
#export n_mpi_ranks_per_node=202
#export n_mpi_ranks=202
#export n_openmp_threads_per_rank=64
#export n_hyperthreads_per_core=4
#aprun -n 1 -N 1 -d 1 -j 4 -cc depth -e OMP_NUM_THREADS=256 -cc depth $CMD
#EOA
#####################################################################
#chmod +x $CMD_sub

### reference
#echo "aprun -n 1 -N 1 -d 128 -j 2 -cc depth -e OMP_NUM_THREADS=128 $CMD > ./job/log.tckgen.${SUBJECT} 2>&1 &">>$CMD_batch 
echo "aprun -n 1 -N 1 -d ${threads} -j $((${threads}/64)) -cc depth -e OMP_NUM_THREADS=$threads $CMD > $LOG 2>&1 &">>$CMD_batch

echo "sleep 0.2">>$CMD_batch
i=$(($i+1))
echo $i
#echo "execute $CMD_sub"

done

echo "wait" >> $CMD_batch
### batch submission

echo $CMD_batch
chmod +x $CMD_batch
qsub $CMD_batch

#$code/fsl_sub_hpc_2 -s smp,$threads -l /ifs/scratch/pimri/posnerlab/1anal/adni/adni_on_c2b2/job -t $CMD_batch
#$code/fsl_sub_hpc_6 -l /ifs/scratch/pimri/posnerlab/1anal/adni/adni_on_c2b2/job -t $CMD_batch
