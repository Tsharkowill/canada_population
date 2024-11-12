# Canada Population Quarterly



# Make a column that gives percentage of each regions population of the whole country for a line chart
# quarterly_population.csv

SELECT 
    CAST(CONCAT(REF_DATE, '-01') AS DATETIME) AS ref_date,
    GEO AS region,
    VALUE AS population,
    ROUND((VALUE / (SELECT VALUE 
              FROM population_quarterly AS p
              WHERE p.GEO = 'Canada' AND p.REF_DATE = population_quarterly.REF_DATE) * 100), 2) AS percent_of_total_pop
FROM 
    population_quarterly
;


    
# Make another column that gives percentage growth of each region compared to itself in the previous year
# annual_percent_increase.csv

SELECT
	ref_date,
    region,
    annual_percent_increase
FROM
	(SELECT 
		CAST(CONCAT(REF_DATE, '-01') AS DATETIME) AS ref_date,
		GEO AS region,
		VALUE AS current_population,
		LAG(VALUE, 4) OVER (PARTITION BY GEO ORDER BY REF_DATE) AS previous_year_population,
		ROUND(((VALUE - LAG(VALUE, 4) OVER (PARTITION BY GEO ORDER BY REF_DATE)) / LAG(VALUE, 4) OVER (PARTITION BY GEO ORDER BY REF_DATE)) * 100, 2) AS annual_percent_increase
	FROM 
		population_quarterly
	ORDER BY 
		GEO, REF_DATE) AS lagged
WHERE annual_percent_increase IS NOT NULL
;



# Births and Deaths
# births_and_deaths_clean.csv

SELECT
	CAST(CONCAT(REF_DATE, + '-01') AS DATETIME) AS ref_date,
    GEO as region,
    Estimates AS birth_or_death,
    VALUE AS num_people,
    SUM((CASE 
			WHEN Estimates = 'Births' THEN VALUE
            ELSE 0
		END) -
        (CASE
			WHEN Estimates = 'Deaths' THEN VALUE
            ELSE 0
		END)
	) OVER (PARTITION BY REF_DATE, GEO) AS growth_from_births
FROM
	births_and_deaths
WHERE
	Estimates != 'Marriages'
;



# Births seperately
# births.csv

SELECT
	CAST(CONCAT(REF_DATE, + '-01') AS DATETIME) AS ref_date,
    GEO as region,
    VALUE AS num_births
FROM 
	births_and_deaths
WHERE
	Estimates = 'Births'
AND
	REF_DATE < 2023
;



# Deaths seperately
# deaths.csv

SELECT
	CAST(CONCAT(REF_DATE, + '-01') AS DATETIME) AS ref_date,
    GEO as region,
    VALUE AS num_deaths
FROM 
	births_and_deaths
WHERE
	Estimates = 'Deaths'
AND
	REF_DATE < 2023
;



# Immigration as percentage of population growth
# Q3 of 1971 They started counting Immigrants, Net emigration, Emigrants, Returning emigrants and Net non-permanent residents
# Before its just Immigrants and Emigrants

# Use CTE to create table from population_quarterly with the LAG calculated population increase per year then join it to international_immigration
# immigration_effect_on_population.csv

WITH pop_growth AS (
	SELECT
		REF_DATE,
        GEO AS region,
        VALUE AS population,
        VALUE - LAG(VALUE, 4) OVER (PARTITION BY GEO ORDER BY REF_DATE) AS annual_population_growth
	FROM population_quarterly
)
        

SELECT
	CAST(CONCAT(i.REF_DATE, '-01') AS DATETIME) AS ref_date,
	i.GEO AS region,
	i.`Components of population growth` AS status,
	i.VALUE AS population_change,
    p.annual_population_growth,
    ROUND((ABS(i.VALUE) / p.population) * 100, 2) AS percent_of_total_population, # Keeping this as ABS() because the negative population_change numbers make my percentages negative when it doesn't make sense
    ROUND((i.VALUE / p.annual_population_growth) * 100, 2) AS percent_of_population_change # Here it makes sense to have negative percentages to represent that positive immigration to a region that is declining in population has a negative effect omn the population change
FROM 
	international_migration AS i
JOIN 
	pop_growth AS p
	ON i.REF_DATE = p.REF_DATE
    AND i.GEO = p.region
;



# Immigration by Age and Sex, maybe do a window function to segment the different parts of the population
# This table can basically just be set up as a dashboard with a map and toggles for age, sex and time period
# age_and_sex_of_immigrants.csv

SELECT
	SUBSTRING_INDEX(GEO, '(', 1) AS region,
    SUBSTRING(DGUID, LENGTH(DGUID) -2, 3) AS geo_code,
	`Age (15C)` AS age,
    `Gender (3)` AS gender,
    `Statistics (2)` AS statistic,
    `Total - Immigrant status and period of immigration[1]` AS total_count,
    `Non-immigrants[2]` AS non_immigrant_count,
    `Immigrants[3]` AS immigrant_count,
    `Before 2001[4]` AS immigrant_count_pre_2001,
    `2001 to 2005[5]` AS immigrant_count_2001_2005,
    `2006 to 2010[6]` AS immigrant_count_2006_2010,
    `2011 to 2015[7]` AS immigrant_count_2011_2015,
    `2016 to 2021[8]` AS immigrant_count_2016_2021,
    `Non-permanent residents[9]` AS non_permanent_residents
FROM immigrant_status_and_period
;



# Different binning of age categories from 2021 census
# 2021_province_age_clean.csv

