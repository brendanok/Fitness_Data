-- Returns variability by date. Stored as view dbo.variable
SELECT TOP (100) PERCENT lift_date, COUNT(DISTINCT exercise) AS variability
FROM   dbo.lift
GROUP BY lift_date
ORDER BY lift_date DESC

--Joins above view with main table (lift.csv) to return data grouped by exercise type and date and aggregates the other columns stored as dbo.grouplift
SELECT        L.exercise, L.lift_date, COUNT(L.[set]) AS num_sets, SUM(L.reps) AS num_reps, SUM(L.lb) AS num_lbs, SUM(V.variability) / COUNT(V.variability) AS variability, SUM(G.value_weight) / COUNT(G.value_weight) 
                         AS value_weight
FROM            dbo.lift AS L LEFT OUTER JOIN
                         dbo.variable AS V ON L.lift_date = V.lift_date LEFT OUTER JOIN
                         dbo.groups AS G ON L.exercise = G.exercise
GROUP BY L.exercise, L.lift_date

--Uses the  aggregated view to normalize data which is used to create the algorithm outside the CTE
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
