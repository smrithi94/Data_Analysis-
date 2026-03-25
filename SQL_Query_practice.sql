1. Identify Power Users (Subquery, Aggregation)
A social app stores post data in posts:
Column
post_id
user_id
post_date
Find users who post more than twice the average number of posts per user.
Return: user_id, post_count, average_post_count, multiplier

WITH avg_post_per_user AS (
            SELECT COUNT(post_id) * 1.0 / COUNT(DISTINCT user_id) AS average_post_count
             FROM posts
 )
SELECT
        p.user_id,
        COUNT(*) AS post_count,
        a.average_post_count,
        COUNT(*) / a.average_post_count AS multiplier
FROM posts p
CROSS JOIN avg_post_per_user a
GROUP BY p.user_id, a.average_post_count
HAVING COUNT(*) > 2 * a.average_post_count;

__________________________________________________________________

2. Employee Project Involvement Gap (JOINs, DateDiff, LAG)
Tables:
employees(employee_id, name)
projects(project_id, employee_id, start_date, end_date)
Question:
For each employee, find gaps greater than 30 days between the end of one project and the start of the next.
Return: employee_id, gap_days, previous_project_end, next_project_start.


WITH project_gaps AS (
          SELECT
                 e.employee_id,
                 p.project_id,
                 LAG(p.end_date) OVER (PARTITION BY e.employee_id ORDER BY p.start_date) AS previous_end_date,
                 p.start_date AS current_start_date
         FROM employees e
        JOIN projects p ON e.employee_id = p.employee_id
  )  
SELECT employee_id,
               previous_end_date,
               current_start_date,
               DATEDIFF(day, previous_end_date, current_start_date) AS gap_days
FROM project_gaps
WHERE DATEDIFF(day, previous_end_date, current_start_date) > 30;

___________________________________________________________________________

3. Tables:
features(feature_id, feature_name)
client_feature_usage(client_id, feature_id, used_flag)
clients(client_id, tier)
Question:
Find all features that are never used (used_flag = false) by any ‘Pro’ tier clients.
Return: feature_name.

SELECT   f.feature_name
FROM features f
WHERE NOT EXISTS (
     SELECT 1
     FROM client_feature_usage c
     JOIN clients cl ON c.client_id = cl.client_id
     WHERE c.feature_id = f.feature_id
     AND cl.tier = 'Pro'
     AND c.used_flag = TRUE
  );

__________________________________________________________________________________

4. Team Performance vs Individual Stars
You have:
players(player_id, team_id, player_name)
matches(match_id, team_id, player_id, points_scored)
Find teams where no single player contributed more than 50% of the team’s total points in any match. Return such team_ids.


WITH match_scores AS (
         SELECT 
            m.match_id,
            m.team_id,
            m.player_id,
            SUM(m.points_scored) AS player_points
        FROM matches m
       GROUP BY m.match_id, m.team_id, m.player_id
 ),
team_scores AS (
    SELECT 
         match_id,
         team_id,
        SUM(points_scored) AS total_points
    FROM matches
    GROUP BY match_id, team_id
  ),
player_vs_team AS (
    SELECT 
        ms.match_id,
        ms.team_id,
        ms.player_id,
        ms.player_points,
        ts.total_points
    FROM match_scores ms
    JOIN team_scores ts 
      ON ms.match_id = ts.match_id AND ms.team_id = ts.team_id
),
violating_teams AS (
    SELECT DISTINCT team_id
    FROM player_vs_team
    WHERE player_points * 1.0 / total_points > 0.5
  )
SELECT DISTINCT team_id
FROM matches
WHERE team_id NOT IN (SELECT team_id FROM violating_teams);


_______________________________________________________________________________

5. You are given a table logins(user_id, login_date) with one row per login.
Find all users who logged in on 3 or more consecutive days at least once. Return their user_id and the earliest such 3-day streak’s start date.

  --- create a row number for each login.  WITH numbered_logins AS (
    SELECT 
        user_id,
        login_date,
        ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY login_date) AS rn
    FROM logins
),
streaks AS (
    SELECT 
        user_id,
        login_date,
        DATE_SUB(login_date, INTERVAL rn DAY) AS streak_id
    FROM numbered_logins
),
grouped_streaks AS (
    SELECT 
        user_id,
        MIN(login_date) AS streak_start,
        COUNT(*) AS streak_length
    FROM streaks
    GROUP BY user_id, streak_id
    HAVING COUNT(*) >= 3
),
ranked_streaks AS (
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY streak_start) AS streak_rank
    FROM grouped_streaks
)
SELECT user_id, streak_start
FROM ranked_streaks
WHERE streak_rank = 1;

_____________________________________________________________________________________________________________

6. Carts That Became Purchases After Abandonment
Tables:
carts(cart_id, user_id, created_at)
cart_items(cart_id, product_id)
purchases(purchase_id, user_id, purchase_time, product_id)

Problem:
Find all users who abandoned a cart, but later purchased any of the same products (not from that cart).
Return:

user_id,
product_id,
cart_created_at,
purchase_time.

WITH purchases_per_user AS (
  SELECT 
    c.user_id,
    ci.product_id,
    c.created_at AS cart_created_at,
    p.purchase_time
  FROM carts c
  JOIN cart_items ci ON c.cart_id = ci.cart_id
  JOIN purchases p 
    ON c.user_id = p.user_id
   AND ci.product_id = p.product_id
  WHERE p.purchase_time > c.created_at
)
SELECT DISTINCT 
  user_id,
  product_id,
  cart_created_at,
  purchase_time
FROM purchases_per_user;

