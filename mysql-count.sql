DELIMITER $$

DROP PROCEDURE IF EXISTS count_all_tables $$
CREATE PROCEDURE count_all_tables(IN p_schema VARCHAR(64))
BEGIN
    DECLARE done INT DEFAULT 0;
    DECLARE v_table VARCHAR(64);
    DECLARE cur CURSOR FOR
        SELECT table_name
        FROM information_schema.tables
        WHERE table_schema = p_schema
          AND table_type = 'BASE TABLE'
        ORDER BY table_name;
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;

    DROP TEMPORARY TABLE IF EXISTS table_counts;
    CREATE TEMPORARY TABLE table_counts (
        table_name VARCHAR(64),
        row_count BIGINT
    );

    OPEN cur;

    read_loop: LOOP
        FETCH cur INTO v_table;
        IF done = 1 THEN
            LEAVE read_loop;
        END IF;

        SET @sql = CONCAT(
            'INSERT INTO table_counts (table_name, row_count) ',
            'SELECT ''', v_table, ''', COUNT(*) FROM `', p_schema, '`.`', v_table, '`'
        );

        PREPARE stmt FROM @sql;
        EXECUTE stmt;
        DEALLOCATE PREPARE stmt;
    END LOOP;

    CLOSE cur;

    SELECT *
    FROM table_counts
    ORDER BY table_name;
END $$

DELIMITER ;

CALL count_all_tables('mysql-database-name');
