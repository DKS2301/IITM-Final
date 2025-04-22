# 📸 Audit Logging Implementation - Proof of Execution
This document contains **screenshots** of SQL query outputs to **demonstrate** the correct working of the **Audit Logging feature**.

-------------------------------------
## **1️⃣ Checking the Audit Log Table (Before Action)
This query retrieves the audit log entries before any job actions have occurred.

```
SELECT * FROM pgagent.pga_job_audit_log;
```
✅ **Expected Output**:
The audit log table should be empty before any actions are performed.

📸 **Screenshot**:
![Log Table before any action ](https://github.com/user-attachments/assets/dc6f2209-e90d-4a75-b50a-2c87431e7e57)


## **2️⃣ Performing Job Actions
Perform job actions like creating, modifying, or deleting a job. For example, create a new job.


```
SELECT * FROM pgagent.pga_job_audit_log;
```
✅ **Expected Output**:
An entry should be added to the audit log table with event_type = CREATE.

📸 **Screenshot**:
![Log Table After Creation of a Job A](https://github.com/user-attachments/assets/237d3c60-0ac1-42a2-aa96-2c37d8806c5e)

## **3️⃣ Checking Audit Log for Job Action
Verifying that the correct action is logged after the job creation.

```
SELECT * FROM pgagent.pga_job_audit_log WHERE operation_type = 'CREATE';
```
✅ **Expected Output**:
The log entry should contain the job ID, event type (CREATE), timestamp, and user who performed the action.

📸 **Screenshot**:
 ![Log Table Query by Operation Type](https://github.com/user-attachments/assets/8223a9a2-7d54-4932-847d-efc80abea591)


## **4️⃣ Verifying Job Modification
Modify an existing job.

✅ **Expected Output**:
An entry should be added to the audit log table with event_type = MODIFY.

📸 **Screenshot**:
![image](https://github.com/user-attachments/assets/4aadf420-d1d5-4209-a913-3763171d908c)


## **5️⃣ Verifying Job Deletion
Delete an existing job.


✅ **Expected Output**:
An entry should be added to the audit log table with event_type = DELETE.

📸 **Screenshot**:
![Logging Job Deletion](https://github.com/user-attachments/assets/db01c7af-06b7-4b48-ab84-5f75017cbf98)


## **6️⃣ Verifying Job Execution
Trigger a job execution (e.g., a manual run).


✅ **Expected Output**:
An entry should be added to the audit log table with event_type = EXECUTE.

📸 **Screenshot**:
![Logging Job Execution both the starting and the ending of execution](https://github.com/user-attachments/assets/91bae1bc-0aec-46f8-ab81-66173138c2d8)


📸 **Video Proof of Audit Logging**:



https://github.com/user-attachments/assets/c86c3dd3-56a7-4a7e-945d-d04eca59757f



https://github.com/user-attachments/assets/d5e8f434-22e8-4784-838e-f723cad50ae1



https://github.com/user-attachments/assets/ba72fd7f-6724-4e0b-b95c-4c8fb2a7fed8




https://github.com/user-attachments/assets/ba108b87-6978-4508-ae64-657f8e054c56

## **7️⃣ Verifying UI Changes made to PgAgent Jobs Context Menu
Right Click on PgAgent jobs in PgAdmin UI. This will open up a context menu containing general audit logging as well as filtered audit logging according to the operation type.Click on any of the options.

✅ **Expected Output**:
This should open up the query tool in the PgAdmin UI with the respective query to be executed copied to the clipboard of the user. The user can just paste it (ctrl+v) onto the query tool and execute to get the audit logs.

📸 **Screenshot**:
![added_audit_log_with_filter_as_part_of_pgagent_job_context_menu](https://github.com/user-attachments/assets/6e6cda88-8d3e-47da-b345-414140bfe062)

![query_tool_opens_with_the_respective_query_copied_on_the_device_clipboard](https://github.com/user-attachments/assets/9d912233-fce8-4739-b192-2bf807673b43)

![query_tool_opens_with_the_respective_query_copied_on_the_device_clipboard-2](https://github.com/user-attachments/assets/7d0097a7-7523-444a-ba6d-ce803ad8a373)


📸 **Video Proof of Audit Logging UI**:


## **8️⃣ Verifying UI Changes made to PgAgent Job Properties
Select any job under the PgAgent Jobs section in PgAdmin UI. Select Properties Tab in the Dashboard.

✅ **Expected Output**:
The Audit Logs for the selected job gets displayed in a table like format under the properties tab.

📸 **Screenshot**:
![added_audit_log_for_job_b_in_properties](https://github.com/user-attachments/assets/b5db7168-6f34-4c5a-b295-69fd6e2aa753)

![added_audit_log_for_job_c_in_properties](https://github.com/user-attachments/assets/fa901056-bad4-43d6-99d5-fa060eb829c8)



## **🎯 Conclusion:
The Audit Logging feature is working as expected, accurately logging job actions such as creation, modification, deletion, and execution.
Note: If the figures are not clear, please see the images in the outputs folder inside Audit Logging.
