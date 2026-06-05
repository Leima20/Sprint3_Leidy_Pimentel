
Nivell 1: Entorn i Ingesta Híbrida (Code-First)

--Ejercicio 1: Arquitectura de Datos (Lógica vs. Física)

/*Dataset Físico sprint3_silver */

CREATE SCHEMA `sprint3-leidy-pimentel.sprint3_silver`
OPTIONS(
  location = 'EU'
);


/* Ejercicio 2: Ingesta en Capa Bronze (Conexión DDL)*/

--Crear transactions_raw 
CREATE OR REPLACE EXTERNAL TABLE `sprint3-leidy-pimentel-v2.sprint3_bronze.transactions_raw`
OPTIONS (
  format = 'CSV',
  uris = ['gs://bootcamp-data-analytics-public/ERP/transactions.csv'],
  field_delimiter = ';'
);


--Crear tabla de prueba para inspeccionar los datos en companies.csv
CREATE OR REPLACE EXTERNAL TABLE `sprint3-leidy-pimentel-v2.sprint3_bronze.tabla_inspeccion_companies`
OPTIONS (
  format = 'CSV',
  uris = ['gs://bootcamp-data-analytics-public/ERP/companies.csv']
);

-- Se verifica las columnas que contiene 
SELECT * FROM `sprint3-leidy-pimentel-v2.sprint3_bronze.tabla_inspeccion_companies` 
LIMIT 1;

-- Se crea la tabla definitiva companies_raw, sabiendo cuáles columnas la conforman:
CREATE OR REPLACE EXTERNAL TABLE `sprint3-leidy-pimentel-v2.sprint3_bronze.companies_raw` (
  company_id STRING,
  company_name STRING,
  phone STRING,
  email STRING,
  country STRING,
  website STRING
)
OPTIONS (
  format = 'CSV',
  uris = ['gs://bootcamp-data-analytics-public/ERP/companies.csv'],
  skip_leading_rows = 1
);

--Verificar la creación de la tabla companies_raw:
SELECT *
FROM `sprint3-leidy-pimentel-v2.sprint3_bronze.companies_raw`
LIMIT 5;

--Una vez creada la tabla companies_raw, se elimina la tabla_inspeccion_compoanies
DROP TABLE `sprint3-leidy-pimentel-v2.sprint3_bronze.tabla_inspeccion_companies`;

-- Se crea la tabla american_users_raw
CREATE OR REPLACE EXTERNAL TABLE `sprint3-leidy-pimentel-v2.sprint3_bronze.american_users_raw`
OPTIONS (
  format = 'CSV',
  uris = ['gs://bootcamp-data-analytics-public/CRM/american_users.csv']
);


--Se crea la tabla european_users_raw 
CREATE OR REPLACE EXTERNAL TABLE `sprint3-leidy-pimentel-v2.sprint3_bronze.european_users_raw`
OPTIONS (
  format = 'CSV',
  uris = ['gs://bootcamp-data-analytics-public/CRM/european_users.csv']
);


--Se crea la tabla credit_cards_raw
CREATE OR REPLACE EXTERNAL TABLE `sprint3-leidy-pimentel-v2.sprint3_bronze.credit_cards_raw`
OPTIONS (
  format = 'CSV',
  uris = ['gs://bootcamp-data-analytics-public/CRM/credit_cards.csv']
);

-- Ejercicio 4: Arquitectura y Rendimiento. Materialitzación de Datos (Asistido por IA)

--a) Materialitzación de Datos (Asistido por IA)

CREATE OR REPLACE TABLE sprint3_bronze.transactions_raw_native AS
SELECT * FROM sprint3_bronze.transactions_raw;


/*b) Auditoria de Costos.*/

SELECT id FROM sprint3_bronze.transactions_raw;

SELECT id FROM sprint3_bronze.transactions_raw_native;

/*c) El peligro del LIMIT*/


 SELECT * FROM sprint3_bronze.transactions_raw_native;
 SELECT * FROM sprint3_bronze.transactions_raw_native LIMIT 10;



/*Ejercicio 5: Adaptación de sintaxis (Reporting)*/

 SELECT 
  DATE(timestamp) AS fecha,
  ROUND(SUM(amount), 2) AS ingresos_totales
FROM 
  `sprint3_bronze.transactions_raw_native`
WHERE 
  EXTRACT(YEAR FROM timestamp) = 2021 AND declined = 0
GROUP BY 
  fecha
ORDER BY 
  ingresos_totales DESC
LIMIT 5;

/*Ejercicio 6: Consultas Complejas*/

 SELECT 
    c.company_name, 
    c.country, 
    DATE(t.timestamp) AS fecha_transaccion
FROM 
    `sprint3-leidy-pimentel-v2.sprint3_bronze.transactions_raw_native` AS t
INNER JOIN 
    `sprint3-leidy-pimentel-v2.sprint3_bronze.companies_raw` AS c 
    ON t.business_id = c.company_id
WHERE 
    t.amount BETWEEN 100 AND 200
    AND DATE(t.timestamp) IN ('2015-04-29', '2018-07-20', '2024-03-13')
    AND t.declined = 0;

--Nivell 2: Neteja i Transformació (ELT)
--Ejercicio 1: Limpieza de Productos (Data Quality)

--Verificamos que los datos se han cargado correctamente:

  SELECT id, product_name, price, cost 
FROM `sprint3-leidy-pimentel-v2.sprint3_bronze.products_raw` 
LIMIT 5;


/*Se crea la tabla products_clean*/

