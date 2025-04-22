-- Prevent circular dependencies in pgAgent jobs

BEGIN TRANSACTION;

-- Function to check for circular dependencies
CREATE OR REPLACE FUNCTION pgagent.check_circular_dependency()
RETURNS trigger AS $$
DECLARE
    cycle_exists BOOLEAN;
BEGIN
    -- First check direct self-dependency
    IF NEW.jobid = NEW.dependent_jobid THEN
        RAISE EXCEPTION 'A job cannot depend on itself.';
    END IF;

    WITH RECURSIVE dependency_chain AS (
        -- Base case: direct dependencies
        SELECT d.jobid, d.dependent_jobid, 1 as level
        FROM pgagent.pga_job_dependency d
        WHERE d.jobid = NEW.dependent_jobid
        
        UNION
        
        -- Recursive case: dependencies of dependencies
        SELECT d.jobid, d.dependent_jobid, dc.level + 1
        FROM pgagent.pga_job_dependency d
        JOIN dependency_chain dc ON d.jobid = dc.dependent_jobid
        WHERE dc.level < 100  -- Prevent infinite recursion
    )
    SELECT EXISTS (
        SELECT 1 FROM dependency_chain WHERE dependent_jobid = NEW.jobid
    ) INTO cycle_exists;

    IF cycle_exists THEN
        RAISE EXCEPTION 'Circular dependency detected: This would create a cycle between jobs.';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop existing trigger if it exists
DROP TRIGGER IF EXISTS prevent_circular_dependency ON pgagent.pga_job_dependency;

-- Create trigger to prevent circular dependencies
CREATE TRIGGER prevent_circular_dependency
    BEFORE INSERT OR UPDATE ON pgagent.pga_job_dependency
    FOR EACH ROW
    EXECUTE FUNCTION pgagent.check_circular_dependency();

COMMIT TRANSACTION;
