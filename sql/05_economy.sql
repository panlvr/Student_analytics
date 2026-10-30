-- Students earning coins (%)
select 
	count(distinct user_id) filter (where type_id between 2 and 22 or type_id = 29)::numeric / 
	(select count(id) from users where company_id = 1) as earning_students_share
	from "transaction" t
	where user_id in (select id from users where company_id = 1)

-- Median coins earned
with students_earned_num as (
	select user_id, sum(value) filter (where type_id between 2 and 22 or type_id = 29) as earned from "transaction" t
	where user_id in (select id from users where company_id = 1)
	group by user_id
)
select
	PERCENTILE_CONT(0.5) within group (order by earned) as median_earned
from students_earned_num

-- Monthly earnings
select date_trunc('month', created_at)::date as "Month", tt.description,
		sum(t.value) as  "Monthly earning"
	from "transaction" t 
	join transactiontype tt 
	on t.type_id = tt.type
	where user_id in (select id from users where company_id = 1) and (type_id between 2 and 22 or type_id = 29)
	[[and created_at between {{date1}} and {{date2}}]]
	group by date_trunc('month', created_at)::date, description
	order by date_trunc('month', created_at)::date 

-- Earnings breakdown
select date_trunc('month', created_at)::date as "Month", tt.description,
		sum(t.value) as  "Monthly earning"
	from "transaction" t 
	join transactiontype tt 
	on t.type_id = tt.type
	where user_id in (select id from users where company_id = 1) and type_id between 2 and 22 or type_id = 29
	group by date_trunc('month', created_at)::date, description
	order by date_trunc('month', created_at)::date 

-- Students spending coins (%)
select 
	count(distinct user_id) filter (where type_id between 23 and 28 or type_id = 1)::numeric / 
	(select count(id) from users where company_id = 1) as spending_students_share
from "transaction" t
where user_id in (select id from users where company_id = 1)

-- Median coins spent
with students_spent_num as (
	select user_id, sum(value) filter (where type_id between 23 and 28 or type_id = 1) as spent from "transaction" t
	where user_id in (select id from users where company_id = 1)
	group by user_id
)
select 
	PERCENTILE_CONT(0.5) within group (order by spent) as median_spent
	from students_spent_num 

-- Monthly spending
select date_trunc('month', created_at)::date as "Month", tt.description,
		sum(t.value) as  "Monthly earning"
	from "transaction" t 
	join transactiontype tt 
	on t.type_id = tt.type
	where user_id in (select id from users where company_id = 1) and type_id between 23 and 28 or type_id = 1
	group by date_trunc('month', created_at)::date, description
	order by date_trunc('month', created_at)::date 

-- Monthly spending by category
select date_trunc('month', t.created_at)::date as "Month", tt.description,
		sum(t.value) as  "Monthly spending"
	from "transaction" t 
	join transactiontype tt 
	on t.type_id = tt.type
	where t.user_id in (select id from users where company_id = 1) and (t.type_id between 23 and 28 or t.type_id = 1)
	group by date_trunc('month', created_at)::date, description
	order by date_trunc('month', created_at)::date 