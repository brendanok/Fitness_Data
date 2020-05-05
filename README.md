
## Fitness Project

I thought it'd be interesting to start logging all my exercises to keep track and hopefully use it to improve. I [recorded](https://github.com/brendanok/Fitness_Data/blob/master/lift.csv) every single workout I did in the gym since September 2019 and used it to make a scoring metric for my workouts and a PowerBI dashboard to throw the data onto. Fitness trackers like Fitbits and Apple Watches keep track of measurable health data and you can compete with friends. I thought it'd be fun to make an algorithm that puts a score to my exercises in order to make sort of a universal measure of how well I worked out on a particular day. I made that along with the general recorded data the basis of my project. All the data powering the Power BI dashboard is housed in a personal MS SQL Server on my computer. The dashboard will only be up as long as I still have access to it (work license), but check out this [video](https://youtu.be/eMbl2M5_ISM) to see how it works. 

People motivate themselves in all sorts of ways. For me, that would be visually stimulating graphs and progress logs that show my stats. 
### Table of Contents

- [Data Collection and Manipulation](#Data-Collection-and-Manipulation)


### Data Collection and Manipulation

I recorded date, workout, reps, and sets in my phone's Notes app like this:
```
Monday 9/9/2019

squat:
130 lb - 5 reps
130 lb - 5 reps
130 lb - 5 reps
130 lb - 5 reps
130 lb - 5 reps

leg extension:
90 lb - 12 reps
90 lb - 12 reps
90 lb - 12 reps
90 lb - 12 reps
90 lb - 12 reps

Tuesday 9/10/2019

bench press:
165 lb - 5 reps
165 lb - 5 reps
...

(Cont'd)
```
Using a multitide of Excel tricks and formulas, I was able to transform all that raw data into a nice table that I saved as "lift.csv".

The columns are pretty self explanatory:

>* <b>exercise:</b> name of the workout
>* <b>lift_date:</b> date of the workout
>* <b>lb:</b> amount of lbs lifted for the set (body weight exercises are 0)
>* <b>reps:</b> number of repetitions for the set
>* <b>set:</b> which set of the workout

I also included a separate table in a file called "groups.csv" that I use for extra information regarding the workouts:

>* <b>exercise:</b> name of the workout
>* <b>first:</b> primary muscle group(s) targeted
>* <b>second:</b> seconday muscle group(s) targeted
>* <b>value_weight:</b> personal ranking of most important, difficult, well rounded workouts (higher means better rank)

I knew since this was going to be used in a dashboard, I wanted to make this easily refreshable. So thinking about the future, I decided to create a use set up Microsoft SQL Server on my computer to will drive the project:

![photo](https://raw.githubusercontent.com/brendanok/Fitness_Data/master/images/table.png)

### Querying and Analysis

In order to get started on creating a scoring algorithm, I aggregated the tables into this view called `dbo.grouplift`. I grouped everything by the exercise and the day which is how I want to score things. So on a particular day, if I did a certain amount of sets and reps of squats at this many pounds, how many points do I earn for that day? That's basically what I want for my score to answer. 

There's also a new column I created for this view called **variability**. This just tells me how many different exercise types I did in a day. So if one day I did squats and leg extension only, my variability for that day would be 2. If  I just did squats and nothing else, my variability would be 1. Here's the query for the view:
```TSQL
SELECT L.exercise, 
       L.lift_date, 
       COUNT(L.[set])                              AS num_sets, 
       SUM(L.reps)                                 AS num_reps, 
       SUM(L.lb)                                   AS num_lbs, 
       SUM(V.variability) / Count(V.variability)   AS variability, 
       SUM(G.value_weight) / Count(G.value_weight) AS value_weight 
FROM   Fitness.dbo.lift AS L 
       LEFT OUTER JOIN (SELECT TOP (100) PERCENT lift_date, 
                                                 COUNT(DISTINCT exercise) AS 
                                                    variability 
                        FROM   Fitness.dbo.lift 
                        GROUP  BY lift_date) AS V 
                    ON L.lift_date = V.lift_date 
       LEFT OUTER JOIN Fitness.dbo.groups AS G 
                    ON L.exercise = G.exercise 
GROUP BY  L.exercise, 
          L.lift_date 
```
![photo](https://raw.githubusercontent.com/brendanok/Fitness_Data/master/images/grouped.PNG)

Then, I normalized the data using min/max. I would've much preferred to use variables for this but I wasn't sure how PowerBI would be able to handle that, so I decided to make another view and did the math straight up in the query. In hindsight, I should have made the tables with the decimal data type so that this query wouldn't have to be so ugly. Just in case, I opened up R and made the same calculation to check my work.

```TSQL
--(Xi - Xmin) / (Xmax - Xmin)
SELECT *, 
	   CONVERT(DECIMAL,(num_sets - (SELECT MIN(num_sets) FROM Fitness.dbo.grouplift))) / CONVERT(DECIMAL,((SELECT MAX(num_sets) FROM Fitness.dbo.grouplift) - (SELECT MIN(num_sets) FROM Fitness.dbo.grouplift))) AS norm_num_sets,
	   CONVERT(DECIMAL,(num_reps - (SELECT MIN(num_reps) FROM Fitness.dbo.grouplift))) / CONVERT(DECIMAL,((SELECT MAX(num_reps) FROM Fitness.dbo.grouplift) - (SELECT MIN(num_reps) FROM Fitness.dbo.grouplift))) AS norm_num_reps,
	   CONVERT(DECIMAL,(num_lbs - (SELECT MIN(num_lbs) FROM Fitness.dbo.grouplift))) / CONVERT(DECIMAL,((SELECT MAX(num_lbs) FROM Fitness.dbo.grouplift) - (SELECT MIN(num_lbs) FROM Fitness.dbo.grouplift))) AS norm_num_lbs,
	   CONVERT(DECIMAL,(variability - (SELECT MIN(variability) FROM Fitness.dbo.grouplift))) / CONVERT(DECIMAL,((SELECT MAX(variability) FROM Fitness.dbo.grouplift) - (SELECT MIN(variability) FROM Fitness.dbo.grouplift))) AS norm_variability,
	   (value_weight - (SELECT MIN(value_weight) FROM Fitness.dbo.grouplift)) / ((SELECT MAX(value_weight) FROM Fitness.dbo.grouplift) - (SELECT MIN(value_weight) FROM Fitness.dbo.grouplift)) AS norm_value_weight
FROM  Fitness.dbo.grouplift

```
```R
fitness['norm_num_sets'] <- (fitness$num_sets - min(fitness$num_sets)) / (max(fitness$num_sets) - min(fitness$num_sets))
fitness['norm_num_reps'] <- (fitness$num_reps - min(fitness$num_reps)) / (max(fitness$num_reps) - min(fitness$num_reps))
fitness['norm_num_lbs'] <- (fitness$num_lbs - min(fitness$num_lbs)) / (max(fitness$num_lbs) - min(fitness$num_lbs))
fitness['norm_value_weight'] <- (fitness$value_weight - min(fitness$value_weight)) / (max(fitness$value_weight) - min(fitness$value_weight))
```
![picture](https://raw.githubusercontent.com/brendanok/Fitness_Data/master/images/norm.PNG)

Now that everything is scaled from 0 to 1, it's time to write the equation for the score. I took the calculations from above and housed them in a common table expression. I created the last column `score` using an algorithm based on the existing normalized columns, but I changed some of the weights. I tried accounting for the other stuff already. For example, deadlifts are a heck of a lot more of a workout in many ways than lets say the seated leg curl. That's why I the value_weight column exists. The number of reps and the number of sets completed should work against each other generally, so I don't really need to make changes there. Pounds (lbs) was interesting. Not that I don't care about how heavy I can go, but I always felt the important thing was just exercising flat out. The same principle applied to variability as well.

This view is called `dbo.score_detail`

```TSQL
WITH algo_CTE (exercise, lift_date, num_sets, num_reps, num_lbs, variability, value_weight, norm_num_sets, norm_num_reps, norm_num_lbs, norm_variability, norm_value_weight)
AS (
SELECT *, 
	   CONVERT(DECIMAL,(num_sets - (SELECT MIN(num_sets) FROM Fitness.dbo.grouplift))) / CONVERT(DECIMAL,((SELECT MAX(num_sets) FROM Fitness.dbo.grouplift) - (SELECT MIN(num_sets) FROM Fitness.dbo.grouplift))) AS norm_num_sets,
	   CONVERT(DECIMAL,(num_reps - (SELECT MIN(num_reps) FROM Fitness.dbo.grouplift))) / CONVERT(DECIMAL,((SELECT MAX(num_reps) FROM Fitness.dbo.grouplift) - (SELECT MIN(num_reps) FROM Fitness.dbo.grouplift))) AS norm_num_reps,
	   CONVERT(DECIMAL,(num_lbs - (SELECT MIN(num_lbs) FROM Fitness.dbo.grouplift))) / CONVERT(DECIMAL,((SELECT MAX(num_lbs) FROM Fitness.dbo.grouplift) - (SELECT MIN(num_lbs) FROM Fitness.dbo.grouplift))) AS norm_num_lbs,
	   CONVERT(DECIMAL,(variability - (SELECT MIN(variability) FROM Fitness.dbo.grouplift))) / CONVERT(DECIMAL,((SELECT MAX(variability) FROM Fitness.dbo.grouplift) - (SELECT MIN(variability) FROM Fitness.dbo.grouplift))) AS norm_variability,
	   (value_weight - (SELECT MIN(value_weight) FROM Fitness.dbo.grouplift)) / ((SELECT MAX(value_weight) FROM Fitness.dbo.grouplift) - (SELECT MIN(value_weight) FROM Fitness.dbo.grouplift)) AS norm_value_weight
FROM  Fitness.dbo.grouplift
)
SELECT *, ROUND(((norm_num_sets + norm_num_reps + (0.7 * norm_num_lbs) + (0.8 * norm_variability) + norm_value_weight)*1000),0) AS score
FROM algo_CTE;

-- I multiplied by 1000 to make it a more attractive number. I'm pretty sure there's some kind of psychology behind this.
```

Here's the results of some selected columns from the above view:
![pic](https://raw.githubusercontent.com/brendanok/Fitness_Data/master/images/score.png)

So after throwing this into PowerBI, I created this interactive report that serves as a tracker. As long as things are fed into the database, the queries will update and the report will update as well.
![pic](https://raw.githubusercontent.com/brendanok/Fitness_Data/master/images/powerbi.PNG)

Unfortunately, I can't share the report itself since it's hosted using a work license, but click [here](https://youtu.be/eMbl2M5_ISM) for a video demo of the dashboard. 

