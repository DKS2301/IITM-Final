-- Add audit logging table for pgAgent jobs
CREATE TABLE pgagent.pga_job_audit_log (
    audit_id          serial               NOT NULL PRIMARY KEY,
    job_id            int4                 NOT NULL ,
    operation_type    text                 NOT NULL CHECK (operation_type IN ('CREATE', 'MODIFY', 'DELETE', 'EXECUTE')),
    operation_time    timestamptz          NOT NULL DEFAULT current_timestamp,
    operation_user    text                 NOT NULL,
    old_values        jsonb                NULL,
    new_values        jsonb                NULL,
    additional_info   text                 NULL
) WITHOUT OIDS;

CREATE INDEX pga_job_audit_log_jobid ON pgagent.pga_job_audit_log(job_id);
CREATE INDEX pga_job_audit_log_operation_time ON pgagent.pga_job_audit_log(operation_time);

COMMENT ON TABLE pgagent.pga_job_audit_log IS 'Audit log for pgAgent job operations';
COMMENT ON COLUMN pgagent.pga_job_audit_log.operation_type IS 'Type of operation performed (CREATE, MODIFY, DELETE, EXECUTE)';
COMMENT ON COLUMN pgagent.pga_job_audit_log.old_values IS 'Previous values of modified fields (for MODIFY operations)';
COMMENT ON COLUMN pgagent.pga_job_audit_log.new_values IS 'New values of modified fields (for MODIFY operations)';
COMMENT ON COLUMN pgagent.pga_job_audit_log.additional_info IS 'Additional information about the operation';

-- Function to log job operations
CREATE OR REPLACE FUNCTION pgagent.pga_log_job_operation(
    p_job_id integer,
    p_operation_type text,
    p_operation_user text,
    p_old_values jsonb,
    p_new_values jsonb,
    p_additional_info text
) RETURNS void AS $$
BEGIN
    INSERT INTO pgagent.pga_job_audit_log (
        job_id,
        operation_type,
        operation_user,
        old_values,
        new_values,
        additional_info
    ) VALUES (
        p_job_id,
        p_operation_type,
        p_operation_user,
        p_old_values,
        p_new_values,
        p_additional_info
    );
END;
$$ LANGUAGE plpgsql;

-- Trigger function for job modifications
CREATE OR REPLACE FUNCTION pgagent.pga_job_audit_trigger()
RETURNS trigger AS $$
DECLARE
    significant_change boolean;
BEGIN
    significant_change := false;
    
    IF TG_OP = 'INSERT' THEN
        -- Always log job creation
        PERFORM pgagent.pga_log_job_operation(
            NEW.jobid,
            'CREATE',
            current_user,
            NULL,
            row_to_json(NEW)::jsonb,
            NULL
        );
        RETURN NULL;
    ELSIF TG_OP = 'UPDATE' THEN
        -- Only log significant changes
        IF (OLD.jobname != NEW.jobname) OR
           (OLD.jobdesc != NEW.jobdesc) OR
           (OLD.jobhostagent != NEW.jobhostagent) OR
           (OLD.jobenabled != NEW.jobenabled) OR
           (OLD.jobjclid != NEW.jobjclid) THEN
            significant_change := true;
        END IF;

        -- Don't log changes to jobagentid, joblastrun, jobnextrun as they are internal state changes
        IF significant_change THEN
            PERFORM pgagent.pga_log_job_operation(
                NEW.jobid,
                'MODIFY',
                current_user,
                row_to_json(OLD)::jsonb,
                row_to_json(NEW)::jsonb,
                NULL
            );
        END IF;
        RETURN NULL;
    ELSIF TG_OP = 'DELETE' THEN
        -- Log the deletion after the job is actually deleted
        PERFORM pgagent.pga_log_job_operation(
            OLD.jobid,
            'DELETE',
            current_user,
            row_to_json(OLD)::jsonb,
            NULL,
            'Job deleted by user ' || current_user
        );
        RETURN NULL;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for job table
DROP TRIGGER IF EXISTS pga_job_audit_trigger ON pgagent.pga_job;
CREATE TRIGGER pga_job_audit_trigger
    AFTER INSERT OR UPDATE OR DELETE ON pgagent.pga_job
    FOR EACH ROW
    EXECUTE FUNCTION pgagent.pga_job_audit_trigger();

-- Update schema version
UPDATE pg_extension SET extversion = '4.3' WHERE extname = 'pgagent'; 