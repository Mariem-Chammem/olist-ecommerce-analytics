CREATE DATABASE olist_analytics;
USE olist_analytics;
SELECT DATABASE();
USE olist_analytics;

CREATE TABLE customers (
    customer_id VARCHAR(50) PRIMARY KEY,
    customer_unique_id VARCHAR(50),
    customer_zip_code_prefix INT,
    customer_city VARCHAR(100),
    customer_state VARCHAR(10)
);

CREATE TABLE orders (
    order_id VARCHAR(50) PRIMARY KEY,
    customer_id VARCHAR(50),
    order_status VARCHAR(30),
    order_purchase_timestamp DATETIME,
    order_approved_at DATETIME NULL,
    order_delivered_carrier_date DATETIME NULL,
    order_delivered_customer_date DATETIME NULL,
    order_estimated_delivery_date DATETIME NULL,
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
);

CREATE TABLE order_items (
    order_id VARCHAR(50),
    order_item_id INT,
    product_id VARCHAR(50),
    seller_id VARCHAR(50),
    shipping_limit_date DATETIME,
    price DECIMAL(12,2),
    freight_value DECIMAL(12,2),
    PRIMARY KEY (order_id, order_item_id)
);

CREATE TABLE products (
    product_id VARCHAR(50) PRIMARY KEY,
    product_category_name VARCHAR(100),
    product_name_lenght INT,
    product_description_lenght INT,
    product_photos_qty INT,
    product_weight_g DECIMAL(12,2),
    product_length_cm DECIMAL(12,2),
    product_height_cm DECIMAL(12,2),
    product_width_cm DECIMAL(12,2)
);

CREATE TABLE sellers (
    seller_id VARCHAR(50) PRIMARY KEY,
    seller_zip_code_prefix INT,
    seller_city VARCHAR(100),
    seller_state VARCHAR(10)
);
SHOW TABLES;
SHOW VARIABLES LIKE 'secure_file_priv';
USE olist_analytics;

LOAD DATA INFILE
'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/olist_customers_dataset.csv'
INTO TABLE customers
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(
    customer_id,
    customer_unique_id,
    customer_zip_code_prefix,
    customer_city,
    customer_state
);
SELECT COUNT(*) AS customer_count
FROM customers;
SELECT COUNT(*) AS order_count
FROM orders;
LOAD DATA INFILE
'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/olist_orders_dataset.csv'
INTO TABLE orders
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(
    order_id,
    customer_id,
    order_status,
    @purchase,
    @approved,
    @carrier,
    @customer_delivery,
    @estimated
)
SET
    order_purchase_timestamp =
        NULLIF(@purchase, ''),
    order_approved_at =
        NULLIF(@approved, ''),
    order_delivered_carrier_date =
        NULLIF(@carrier, ''),
    order_delivered_customer_date =
        NULLIF(@customer_delivery, ''),
    order_estimated_delivery_date =
        NULLIF(@estimated, '');
SELECT COUNT(*) AS order_count
FROM orders;
SELECT COUNT(*) AS orphan_orders
FROM orders o
LEFT JOIN customers c
    ON o.customer_id = c.customer_id
WHERE c.customer_id IS NULL;
SELECT COUNT(*) AS product_count
FROM products;
LOAD DATA INFILE
'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/olist_products_dataset.csv'
INTO TABLE products
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(
    product_id,
    product_category_name,
    @name_length,
    @description_length,
    @photos_qty,
    @weight_g,
    @length_cm,
    @height_cm,
    @width_cm
)
SET
    product_name_lenght = NULLIF(@name_length, ''),
    product_description_lenght = NULLIF(@description_length, ''),
    product_photos_qty = NULLIF(@photos_qty, ''),
    product_weight_g = NULLIF(@weight_g, ''),
    product_length_cm = NULLIF(@length_cm, ''),
    product_height_cm = NULLIF(@height_cm, ''),
    product_width_cm = NULLIF(@width_cm, '');
