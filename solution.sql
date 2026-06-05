-- Этап 1. Создание и заполнение БД

-- ПРОЕКТ "ВРУМ-БУМ"

-- ЭТАП 1. СОЗДАНИЕ СХЕМ И ТАБЛИЦ

CREATE SCHEMA IF NOT EXISTS raw_data;

CREATE TABLE raw_data.sales (
    id INTEGER,
    auto VARCHAR(100),
    gasoline_consumption NUMERIC(4,1),
    price NUMERIC(10,2),
    sale_date DATE,
    person_name VARCHAR(100),
    phone VARCHAR(50),
    discount INTEGER,
    brand_origin VARCHAR(100)
);

CREATE SCHEMA IF NOT EXISTS car_shop;

-- Страны производителей

CREATE TABLE car_shop.countries (
    country_id SERIAL PRIMARY KEY, 
    /* автоинкрементный идентификатор страны */
    country_name VARCHAR(100) NOT NULL UNIQUE 
    /* название страны содержит текстовые данные различной длины */
);

-- Бренды автомобилей

CREATE TABLE car_shop.brands (
    brand_id SERIAL PRIMARY KEY, 
    /* автоинкрементный идентификатор бренда */
    brand_name VARCHAR(100) NOT NULL UNIQUE, 
    /* название бренда может содержать буквы, цифры и специальные символы */
    country_id INTEGER NOT NULL REFERENCES car_shop.countries(country_id) 
    /* внешний ключ на страну производителя */
);

-- Модели автомобилей

CREATE TABLE car_shop.car_models (
    model_id SERIAL PRIMARY KEY,
    /* автоинкрементный идентификатор модели */
    brand_id INTEGER NOT NULL REFERENCES car_shop.brands(brand_id),
    /* внешний ключ на бренд */
    model_name VARCHAR(100) NOT NULL,
    /* название модели является строковым значением */
    gasoline_consumption NUMERIC(4,1)
    /* расход топлива хранится с точностью до десятых;
       допускается NULL, так как в исходных данных есть значения null */
);

-- Цвета автомобилей

CREATE TABLE car_shop.colors (
    color_id SERIAL PRIMARY KEY,
    /* автоинкрементный идентификатор цвета */
    color_name VARCHAR(50) NOT NULL UNIQUE
    /* название цвета является текстом небольшой длины */
);

-- Автомобили

CREATE TABLE car_shop.cars (
    car_id SERIAL PRIMARY KEY,
    /* автоинкрементный идентификатор автомобиля */
    model_id INTEGER NOT NULL REFERENCES car_shop.car_models(model_id)
    /* внешний ключ на модель автомобиля */
);

-- Связь многие-ко-многим между автомобилями и цветами

CREATE TABLE car_shop.car_colors (
    car_id INTEGER NOT NULL REFERENCES car_shop.cars(car_id),
    /* внешний ключ на автомобиль */
    color_id INTEGER NOT NULL REFERENCES car_shop.colors(color_id),
    /* внешний ключ на цвет */
    PRIMARY KEY (car_id, color_id)
    /* составной ключ исключает дублирование связей */
);

-- Покупатели

CREATE TABLE car_shop.customers (
    customer_id SERIAL PRIMARY KEY,
    /* автоинкрементный идентификатор клиента */
    customer_name VARCHAR(100) NOT NULL,
    /* имя клиента содержит текстовые данные */
    phone VARCHAR(50) NOT NULL UNIQUE
    /* телефон может содержать цифры, +, -, пробелы и расширения вида x123 */
);

-- Продажи

CREATE TABLE car_shop.sales (
    sale_id SERIAL PRIMARY KEY,
    /* автоинкрементный идентификатор продажи */
    car_id INTEGER NOT NULL REFERENCES car_shop.cars(car_id),
    /* проданный автомобиль */
    customer_id INTEGER NOT NULL REFERENCES car_shop.customers(customer_id),
    /* покупатель */
    sale_date DATE NOT NULL,
    /* хранится только календарная дата продажи */
    price NUMERIC(10,2) NOT NULL CHECK (price > 0),
    /* денежные значения требуют высокой точности,
       две цифры после запятой достаточны для стоимости автомобиля */
    discount INTEGER CHECK (discount BETWEEN 0 AND 100)
    /* скидка задаётся целым числом процентов от 0 до 100 */
);

SELECT *
FROM raw_data.sales
LIMIT 10;

