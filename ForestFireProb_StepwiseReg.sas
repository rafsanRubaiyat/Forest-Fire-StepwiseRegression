*Import the File and Create the Data Set; 
FILENAME REFFILE '/home/u62197971/611regression/Algerian_Forest_Fire.csv';

PROC IMPORT DATAFILE=REFFILE
	DBMS=CSV
	OUT=WORK.IMPORT; 
	GETNAMES=YES;
RUN; 
 
* Specify the kvalue; 
%let kvalue=10;  

*Declare random variable to have a variable for the k-value; 
data fireProbDS; 
set work.import; 
rand_var= rand("integer",1,&kvalue.); 
run; 

*check if there is any missing value in the dataset; 
proc means data=fireProbDS nmiss; 
run; 

*Declare the set of the predictor variables for the regression; 
%let predictor_vars = Temperature RainAmount FineMoisture DuffMoisture Drought InitialSpeed BuildUp WeatherIndex Wind;  

*Conduct Least square regression; 
proc reg data=fireprobds outest=LeastSquareEstimates; 
LeastSquareModel: model fireProb=&predictor_vars.;
run;  

*Conduct Stepwise Regressions and K-fold validations; 
%macro k_fold_cv(k);
ods select none; 

%do i=1 %to &k.;
 
	data trainingDS;
	set fireProbDS(where=(rand_var ne &i.));
	run;

	proc reg data=trainingDS outest=estimate; 
	regModel: model FireProb= &predictor_vars. 
		/slstay=0.05 slentry=0.05
	selection=stepwise;     
	run; 
	
	data testingDS;
 	set fireProbDS(where=(rand_var eq &i.));
	run; 

	proc score data=testingDS score=estimate out=compare type=parms;
	var &predictor_vars.; 
	run;
	
	*The FitStatistics contains the result statistics values; 
	ods output FitStatistics = fitStats&i.; 
	proc reg data=compare;
	model regModel= FireProb;
	run;
	
%end;  

*Combine all the result statistics to a single Data Set; 
data k_fold_result (drop=model dependent);
 set fitStats1-fitStats&k;
run;
ods select all; 
%mend; 

*Call the Macro;  
%k_fold_cv(&kvalue.);  


*Split the results as RMSE, R-Square and Adjusted R-Square; 
proc sql;  
create table RMSE as 
select nvalue1 as RMSE_value, avg(nvalue1) as AVG_RMSE
from k_fold_result 
where Label1='Root MSE';  
create table RSquares as 
select nvalue2 as RSquare_value, avg(nvalue2) as AVG_RSquare
from k_fold_result 
where Label2='R-Square';
create table AdjustedRSquare as 
select nvalue2 as AdjRSquare_value, avg(nvalue2) as AVG_AdjRSquare
from k_fold_result 
where Label2='Adj R-Sq';
quit;   

/***********------------------------******************/

