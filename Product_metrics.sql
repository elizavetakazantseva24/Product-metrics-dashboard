--расчет DAU (при этом он считается по совершению заказа)
SELECT log_date,
    COUNT(DISTINCT user_id) AS DAU
FROM analytics_events
JOIN cities USING(city_id)
WHERE event = 'order' AND log_date BETWEEN '2021-01-05' AND '2021-06-30' AND city_name = 'Саранск'
GROUP BY 1
ORDER BY log_date
LIMIT 10;

--расчет Conversion Rate из регистрации в оформление заказа
SELECT
    log_date,
    COUNT(DISTINCT user_id) FILTER (WHERE event='order') AS orders,
    COUNT(DISTINCT user_id) AS registrations,
    ROUND((COUNT(DISTINCT user_id) FILTER (WHERE event='order')/COUNT(DISTINCT user_id)::float)::numeric, 2) AS CR
FROM analytics_events
JOIN cities USING(city_id)
WHERE log_date BETWEEN '2021-05-01' AND '2021-06-30' AND city_name = 'Саранск'
GROUP BY 1
ORDER BY 1;

--расчет среднего чека (получения комиссии от партнеров)
WITH orders AS (
     SELECT *,
            revenue * commission AS commission_revenue
     FROM analytics_events
     JOIN cities ON analytics_events.city_id = cities.city_id
     WHERE revenue IS NOT NULL
         AND log_date BETWEEN '2021-05-01' AND '2021-06-30'
         AND city_name = 'Саранск'
)
SELECT
    DATE_TRUNC('month', log_date)::date AS "Месяц",
    COUNT(DISTINCT order_id) AS "Количество заказов",
    ROUND(SUM(commission_revenue)::numeric, 2) AS "Сумма комиссии",
    ROUND((SUM(commission_revenue)/COUNT(DISTINCT order_id))::numeric, 2) AS "Средний чек"
FROM orders
GROUP BY DATE_TRUNC('month', log_date)
ORDER BY "Месяц";

--расчет LTV топ-3 ресторанов-партнеров
WITH orders AS (
     SELECT analytics_events.rest_id,
            analytics_events.city_id,
            revenue * commission AS commission_revenue
     FROM analytics_events
     JOIN cities ON analytics_events.city_id = cities.city_id
     WHERE revenue IS NOT NULL
         AND log_date BETWEEN '2021-05-01' AND '2021-06-30'
         AND city_name = 'Саранск'
)
SELECT 
    o.rest_id,
    chain AS "Название сети",
    type AS "Тип кухни",
    ROUND(SUM(commission_revenue)::numeric, 2) AS LTV
FROM orders o
JOIN partners p ON o.rest_id = p.rest_id AND o.city_id = p.city_id
GROUP BY 1, 2, 3
ORDER BY LTV DESC
LIMIT 3;

--расчет LTV топ-5 блюд из популярных ресторанов
WITH orders AS (
     SELECT analytics_events.rest_id,
            analytics_events.city_id,
            analytics_events.object_id,
            revenue * commission AS commission_revenue
     FROM analytics_events
     JOIN cities ON analytics_events.city_id = cities.city_id
     WHERE revenue IS NOT NULL
         AND log_date BETWEEN '2021-05-01' AND '2021-06-30'
         AND city_name = 'Саранск'
), 
top_ltv_restaurants AS (
     SELECT orders.rest_id,
            chain,
            type,
            ROUND(SUM(commission_revenue)::numeric, 2) AS LTV
     FROM orders
     JOIN partners ON orders.rest_id = partners.rest_id AND orders.city_id = partners.city_id
     GROUP BY 1, 2, 3
     ORDER BY LTV DESC
     LIMIT 2
)
SELECT chain AS "Название сети",
    name AS "Название блюда",
    spicy,
    fish, 
    meat,
    ROUND(SUM(commission_revenue)::numeric, 2) AS LTV
FROM orders
JOIN top_ltv_restaurants ON orders.rest_id = top_ltv_restaurants.rest_id
JOIN dishes ON orders.object_id = dishes.object_id
AND top_ltv_restaurants.rest_id = dishes.rest_id
GROUP BY 1, 2, 3, 4, 5
ORDER BY LTV DESC
LIMIT 5;

--расчет Retention Rate первой недели по месяцам 
WITH new_users AS (
     SELECT DISTINCT first_date,
                     user_id
     FROM analytics_events
     JOIN cities ON analytics_events.city_id = cities.city_id
     WHERE first_date BETWEEN '2021-05-01' AND '2021-06-24'
         AND city_name = 'Саранск'
),
active_users AS (
     SELECT DISTINCT log_date,
                     user_id
     FROM analytics_events
     JOIN cities ON analytics_events.city_id = cities.city_id
     WHERE log_date BETWEEN '2021-05-01' AND '2021-06-30'
         AND city_name = 'Саранск'
),
daily_retention AS (
     SELECT new_users.user_id,
            first_date,
            log_date::date - first_date::date AS day_since_install
     FROM new_users
     JOIN active_users ON new_users.user_id = active_users.user_id
     AND log_date >= first_date
)
SELECT 
    DATE_TRUNC('month', first_date)::date AS "Месяц", 
    day_since_install,
    COUNT(DISTINCT user_id) AS retained_users,
    ROUND((1.0 * COUNT(DISTINCT user_id) / MAX(COUNT(DISTINCT user_id)) OVER (PARTITION BY CAST(DATE_TRUNC('month', first_date) AS date) ORDER BY day_since_install))::numeric, 2) AS retention_rate
FROM daily_retention
WHERE day_since_install < 8
GROUP BY "Месяц", day_since_install
ORDER BY "Месяц", day_since_install;