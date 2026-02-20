
-- 2. Creamos la primera tabla: Departamentos
CREATE TABLE prueba.departamentos (
    id_depto SERIAL PRIMARY KEY,
    nombre VARCHAR(50) NOT NULL,
    ubicacion VARCHAR(50)
);

-- 3. Creamos la segunda tabla: Empleados (relacionada con departamentos)
CREATE TABLE prueba.empleados (
    id_empleado SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    puesto VARCHAR(50),
    salario NUMERIC(10, 2),
    fecha_contratacion DATE DEFAULT CURRENT_DATE,
    id_depto INT,
    -- Aquí creamos la relación (Llave foránea) con la tabla departamentos
    CONSTRAINT fk_departamento
        FOREIGN KEY (id_depto) 
        REFERENCES prueba.departamentos(id_depto)
        ON DELETE SET NULL
);

-- 4. Insertamos datos de prueba en Departamentos
INSERT INTO prueba.departamentos (nombre, ubicacion) VALUES 
('Recursos Humanos', 'Planta 1'),
('Tecnología', 'Planta 2'),
('Ventas', 'Planta Baja');

-- 5. Insertamos datos de prueba en Empleados
INSERT INTO prueba.empleados (nombre, puesto, salario, fecha_contratacion, id_depto) VALUES 
('Ana García', 'Directora HR', 4500.00, '2022-03-15', 1),
('Carlos López', 'Desarrollador Backend', 3200.50, '2023-08-01', 2),
('María Fernández', 'Analista de Datos', 3100.00, '2023-09-10', 2),
('Juan Pérez', 'Ejecutivo de Ventas', 2500.00, '2024-01-20', 3),
('Laura Gómez', 'Soporte Técnico', 2100.00, '2024-02-05', 2);

-- 6. Creamos un objeto extra: Una Vista (View)
-- Esto te servirá para ver los datos de ambas tablas unidos de forma sencilla
CREATE VIEW prueba.vista_empleados_info AS
SELECT 
    e.nombre AS empleado,
    e.puesto,
    e.salario,
    d.nombre AS departamento,
    d.ubicacion
FROM 
    prueba.empleados e
LEFT JOIN 
    prueba.departamentos d ON e.id_depto = d.id_depto;
