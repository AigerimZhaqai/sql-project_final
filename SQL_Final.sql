select * from customers_info;
# Задание 1. список клиентов с непрерывной историей за год, то есть каждый месяц на регулярной основе без пропусков за указанный годовой период,
# средний чек за период с 01.06.2015 по 01.06.2016, средняя сумма покупок за месяц, количество всех операций по клиенту за период;

-- Период анализа:
-- с 01.06.2015 включительно по 01.06.2016 не включительно

-- 1. Клиенты с непрерывной историей за год
SELECT
    t.ID_client,
    COUNT(DISTINCT DATE_FORMAT(t.date_new, '%Y-%m')) AS active_months,
    AVG(t.Sum_payment) AS avg_check,
    SUM(t.Sum_payment) / 12 AS avg_monthly_purchase_amount,
    COUNT(*) AS total_operations
FROM transactions t
WHERE t.date_new >= '2015-06-01'
  AND t.date_new < '2016-06-01'
GROUP BY t.ID_client
HAVING COUNT(DISTINCT DATE_FORMAT(t.date_new, '%Y-%m')) = 12;

# Задание 2. # средняя сумма чека в месяц;
#среднее количество операций в месяц;
#среднее количество клиентов, которые совершали операции;
#долю от общего количества операций за год и долю в месяц от общей суммы операций;

-- 2. Показатели по месяцам
WITH monthly AS (
    SELECT
        DATE_FORMAT(date_new, '%Y-%m') AS month,
        COUNT(*) AS operations_count,
        COUNT(DISTINCT ID_client) AS clients_count,
        SUM(Sum_payment) AS total_sum,
        AVG(Sum_payment) AS avg_check
    FROM transactions
    WHERE date_new >= '2015-06-01'
      AND date_new < '2016-06-01'
    GROUP BY DATE_FORMAT(date_new, '%Y-%m')
),
year_total AS (
    SELECT
        COUNT(*) AS year_operations,
        SUM(Sum_payment) AS year_sum
    FROM transactions
    WHERE date_new >= '2015-06-01'
      AND date_new < '2016-06-01'
)
SELECT
    m.month,
    m.avg_check AS avg_check_month,
    m.operations_count,
    m.clients_count,
    m.operations_count / m.clients_count AS avg_operations_per_client,
    m.operations_count / yt.year_operations * 100 AS operations_share_percent,
    m.total_sum / yt.year_sum * 100 AS sum_share_percent
FROM monthly m
CROSS JOIN year_total yt
ORDER BY m.month;

-- 2.1. Соотношение M/F/NA по месяцам + доля затрат

WITH monthly_gender AS (
    SELECT
        DATE_FORMAT(t.date_new, '%Y-%m') AS month,
        COALESCE(NULLIF(c.Gender, ''), 'NA') AS gender,
        COUNT(*) AS operations_count,
        SUM(t.Sum_payment) AS total_sum
    FROM transactions t
    LEFT JOIN customers_info c
        ON t.ID_client = c.Id_client
    WHERE t.date_new >= '2015-06-01'
      AND t.date_new < '2016-06-01'
    GROUP BY
        DATE_FORMAT(t.date_new, '%Y-%m'),
        COALESCE(NULLIF(c.Gender, ''), 'NA')
),
monthly_total AS (
    SELECT
        DATE_FORMAT(date_new, '%Y-%m') AS month,
        COUNT(*) AS month_operations,
        SUM(Sum_payment) AS month_sum
    FROM transactions
    WHERE date_new >= '2015-06-01'
      AND date_new < '2016-06-01'
    GROUP BY DATE_FORMAT(date_new, '%Y-%m')
)
SELECT
    mg.month,
    mg.gender,
    mg.operations_count,
    mg.total_sum,
    mg.operations_count / mt.month_operations * 100 AS gender_operations_share_percent,
    mg.total_sum / mt.month_sum * 100 AS gender_sum_share_percent
FROM monthly_gender mg
JOIN monthly_total mt
    ON mg.month = mt.month
ORDER BY mg.month, mg.gender;

#Задание 3. возрастные группы клиентов с шагом 10 лет и отдельно клиентов, у которых нет данной информации, 
#с параметрами сумма и количество операций за весь период, и поквартально - средние показатели и %.

-- 3. Возрастные группы за весь период
SELECT
    CASE
        WHEN c.AGE IS NULL THEN 'NA'
        WHEN c.AGE < 20 THEN 'до 20'
        WHEN c.AGE BETWEEN 20 AND 29 THEN '20-29'
        WHEN c.AGE BETWEEN 30 AND 39 THEN '30-39'
        WHEN c.AGE BETWEEN 40 AND 49 THEN '40-49'
        WHEN c.AGE BETWEEN 50 AND 59 THEN '50-59'
        WHEN c.AGE BETWEEN 60 AND 69 THEN '60-69'
        ELSE '70+'
    END AS age_group,
    SUM(t.Sum_payment) AS total_sum,
    COUNT(*) AS operations_count,
    AVG(t.Sum_payment) AS avg_check
FROM transactions t
LEFT JOIN customers_info c
    ON t.ID_client = c.Id_client
WHERE t.date_new >= '2015-06-01'
  AND t.date_new < '2016-06-01'
GROUP BY age_group
ORDER BY age_group;

-- 3.1. Возрастные группы поквартально

WITH age_quarter AS (
    SELECT
        CONCAT(YEAR(t.date_new), '-Q', QUARTER(t.date_new)) AS quarter,
        CASE
            WHEN c.AGE IS NULL THEN 'NA'
            WHEN c.AGE < 20 THEN 'до 20'
            WHEN c.AGE BETWEEN 20 AND 29 THEN '20-29'
            WHEN c.AGE BETWEEN 30 AND 39 THEN '30-39'
            WHEN c.AGE BETWEEN 40 AND 49 THEN '40-49'
            WHEN c.AGE BETWEEN 50 AND 59 THEN '50-59'
            WHEN c.AGE BETWEEN 60 AND 69 THEN '60-69'
            ELSE '70+'
        END AS age_group,
        SUM(t.Sum_payment) AS total_sum,
        COUNT(*) AS operations_count,
        AVG(t.Sum_payment) AS avg_check
    FROM transactions t
    LEFT JOIN customers_info c
        ON t.ID_client = c.Id_client
    WHERE t.date_new >= '2015-06-01'
      AND t.date_new < '2016-06-01'
    GROUP BY quarter, age_group
),
quarter_total AS (
    SELECT
        CONCAT(YEAR(date_new), '-Q', QUARTER(date_new)) AS quarter,
        SUM(Sum_payment) AS quarter_sum,
        COUNT(*) AS quarter_operations
    FROM transactions
    WHERE date_new >= '2015-06-01'
      AND date_new < '2016-06-01'
    GROUP BY quarter
)
SELECT
    aq.quarter,
    aq.age_group,
    aq.total_sum,
    aq.operations_count,
    aq.avg_check,
    aq.total_sum / qt.quarter_sum * 100 AS sum_share_percent,
    aq.operations_count / qt.quarter_operations * 100 AS operations_share_percent
FROM age_quarter aq
JOIN quarter_total qt
    ON aq.quarter = qt.quarter
ORDER BY aq.quarter, aq.age_group;