-- ЭТАП 1. ЗАПОЛНЕНИЕ ТАБЛИЦ

INSERT INTO car_shop.countries (country_name)
SELECT DISTINCT brand_origin
FROM raw_data.sales
WHERE brand_origin IS NOT NULL;

SELECT *
FROM car_shop.countries;

INSERT INTO car_shop.colors (color_name)
SELECT DISTINCT trim(split_part(auto, ',', 2))
FROM raw_data.sales;

SELECT *
FROM car_shop.colors
ORDER BY color_name;

INSERT INTO car_shop.customers (
    customer_name,
    phone
)
SELECT DISTINCT
    person_name,
    phone
FROM raw_data.sales;

SELECT COUNT(*)
FROM car_shop.customers;

ALTER TABLE car_shop.brands
ALTER COLUMN country_id DROP NOT NULL;

SELECT
    column_name,
    is_nullable
FROM information_schema.columns
WHERE table_schema = 'car_shop'
  AND table_name = 'brands';

INSERT INTO car_shop.brands (
    brand_name,
    country_id
)
SELECT DISTINCT
    split_part(s.auto, ' ', 1),
    c.country_id
FROM raw_data.sales s
LEFT JOIN car_shop.countries c
       ON c.country_name = s.brand_origin;

SELECT *
FROM car_shop.brands
ORDER BY brand_name;

INSERT INTO car_shop.car_models (
    brand_id,
    model_name,
    gasoline_consumption
)
SELECT DISTINCT
    b.brand_id,
    trim(
        replace(
            split_part(s.auto, ',', 1),
            split_part(s.auto, ' ', 1),
            ''
        )
    ),
    s.gasoline_consumption
FROM raw_data.sales s
JOIN car_shop.brands b
    ON b.brand_name = split_part(s.auto, ' ', 1);

SELECT COUNT(*)
FROM car_shop.car_models;

SELECT *
FROM car_shop.car_models
ORDER BY model_id
LIMIT 15;

SELECT
    b.brand_name,
    m.model_name,
    COUNT(DISTINCT m.gasoline_consumption)
FROM car_shop.car_models m
JOIN car_shop.brands b
    ON b.brand_id = m.brand_id
GROUP BY b.brand_name, m.model_name
HAVING COUNT(DISTINCT m.gasoline_consumption) > 1;

INSERT INTO car_shop.cars (model_id)
SELECT model_id
FROM car_shop.car_models;

SELECT COUNT(*)
FROM car_shop.cars;

SELECT
    split_part(auto, ',', 1) AS car,
    COUNT(DISTINCT trim(split_part(auto, ',', 2))) AS colors_count
FROM raw_data.sales
GROUP BY 1
HAVING COUNT(DISTINCT trim(split_part(auto, ',', 2))) > 1;

SELECT *
FROM car_shop.cars
LIMIT 5;

SELECT
    column_name
FROM information_schema.columns
WHERE table_schema = 'car_shop'
  AND table_name = 'cars';

SELECT DISTINCT
    c.car_id,
    clr.color_id
FROM raw_data.sales s
JOIN car_shop.brands b
    ON b.brand_name = split_part(s.auto, ' ', 1)
JOIN car_shop.car_models m
    ON m.brand_id = b.brand_id
   AND m.model_name =
       trim(
           replace(
               split_part(s.auto, ',', 1),
               split_part(s.auto, ' ', 1),
               ''
           )
       )
JOIN car_shop.cars c
    ON c.model_id = m.model_id
JOIN car_shop.colors clr
    ON clr.color_name = trim(split_part(s.auto, ',', 2))
LIMIT 10;

SELECT COUNT(*)
FROM car_shop.car_colors;

INSERT INTO car_shop.car_colors (car_id, color_id)
SELECT DISTINCT
    c.car_id,
    clr.color_id
FROM raw_data.sales s
JOIN car_shop.brands b
    ON b.brand_name = split_part(s.auto, ' ', 1)
JOIN car_shop.car_models m
    ON m.brand_id = b.brand_id
   AND m.model_name =
       trim(
           replace(
               split_part(s.auto, ',', 1),
               split_part(s.auto, ' ', 1),
               ''
           )
       )
JOIN car_shop.cars c
    ON c.model_id = m.model_id
JOIN car_shop.colors clr
    ON clr.color_name =
       trim(split_part(s.auto, ',', 2));

SELECT COUNT(*)
FROM car_shop.car_colors;

