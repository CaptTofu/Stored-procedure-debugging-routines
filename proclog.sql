delimiter |

DROP PROCEDURE IF EXISTS setupProcLog |
CREATE PROCEDURE setupProcLog()
BEGIN
    DECLARE proclog_exists int default 0;

    /* 
       check if proclog is existing. This check seems redundant, but
       simply relying on 'create table if not exists' is not enough because
       a warning is thrown which will be caught by your exception handler
    */
    SELECT count(*) INTO proclog_exists
        FROM information_schema.tables 
        WHERE table_schema = database() AND table_name = 'proclog';

    IF proclog_exists = 0 THEN 
         create table if not exists proclog(entrytime datetime, 
                                        connection_id int not null default 0,
                                        msg varchar(512));
    END IF;
    /* 
     * temp table is not checked in information_schema because it is a temp
     * table
     */
     create temporary table if not exists tmp_proclog(
                                                entrytime timestamp, 
                                                connection_id int not null default 0,
                                                msg varchar(512)) engine = memory;
END |

DROP PROCEDURE IF EXISTS procLog |

CREATE PROCEDURE procLog(in logMsg varchar(512))
BEGIN
  Declare continue handler for 1146 -- Table not found
  BEGIN
    call setupProcLog();
    insert into tmp_proclog (connection_id, msg) values (connection_id(), 'reset tmp table');
    insert into tmp_proclog (connection_id, msg) values (connection_id(), logMsg);
  END;

  insert into tmp_proclog (connection_id, msg) values (connection_id(), logMsg);
END |

DROP PROCEDURE IF EXISTS cleanup |
CREATE PROCEDURE cleanup(in logMsg varchar(512))
BEGIN
   call procLog(concat("cleanup() ",ifnull(logMsg, ''))); 
   insert into proclog select * from tmp_proclog;
   drop table tmp_proclog;
END |
