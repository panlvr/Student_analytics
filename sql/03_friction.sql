-- Problem reach vs unsuccessful submission rate
WITH
  problem_type AS (
    SELECT
      p.id,
      p.complexity,
      CASE
        WHEN ptc.problem_id IS NOT NULL THEN 'Assigned'
        ELSE 'Non-assigned'
      END AS type
    FROM
      problem p
      LEFT JOIN problem_to_company ptc ON p.id = ptc.problem_id
      AND ptc.company_id = 1
  ),
  solvers AS (
    SELECT DISTINCT
      cs.problem_id,
      count(DISTINCT u.id) FILTER (
        WHERE
          is_false = 0
      ) AS solvers,
      count(DISTINCT u.id) AS problem_attempters,
      count(cs.id) FILTER (
        WHERE
          is_false = 1
      ) AS unsuccessful_attempts,
      count(cs.id) AS all_attempts
    FROM
      users u
      JOIN codesubmit cs ON cs.user_id = u.id
    WHERE
      u.company_id = 1
    GROUP BY
      cs.problem_id
  ),
  all_attempts AS (
    SELECT
      count(DISTINCT u.id) AS all_attempters
    FROM
      users u
      JOIN codesubmit cs ON cs.user_id = u.id
    WHERE
      u.company_id = 1
  ),
  agg AS (
    SELECT
      p.type,
      p.id,
      p.complexity,
      all_attempts "Attempts for this problem",
      all_attempters "Students attempting problems",
      coalesce(
        round(unsuccessful_attempts * 100.0 / all_attempts, 2),
        0
      ) AS unsuccessful_attempts_share,
      coalesce(
        round(problem_attempters * 100.0 / all_attempters, 2),
        0
      ) AS students_attempted_share,
      coalesce(round(solvers * 100.0 / problem_attempters, 2), 0) AS "Students solved this problem (%)"
    FROM
      problem_type p
      LEFT JOIN solvers s ON p.id = s.problem_id
      CROSS JOIN all_attempts
  )
  select * from agg 
  where students_attempted_share > {{minimal_threshold}}
  [[and type = {{Type}}]]

-- Failure rate by complexity and language
select p.complexity, 
round(count(cs.id) filter (where cs.is_false = 1 and l.name = 'Python')::NUMERIC/count(cs.id) filter (where l.name = 'Python')*100,2) as Python,
round(count(cs.id) filter (where cs.is_false = 1 and l.name = 'SQL')::NUMERIC/count(cs.id) filter (where l.name = 'SQL')*100,2) as SQL from problem p
join languagetoproblem ltp on ltp.pr_id = p.id
join language l on ltp.lang_id = l.id
join codesubmit cs on p.id = cs.problem_id
group by p.complexity
order by complexity 

-- Median failed submissions before success
with min_time as (
	select u.id, min(cs.created_at) as min_time from users u
	join codesubmit cs 
	on u.id = cs.user_id
	where u.company_id = 1 and cs.is_false = 0
	group by u.id
),
attempts_before_success as (
select u.id, count(cs.problem_id) filter (where cs.is_false = 1) as attempts_before_success from users u
join codesubmit cs
on u.id = cs.user_id
join min_time m
on u.id = m.id
where company_id = 1 and cs.created_at < m.min_time 
group by u.id
)
select PERCENTILE_CONT(0.5) within group (order by attempts_before_success) as median_attempts from attempts_before_success

