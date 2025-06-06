/*
// pgAgent - PostgreSQL Tools
// 
// Copyright (C) 2002 - 2024, The pgAdmin Development Team
// This software is released under the PostgreSQL Licence
//
// pgagent.sql - pgAgent tables and functions
//
*/

BEGIN TRANSACTION;



CREATE SCHEMA pgagent;
COMMENT ON SCHEMA pgagent IS 'pgAgent system tables';



CREATE TABLE pgagent.pga_jobagent (
jagpid               int4                 NOT NULL PRIMARY KEY,
jaglogintime         timestamptz          NOT NULL DEFAULT current_timestamp,
jagstation           text                 NOT NULL
) WITHOUT OIDS;
COMMENT ON TABLE pgagent.pga_jobagent IS 'Active job agents';



CREATE TABLE pgagent.pga_jobclass (
jclid                serial               NOT NULL PRIMARY KEY,
jclname              text                 NOT NULL
) WITHOUT OIDS;
CREATE UNIQUE INDEX pga_jobclass_name ON pgagent.pga_jobclass(jclname);
COMMENT ON TABLE pgagent.pga_jobclass IS 'Job classification';

INSERT INTO pgagent.pga_jobclass (jclname) VALUES ('Routine Maintenance');
INSERT INTO pgagent.pga_jobclass (jclname) VALUES ('Data Import');
INSERT INTO pgagent.pga_jobclass (jclname) VALUES ('Data Export');
INSERT INTO pgagent.pga_jobclass (jclname) VALUES ('Data Summarisation');
INSERT INTO pgagent.pga_jobclass (jclname) VALUES ('Miscellaneous');
-- Be sure to update pg_extension_config_dump() below and in
-- upgrade scripts etc, when adding new classes.


CREATE TABLE pgagent.pga_job (
jobid                serial               NOT NULL PRIMARY KEY,
jobjclid             int4                 NOT NULL REFERENCES pgagent.pga_jobclass (jclid) ON DELETE RESTRICT ON UPDATE RESTRICT,
jobname              text                 NOT NULL,
jobdesc              text                 NOT NULL DEFAULT '',
jobhostagent         text                 NOT NULL DEFAULT '',
jobenabled           bool                 NOT NULL DEFAULT true,
jobcreated           timestamptz          NOT NULL DEFAULT current_timestamp,
jobchanged           timestamptz          NOT NULL DEFAULT current_timestamp,
jobagentid           int4                 NULL REFERENCES pgagent.pga_jobagent(jagpid) ON DELETE SET NULL ON UPDATE RESTRICT,
jobnextrun           timestamptz          NULL,
joblastrun           timestamptz          NULL
) WITHOUT OIDS;
COMMENT ON TABLE pgagent.pga_job IS 'Job main entry';
COMMENT ON COLUMN pgagent.pga_job.jobagentid IS 'Agent that currently executes this job.';

-- Add notification settings table
CREATE TABLE pgagent.pga_job_notification (
jnid                 serial               NOT NULL PRIMARY KEY,
jnjobid              int4                 NOT NULL REFERENCES pgagent.pga_job (jobid) ON DELETE CASCADE ON UPDATE RESTRICT,
jnenabled            bool                 NOT NULL DEFAULT true,
jnbrowser            bool                 NOT NULL DEFAULT true,
jnemail              bool                 NOT NULL DEFAULT false,
jnwhen               char                 NOT NULL CHECK (jnwhen IN ('a', 's', 'f', 'b')) DEFAULT 'f', -- a=all, s=success, f=failure, b=both (success and failure)
jnmininterval        int4                 NOT NULL DEFAULT 0, -- minimum interval between notifications in seconds (0 = no limit)
jnemailrecipients    text                 NOT NULL DEFAULT '', -- comma-separated list of email recipients
jncustomtext         text                 NOT NULL DEFAULT '', -- custom text to include in notifications
jnlastnotification   timestamptz          NULL    -- timestamp of last notification sent
) WITHOUT OIDS;
CREATE INDEX pga_job_notification_jobid ON pgagent.pga_job_notification(jnjobid);
COMMENT ON TABLE pgagent.pga_job_notification IS 'Job notification settings';
COMMENT ON COLUMN pgagent.pga_job_notification.jnwhen IS 'When to send notifications: a=all states, s=success only, f=failure only, b=both success and failure';

