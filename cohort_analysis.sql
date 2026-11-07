WITH users_norm AS (
SELECT user_id, promo_signup_flag,
REPLACE(
REPLACE(
TRIM(SPLIT_PART(TRIM(signup_datetime), ' ', 1)), '.', '-'),'/', '-') AS signup_date
FROM cohort_users_raw
),
users_parsed AS (
SELECT user_id, promo_signup_flag,
CASE
WHEN SPLIT_PART(signup_date, '-', 1) ~ '^\d{1,2}$'
AND SPLIT_PART(signup_date, '-', 2) ~ '^\d{1,2}$'
AND SPLIT_PART(signup_date, '-', 3) ~ '^\d{2}$|^\d{4}$'
THEN TO_DATE(LPAD(SPLIT_PART(signup_date, '-', 1), 2, '0') || '-' || 
LPAD(SPLIT_PART(signup_date, '-', 2), 2, '0') || '-' ||
CASE
WHEN LENGTH(SPLIT_PART(signup_date, '-', 3)) = 2
THEN '20' || SPLIT_PART(signup_date, '-', 3)
ELSE SPLIT_PART(signup_date, '-', 3)
END, 'DD-MM-YYYY')::TIMESTAMP
ELSE NULL
END AS signup_datetime_clean
FROM users_norm
),
events_norm AS (
select event_id, user_id, event_type, revenue,
REPLACE(
REPLACE(
TRIM(SPLIT_PART(TRIM(event_datetime), ' ', 1)), '.', '-'), '/', '-') AS event_date
FROM cohort_events_raw
),
events_parsed AS (
SELECT event_id, user_id, event_type, revenue,
CASE
WHEN SPLIT_PART(event_date, '-', 1) ~ '^\d{1,2}$'
AND SPLIT_PART(event_date, '-', 2) ~ '^\d{1,2}$'
AND SPLIT_PART(event_date, '-', 3) ~ '^\d{2}$|^\d{4}$'
THEN TO_DATE(LPAD(SPLIT_PART(event_date, '-', 1), 2, '0') || '-' ||
LPAD(SPLIT_PART(event_date, '-', 2), 2, '0') || '-' ||
CASE
WHEN LENGTH(SPLIT_PART(event_date, '-', 3)) = 2
THEN '20' || SPLIT_PART(event_date, '-', 3)
ELSE SPLIT_PART(event_date, '-', 3)
END, 'DD-MM-YYYY')::TIMESTAMP
ELSE NULL
END AS event_datetime_clean
FROM events_norm
),
joined_data AS (
select u.user_id, u.promo_signup_flag, u.signup_datetime_clean, e.event_id, e.event_datetime_clean,
e.event_type, e.revenue,
DATE_TRUNC('month', u.signup_datetime_clean) AS cohort_month,
DATE_TRUNC('month', e.event_datetime_clean) AS activity_month
FROM users_parsed u
JOIN events_parsed e
ON u.user_id = e.user_id
WHERE u.signup_datetime_clean IS NOT NULL
AND e.event_datetime_clean IS NOT NULL
AND e.event_type IS NOT NULL
AND e.event_type <> 'test_event'
AND e.event_datetime_clean >= u.signup_datetime_clean
),
cohort_data AS (
select user_id, promo_signup_flag, cohort_month, activity_month, (
EXTRACT(YEAR FROM activity_month) - 
EXTRACT(YEAR FROM cohort_month)) * 12 + (
EXTRACT(MONTH FROM activity_month) - 
EXTRACT(MONTH FROM cohort_month)) AS month_offset
FROM joined_data
WHERE activity_month >= '2025-01-01'
AND activity_month < '2025-07-01'
)
select promo_signup_flag, cohort_month, month_offset, COUNT(DISTINCT user_id) AS users_total
FROM cohort_data
GROUP BY promo_signup_flag, cohort_month, month_offset
ORDER by promo_signup_flag, cohort_month, month_offset