
✨ **Audit Logging Feature in pgAgent**

---

## 📌 Overview

This enhancement introduces **Audit Logging** in **pgAgent**, enabling tracking of all critical job-related actions such as job creation, modification, deletion, and execution.

Previously, pgAgent lacked an in-depth audit mechanism, making it difficult to track changes in job configurations. With this feature:

- **Every job-related action is logged** for audit purposes.
- **Users can track changes made to jobs over time.**
- **Execution history is recorded**, including timestamps and status.

---

## 🛠️ Modified Files

| File                        | Description                              | Changes Implemented                                     |
| -------------               | -----------------                        | --------------------------------------------            |
| `pgagent.sql`               | Schema Changes                           | Created `pga_job_audit_log` table                       |
| `job.cpp`                   | Execution Logging                        | Added function to log job execution details             |
| `pgagent--4.2--4.3.sql`     | Schema Changes specific to audit logging | Created `pga_job_audit_log` table, function  & triggers |
| `pga_job.js`                | UI Changes to add the audit log and the filtered audit log in job context menu and query tool implementation with copy to clipboard feature |Added job audit log and job audit log(operation) to context menu which when clicked opens the query tool with the respective query copied onto the user's clipboard |
| `__init__.py`     |Added Audit Log tab in the Job Properties | Created Audit Log tab in Job Properties |
| `pga_job.ui.js`     |UI changes for the audit log tab in job properties | Created the UI for audit log tab in Job Properties |
| `pga_audit_log.macros`     | For SQL fetching from the pgagent Schema | Added macros for fetching data from table in pgagent schema |
| `audit_logs.sql`     | For implementing the macro in order to fetch the data from the table | Fetched audit logs from the pgagent audit log table in the pgagent schema|

---

## 🖥️ UI Modifications

### 📌 Audit Logging Interface for a particular job
- Added a new **Audit Log** tab in job properties
- This section shows all the logs related to that particular job

### 📌 Audit Logging Interface for all jobs with filtering
- Added new menus **Job Audit Log(All)**,**Job Audit Log(Create)**,**Job Audit Log(Delete)**,**Job Audit Log(Execute)**,**Job Audit Log(Delete)**  in PgAgent Jobs COntext Menu.
- When any of these options are selected, it opens up the query tool with the particular query for that operation copied onto the user's clipboard. 



### 📌 Features
1. **Audit Logging Tab**
   - Accessible in job properties view
   - Shows list of current audit logs for that particular job including creation, all modifications and executions. 

2. **Audit Log Context Menu**
   - Dropdown list of all job audit logs with option for filtering according to the operation type.
   - This when clicked opens up the query tool with the query copied onto the user's clipboard
   - The user only has to paste it onto the query tool(ctrl+v) and then execute it.
     

3. **User Experience**
   - Intuitive interface similar to other tabs in PgAdmin.
   - Clear visual feedback for all Logs related to the particular job.
   - Easy to view all job audit logs , and also filter them according to the operation type and job.

---

## ⚙️ **Schema Modification**

A new table, `pga_job_audit_log`, has been introduced to store audit logs of job actions.

### 📌 **Table Definition**

```sql
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
```

- `operation_type` → Captures the type of action performed.
- `operation_time` → Stores the timestamp when the action occurred.
- `job_id` → Stores the job on which action is performed.

---

## 🔧 **Functions and Triggers for Automated Logging in case of job creation, modification and deletion**

Triggers are created to **automatically log actions** when jobs are created, modified, or deleted.

```sql
-- Function to log job operations
CREATE OR REPLACE FUNCTION pgagent.pga_log_job_operation(
    p_job_id integer,
    p_operation_type text,
    p_operation_user text,
    p_old_values jsonb,
    p_new_values jsonb,
    p_additional_info text DEFAULT NULL
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
            row_to_json(NEW)::jsonb
        );
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
                row_to_json(NEW)::jsonb
            );
        END IF;
    ELSIF TG_OP = 'DELETE' THEN
        -- Log the deletion before the job is actually deleted
        PERFORM pgagent.pga_log_job_operation(
            OLD.jobid,
            'DELETE',
            current_user,
            row_to_json(OLD)::jsonb,
            NULL,
            'Job deleted by user ' || current_user
        );
        -- Allow the deletion to proceed
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Create triggers for job table
DROP TRIGGER IF EXISTS pga_job_audit_trigger ON pgagent.pga_job;
CREATE TRIGGER pga_job_audit_trigger
    AFTER INSERT OR UPDATE ON pgagent.pga_job
    FOR EACH ROW
    EXECUTE FUNCTION pgagent.pga_job_audit_trigger();

-- Create separate trigger for DELETE operations
DROP TRIGGER IF EXISTS pga_job_audit_delete_trigger ON pgagent.pga_job;
CREATE TRIGGER pga_job_audit_delete_trigger
    BEFORE DELETE ON pgagent.pga_job
    FOR EACH ROW
    EXECUTE FUNCTION pgagent.pga_job_audit_trigger();
```

---

## 🔍 **Verifying Audit Logs**

### ✅ **Check All Logged Events**

```sql
SELECT * FROM pgagent.pga_job_audit_log ORDER BY event_time DESC;
```

### ✅ **Check Logs for a Specific Job**

```sql
SELECT * FROM pgagent.pga_job_audit_log WHERE jobid = <JOB_ID>;
```

(Replace `<JOB_ID>` with the actual job ID.)

### ✅ **Check Logs by Type**

```sql
SELECT * FROM pgagent.pga_job_audit_log WHERE operation_type = 'type';
```

(Replace `'type'` with the actual operation type.)

---

## 📅 **Expected Behavior**

| Action Performed | Expected Log Entry     |
| ---------------- | ---------------------- |
| Job Created      | `event_type = CREATE`  |
| Job Modified     | `event_type = MODIFY`  |
| Job Deleted      | `event_type = DELETE`  |
| Job Executed     | `event_type = EXECUTE` |

---

## 📓 **Conclusion**

This **Audit Logging** feature ensures transparency and security by maintaining a **complete history of job-related changes in pgAgent**.

### **Next Steps:**

- **Enhance UI** to display audit logs in pgAdmin.
  
---

📖 **Refer to the [Main README](https://github.com/brianchristy/Enhancement-to-pgAgent/blob/main/README.md) for general setup and instructions.**  