CREATE OR REPLACE TABLE `sprint3-leidy-pimentel-v2.sprint3_silver.products_clean` AS
SELECT
    id AS product_id,
    product_name AS name,
    CAST(REGEXP_REPLACE(warehouse_id, r'^WH-', '') AS INT64) AS warehouse_id,
    CAST(price AS FLOAT64) AS price,
    weight,
    colour,
    category,
    brand,
    cost,
    launch_date
FROM 
    `sprint3-leidy-pimentel-v2.sprint3_bronze.products_raw`;

  

/*Ejercicio 2: Creación de 'trasactions_clean' (Capa Silver)*/

  CREATE OR REPLACE TABLE `sprint3-leidy-pimentel-v2.sprint3_silver.transactions_clean` AS
SELECT
    id AS transaction_id,
    IFNULL(SAFE_CAST(amount AS FLOAT64), 0.0) AS amount,
    SAFE_CAST(timestamp AS TIMESTAMP) AS timestamp,
    SAFE_CAST(lat AS FLOAT64) AS lat,
    SAFE_CAST(longitude AS FLOAT64) AS longitude,
    ARRAY(
        SELECT CAST(TRIM(id_item) AS INT64) 
        FROM UNNEST(SPLIT(product_ids, ',')) AS id_item
    ) AS product_ids,
    business_id,
    card_id,
    declined
FROM 
    `sprint3-leidy-pimentel-v2.sprint3_bronze.transactions_raw_native`;

/*Ejercicio 3: Unificación de usuarios (UNION)*/

   CREATE OR REPLACE TABLE `sprint3-leidy-pimentel-v2.sprint3_silver.users_combined` AS
SELECT
    id AS user_id,
    name,
    surname,
    phone,
    email,
    SAFE_CAST(birth_date AS DATE) AS birth_date, 
    country,
    city,
    postal_code,
    address,
    'Europe' AS origin
FROM 
    `sprint3-leidy-pimentel-v2.sprint3_bronze.european_users_raw`

UNION ALL

SELECT
    id AS user_id,
    name,
    surname,
    phone,
    email,
    SAFE_CAST(birth_date AS DATE) AS birth_date, 
    country,
    city,
    postal_code,
    address,
    'USA' AS origin
FROM 
    `sprint3-leidy-pimentel-v2.sprint3_bronze.american_users_raw`;

   
/*Ejercicio 4: Materialitzación de Companies y Credit_cards*/

--Creación de companies_clean
    CREATE OR REPLACE TABLE `sprint3-leidy-pimentel-v2.sprint3_silver.companies_clean` AS
SELECT
    company_id,
    company_name,
    phone,
    email,
    country,
    website
FROM 
    `sprint3-leidy-pimentel-v2.sprint3_bronze.companies_raw`;

--Creación de credit_cards_clean:

    CREATE OR REPLACE TABLE `sprint3-leidy-pimentel-v2.sprint3_silver.credit_cards_clean` AS
SELECT
    id AS card_id,      
    user_id,
    iban,
    pan,
    pin,
    cvv,
    track1,
    track2,
    expiring_date
FROM 
    `sprint3-leidy-pimentel-v2.sprint3_bronze.credit_cards_raw`;



/* Nivell 3: Presentació de Dades i Creació de Vistes

Ejercicio 1: La Vista de Marketing (Lógica de Negocio)*/

CREATE OR REPLACE VIEW `sprint3-leidy-pimentel-v2.sprint3_gold.v_marketing_kpis` AS
SELECT
    c.company_id,
    ANY_VALUE(c.company_name) AS company_name,
    ANY_VALUE(c.phone) AS phone,
    ANY_VALUE(c.country) AS country,
    AVG(t.amount) AS average_purchase,
    CASE
        WHEN AVG(t.amount) > 260 THEN 'Premium'
        ELSE 'Standard'
    END AS client_tier
FROM `sprint3-leidy-pimentel-v2.sprint3_silver.companies_clean` AS c
LEFT JOIN `sprint3-leidy-pimentel-v2.sprint3_silver.transactions_clean` AS t
    ON c.company_id = t.business_id
    AND t.declined = 0
GROUP BY c.company_id;

--Para ordenar la tabla:
SELECT *
FROM `sprint3-leidy-pimentel-v2.sprint3_gold.v_marketing_kpis`
ORDER BY
    CASE
        WHEN client_tier = 'Premium' THEN 1
        ELSE 2
    END,
    average_purchase DESC;

--Ejercicio 2: 

CREATE OR REPLACE TABLE `sprint3-leidy-pimentel-v2.sprint3_gold.product_sales_ranking` AS
WITH ventas_individuales AS (
    SELECT 
        id_producto
    FROM 
        `sprint3-leidy-pimentel-v2.sprint3_silver.transactions_clean` AS t,
        UNNEST(t.product_ids) AS id_producto
    WHERE 
        t.declined = 0 
)
SELECT
    p.product_id,
    ANY_VALUE(p.name) AS name,
    ANY_VALUE(p.price) AS price,
    ANY_VALUE(p.colour) AS colour, 
    IFNULL(COUNT(vi.id_producto), 0) AS total_sold
FROM 
    `sprint3-leidy-pimentel-v2.sprint3_silver.products_clean` AS p
LEFT JOIN 
    ventas_individuales AS vi
    ON p.product_id = vi.id_producto
GROUP BY 
    p.product_id 
ORDER BY 
    total_sold DESC; 

--Comprobación 
    SELECT * FROM `sprint3-leidy-pimentel-v2.sprint3_gold.product_sales_ranking`
ORDER BY total_sold DESC;

/*Ejercicio 3: Exportación de Resultados*/
SELECT * FROM `sprint3-leidy-pimentel-v2.sprint3_gold.product_sales_ranking`
ORDER BY total_sold DESC;