SELECT COUNT(*) AS product_count
FROM products;
LOAD DATA INFILE
'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/olist_sellers_dataset.csv'
INTO TABLE sellers
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(
    seller_id,
    seller_zip_code_prefix,
    seller_city,
    seller_state
);
SELECT COUNT(*) AS seller_count
FROM sellers;
LOAD DATA INFILE
'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/olist_order_items_dataset.csv'
INTO TABLE order_items
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(
    order_id,
    order_item_id,
    product_id,
    seller_id,
    shipping_limit_date,
    price,
    freight_value
);
SELECT COUNT(*) AS item_count
FROM order_items;
SELECT COUNT(*) AS orphan_order_items
FROM order_items oi
LEFT JOIN orders o
    ON oi.order_id = o.order_id
WHERE o.order_id IS NULL;
SELECT COUNT(*) AS orphan_products
FROM order_items oi
LEFT JOIN products p
    ON oi.product_id = p.product_id
WHERE p.product_id IS NULL;
CREATE TABLE category_translation (
    product_category_name VARCHAR(100) PRIMARY KEY,
    product_category_name_english VARCHAR(100)
);
SHOW TABLES;
LOAD DATA INFILE
'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/product_category_name_translation.csv'
INTO TABLE category_translation
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;
SELECT COUNT(*) AS translation_rows
FROM category_translation;
SELECT
    COUNT(DISTINCT o.order_id) AS total_orders,
    COUNT(DISTINCT CASE
        WHEN o.order_status = 'delivered' THEN o.order_id
    END) AS delivered_orders,

    ROUND(
        100.0 * COUNT(DISTINCT CASE
            WHEN o.order_status = 'delivered' THEN o.order_id
        END)
        / COUNT(DISTINCT o.order_id),
        2
    ) AS delivery_rate_pct,

    ROUND(SUM(oi.price), 2) AS product_revenue,
    ROUND(SUM(oi.freight_value), 2) AS freight_revenue,
    ROUND(SUM(oi.price + oi.freight_value), 2) AS total_transaction_value,

    ROUND(
        SUM(oi.price) / COUNT(DISTINCT o.order_id),
        2
    ) AS average_order_value

FROM orders o
JOIN order_items oi
    ON o.order_id = oi.order_id;
WITH monthly_sales AS (
    SELECT
        DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m') AS month,
        SUM(oi.price) AS revenue,
        COUNT(DISTINCT o.order_id) AS orders
    FROM orders o
    JOIN order_items oi
        ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m')
)

SELECT
    month,
    ROUND(revenue, 2) AS revenue,
    orders,
    ROUND(
        100 * (revenue - LAG(revenue) OVER (ORDER BY month))
        / LAG(revenue) OVER (ORDER BY month),
        2
    ) AS revenue_growth_pct
FROM monthly_sales
ORDER BY month;
WITH customer_orders AS (
    SELECT
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id) AS order_count,
        SUM(oi.price) AS total_spend
    FROM customers c
    JOIN orders o
        ON c.customer_id = o.customer_id
    JOIN order_items oi
        ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
),

customer_segments AS (
    SELECT
        customer_unique_id,
        order_count,
        total_spend,
        CASE
            WHEN order_count = 1 THEN 'One-time'
            ELSE 'Repeat'
        END AS customer_type
    FROM customer_orders
)

SELECT
    customer_type,
    COUNT(*) AS customers,
    ROUND(
        100.0 * COUNT(*) / SUM(COUNT(*)) OVER (),
        2
    ) AS customer_share_pct,
    ROUND(SUM(total_spend), 2) AS revenue,
    ROUND(
        100.0 * SUM(total_spend) / SUM(SUM(total_spend)) OVER (),
        2
    ) AS revenue_share_pct,
    ROUND(AVG(total_spend), 2) AS avg_customer_spend
FROM customer_segments
GROUP BY customer_type
ORDER BY revenue DESC;
WITH seller_performance AS (
    SELECT
        s.seller_id,
        s.seller_city,
        s.seller_state,
        COUNT(DISTINCT o.order_id) AS orders,
        COUNT(oi.order_item_id) AS units_sold,
        SUM(oi.price) AS revenue,
        AVG(oi.price) AS avg_item_price
    FROM sellers s
    JOIN order_items oi
        ON s.seller_id = oi.seller_id
    JOIN orders o
        ON oi.order_id = o.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY
        s.seller_id,
        s.seller_city,
        s.seller_state
)

