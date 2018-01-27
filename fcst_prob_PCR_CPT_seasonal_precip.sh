#! /bin/bash
#Script to automate the download of NMME seasonal rainfall deterministic hindcasts and observations, 
#and to execute CPT to assess associated raw skill
#Author: Á.G. Muñoz (agmunoz@iri.columbia.edu)
#
#Output:
# + Several skill maps for assessment of deterministic forecast, in the output folder.
# + CPT scripts used to assess skill, in the scripts folder.
# + Downloaded input files, in the input folder.
#Notes:
# + Old data in the input folder is deleted at the beginning of the process!
# + User needs to know how many EOFs to use for PCR.
# + Rainfall observations are CPC Unified (Chen et al 2008).
# + Cross-validation windows is set to be 3 yrs.

####START OF USER-MODIFIABLE SECTION##########################################################################

#Initialization month(s) -modify as needed:
#declare -a mon=('Jan' 'Feb' 'Mar' 'Apr' 'May' 'Jun' 'Jul' 'Aug' 'Sep' 'Oct' 'Nov' 'Dec')
declare -a mon=('Jan')  #if just a particular month is desired
#Target months
declare -a tgti=('1.5')   #S: start for the DL
declare -a tgtf=('3.5')   #S: end for the DL 
declare -a tgt=('Feb-Apr') #just write the target period(s) (for DL) for each init
#Initial and end years (hindcasts) and length of training period
iyear=1982  #typically 1982 for NMME models (must be [1982,2010])
fyear=2018  #typically last year available (must be [2011,today])
lent=30     #length of training period
#Start year to forecast (don't change for now)
fsyear=2018
#Number of years to forecast (don't change for now)
nyear=1
#Spatial domain for predictor
nla1=29 # Nothernmost latitude
sla1=23 # Southernmost latitude
wlo1=82 # Westernmost longitude
elo1=90 # Easternmost longitude
#Spatial domain for predictand
nla2=27 # Nothernmost latitude
sla2=24 # Southernmost latitude
wlo2=83 # Westernmost longitude
elo2=88 # Easternmost longitude
#Maximum number of EOFs for predictand: (minimum is always 1 in this script)
nEOF=6
#PATH to CPT root directory
cptdir='/Users/agmunoz/Documents/Angel/CPT/CPT/15.7.3/'

####END OF USER-MODIFIABLE SECTION############################################################################
####DO NOT CHANGE ANYTHING BELOW THIS LINE####