-- For each existing job, create a default notification entry
INSERT INTO pgagent.pga_job_notification (jnjobid, jnenabled, jnbrowser, jnemail, jnwhen)
SELECT jobid, true, true, false, 'f' FROM pgagent.pga_job;



CREATE TABLE pgagent.pga_jobstep (
jstid                serial               NOT NULL PRIMARY KEY,
jstjobid             int4                 NOT NULL REFERENCES pgagent.pga_job (jobid) ON DELETE CASCADE ON UPDATE RESTRICT,
jstname              text                 NOT NULL,
jstdesc              text                 NOT NULL DEFAULT '',
jstenabled           bool                 NOT NULL DEFAULT true,
jstkind              char                 NOT NULL CHECK (jstkind IN ('b', 's')), -- batch, sql
jstcode              text                 NOT NULL,
jstconnstr           text                 NOT NULL DEFAULT '' CHECK ((jstconnstr != '' AND jstkind = 's' ) OR (jstconnstr = '' AND (jstkind = 'b' OR jstdbname != ''))),
jstdbname            name                 NOT NULL DEFAULT '' CHECK ((jstdbname != '' AND jstkind = 's' ) OR (jstdbname = '' AND (jstkind = 'b' OR jstconnstr != ''))),
jstonerror           char                 NOT NULL CHECK (jstonerror IN ('f', 's', 'i')) DEFAULT 'f', -- fail, success, ignore
jscnextrun           timestamptz          NULL
) WITHOUT OIDS;
CREATE INDEX pga_jobstep_jobid ON pgagent.pga_jobstep(jstjobid);
COMMENT ON TABLE pgagent.pga_jobstep IS 'Job step to be executed';
COMMENT ON COLUMN pgagent.pga_jobstep.jstkind IS 'Kind of jobstep: s=sql, b=batch';
COMMENT ON COLUMN pgagent.pga_jobstep.jstonerror IS 'What to do if step returns an error: f=fail the job, s=mark step as succeeded and continue, i=mark as fail but ignore it and proceed';



CREATE TABLE pgagent.pga_schedule (
jscid                serial               NOT NULL PRIMARY KEY,
jscjobid             int4                 NOT NULL REFERENCES pgagent.pga_job (jobid) ON DELETE CASCADE ON UPDATE RESTRICT,
jscname              text                 NOT NULL,
jscdesc              text                 NOT NULL DEFAULT '',
jscenabled           bool                 NOT NULL DEFAULT true,
jscstart             timestamptz          NOT NULL DEFAULT current_timestamp,
jscend               timestamptz          NULL,
jscminutes           bool[60]             NOT NULL DEFAULT '{f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f}',
jschours             bool[24]             NOT NULL DEFAULT '{f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f}',
jscweekdays          bool[7]              NOT NULL DEFAULT '{f,f,f,f,f,f,f}',
jscmonthdays         bool[32]             NOT NULL DEFAULT '{f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f}',
jscmonths            bool[12]             NOT NULL DEFAULT '{f,f,f,f,f,f,f,f,f,f,f,f}',
CONSTRAINT pga_schedule_jscminutes_size CHECK (array_upper(jscminutes, 1) = 60),
CONSTRAINT pga_schedule_jschours_size CHECK (array_upper(jschours, 1) = 24),
CONSTRAINT pga_schedule_jscweekdays_size CHECK (array_upper(jscweekdays, 1) = 7),
CONSTRAINT pga_schedule_jscmonthdays_size CHECK (array_upper(jscmonthdays, 1) = 32),
CONSTRAINT pga_schedule_jscmonths_size CHECK (array_upper(jscmonths, 1) = 12)
) WITHOUT OIDS;
CREATE INDEX pga_jobschedule_jobid ON pgagent.pga_schedule(jscjobid);
COMMENT ON TABLE pgagent.pga_schedule IS 'Schedule for a job';