SELECT
    column_name,
    data_type
FROM information_schema.columns
WHERE table_schema = 'car_shop'
  AND table_name = 'sales'
ORDER BY ordinal_position;

SELECT *
FROM raw_data.sales
LIMIT 1;

INSERT INTO car_shop.sales (
    car_id,
    customer_id,
    sale_date,
    price,
    discount
)
SELECT
    c.car_id,
    cust.customer_id,
    s.sale_date,
    s.price,
    s.discount
FROM raw_data.sales s
JOIN car_shop.customers cust
    ON cust.phone = s.phone
JOIN car_shop.brands b
    ON b.brand_name = split_part(s.auto, ' ', 1)
JOIN car_shop.car_models m
    ON m.brand_id = b.brand_id
   AND m.model_name =
       trim(
           replace(
               split_part(s.auto, ',', 1),
               split_part(s.auto, ' ', 1),
               ''
           )
       )
JOIN car_shop.cars c
    ON c.model_id = m.model_id;

SELECT COUNT(*) FROM car_shop.sales;

SELECT COUNT(*) FROM raw_data.sales;


-- Этап 2. Создание выборок

---- Задание 1. Напишите запрос, который выведет процент моделей машин, у которых нет параметра `gasoline_consumption`.
SELECT ROUND(
    100.0 * COUNT(*) FILTER (WHERE gasoline_consumption IS NULL)
    / COUNT(*),
    2
) AS nulls_percentage_gasoline_consumption
FROM car_shop.car_models;


---- Задание 2. Напишите запрос, который покажет название бренда и среднюю цену его автомобилей в разбивке по всем годам с учётом скидки.
SELECT
    b.brand_name,
    EXTRACT(YEAR FROM s.sale_date)::integer AS year,
    ROUND(AVG(s.price), 2) AS price_avg
FROM car_shop.sales s
JOIN car_shop.cars c
    ON c.car_id = s.car_id
JOIN car_shop.car_models m
    ON m.model_id = c.model_id
JOIN car_shop.brands b
    ON b.brand_id = m.brand_id
GROUP BY
    b.brand_name,
    EXTRACT(YEAR FROM s.sale_date)
ORDER BY
    b.brand_name,
    year;


---- Задание 3. Посчитайте среднюю цену всех автомобилей с разбивкой по месяцам в 2022 году с учётом скидки.
SELECT
    EXTRACT(MONTH FROM sale_date)::integer AS month,
    EXTRACT(YEAR FROM sale_date)::integer AS year,
    ROUND(AVG(price), 2) AS price_avg
FROM car_shop.sales
WHERE EXTRACT(YEAR FROM sale_date) = 2022
GROUP BY
    EXTRACT(YEAR FROM sale_date),
    EXTRACT(MONTH FROM sale_date)
ORDER BY month;


---- Задание 4. Напишите запрос, который выведет список купленных машин у каждого пользователя.
SELECT
    cu.customer_name AS person,
    STRING_AGG(
        b.brand_name || ' ' || m.model_name,
        ', '
    ) AS cars
FROM car_shop.sales s
JOIN car_shop.customers cu
    ON cu.customer_id = s.customer_id
JOIN car_shop.cars c
    ON c.car_id = s.car_id
JOIN car_shop.car_models m
    ON m.model_id = c.model_id
JOIN car_shop.brands b
    ON b.brand_id = m.brand_id
GROUP BY
    cu.customer_name
ORDER BY
    cu.customer_name;


---- Задание 5. Напишите запрос, который вернёт самую большую и самую маленькую цену продажи автомобиля.
SELECT
    co.country_name AS brand_origin,
    ROUND(MAX(s.price / (1 - s.discount / 100.0)), 2) AS price_max,
    ROUND(MIN(s.price / (1 - s.discount / 100.0)), 2) AS price_min
FROM car_shop.sales s
JOIN car_shop.cars c
    ON c.car_id = s.car_id
JOIN car_shop.car_models m
    ON m.model_id = c.model_id
JOIN car_shop.brands b
    ON b.brand_id = m.brand_id
JOIN car_shop.countries co
    ON co.country_id = b.country_id
GROUP BY
    co.country_name
ORDER BY
    co.country_name;


---- Задание 6. Напишите запрос, который покажет количество всех пользователей из США.
SELECT COUNT(*) AS persons_from_usa_count
FROM car_shop.customers
WHERE phone LIKE '+1%';
