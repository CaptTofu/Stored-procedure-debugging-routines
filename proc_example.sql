delimiter |

DROP PROCEDURE IF EXISTS someother_proc | 
CREATE PROCEDURE someother_proc 
(
    _rand float,
	_username varchar(32),
    out _return_val int
)
 MODIFIES SQL DATA
 BEGIN
    /* 
     * this is passed by the calling procedure and is available after the
     * program is called
     */
    set _return_val = 0;

    /* 
     * this will cause grief for the test procedure that calls it because it
     * will result in an attempt of a nested procedure, which is not supported
     * in MySQL. This call will be an implicit commit, so all subsequent DML
     * statements in the calling procedure will be committed
     */
    START TRANSACTION;

    /* 
     * Arbitrary. Just to have some way to randomly set a true value that the
     * calling procedure will use to test whether or not to leave the loop
     * that this procedure was called from
     */
    IF (_rand > 0.5)
    THEN
        SET _return_val = 1;
    END IF;

    /* this is here to provide a means to see what random value was tested */
    INSERT INTO randlog (username, rvalue, returned) 
        VALUES (_username, _rand, _return_val);
    
    COMMIT;
END|

DROP PROCEDURE IF EXISTS proc_example | 

CREATE PROCEDURE proc_example 
(
	_username varchar(32)
)
 BEGIN

	DECLARE status_code int;
    DECLARE counter int default 0;
	DECLARE BAIL int default 0;
    DECLARE sleep_foo int;
	
    /* 
     * exit handler for anything that goes wrong during execution. This will
     * ensure the any subsequent DML statements are rolled back
     */
	DECLARE EXIT HANDLER FOR SQLEXCEPTION
	BEGIN
		SET status_code = -1;
		ROLLBACK;
	    SELECT status_code as status_code;
        call cleanup("line 65: exception handler");
	END;
	
	SET status_code = 0;

    CALL setupProcLog();
    CALL procLog("line 71: Entering proc_example");

    /* start the transaction - so that anything that follows will be atomic */
	START TRANSACTION; 
	
    call procLog(concat("line 76: START TRANSACTION, status_code=",
                        ifnull(status_code, NULL)));
	IF status_code = 0
	THEN
        /* 
         * the loop. The only thing that will cause this loop to end other
         * than the counter exceeding the value of 5 is if BAIL is set to 1
         */
        myloop: LOOP
            CALL procLog(concat("line 85: loop iteration #",
                                ifnull(counter, NULL)));

            /* leave the loop is counter exceeds the value of 5 */
            IF counter > 5 THEN
                LEAVE myloop;
            END IF;

            /* 
             * this statement is just to show an example of an insert
             * statement that should NOT be committed until the end of 
             * the procedure, or if the status_code is anything other than
             * zero then a rollback will result in this statement being rolled
             * back
             */
            INSERT INTO userloop_count (username, count) 
                VALUES (_username, counter);

            CALL procLog("line 103: CALL someother_proc()");
            /* 
             * This call to someother_proc() will set a value for BAIL. This
             * is the type of thing you want to be cognizant of in your stored 
             * procedures - that a procedure that you call doesn't have it's
             * own transaction. Nested transactions are not supported by MySQL
             */
            CALL someother_proc(rand(), _username, BAIL);
            CALL procLog(concat("line 111: BAIL = ", ifnull(BAIL, 'NULL')));
            IF BAIL THEN
                SET status_code = 1;
                LEAVE myloop;
            END IF;

            SET counter = counter + 1;

        END LOOP;		
    END IF;

    select sleep(3) into sleep_foo;

    /* 
     * this is the do or die part of the procedure that will either commit or
     * roll back any subsequent DML statements (insert, update, delete, etc)
     * if the username exists, a status_code of 2 is set, which results in a
     * rollback, and if not, an insert into users is called. If the insert
     * fails for any reason, the EXIT handler will also roll back subsequent
     * statements 
     *  
     */
    IF (status_code = 0)
    THEN
        IF (SELECT user_id FROM users WHERE username = _username) IS NOT NULL 
        THEN 
            call procLog("line 137: user exists, setting status_code to 5");
            SET status_code = 2;
        ELSE
            call procLog("line 140: user does not exist, inserting");
	        INSERT INTO users (username) VALUES (_username);
        END IF;
    END IF;

    call procLog(concat( "line 145 code = ", ifnull(status_code,'NULL')));
    /* if status_code of 0, then commit, else roll back */
    IF (status_code = 0) THEN
	    COMMIT;
	ELSE
	    ROLLBACK;
	END IF;
			
    /* 
     * call cleanup() to ensure the temp proc logging table's entries are
     * copied to the proclog table
     */
    call cleanup("line 156: end of proc");
	SELECT status_code as status_code;

 END|

delimiter ;
