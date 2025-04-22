# 🚀 Job Dependency Enhancement in pgAgent  

## 📌 Overview  
This enhancement introduces **Job Dependencies** in pgAgent, allowing jobs to execute **only when dependent jobs have completed successfully**.  

Previously, **pgAgent** executed jobs **independently** based on schedules. With this feature:  
- A **child job (Job B)** runs **only if** its **parent job (Job A)** **executes successfully**.  
- Multiple job dependencies can be defined.  
- Jobs without dependencies run as usual.  

---

## 🛠️ Modified Files  

| File | Description | Changes |
|------|------------|---------|
| [`pgagent.sql`](https://github.com/brianchristy/Enhancement-to-pgAgent/blob/main/pgagent/sql/pgagent.sql#L123) | Schema Changes | Modified `pgagent.pga_joblog` table |
| [`pgagent.sql`](https://github.com/brianchristy/Enhancement-to-pgAgent/blob/main/pgagent/sql/pgagent.sql#L148-L155) | Schema Changes | Added `pga_job_dependency` table |
| [`job.h`](https://github.com/brianchristy/Enhancement-to-pgAgent/blob/main/pgagent/include/job.h#L29-L30) | Job Struct Updates | Defined dependency handling functions |
| [`job.cpp`](https://github.com/brianchristy/Enhancement-to-pgAgent/blob/main/pgagent/job.cpp#L487-L499) | Scheduler Logic | Modified job execution order |
| [`job.cpp`](https://github.com/brianchristy/Enhancement-to-pgAgent/blob/main/pgagent/job.cpp#L75-L124) | Dependency Function | Added function for checking dependency and setting Job Status |
| [`pga_job.ui.js`](https://github.com/brianchristy/Enhancement-to-pgAgent/blob/main/pgadmin4/web/pgadmin/browser/server_groups/servers/pgagent/static/js/pga_job.ui.js) | UI Schema | Added dependency collection field |
| [`pga_job_dependency.ui.js`](https://github.com/brianchristy/Enhancement-to-pgAgent/blob/main/pgadmin4/web/pgadmin/browser/server_groups/servers/pgagent/static/js/pga_job_dependency.ui.js) | UI Schema | Added dependency form fields |
| [`update_dependencies.sql`](https://github.com/brianchristy/Enhancement-to-pgAgent/blob/main/pgadmin4/web/pgadmin/browser/server_groups/servers/pgagent/templates/pga_job/sql/pre3.4/update_dependencies.sql) | SQL Template | Added dependency update logic |
| [`jobs.sql`](https://github.com/brianchristy/Enhancement-to-pgAgent/blob/main/pgadmin4/web/pgadmin/browser/server_groups/servers/pgagent/templates/pga_job/sql/pre3.4/jobs.sql) | SQL Template | Modified to filter out existing dependencies |

---

## 🖥️ UI Modifications

### 📌 Dependency Management Interface
- Added a new **Dependencies** tab in job properties
- Implemented dependency collection with add/edit/delete capabilities
- Added validation to prevent duplicate dependencies

### 📌 Features
1. **Dependency Tab**
   - Accessible in job properties view
   - Shows list of current dependencies
   - Allows adding new dependencies
   - Allows removing existing dependencies

2. **Dependency Selection**
   - Dropdown list of available jobs
   - Filters out already selected dependencies
   - Prevents self-dependency
   - Shows job names for better identification

3. **Dependency Management**
   - Real-time updates when adding/removing dependencies
   - Validation to prevent invalid dependencies
   - Proper error handling and user feedback

4. **User Experience**
   - Intuitive interface similar to Schedules and Steps tabs
   - Clear visual feedback for dependency status
   - Easy to understand dependency relationships

---

## ⚙️ Schema Modification  

A new table **`pgagent.pga_job_dependency`** has been added to track dependencies.  

### 📌 Table Definition  
```
CREATE TABLE pgagent.pga_job_dependency (
    jdepid SERIAL PRIMARY KEY,    -- Unique ID for the dependency
    jdparent INTEGER NOT NULL,    -- Parent job (must complete first)
    jdchild INTEGER NOT NULL,     -- Child job (executes after parent)
    CONSTRAINT fk_parent FOREIGN KEY (jdparent) REFERENCES pgagent.pga_job(jobid) ON DELETE CASCADE,
    CONSTRAINT fk_child FOREIGN KEY (jdchild) REFERENCES pgagent.pga_job(jobid) ON DELETE CASCADE
);
```
- **`jdparent`** → The job that must finish first.  
- **`jdchild`** → The job that runs only if `jdparent` succeeds.  
- **Cascading delete** ensures dependencies are removed when a job is deleted.  

An existing table **`pgagent.pga_job_log`** has been modifed to hold the status after failure due to dependency check.  

### 📌 New Table Definition  
```
CREATE TABLE pgagent.pga_joblog (
jlgid                serial               NOT NULL PRIMARY KEY,
jlgjobid             int4                 NOT NULL REFERENCES pgagent.pga_job (jobid) ON DELETE CASCADE ON UPDATE RESTRICT,
jlgstatus            char                 NOT NULL CHECK (jlgstatus IN ('r', 's', 'f', 'i', 'd', 'x')) DEFAULT 'r', -- running, success, failed, internal failure, aborted, dependency not met
jlgstart             timestamptz          NOT NULL DEFAULT current_timestamp,
jlgduration          interval             NULL
) WITHOUT OIDS;
```
- **`x`** → The job has failed because the dependency is not met.  

---

## 🛠️ Testing Job Dependency  

### **1️⃣ Creating Sample Jobs**  

We will create three jobs:  
- **Job A** → The parent job.  
- **Job B** → Runs **after** Job A.  
- **Job C** → Runs **before** Job A (should **fail** due to dependency order).  


### **2️⃣ Creating Job Steps**  

Each job should insert an entry into a **test table** upon execution.  

#### **Create Test Table for Tracking Execution**  
```
CREATE TABLE job_execution_log (
    logid SERIAL PRIMARY KEY,
    jobname TEXT NOT NULL,
    execution_time TIMESTAMP DEFAULT now()
);
```


---

### **3️⃣ Setting Up Job Dependencies**  

We now define dependencies:  
- **Job B depends on Job A** (`Job A` must execute before `Job B`).  
- **Job C depends on Job B** (`Job B` must execute before `Job C`, which should fail).  

```
INSERT INTO pgagent.pga_job_dependency (jdparent, jdchild) VALUES 
(5, 6), -- Job B runs only after Job A
(6, 7); -- Job C runs only after Job B (which depends on A)
```
*(Replace `5`, `6`, and `7` with actual `jobid` values.)*  

---

### **4️⃣ Scheduling Jobs**  

We now schedule jobs such that:  
- **Job C is scheduled first** (`Job C` should not complete its execution before `Job B`).  
- **Job A is scheduled next** (`Job A` must execute since it is independent).  
- **Job B is scheduled last** (`Job B` must execute since it is dependent on `Job A` and `Job A` has successfully completed its execution).  

*(Adjust time as needed.)*  

---

## 🔍 Verifying Execution  

### ✅ Check if Jobs are Scheduled  
```
SELECT jobid, jobname, jobnextrun FROM pgagent.pga_job WHERE jobid IN (5, 6, 7);
```
*(Replace `5`, `6`, and `7` with actual `jobid` values.)*  

- `jobnextrun` should be set based on dependencies.  
- **Job C** should have the earliest execution time.  

### ✅ Verify Dependency Execution  
```
SELECT * FROM job_execution_log ORDER BY execution_time;
```
- **Expected Outcome:**  
  - **Job A** executes first.  
  - **Job B** executes after **Job A** completes.  
  - **Job C** does **not** execute if **Job B** fails.  

### ✅ Verify Dependency Table  
```
SELECT * FROM pgagent.pga_job_dependency;
```
- This should list all defined dependencies.  

---

## 📅 Expected Behavior  

| Job  | Dependency | Execution Status |
|------|-----------|------------------|
| Job A | None | ✅ Runs as scheduled |
| Job B | Job A | ✅ Runs after Job A |
| Job C | Job B | ❌ Does not run (depends on Job B) |

---

## 📝 Conclusion  

This **Job Dependency** feature allows controlled execution of jobs, ensuring they run **only when parent jobs succeed**.  

**Next Steps**:  
- **Improve logging** for job dependency failures.  
- **Implement Role-Based Access Control (RBAC)** in the next enhancement.  

---

📖 **Refer to the [Main README](https://github.com/brianchristy/Enhancement-to-pgAgent/blob/main/README.md) for general setup and instructions.**  

📖 **Refer to the [Proof of execution](https://github.com/brianchristy/Enhancement-to-pgAgent/blob/main/Enhancements/Job_Dependency/proof_of_execution.md) for output verification.**  