CREATE TABLE pgagent.pga_exception (
jexid                serial               NOT NULL PRIMARY KEY,
jexscid              int4                 NOT NULL REFERENCES pgagent.pga_schedule (jscid) ON DELETE CASCADE ON UPDATE RESTRICT,
jexdate              date                NULL,
jextime              time                NULL
)
WITHOUT OIDS;
CREATE INDEX pga_exception_jexscid ON pgagent.pga_exception (jexscid);
CREATE UNIQUE INDEX pga_exception_datetime ON pgagent.pga_exception (jexdate, jextime);
COMMENT ON TABLE pgagent.pga_schedule IS 'Job schedule exceptions';



CREATE TABLE pgagent.pga_joblog (
jlgid                serial               NOT NULL PRIMARY KEY,
jlgjobid             int4                 NOT NULL REFERENCES pgagent.pga_job (jobid) ON DELETE CASCADE ON UPDATE RESTRICT,
jlgstatus            char                 NOT NULL CHECK (jlgstatus IN ('r', 's', 'f', 'i', 'd', 'x')) DEFAULT 'r', -- running, success, failed, internal failure, aborted, dependency failure
jlgstart             timestamptz          NOT NULL DEFAULT current_timestamp,
jlgduration          interval             NULL
) WITHOUT OIDS;
CREATE INDEX pga_joblog_jobid ON pgagent.pga_joblog(jlgjobid);
COMMENT ON TABLE pgagent.pga_joblog IS 'Job run logs.';
COMMENT ON COLUMN pgagent.pga_joblog.jlgstatus IS 'Status of job: r=running, s=successfully finished, f=failed, i=no steps to execute, d=aborted, x=dependency failure';



CREATE TABLE pgagent.pga_jobsteplog (
jslid                serial               NOT NULL PRIMARY KEY,
jsljlgid             int4                 NOT NULL REFERENCES pgagent.pga_joblog (jlgid) ON DELETE CASCADE ON UPDATE RESTRICT,
jsljstid             int4                 NOT NULL REFERENCES pgagent.pga_jobstep (jstid) ON DELETE CASCADE ON UPDATE RESTRICT,
jslstatus            char                 NOT NULL CHECK (jslstatus IN ('r', 's', 'i', 'f', 'd')) DEFAULT 'r', -- running, success, ignored, failed, aborted
jslresult            int4                 NULL,
jslstart             timestamptz          NOT NULL DEFAULT current_timestamp,
jslduration          interval             NULL,
jsloutput            text
) WITHOUT OIDS;
CREATE INDEX pga_jobsteplog_jslid ON pgagent.pga_jobsteplog(jsljlgid);
COMMENT ON TABLE pgagent.pga_jobsteplog IS 'Job step run logs.';
COMMENT ON COLUMN pgagent.pga_jobsteplog.jslstatus IS 'Status of job step: r=running, s=successfully finished,  f=failed stopping job, i=ignored failure, d=aborted';
COMMENT ON COLUMN pgagent.pga_jobsteplog.jslresult IS 'Return code of job step';

CREATE OR REPLACE FUNCTION pgagent.pgagent_schema_version() RETURNS int2 AS '
BEGIN
    -- RETURNS PGAGENT MAJOR VERSION
    -- WE WILL CHANGE THE MAJOR VERSION, ONLY IF THERE IS A SCHEMA CHANGE
    RETURN 4;
END;
' LANGUAGE 'plpgsql' VOLATILE;