clear
echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
echo Script to automate the download of NMME seasonal rainfall deterministic hindcasts and observations,
echo and to execute CPT to assess associated raw skill
echo Author: Á.G. Muñoz - agmunoz@iri.columbia.edu
echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
echo
echo
#Prepare folders
echo Creating working folders, if not already there...
mkdir -p input
mkdir -p output
mkdir -p scripts
rm -Rf input/model_*.tsv input/obs_*.tsv  #comment if deletion of old input files is not desired.
rm -Rf scripts/*

cd input      
#Set up some parameters
export CPT_BIN_DIR=${cptdir}

#Start loop 
for mo in "${mon[@]}"
do
#Download hindcasts and forecasts
url='http://iridl.ldeo.columbia.edu/SOURCES/.Models/.NMME/.CMC1-CanCM3/.HINDCAST/.MONTHLY/.prec/S/%280000%201%20'${mo}'%20'${iyear}'-2010%29/VALUES/SOURCES/.Models/.NMME/.CMC1-CanCM3/.FORECAST/.MONTHLY/.prec/S/%280000%201%20'${mo}'%202011-'${fyear}'%29/VALUES/appendstream/L/%28'${tgti}'%29/%28'${tgtf}'%29/RANGEEDGES/%5BL%5D//keepgrids/average/%5BM%5D/average/Y/%28'${sla1}'%29/%28'${nla1}'%29/RANGEEDGES/X/%28'${wlo1}'%29/%28'${elo1}'%29/RANGEEDGES/-999/setmissing_value/%5BX/Y%5D%5BL/S/add%5D/cptv10.tsv'
echo $url
echo ---------------------------------------------------
echo Downloading hindcasts and forecasts for $tgt initialized in $mo ...
curl -k ''$url'' > model_precip_${tgt}_ini${mon}.tsv

#Download observations
url='http://iridl.ldeo.columbia.edu/SOURCES/.Models/.NMME/.CPC-CMAP-URD/prate/T/%28Jan%20'${iyear}'%29/%28Dec%20'${fyear}'%29/RANGE/T/3/runningAverage/T/%28'${tgt}'%29/VALUES/Y/%28'${sla2}'%29/%28'${nla2}'%29/RANGEEDGES/X/%28'${wlo2}'%29/%28'${elo2}'%29/RANGEEDGES/-999/setmissing_value/%5BX/Y%5D%5BT%5Dcptv10.tsv'
echo $url
echo ---------------------------------------------------
echo Downloading observations for $tgt initialized in $mo ...
curl -k ''$url'' > obs_precip_${tgt}.tsv


#Create CPT script
cd ../scripts
echo ---------------------------------------------------
echo Producing CPT scripts for $tgt initialized in $mo ...

  
cat  <<< '#!/bin/bash 
'${cptdir}'CPT.x <<- END
612 # Opens PCR
1 # Opens X input file
../input/model_precip_'${tgt}'_ini'${mon}'.tsv
'${nla1}' # Nothernmost latitude
'${sla1}' # Southernmost latitude
'${wlo1}' # Westernmost longitude
'${elo1}' # Easternmost longitude
1 		  # Minimum number of modes
'${nEOF}' # Maximum number of modes

2 # Opens Y input file
../input/obs_precip_'${tgt}'.tsv
'${nla2}' # Nothernmost latitude
'${sla2}' # Southernmost latitude
'${wlo2}' # Westernmost longitude
'${elo2}' # Easternmost longitude

4 # X training period
'${iyear}' # First year of X training period
5 # Y training period
'${iyear}' # First year of Y training period
6 # Forecast period settings
'${fsyear}' 
9 # Number of forecasts
'${nyear}'

531 # Goodness index
3 # Kendalls tau

7 # Option: Lenght of training period
'${lent}' # Lenght of training period 
8 # Option: Length of cross-validation window
3 # Enter length

541 # Turn ON Transform predictand data
542 # Turn ON zero bound for Y data
545 # Turn ON synchronous predictors
#561 # Turn ON p-values for skill maps

544 # Missing value options
-999 # Missing value X flag:
10 # Maximum % of missing values
10 # Maximum % of missing gridpoints
1 # Number of near-neighbours
4 # Missing value replacement : best-near-neighbours
-999 # Y missing value flag
10 # Maximum % of missing values
10 # Maximum % of missing stations
1 # Number of near-neighours
4 # Best near neighbour

#554 # Transformation seetings
#1   #Empirical distribution


# Cross-validation
112 # save goodness index
../output/PRCP_Kendallstau_raw_'${tgt}'_ini'${mon}'.txt

#######BUILD MODEL AND VALIDATE IT  !!!!!
311 # Cross-validation

#131 # select output format
#3 # GrADS format
# Save forecast results
#111 # output results
# save as GrADS

413 # cross-validated skill maps
2 # save Spearmans Correlation
../output/PRCP_Spearman_raw_'${tgt}'_ini'${mon}'.txt

413 # cross-validated skill maps
3 # save 2AFC score
../output/PRCP_2AFC_raw_'${tgt}'_ini'${mon}'.txt

413 # cross-validated skill maps
10 # save 2AFC score
../output/PRCP_RocBelow_raw_'${tgt}'_ini'${mon}'.txt

413 # cross-validated skill maps
11 # save 2AFC score
../output/PRCP_RocAbove_raw_'${tgt}'_ini'${mon}'.txt

#######FORECAST(S)  !!!!!
455 # Probabilistic (3 categories) maps

111 # Output results
501 # Forecast probabilities
../output/PRCP_PCRFCST_PROB_'${tgt}'_ini'${mon}'.txt
#502 # Forecast odds
0 #Exit submenu

0 # Stop saving  (not needed in newest version of CPT)

0 # Exit
END
' > PCRForecast_precip_${tgt}_ini${mon}.cpt 

#Execute CPT and produce skill maps
echo ---------------------------------------------------
echo Executing CPT and producing skill maps for $mo ...
chmod 755 PCRForecast_precip_${tgt}_ini${mon}.cpt  
./PCRForecast_precip_${tgt}_ini${mon}.cpt 

cd ../input

echo Done with $tgt initialized in $mo !! Check output folder for results.
echo
echo
done