SELECT
    seller_id,
    seller_city,
    seller_state,
    orders,
    units_sold,
    ROUND(revenue, 2) AS revenue,
    ROUND(avg_item_price, 2) AS avg_item_price,
    RANK() OVER (ORDER BY revenue DESC) AS revenue_rank
FROM seller_performance
ORDER BY revenue DESC
LIMIT 15;
WITH category_sales AS (
    SELECT
        COALESCE(
            ct.product_category_name_english,
            p.product_category_name,
            'unknown'
        ) AS category,
        COUNT(DISTINCT oi.order_id) AS orders,
        COUNT(*) AS units_sold,
        SUM(oi.price) AS revenue,
        SUM(oi.freight_value) AS freight
    FROM order_items oi
    JOIN orders o
        ON oi.order_id = o.order_id
    JOIN products p
        ON oi.product_id = p.product_id
    LEFT JOIN category_translation ct
        ON p.product_category_name = ct.product_category_name
    WHERE o.order_status = 'delivered'
    GROUP BY
        COALESCE(
            ct.product_category_name_english,
            p.product_category_name,
            'unknown'
        )
)

SELECT
    category,
    orders,
    units_sold,
    ROUND(revenue, 2) AS revenue,
    ROUND(freight, 2) AS freight,
    ROUND(revenue / units_sold, 2) AS avg_item_revenue,
    RANK() OVER (ORDER BY revenue DESC) AS revenue_rank
FROM category_sales
ORDER BY revenue DESC
LIMIT 15;
WITH delivery_analysis AS (
    SELECT
        o.order_id,

        DATEDIFF(
            o.order_delivered_customer_date,
            o.order_purchase_timestamp
        ) AS delivery_days,

        DATEDIFF(
            o.order_delivered_customer_date,
            o.order_estimated_delivery_date
        ) AS delay_days

    FROM orders o
    WHERE o.order_status = 'delivered'
      AND o.order_delivered_customer_date IS NOT NULL
      AND o.order_estimated_delivery_date IS NOT NULL
)

SELECT
    CASE
        WHEN delay_days < 0 THEN 'Early'
        WHEN delay_days = 0 THEN 'On Time'
        WHEN delay_days > 0 THEN 'Late'
    END AS delivery_status,

    COUNT(*) AS orders,

    ROUND(
        100.0 * COUNT(*) / SUM(COUNT(*)) OVER (),
        2
    ) AS percentage_of_orders,

    ROUND(AVG(delivery_days), 2) AS avg_delivery_days,

    ROUND(AVG(delay_days), 2) AS avg_delay_days

FROM delivery_analysis
GROUP BY
    CASE
        WHEN delay_days < 0 THEN 'Early'
        WHEN delay_days = 0 THEN 'On Time'
        WHEN delay_days > 0 THEN 'Late'
    END
ORDER BY orders DESC;
WITH seller_delivery AS (
    SELECT
        oi.seller_id,
        s.seller_city,
        s.seller_state,

        COUNT(DISTINCT o.order_id) AS orders,

        SUM(
            CASE
                WHEN o.order_delivered_customer_date
                     > o.order_estimated_delivery_date
                THEN 1
                ELSE 0
            END
        ) AS late_orders,

        AVG(
            DATEDIFF(
                o.order_delivered_customer_date,
                o.order_estimated_delivery_date
            )
        ) AS avg_delay_days

    FROM order_items oi

    JOIN orders o
        ON oi.order_id = o.order_id

    JOIN sellers s
        ON oi.seller_id = s.seller_id

    WHERE o.order_status = 'delivered'
      AND o.order_delivered_customer_date IS NOT NULL
      AND o.order_estimated_delivery_date IS NOT NULL

    GROUP BY
        oi.seller_id,
        s.seller_city,
        s.seller_state
),

seller_risk AS (
    SELECT
        *,
        ROUND(
            100.0 * late_orders / orders,
            2
        ) AS late_rate_pct
    FROM seller_delivery
)