CREATE OR REPLACE FUNCTION pgagent.pga_next_schedule(int4, timestamptz, timestamptz, _bool, _bool, _bool, _bool, _bool) RETURNS timestamptz AS '
DECLARE
    jscid           ALIAS FOR $1;
    jscstart        ALIAS FOR $2;
    jscend          ALIAS FOR $3;
    jscminutes      ALIAS FOR $4;
    jschours        ALIAS FOR $5;
    jscweekdays     ALIAS FOR $6;
    jscmonthdays    ALIAS FOR $7;
    jscmonths       ALIAS FOR $8;

    nextrun         timestamp := ''1970-01-01 00:00:00-00'';
    runafter        timestamp := ''1970-01-01 00:00:00-00'';

    bingo            bool := FALSE;
    gotit            bool := FALSE;
    foundval        bool := FALSE;
    daytweak        bool := FALSE;
    minutetweak        bool := FALSE;

    i                int2 := 0;
    d                int2 := 0;

    nextminute        int2 := 0;
    nexthour        int2 := 0;
    nextday            int2 := 0;
    nextmonth       int2 := 0;
    nextyear        int2 := 0;


BEGIN
    -- No valid start date has been specified
    IF jscstart IS NULL THEN RETURN NULL; END IF;

    -- The schedule is past its end date
    IF jscend IS NOT NULL AND jscend < now() THEN RETURN NULL; END IF;

    -- Get the time to find the next run after. It will just be the later of
    -- now() + 1m and the start date for the time being, however, we might want to
    -- do more complex things using this value in the future.
    IF date_trunc(''MINUTE'', jscstart) > date_trunc(''MINUTE'', (now() + ''1 Minute''::interval)) THEN
        runafter := date_trunc(''MINUTE'', jscstart);
    ELSE
        runafter := date_trunc(''MINUTE'', (now() + ''1 Minute''::interval));
    END IF;

    --
    -- Enter a loop, generating next run timestamps until we find one
    -- that falls on the required weekday, and is not matched by an exception
    --

    WHILE bingo = FALSE LOOP

        --
        -- Get the next run year
        --
        nextyear := date_part(''YEAR'', runafter);

        --
        -- Get the next run month
        --
        nextmonth := date_part(''MONTH'', runafter);
        gotit := FALSE;
        FOR i IN (nextmonth) .. 12 LOOP
            IF jscmonths[i] = TRUE THEN
                nextmonth := i;
                gotit := TRUE;
                foundval := TRUE;
                EXIT;
            END IF;
        END LOOP;
        IF gotit = FALSE THEN
            FOR i IN 1 .. (nextmonth - 1) LOOP
                IF jscmonths[i] = TRUE THEN
                    nextmonth := i;

                    -- Wrap into next year
                    nextyear := nextyear + 1;
                    gotit := TRUE;
                    foundval := TRUE;
                    EXIT;
                END IF;
           END LOOP;
        END IF;

        --
        -- Get the next run day
        --
        -- If the year, or month have incremented, get the lowest day,
        -- otherwise look for the next day matching or after today.
        IF (nextyear > date_part(''YEAR'', runafter) OR nextmonth > date_part(''MONTH'', runafter)) THEN
            nextday := 1;
            FOR i IN 1 .. 32 LOOP
                IF jscmonthdays[i] = TRUE THEN
                    nextday := i;
                    foundval := TRUE;
                    EXIT;
                END IF;
            END LOOP;
        ELSE
            nextday := date_part(''DAY'', runafter);
            gotit := FALSE;
            FOR i IN nextday .. 32 LOOP
                IF jscmonthdays[i] = TRUE THEN
                    nextday := i;
                    gotit := TRUE;
                    foundval := TRUE;
                    EXIT;
                END IF;
            END LOOP;
            IF gotit = FALSE THEN
                FOR i IN 1 .. (nextday - 1) LOOP
                    IF jscmonthdays[i] = TRUE THEN
                        nextday := i;

                        -- Wrap into next month
                        IF nextmonth = 12 THEN
                            nextyear := nextyear + 1;
                            nextmonth := 1;
                        ELSE
                            nextmonth := nextmonth + 1;
                        END IF;
                        gotit := TRUE;
                        foundval := TRUE;
                        EXIT;
                    END IF;
                END LOOP;
            END IF;
        END IF;

        -- Was the last day flag selected?
        IF nextday = 32 THEN
            IF nextmonth = 1 THEN
                nextday := 31;
            ELSIF nextmonth = 2 THEN
                IF pgagent.pga_is_leap_year(nextyear) = TRUE THEN
                    nextday := 29;
                ELSE
                    nextday := 28;
                END IF;
            ELSIF nextmonth = 3 THEN
                nextday := 31;
            ELSIF nextmonth = 4 THEN
                nextday := 30;
            ELSIF nextmonth = 5 THEN
                nextday := 31;
            ELSIF nextmonth = 6 THEN
                nextday := 30;
            ELSIF nextmonth = 7 THEN
                nextday := 31;
            ELSIF nextmonth = 8 THEN
                nextday := 31;
            ELSIF nextmonth = 9 THEN
                nextday := 30;
            ELSIF nextmonth = 10 THEN
                nextday := 31;
            ELSIF nextmonth = 11 THEN
                nextday := 30;
            ELSIF nextmonth = 12 THEN
                nextday := 31;
            END IF;
        END IF;

        --
        -- Get the next run hour
        --
        -- If the year, month or day have incremented, get the lowest hour,
        -- otherwise look for the next hour matching or after the current one.
        IF (nextyear > date_part(''YEAR'', runafter) OR nextmonth > date_part(''MONTH'', runafter) OR nextday > date_part(''DAY'', runafter) OR daytweak = TRUE) THEN
            nexthour := 0;
            FOR i IN 1 .. 24 LOOP
                IF jschours[i] = TRUE THEN
                    nexthour := i - 1;
                    foundval := TRUE;
                    EXIT;
                END IF;
            END LOOP;
        ELSE
            nexthour := date_part(''HOUR'', runafter);
            gotit := FALSE;
            FOR i IN (nexthour + 1) .. 24 LOOP
                IF jschours[i] = TRUE THEN
                    nexthour := i - 1;
                    gotit := TRUE;
                    foundval := TRUE;
                    EXIT;
                END IF;
            END LOOP;
            IF gotit = FALSE THEN
                FOR i IN 1 .. nexthour LOOP
                    IF jschours[i] = TRUE THEN
                        nexthour := i - 1;

                        -- Wrap into next month
                        IF (nextmonth = 1 OR nextmonth = 3 OR nextmonth = 5 OR nextmonth = 7 OR nextmonth = 8 OR nextmonth = 10 OR nextmonth = 12) THEN
                            d = 31;
                        ELSIF (nextmonth = 4 OR nextmonth = 6 OR nextmonth = 9 OR nextmonth = 11) THEN
                            d = 30;
                        ELSE
                            IF pgagent.pga_is_leap_year(nextyear) = TRUE THEN
                                d := 29;
                            ELSE
                                d := 28;
                            END IF;
                        END IF;

                        IF nextday = d THEN
                            nextday := 1;
                            IF nextmonth = 12 THEN
                                nextyear := nextyear + 1;
                                nextmonth := 1;
                            ELSE
                                nextmonth := nextmonth + 1;
                            END IF;
                        ELSE
                            nextday := nextday + 1;
                        END IF;

                        gotit := TRUE;
                        foundval := TRUE;
                        EXIT;
                    END IF;
                END LOOP;
            END IF;
        END IF;

        --
        -- Get the next run minute
        --
        -- If the year, month day or hour have incremented, get the lowest minute,
        -- otherwise look for the next minute matching or after the current one.
        IF (nextyear > date_part(''YEAR'', runafter) OR nextmonth > date_part(''MONTH'', runafter) OR nextday > date_part(''DAY'', runafter) OR nexthour > date_part(''HOUR'', runafter) OR daytweak = TRUE) THEN
            nextminute := 0;
            IF minutetweak = TRUE THEN
        d := 1;
            ELSE
        d := date_part(''MINUTE'', runafter)::int2;
            END IF;
            FOR i IN d .. 60 LOOP
                IF jscminutes[i] = TRUE THEN
                    nextminute := i - 1;
                    foundval := TRUE;
                    EXIT;
                END IF;
            END LOOP;
        ELSE
            nextminute := date_part(''MINUTE'', runafter);
            gotit := FALSE;
            FOR i IN (nextminute + 1) .. 60 LOOP
                IF jscminutes[i] = TRUE THEN
                    nextminute := i - 1;
                    gotit := TRUE;
                    foundval := TRUE;
                    EXIT;
                END IF;
            END LOOP;
            IF gotit = FALSE THEN
                FOR i IN 1 .. nextminute LOOP
                    IF jscminutes[i] = TRUE THEN
                        nextminute := i - 1;

                        -- Wrap into next hour
                        IF (nextmonth = 1 OR nextmonth = 3 OR nextmonth = 5 OR nextmonth = 7 OR nextmonth = 8 OR nextmonth = 10 OR nextmonth = 12) THEN
                            d = 31;
                        ELSIF (nextmonth = 4 OR nextmonth = 6 OR nextmonth = 9 OR nextmonth = 11) THEN
                            d = 30;
                        ELSE
                            IF pgagent.pga_is_leap_year(nextyear) = TRUE THEN
                                d := 29;
                            ELSE
                                d := 28;
                            END IF;
                        END IF;

                        IF nexthour = 23 THEN
                            nexthour = 0;
                            IF nextday = d THEN
                                nextday := 1;
                                IF nextmonth = 12 THEN
                                    nextyear := nextyear + 1;
                                    nextmonth := 1;
                                ELSE
                                    nextmonth := nextmonth + 1;
                                END IF;
                            ELSE
                                nextday := nextday + 1;
                            END IF;
                        ELSE
                            nexthour := nexthour + 1;
                        END IF;

                        gotit := TRUE;
                        foundval := TRUE;
                        EXIT;
                    END IF;
                END LOOP;
            END IF;
        END IF;

        -- Build the result, and check it is not the same as runafter - this may
        -- happen if all array entries are set to false. In this case, add a minute.

        nextrun := (nextyear::varchar || ''-''::varchar || nextmonth::varchar || ''-'' || nextday::varchar || '' '' || nexthour::varchar || '':'' || nextminute::varchar)::timestamptz;

        IF nextrun = runafter AND foundval = FALSE THEN
                nextrun := nextrun + INTERVAL ''1 Minute'';
        END IF;

        -- If the result is past the end date, exit.
        IF nextrun > jscend THEN
            RETURN NULL;
        END IF;

        -- Check to ensure that the nextrun time is actually still valid. Its
        -- possible that wrapped values may have carried the nextrun onto an
        -- invalid time or date.
        IF ((jscminutes = ''{f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f}'' OR jscminutes[date_part(''MINUTE'', nextrun) + 1] = TRUE) AND
            (jschours = ''{f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f}'' OR jschours[date_part(''HOUR'', nextrun) + 1] = TRUE) AND
            (jscmonthdays = ''{f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f}'' OR jscmonthdays[date_part(''DAY'', nextrun)] = TRUE OR
            (jscmonthdays = ''{f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,t}'' AND
             ((date_part(''MONTH'', nextrun) IN (1,3,5,7,8,10,12) AND date_part(''DAY'', nextrun) = 31) OR
              (date_part(''MONTH'', nextrun) IN (4,6,9,11) AND date_part(''DAY'', nextrun) = 30) OR
              (date_part(''MONTH'', nextrun) = 2 AND ((pgagent.pga_is_leap_year(date_part(''YEAR'', nextrun)::int2) AND date_part(''DAY'', nextrun) = 29) OR date_part(''DAY'', nextrun) = 28))))) AND
            (jscmonths = ''{f,f,f,f,f,f,f,f,f,f,f,f}'' OR jscmonths[date_part(''MONTH'', nextrun)] = TRUE)) THEN


            -- Now, check to see if the nextrun time found is a) on an acceptable
            -- weekday, and b) not matched by an exception. If not, set
            -- runafter = nextrun and try again.

            -- Check for a wildcard weekday
            gotit := FALSE;
            FOR i IN 1 .. 7 LOOP
                IF jscweekdays[i] = TRUE THEN
                    gotit := TRUE;
                    EXIT;
                END IF;
            END LOOP;

            -- OK, is the correct weekday selected, or a wildcard?
            IF (jscweekdays[date_part(''DOW'', nextrun) + 1] = TRUE OR gotit = FALSE) THEN

                -- Check for exceptions
                SELECT INTO d jexid FROM pgagent.pga_exception WHERE jexscid = jscid AND ((jexdate = nextrun::date AND jextime = nextrun::time) OR (jexdate = nextrun::date AND jextime IS NULL) OR (jexdate IS NULL AND jextime = nextrun::time));
                IF FOUND THEN
                    -- Nuts - found an exception. Increment the time and try again
                    runafter := nextrun + INTERVAL ''1 Minute'';
                    bingo := FALSE;
                    minutetweak := TRUE;
            daytweak := FALSE;
                ELSE
                    bingo := TRUE;
                END IF;
            ELSE
                -- We''re on the wrong week day - increment a day and try again.
                runafter := nextrun + INTERVAL ''1 Day'';
                bingo := FALSE;
                minutetweak := FALSE;
                daytweak := TRUE;
            END IF;

        ELSE
            runafter := nextrun + INTERVAL ''1 Minute'';
            bingo := FALSE;
            minutetweak := TRUE;
        daytweak := FALSE;
        END IF;

    END LOOP;

    RETURN nextrun;