SELECT
	GEO_NAME AS region,
    CHARACTERISTIC_NAME AS age,
    C1_COUNT_TOTAL AS total_num,
    `C2_COUNT_MEN+` AS num_men,
    `C3_COUNT_WOMEN+` AS num_women,
    C10_RATE_TOTAL AS total_percent,
    `C11_RATE_MEN+` AS percent_men,
    `C12_RATE_WOMEN+` AS percent_women
FROM
	2021_province_age
;


# Different binning of age categories from 2021 census
# 2021_cma_age_clean.csv

SELECT *
FROM
	2021_cma_age;

SELECT
	GEO_NAME AS city,
    ALT_GEO_CODE AS geo_code,
    CHARACTERISTIC_NAME AS age,
	C1_COUNT_TOTAL AS total_num,
    `C2_COUNT_MEN+` AS num_men,
    `C3_COUNT_WOMEN+` AS num_women,
    C10_RATE_TOTAL AS total_percent,
    `C11_RATE_MEN+` AS percent_men,
    `C12_RATE_WOMEN+` AS percent_women,
    SUM((CASE
		WHEN CHARACTERISTIC_NAME = '0 to 14 years' THEN C1_COUNT_TOTAL
        WHEN CHARACTERISTIC_NAME = '15 to 64 years' THEN C1_COUNT_TOTAL
        WHEN CHARACTERISTIC_NAME = '65 years and over' THEN C1_COUNT_TOTAL
        ELSE 0 END)) OVER (PARTITION BY GEO_NAME) AS total_pop
        
FROM
	2021_cma_age
;



# Immigrant country of origin aggregated at province/national level
# 2021_province_immigration_clean.csv

SELECT
	GEO_NAME AS region,
    CHARACTERISTIC_NAME AS country_of_origin,
    C1_COUNT_TOTAL AS total_num,
    `C2_COUNT_MEN+` AS num_men,
    `C3_COUNT_WOMEN+` AS num_women,
    C10_RATE_TOTAL AS total_percent,
    `C11_RATE_MEN+` AS percent_men,
    `C12_RATE_WOMEN+` AS percent_women
FROM 
	2021_province_immigration
;



# Immigrant country of origin aggregated at census metropolitan level
# 2021_cma_immigration_clean.csv

SELECT 
	GEO_NAME AS city,
    ALT_GEO_CODE AS geo_code,
    CHARACTERISTIC_NAME AS country_of_origin,
    CASE
		WHEN CHARACTERISTIC_ID BETWEEN 1546 AND 1556 THEN 'Americas'
        WHEN CHARACTERISTIC_ID BETWEEN 1558 AND 1573 THEN 'Europe'
        WHEN CHARACTERISTIC_ID BETWEEN 1575 AND 1584 THEN 'Africa'
        WHEN CHARACTERISTIC_ID BETWEEN 1586 AND 1602 THEN 'Asia'
        WHEN CHARACTERISTIC_ID = 1603 THEN 'Oceania'
	END AS continent_of_origin,
    C1_COUNT_TOTAL AS total_num,
    `C2_COUNT_MEN+` AS num_men,
    `C3_COUNT_WOMEN+` AS num_women,
    C10_RATE_TOTAL AS total_percent,
    `C11_RATE_MEN+` AS percent_men,
    `C12_RATE_WOMEN+` AS percent_women,
    SUM(C1_COUNT_TOTAL) OVER (PARTITION BY GEO_NAME) AS total_immigrant
FROM 
	2021_cma_immigration
WHERE
    (CHARACTERISTIC_ID BETWEEN 1546 AND 1556)
    OR (CHARACTERISTIC_ID BETWEEN 1558 AND 1573)
    OR (CHARACTERISTIC_ID BETWEEN 1575 AND 1584)
    OR (CHARACTERISTIC_ID BETWEEN 1586 AND 1602)
    OR (CHARACTERISTIC_ID = 1603)
;



# Directed chord diagram to show flows from province to province
# Internal migration percentage relative to population of the region (both in and out)
# internal_migration_as_percent_of_pop.csv

WITH annual_pop AS (
	SELECT
		REF_DATE,
        GEO AS region,
        VALUE AS population
	FROM
		population_quarterly
)

SELECT
	CAST(CONCAT(i.REF_DATE, '-01') AS DATETIME) AS ref_date,
    i.GEO as region,
    i.`Geography, province of destination` AS destination,
    i.VALUE as num_people,
    a.population AS region_pop,
    ROUND((i.VALUE / a.population) * 100, 4) AS percent_of_region_pop,
    b.population AS destination_pop,
    ROUND((i.VALUE / b.population) * 100, 4) AS percent_of_destination_pop
FROM
	internal_migration_destination AS i
JOIN
	annual_pop AS a
    ON i.REF_DATE = a.REF_DATE
    AND REPLACE(i.GEO, ', province of origin', '') = a.region
JOIN
	annual_pop as b
    ON i.REF_DATE = b.REF_DATE
    AND REPLACE(i.`Geography, province of destination`, ', province of destination', '') = b.region
ORDER BY
 ref_date,
 region,
 destination
 ;



# Internal migration net growth or decline by region
# internal_migration_net_growth.csv

SELECT *
FROM internal_migration_total;

SELECT
    CAST(CONCAT(REF_DATE, '-01') AS DATETIME) AS ref_date,
    GEO AS region,
    `Interprovincial migration` AS migration_status,
    VALUE AS num_people,
    SUM((CASE 
            WHEN `Interprovincial migration` = 'In-migrants' THEN VALUE 
            ELSE 0 
        END) -
        (CASE 
            WHEN `Interprovincial migration` = 'Out-migrants' THEN VALUE 
            ELSE 0 
        END)
    ) OVER (PARTITION BY REF_DATE, GEO) AS net_internal_migration
FROM
    internal_migration_total
;








