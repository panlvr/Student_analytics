-- Test participation funnel
with all_students as (
	select count(id) as cnt from users where company_id = 1
),
test_start as (
	select count(distinct user_id) as cnt from teststart
	where user_id in (select id from users where company_id = 1)
),
test_finish as (
	select count(distinct user_id) as cnt from testresult
	where user_id in (select id from users where company_id = 1)
)
select 'All students' as category, cnt from all_students 
union all 
select 'Started a test' as category, cnt from test_start 
union all
select 'Finished a test' as category, cnt from test_finish 

-- Tests started by students
with agg as (
	select u.id, count(distinct test_id) tested from users u
	left join teststart t 
	on u.id = t.user_id 
	where company_id = 1
	group by u.id	
)
select 'Tests started' as tag,
round(count(case when tested = 0 then id end) * 100.0 / count(id), 2) as "0",
round(count(case when tested <= 5 and tested > 0 then id end) * 100.0 / count(id), 2) as "1-5",
round(count(case when tested <= 10 and tested > 5 then id end) * 100.0 / count(id), 2) as "6-10",
round(count(case when tested <= 15 and tested > 10 then id end) * 100.0 / count(id), 2) as "11-15",
round(count(case when tested <= 20 and tested > 15 then id end) * 100.0 / count(id), 2) as "16-20",
round(count(case when tested <= 24 and tested > 20 then id end) * 100.0 / count(id), 2) as "21-24"
from agg

-- Average student accuracy by test
with correct as (
	select tq.test_id, ta.question_id, ta.id from testquestion tq
	join testanswer ta
	on tq.id = ta.question_id
	where is_correct = true
),
result as (
	select tr.user_id, c.test_id, count(tr.answer_id) filter (where tr.answer_id = c.id) as correct, count(tr.question_id) as all_questions from correct c
	left join testresult tr
	on tr.test_id = c.test_id and c.question_id = tr.question_id
	where user_id in (select id from users where company_id = 1)
	group by tr.user_id, c.test_id
)
select test_id, count(distinct user_id) "Students participated", round(count(correct) * 100.0 / min(all_questions), 2) "Average student accuracy (%)" from result 
group by test_id
order by "Average student accuracy (%)" desc