END;
' LANGUAGE 'plpgsql' VOLATILE;
COMMENT ON FUNCTION pgagent.pga_next_schedule(int4, timestamptz, timestamptz, _bool, _bool, _bool, _bool, _bool) IS 'Calculates the next runtime for a given schedule';



--
-- Test code
--
-- SELECT pgagent.pga_next_schedule(
--     2, -- Schedule ID
--     '2005-01-01 00:00:00', -- Start date
--     '2006-10-01 00:00:00', -- End date
--     '{f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f}', -- Minutes
--     '{f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f}', -- Hours
--     '{f,f,f,f,f,f,f}', -- Weekdays
--     '{f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f}', -- Monthdays
--     '{f,f,f,f,f,f,f,f,f,f,f,f}' -- Months
-- );



CREATE OR REPLACE FUNCTION pgagent.pga_is_leap_year(int2) RETURNS bool AS '
BEGIN
    IF $1 % 4 != 0 THEN
        RETURN FALSE;
    END IF;

    IF $1 % 100 != 0 THEN
        RETURN TRUE;
    END IF;

    RETURN $1 % 400 = 0;
END;
' LANGUAGE 'plpgsql' IMMUTABLE;
COMMENT ON FUNCTION pgagent.pga_is_leap_year(int2) IS 'Returns TRUE if $1 is a leap year';


