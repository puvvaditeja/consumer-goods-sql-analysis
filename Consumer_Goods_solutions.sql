-- 1. Total quantity sold by product category
SELECT dp.category, SUM(fsm.sold_quantity) AS total_sold
FROM fact_sales_monthly fsm
JOIN dim_product dp ON fsm.product_code = dp.product_code
GROUP BY dp.category
ORDER BY total_sold DESC;

-- 2.Top 5 selling products in 2023
SELECT dp.product, SUM(fsm.sold_quantity) AS total_sold
FROM fact_sales_monthly fsm
JOIN dim_product dp ON fsm.product_code = dp.product_code
WHERE fsm.fiscal_year = 2023
GROUP BY dp.product
ORDER BY total_sold DESC
LIMIT 5;

-- 3.In which quarter of 2020, got the maximum total_sold_quantity?
SELECT
CASE
WHEN month(date) IN (9,10,11) THEN "Q1"
WHEN month(date) IN (12,1,2) THEN "Q2"
WHEN month(date) IN (3,4,5) THEN "Q3"
WHEN month(date) IN (6,7,8) THEN "Q4"
END AS Quarters, Concat(Round(sum(sold_quantity)/1000000,2),'M') AS Total_sold_quantity_mln
FROM fact_sales_monthly 
WHERE fiscal_year=2020
GROUP BY Quarters;

-- 4.Identifying Customers Who Only Purchased Products from a Single Product Segment:
SELECT
    dc.customer
FROM
    fact_sales_monthly fsm
JOIN
    dim_customer dc ON fsm.customer_code = dc.customer_code
JOIN
    dim_product dp ON fsm.product_code = dp.product_code
GROUP BY
    dc.customer
HAVING
    COUNT(DISTINCT dp.segment) = 1;
    
-- 5.Calculating the Profit Margin (Gross Price - Manufacturing Cost) for Each Product in a Specific Year
SELECT
    dp.product,
    fgp.fiscal_year,
    AVG(fgp.gross_price) AS average_gross_price,
    AVG(fmc.manufacturing_cost) AS average_manufacturing_cost,
    AVG(fgp.gross_price) - AVG(fmc.manufacturing_cost) AS profit_margin
FROM
    dim_product dp
JOIN
    fact_gross_price fgp ON dp.product_code = fgp.product_code
JOIN
    fact_manufacturing_cost fmc ON dp.product_code = fmc.product_code AND fgp.fiscal_year = fmc.cost_year
WHERE
    fgp.fiscal_year = 2020 -- Specify the fiscal year
GROUP BY
    dp.product,
    fgp.fiscal_year
ORDER BY
    profit_margin DESC;

-- 6.Ranking Customers by Total Sales Quantity within Each Region
SELECT
    dc.region,
    dc.customer,
    SUM(fsm.sold_quantity) AS total_quantity,
    RANK() OVER (PARTITION BY dc.region ORDER BY SUM(fsm.sold_quantity) DESC) AS customer_rank_in_region
FROM
    fact_sales_monthly fsm
JOIN
    dim_customer dc ON fsm.customer_code = dc.customer_code
GROUP BY
    dc.region,
    dc.customer
ORDER BY
    dc.region,
    customer_rank_in_region;
    
-- 7.Products with the Highest Manufacturing Cost in a Given Fiscal Year
SELECT
    dp.product,
    fmc.manufacturing_cost
FROM
    fact_manufacturing_cost fmc
JOIN
    dim_product dp ON fmc.product_code = dp.product_code
WHERE
    fmc.cost_year = 2020 -- Correct column name
ORDER BY
    fmc.manufacturing_cost DESC
LIMIT 1;

-- 8.Customers Who Purchased Products from Multiple Categories
SELECT
    dc.customer
FROM
    fact_sales_monthly fsm
JOIN
    dim_customer dc ON fsm.customer_code = dc.customer_code
JOIN
    dim_product dp ON fsm.product_code = dp.product_code
GROUP BY
    dc.customer
HAVING
    COUNT(DISTINCT dp.category) > 1;
    
-- 9.Products with Sales Quantity Above the Overall Average
SELECT
    dp.product,
    SUM(fsm.sold_quantity) AS total_sold_quantity
FROM
    fact_sales_monthly fsm
JOIN
    dim_product dp ON fsm.product_code = dp.product_code
GROUP BY
    dp.product
HAVING
    SUM(fsm.sold_quantity) > (SELECT AVG(sold_quantity) FROM fact_sales_monthly);

-- 10.To ensure that the sold_quantity in fact_sales_monthly is always greater than 0.
DELIMITER //
CREATE TRIGGER `CheckSalesQuantity`
BEFORE INSERT ON `fact_sales_monthly`
FOR EACH ROW
BEGIN
    IF NEW.sold_quantity <= 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Sold quantity must be greater than zero.';
    END IF;
END //
DELIMITER ;

INSERT INTO fact_sales_monthly (date, product_code, customer_code, sold_quantity)
VALUES ('2024-01-15', 'P001', 001, 0);

-- 11.Products Whose Average Gross Price is Higher Than Their Average Manufacturing Cost
SELECT
    dp.product
FROM
    dim_product dp
WHERE
    dp.product_code IN (
        SELECT
            fgp.product_code
        FROM
            fact_gross_price fgp
        GROUP BY
            fgp.product_code
        HAVING
            AVG(fgp.gross_price) > (
                SELECT
                    AVG(fmc.manufacturing_cost)
                FROM
                    fact_manufacturing_cost fmc
                WHERE
                    fmc.product_code = fgp.product_code
            )
    );
    
-- 12.Customers Whose Average Pre-Invoice Discount Percentage is Higher Than the Average Discount Percentage Across All Customers
SELECT
    dc.customer
FROM
    dim_customer dc
WHERE
    dc.customer_code IN (
        SELECT
            fpd.customer_code
        FROM
            fact_pre_invoice_deductions fpd
        GROUP BY
            fpd.customer_code
        HAVING
            AVG(fpd.pre_invoice_discount_pct) > (SELECT AVG(pre_invoice_discount_pct) FROM fact_pre_invoice_deductions)
    );
    
