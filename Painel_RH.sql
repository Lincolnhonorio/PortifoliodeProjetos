USE hr_analytics;

-- Tabela Dim Date para a mensuração de padrões gerais
CREATE TABLE IF NOT EXISTS dimdate (
    date_id INT PRIMARY KEY COMMENT 'YYYYMMDD - PK para joins rápidos com HireDate/AttritionDate',
    full_date DATE NOT NULL,
    year INT NOT NULL,
    fiscal_year INT NOT NULL COMMENT 'Ano fiscal (jan-dez; mude lógica se julho-início)',
    quarter INT NOT NULL,
    fiscal_quarter INT NOT NULL COMMENT 'Trimestre fiscal para relatórios de performance',
    month INT NOT NULL,
    month_name VARCHAR(20) NOT NULL COMMENT 'Meses em português para dashboards',
    day INT NOT NULL,
    day_name VARCHAR(20) NOT NULL COMMENT 'Dias da semana em PT-BR',
    weekday INT NOT NULL COMMENT '1=Segunda a 7=Domingo',
    is_weekend BOOLEAN DEFAULT FALSE COMMENT 'Útil para análise de ausências/demandas HR',
    is_month_end BOOLEAN DEFAULT FALSE COMMENT 'Fins de mês para pagamentos e relatórios',
    is_quarter_end BOOLEAN DEFAULT FALSE COMMENT 'Fins de trimestre para avaliações de performance',
    days_in_month INT NOT NULL COMMENT 'Para médias diárias/mensais de attrition'
);

TRUNCATE TABLE dimdate;

INSERT INTO dimdate (date_id, full_date, year, fiscal_year, quarter, fiscal_quarter, month, month_name, day, day_name, weekday, is_weekend, is_month_end, is_quarter_end, days_in_month)
SELECT 
    (YEAR(d) * 10000 + MONTH(d) * 100 + DAY(d)) AS date_id,
    d AS full_date,
    YEAR(d) AS year,
    YEAR(d) AS fiscal_year,  
    QUARTER(d) AS quarter,
    QUARTER(d) AS fiscal_quarter,
    MONTH(d) AS month,
    CASE MONTH(d)
        WHEN 1 THEN 'Janeiro' WHEN 2 THEN 'Fevereiro' WHEN 3 THEN 'Março'
        WHEN 4 THEN 'Abril' WHEN 5 THEN 'Maio' WHEN 6 THEN 'Junho'
        WHEN 7 THEN 'Julho' WHEN 8 THEN 'Agosto' WHEN 9 THEN 'Setembro'
        WHEN 10 THEN 'Outubro' WHEN 11 THEN 'Novembro' WHEN 12 THEN 'Dezembro'
        ELSE 'Inválido'
    END AS month_name,
    DAY(d) AS day,
    CASE WEEKDAY(d)
        WHEN 0 THEN 'Segunda-feira' WHEN 1 THEN 'Terça-feira' WHEN 2 THEN 'Quarta-feira'
        WHEN 3 THEN 'Quinta-feira' WHEN 4 THEN 'Sexta-feira'
        WHEN 5 THEN 'Sábado' WHEN 6 THEN 'Domingo'
        ELSE 'Inválido'
    END AS day_name,
    (WEEKDAY(d) + 1) AS weekday,
    (WEEKDAY(d) >= 5) AS is_weekend,
    (DAY(d) = DAY(LAST_DAY(d))) AS is_month_end,
    (MONTH(d) IN (3,6,9,12) AND DAY(d) = DAY(LAST_DAY(d))) AS is_quarter_end,
    DAY(LAST_DAY(d)) AS days_in_month
    
FROM (
    SELECT DATE_ADD('1980-01-01', INTERVAL seq DAY) AS d
    FROM (
        SELECT (a.N + b.N * 10 + c.N * 100 + d.N * 1000 + e.N * 10000) AS seq
        FROM 
            (SELECT 0 AS N UNION SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4 UNION SELECT 5 UNION SELECT 6 UNION SELECT 7 UNION SELECT 8 UNION SELECT 9) a,
            (SELECT 0 AS N UNION SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4 UNION SELECT 5 UNION SELECT 6 UNION SELECT 7 UNION SELECT 8 UNION SELECT 9) b,
            (SELECT 0 AS N UNION SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4 UNION SELECT 5 UNION SELECT 6 UNION SELECT 7 UNION SELECT 8 UNION SELECT 9) c,
            (SELECT 0 AS N UNION SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4 UNION SELECT 5 UNION SELECT 6 UNION SELECT 7 UNION SELECT 8 UNION SELECT 9) d,
            (SELECT 0 AS N UNION SELECT 1 UNION SELECT 2) e
    ) numbers
    WHERE seq >= 0
) dates
WHERE d BETWEEN '1980-01-01' AND '2007-12-31'
ORDER BY d;

SELECT COUNT(*) AS total_datas FROM dimdate;
SELECT * FROM dimdate WHERE year = 2000 AND month = 1 LIMIT 5;

-- Query 1 (Verifica a estrutura da tabela principal):
DESCRIBE employee;

SELECT * FROM employee LIMIT 5;

SELECT 
    COUNT(*) AS total_com_hiredate,
    MIN(STR_TO_DATE(HireDate, '%m/%d/%Y')) AS data_minima,
    MAX(STR_TO_DATE(HireDate, '%m/%d/%Y')) AS data_maxima,
    MIN(YEAR(STR_TO_DATE(HireDate, '%m/%d/%Y'))) AS exemplo_ano
FROM employee
WHERE HireDate IS NOT NULL;

-- Query 2 (Calcula Média Salarial):
SELECT 
    Department,
    ROUND(AVG(Salary), 2) AS media_salarial_inicial
FROM employee
GROUP BY Department;

-- Query3 (Cálculo de Contratações, Demissões e Crescimento Líquido Baseado Nisso): 
SELECT 
    Department,
    YEAR(STR_TO_DATE(HireDate, '%m/%d/%Y')) AS ano,
    COUNT(*) AS contratacoes,
    SUM(CASE WHEN Attrition = 'Yes' THEN 1 ELSE 0 END) AS desligamentos,
    COUNT(*) - SUM(CASE WHEN Attrition = 'Yes' THEN 1 ELSE 0 END) AS crescimento_liquido
FROM employee
GROUP BY Department, ano
ORDER BY Department, ano;

-- Query 4 (Idade Média no Momento da Contratação):
SELECT 
    ROUND(AVG(Age - YearsAtCompany), 2) AS idade_media_contratacao
FROM employee
WHERE Age IS NOT NULL AND YearsAtCompany IS NOT NULL;

-- Query 5 (Tabela Simplificada):
SELECT 
    Department,
    JobRole,
    Age,
    Gender,
    EducationField,
    Education AS 'Nível de Instrução de 1 a 4',
    ROUND(AVG(YearsAtCompany), 2) AS media_tempo_empresa,
    ROUND(AVG(Age - YearsAtCompany), 2) AS idade_media_contratacao,
    ROUND(AVG(Salary), 2) AS salario_medio
FROM employee
GROUP BY Department, JobRole, Age, Gender, EducationField,Education
ORDER BY media_tempo_empresa DESC;