CREATE OR REPLACE FUNCTION pgagent.pga_job_trigger()
  RETURNS "trigger" AS
'
BEGIN
    IF NEW.jobenabled THEN
        IF NEW.jobnextrun IS NULL THEN
             SELECT INTO NEW.jobnextrun
                    MIN(pgagent.pga_next_schedule(jscid, jscstart, jscend, jscminutes, jschours, jscweekdays, jscmonthdays, jscmonths))
               FROM pgagent.pga_schedule
              WHERE jscenabled AND jscjobid=OLD.jobid;
        END IF;
    ELSE
        NEW.jobnextrun := NULL;
    END IF;
    RETURN NEW;
END;
'
  LANGUAGE 'plpgsql' VOLATILE;
COMMENT ON FUNCTION pgagent.pga_job_trigger() IS 'Update the job''s next run time.';

CREATE TRIGGER pga_job_trigger BEFORE UPDATE
  ON pgagent.pga_job FOR EACH ROW
  EXECUTE PROCEDURE pgagent.pga_job_trigger();
COMMENT ON TRIGGER pga_job_trigger ON pgagent.pga_job IS 'Update the job''s next run time.';


CREATE OR REPLACE FUNCTION pgagent.pga_schedule_trigger() RETURNS trigger AS '
BEGIN
    IF TG_OP = ''DELETE'' THEN
        -- update pga_job from remaining schedules
        -- the actual calculation of jobnextrun will be performed in the trigger
        UPDATE pgagent.pga_job
           SET jobnextrun = NULL
         WHERE jobenabled AND jobid=OLD.jscjobid;
        RETURN OLD;
    ELSE
        UPDATE pgagent.pga_job
           SET jobnextrun = NULL
         WHERE jobenabled AND jobid=NEW.jscjobid;
        RETURN NEW;
    END IF;
