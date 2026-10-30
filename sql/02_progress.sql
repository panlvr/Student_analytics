-- Cohort curriculum coverage
with assigned as (
	select count(distinct problem_id) as assigned from problem_to_company
	where company_id = 1
),
attempted as (
	select count(attempted) as attempted from (select distinct cr.problem_id as attempted from coderun cr
	join users u
	on u.id = cr.user_id
	where company_id = 1
	intersect
	select distinct problem_id from problem_to_company
	where company_id = 1) as att
),
submitted as (
	select count(submitted) as submitted from (select distinct cs.problem_id as submitted from codesubmit cs
	join users u 
	on u.id = cs.user_id
	where company_id = 1
	intersect
	select distinct problem_id from problem_to_company
	where company_id = 1) as sub
),
solved as (
	select count(solved) as solved from (select distinct cs.problem_id as solved from codesubmit cs
	join users u 
	on u.id = cs.user_id
	where company_id = 1 and is_false = 0
	intersect 
	select distinct problem_id from problem_to_company
	where company_id = 1) as s
)
select 'Assigned' as stage, assigned as cnt from assigned
union all
select 'Attempted' as stage, attempted as cnt from attempted
union ALL
select 'Submitted' as stage, submitted as cnt from submitted
union all
select 	'Solved' as stage, solved as cnt from solved

-- Assigned vs non-assigned problem activity
with problem_type as (
	select id,
	 case 
	 	when id in (select problem_id from problem_to_company ptc where company_id = 1) then 'Assigned'
	 	when id not in (select problem_id from problem_to_company ptc where company_id = 1) then 'Non-assigned'
	 end as problem_type
	 from problem
),
attempted as (
	select distinct problem_id from coderun c
	join users u
	on u.id = c.user_id 
	where company_id = 1
),
submitted as (
	select distinct problem_id from codesubmit c 
	join users u
	on u.id = c.user_id 
	where company_id = 1
),
solved as (
	select distinct problem_id from codesubmit c 
	join users u
	on u.id = c.user_id 
	where company_id = 1 and is_false = 0
),
agg as (
	select problem_type,
		case 
			when id in (select * from attempted) then 1
			else 0
		end as attempted,
		case 
			when id in (select * from submitted) then 1
			else 0
		end as submitted,
		case 
			when id in (select * from solved) then 1
			else 0
		end as solved,
		case 
			when problem_type = 'Assigned' then 1::numeric
			else 1::numeric
		end as total	
	from problem_type 		
)
select problem_type, sum(attempted) / sum(total) as attempted, sum(submitted) / sum(total) as submitted, sum(solved) / sum(total) as solved from agg
where problem_type = {{Type}}
group by problem_type

-- Student progress distribution
WITH agg AS (
    SELECT u.id AS student,
      round(count(DISTINCT cs.problem_id)::NUMERIC / (SELECT count(DISTINCT problem_id) FROM problem_to_company WHERE company_id = 1) * 100, 2) AS solved
    FROM users u
    LEFT JOIN codesubmit cs ON u.id = cs.user_id
    AND cs.is_false = 0
    AND cs.problem_id IN (SELECT DISTINCT id FROM problem_to_company WHERE company_id = 1)
    WHERE
      company_id = 1 [[and created_at between {{date1}} and {{date2}}]]
    GROUP BY u.id
    ORDER BY solved, student
)
select 'Progress band' AS tag,
    round(count(CASE WHEN solved = 0 THEN student END) * 100.0 / count(student), 2) AS "0(%)",
    round(count(CASE WHEN solved <= 5 AND solved > 0 THEN student END) * 100.0 / count(student), 2) AS "0-5(%)",
    round(count(CASE WHEN solved <= 10 AND solved > 5 THEN student END) * 100.0 / count(student), 2) AS "5-10(%)",
    round(count(CASE WHEN solved <= 20 AND solved > 10 THEN student END) * 100.0 / count(student), 2) AS "10-20(%)",
    round(count(CASE WHEN solved <= 40 AND solved > 20 THEN student END) * 100.0 / count(student), 2) AS "20-40(%)",
    round(count(CASE WHEN solved <= 50 AND solved > 40 THEN student END) * 100.0 / count(student), 2) AS "40-50(%)"
FROM agg

-- Problems engagement table
WITH
  problem_type AS (
    SELECT DISTINCT
      p.id,
      p.name,
      complexity,
      CASE
        WHEN ptc.problem_id IS NOT NULL THEN 'Assigned'
        ELSE 'Non-assigned'
      END AS type
    FROM
      problem p
      LEFT JOIN problem_to_company ptc ON p.id = ptc.problem_id
      AND ptc.company_id = 1
  ),
  attempts AS (
    SELECT DISTINCT
      cs.problem_id,
      count(DISTINCT cs.problem_id) FILTER (
        WHERE
          is_false = 1
      ) AS attempted,
      count(DISTINCT cs.problem_id) FILTER (
        WHERE
          is_false = 0
      ) AS solved
    FROM
      codesubmit cs
      JOIN users u ON u.id = cs.user_id
    WHERE
      company_id = 1
    GROUP BY
      problem_id
  )
SELECT name, complexity
FROM problem_type pt
LEFT JOIN attempts a 
ON pt.id = a.problem_id
WHERE type = {{type}}
and coalesce(solved, 0) = {{solved}}
and coalesce(attempted, 0) = {{attemepted}}
ORDER BY complexity

-- Median curriculum completed (%)
with agg as (
	select u.id as student, 
	round(count(distinct cs.problem_id)::NUMERIC/ (select count(distinct problem_id) from problem_to_company where company_id = 1), 4) as solved
	from users u
	left join codesubmit cs 
	on u.id = cs.user_id and cs.is_false = 0 and cs.problem_id in (select distinct id from problem_to_company where company_id = 1)
	where company_id = 1 
	group by u.id
)
select percentile_cont(0.5) within group (order by solved) as median_problems_solved
from agg