SELECT
    seller_id,
    seller_city,
    seller_state,
    orders,
    late_orders,
    late_rate_pct,
    ROUND(avg_delay_days, 2) AS avg_delay_days,

    RANK() OVER (
        ORDER BY late_rate_pct DESC
    ) AS risk_rank

FROM seller_risk

WHERE orders >= 50

ORDER BY late_rate_pct DESC

LIMIT 15;
WITH customer_revenue AS (
    SELECT
        c.customer_unique_id,
        SUM(oi.price) AS revenue
    FROM customers c
    JOIN orders o
        ON c.customer_id = o.customer_id
    JOIN order_items oi
        ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
),

ranked_customers AS (
    SELECT
        customer_unique_id,
        revenue,

        NTILE(10) OVER (
            ORDER BY revenue DESC
        ) AS revenue_decile

    FROM customer_revenue
)

SELECT
    revenue_decile,

    COUNT(*) AS customers,

    ROUND(SUM(revenue), 2) AS revenue,

    ROUND(
        100 * SUM(revenue)
        / SUM(SUM(revenue)) OVER (),
        2
    ) AS revenue_share_pct

FROM ranked_customers

GROUP BY revenue_decile
ORDER BY revenue_decile;
WITH customer_rfm AS (
    SELECT
        c.customer_unique_id,

        DATEDIFF(
            '2018-09-03',
            MAX(o.order_purchase_timestamp)
        ) AS recency_days,

        COUNT(DISTINCT o.order_id) AS frequency,

        ROUND(SUM(oi.price), 2) AS monetary_value

    FROM customers c

    JOIN orders o
        ON c.customer_id = o.customer_id

    JOIN order_items oi
        ON o.order_id = oi.order_id

    WHERE o.order_status = 'delivered'

    GROUP BY c.customer_unique_id
),

rfm_scored AS (
    SELECT
        *,
        
        CASE
            WHEN recency_days <= 90 THEN 5
            WHEN recency_days <= 180 THEN 4
            WHEN recency_days <= 360 THEN 3
            WHEN recency_days <= 540 THEN 2
            ELSE 1
        END AS R_score,

        CASE
            WHEN frequency = 1 THEN 1
            WHEN frequency = 2 THEN 2
            WHEN frequency = 3 THEN 3
            WHEN frequency BETWEEN 4 AND 5 THEN 4
            ELSE 5
        END AS F_score,

        NTILE(5) OVER (
            ORDER BY monetary_value
        ) AS M_score

    FROM customer_rfm
)

SELECT
    customer_unique_id,
    recency_days,
    frequency,
    monetary_value,
    R_score,
    F_score,
    M_score,
    CONCAT(R_score, F_score, M_score) AS RFM_score,

    CASE
        WHEN R_score >= 4 AND F_score >= 4 AND M_score >= 4
            THEN 'Champions'

        WHEN R_score >= 3 AND F_score >= 3
            THEN 'Loyal Customers'

        WHEN R_score >= 4 AND F_score <= 2
            THEN 'Potential Loyalists'

        WHEN R_score <= 2 AND F_score >= 3
            THEN 'At Risk'

        WHEN R_score <= 2 AND F_score <= 2 AND M_score <= 2
            THEN 'Hibernating / Low Value'

        ELSE 'Other'
    END AS customer_segment

FROM rfm_scored;

SELECT
    COUNT(DISTINCT customer_city) AS unique_cities,
    COUNT(DISTINCT customer_state) AS unique_states
FROM customers;
SELECT
    customer_city,
    customer_state,
    COUNT(*) AS customer_records
FROM customers
GROUP BY customer_city, customer_state
ORDER BY customer_records DESC
LIMIT 20;

SELECT
    customer_city,
    customer_state,
    COUNT(*) AS customer_records
FROM customers
GROUP BY customer_city, customer_state
ORDER BY customer_records DESC
LIMIT 20;
SELECT
    customer_city,
    customer_state,
    COUNT(*) AS customer_records
FROM customers
GROUP BY customer_city, customer_state
ORDER BY customer_records DESC
LIMIT 20;