END;
' LANGUAGE 'plpgsql';
COMMENT ON FUNCTION pgagent.pga_schedule_trigger() IS 'Update the job''s next run time whenever a schedule changes';



CREATE TRIGGER pga_schedule_trigger AFTER INSERT OR UPDATE OR DELETE
   ON pgagent.pga_schedule FOR EACH ROW
   EXECUTE PROCEDURE pgagent.pga_schedule_trigger();
COMMENT ON TRIGGER pga_schedule_trigger ON pgagent.pga_schedule IS 'Update the job''s next run time whenever a schedule changes';


CREATE OR REPLACE FUNCTION pgagent.pga_exception_trigger() RETURNS "trigger" AS '
DECLARE

    v_jobid int4 := 0;

BEGIN

     IF TG_OP = ''DELETE'' THEN

        SELECT INTO v_jobid jscjobid FROM pgagent.pga_schedule WHERE jscid = OLD.jexscid;

        -- update pga_job from remaining schedules
        -- the actual calculation of jobnextrun will be performed in the trigger
        UPDATE pgagent.pga_job
           SET jobnextrun = NULL
         WHERE jobenabled AND jobid = v_jobid;
        RETURN OLD;
    ELSE

        SELECT INTO v_jobid jscjobid FROM pgagent.pga_schedule WHERE jscid = NEW.jexscid;

        UPDATE pgagent.pga_job
           SET jobnextrun = NULL
         WHERE jobenabled AND jobid = v_jobid;
        RETURN NEW;
    END IF;
