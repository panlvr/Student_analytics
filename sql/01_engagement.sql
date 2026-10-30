-- Student engagement funnel
with total_students as (
	select count(*) as total from users 
	where company_id = 1
),
entered as (
	select count(distinct user_id) as entered from userentry
	join users on users.id = userentry.user_id 
	where users.company_id = 1
	[[and entry_at between {{date1}} and {{date2}}]]
),
ran_code as (
	select count(distinct user_id) as ran_code from coderun cr
	join users u on u.id = cr.user_id 
	where u.company_id = 1
	[[and created_at between {{date1}} and {{date2}}]]
),
submitted as (
	select count(distinct user_id) as submitted from codesubmit cs
	join users u on u.id = cs.user_id 
	where u.company_id = 1
	[[and created_at between {{date1}} and {{date2}}]]
),
solved as (
	select count(distinct user_id) as solved from codesubmit cs
	join users u on u.id = cs.user_id 
	where u.company_id = 1 and is_false = 0
	[[and created_at between {{date1}} and {{date2}}]]
)
select 1 as id, 'Total' as stage, total as students_cnt from total_students 
union all
select 2 as id, 'Entered' as stage, entered as students_cnt from entered
union all 
select 3 as id, 'Ran code' as stage, ran_code as students_cnt from ran_code 
union all 
select 4 as id, 'Submitted' as stage, submitted as students_cnt from submitted 
union all
select 5 as id, 'Solved' as stage, solved as students_cnt from solved
order by id asc

-- DAU
select date_trunc('day', ue.entry_at)::date as day_num, 
	round(count(distinct user_id)::numeric / (select count(id) from users where company_id = 1) * 100, 2) as "daily_active_users (%)"
from users u 
join userentry ue on ue.user_id = u.id
where u.company_id = 1 
[[and ue.entry_at between {{date1}} and {{date2}}]]
group by date_trunc('day', ue.entry_at)::date
order by day_num

-- WAU
select date_trunc('week', userentry.entry_at)::date as week, 
	round(count(distinct user_id)::numeric / (select count(id) from users where company_id = 1) * 100, 2) as "weekly_active_users (%)"
from users  
join userentry on userentry.user_id = users.id
where users.company_id = 1
and {{date}}
group by date_trunc('week', userentry.entry_at)::date
order by week

-- MAU
select date_trunc('month', userentry.entry_at)::date as month_num, 
	round(count(distinct user_id)::numeric / (select count(id) from users where company_id = 1) * 100, 2) as "monthly_active_users (%)"
from users  
join userentry on userentry.user_id = users.id
where users.company_id = 1
and {{entry_at}}
group by date_trunc('month', userentry.entry_at)::date
order by month_num

-- Active learning days median
with submit_days as (
	select cs.created_at::DATE as active_days, u.id as student
	from users u
	join codesubmit cs
	on u.id = cs.user_id
	where company_id = 1
	group by u.id, cs.created_at::DATE
),
run_days as (
	select cr.created_at::DATE as active_days, u.id as student
	from users u
	join coderun cr on u.id = cr.user_id
	where u.company_id = 1
	group by u.id, cr.created_at::DATE
),
test_days as (
	select ts.created_at::DATE as active_days, u.id as student
	from users u
	join teststart ts 
	on u.id = ts.user_id
	where company_id = 1
	group by u.id, ts.created_at::DATE
),
active_days as (
	select student, active_days from submit_days
	group by student, active_days
	union 
	select student, active_days from run_days
	group by student, active_days
	union
	select student, active_days from test_days
	group by student, active_days
	order by student
),
agg as (
	select u.id as student, coalesce(count(active_days), 0) as active_days from users u
	left join active_days a
	on u.id = a.student
	where u.company_id = 1
	group by u.id
	order by active_days, student
)
select PERCENTILE_CONT(0.5) within group (order by active_days) as median_active_days
from agg
