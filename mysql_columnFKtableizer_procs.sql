/*
 -----
 WARNING: this code could be dangerous because it directly messes with schemas. Unless you
 really know what you are doing, this should only be used on test databases. I just wrote
 this for a convenience tool
 -----
 

 These stored procedures make it easy to "tableize" columns, meaning here to take
 all unique values of an existing column, put them into a new table, and then create
 a new FK on the original column pointing at the new column. This is useful for tools
 which understand these kinds of relationships, like RapidApp.
 
 Run this SQL to create the procedures, then use it like this:
 
   CALL mysql_columnFKtableizer_tableize('existing_table','existing_column');

 Example use-case based on information_schema.columns 
 (information_schema.columns is a view so we copy to a real table):
 
 
    CREATE TABLE info_schem_columns LIKE information_schema.columns;
    INSERT info_schem_columns SELECT * FROM information_schema.columns;


    CALL mysql_columnFKtableizer_tableize('info_schem_columns','table_schema');


 The above single 'CALL' statement would be the same as running this SQL:
 
    DROP TABLE IF EXISTS info_schem_columns_fk_table_schema;
    CREATE TABLE info_schem_columns_fk_table_schema SELECT DISTINCT(table_schema) FROM info_schem_columns;
    ALTER TABLE info_schem_columns_fk_table_schema ADD PRIMARY KEY(table_schema);

    ALTER TABLE info_schem_columns 
      ADD CONSTRAINT `info_schem_columns_fk_table_schema_ibfk_1`
      FOREIGN KEY (`table_schema`)
      REFERENCES info_schem_columns_fk_table_schema (`table_schema`)
      ON UPDATE CASCADE ON DELETE RESTRICT; 


  ** Note that the procedure is smart enough to be ran over and over, subsequent calls will
     drop the constraint first, which is what the mysql_columnFKtableizer_DropFK proc is for
*/



/* --- mysql_columnFKtableizer_DropFK  -- adapted from:
 https://stackoverflow.com/questions/17161496/drop-foreign-key-only-if-it-exists/34545062#34545062   */
DROP PROCEDURE IF EXISTS mysql_columnFKtableizer_DropFK;
DELIMITER $$
CREATE PROCEDURE mysql_columnFKtableizer_DropFK(IN tableName VARCHAR(64), IN constraintName VARCHAR(64))
BEGIN
    IF EXISTS(
        SELECT * FROM information_schema.table_constraints
        WHERE 
            table_schema    = DATABASE()     AND
            table_name      = tableName      AND
            constraint_name = constraintName AND
            constraint_type = 'FOREIGN KEY')
    THEN
        SET @query = CONCAT('ALTER TABLE ', tableName, ' DROP FOREIGN KEY ', constraintName, ';');
        PREPARE stmt FROM @query; 
        EXECUTE stmt; 
        DEALLOCATE PREPARE stmt; 
    END IF; 
END$$
DELIMITER ;
/* --- */


/* --- mysql_columnFKtableizer_tableize  --- */
DROP PROCEDURE IF EXISTS mysql_columnFKtableizer_tableize;
DELIMITER $$
  CREATE PROCEDURE mysql_columnFKtableizer_tableize(IN tableName VARCHAR(64), IN columnName VARCHAR(64))
  BEGIN
    SET @FKtableName    := CONCAT(tableName,'_fk_',columnName);
    SET @constraintName := CONCAT(@FKtableName,'_ibfk_1');
    
    CALL mysql_columnFKtableizer_DropFK(tableName,@constraintName);
    
    SET @query := CONCAT('DROP TABLE IF EXISTS ',@FKtableName);
    PREPARE stmt FROM @query; 
    EXECUTE stmt; 
    DEALLOCATE PREPARE stmt;
    
    SET @query := CONCAT('CREATE TABLE ',@FKtableName,' SELECT DISTINCT(',columnName,') FROM ',tableName);
    PREPARE stmt FROM @query; 
    EXECUTE stmt; 
    DEALLOCATE PREPARE stmt; 

    SET @query := CONCAT('ALTER TABLE ',@FKtableName,' ADD PRIMARY KEY (',columnName,')');
    PREPARE stmt FROM @query; 
    EXECUTE stmt; 
    DEALLOCATE PREPARE stmt; 
    
    SET @query := CONCAT(
      'ALTER TABLE `',tableName,'` ',
        'ADD CONSTRAINT `', @constraintName,'` ',
        'FOREIGN KEY (`', columnName, '`) ',
        'REFERENCES `',@FKtableName,'` (`',columnName,'`) ',
        'ON UPDATE CASCADE ON DELETE RESTRICT'
    );
    PREPARE stmt FROM @query; 
    EXECUTE stmt; 
    DEALLOCATE PREPARE stmt;   
    
  END $$
DELIMITER ;
/* --- */