END;
' LANGUAGE 'plpgsql' VOLATILE;
COMMENT ON FUNCTION pgagent.pga_exception_trigger() IS 'Update the job''s next run time whenever an exception changes';



CREATE TRIGGER pga_exception_trigger AFTER INSERT OR UPDATE OR DELETE
  ON pgagent.pga_exception FOR EACH ROW
  EXECUTE PROCEDURE pgagent.pga_exception_trigger();
COMMENT ON TRIGGER pga_exception_trigger ON pgagent.pga_exception IS 'Update the job''s next run time whenever an exception changes';

-- Extension dump support.
-- EXT SELECT pg_catalog.pg_extension_config_dump('pga_jobagent', '');
-- EXT SELECT pg_catalog.pg_extension_config_dump('pga_jobclass', $$WHERE jclname NOT IN ('Routine Maintenance', 'Data Import', 'Data Export', 'Data Summarisation', 'Miscellaneous')$$);
-- EXT SELECT pg_catalog.pg_extension_config_dump('pga_job', '');
-- EXT SELECT pg_catalog.pg_extension_config_dump('pga_jobstep', '');
-- EXT SELECT pg_catalog.pg_extension_config_dump('pga_schedule', '');
-- EXT SELECT pg_catalog.pg_extension_config_dump('pga_exception', '');
-- EXT SELECT pg_catalog.pg_extension_config_dump('pga_joblog', '');
-- EXT SELECT pg_catalog.pg_extension_config_dump('pga_jobsteplog', '');

COMMIT TRANSACTION;
