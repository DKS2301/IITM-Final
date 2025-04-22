<<<<<<< HEAD
# IITM-Final
sample push
=======
# 🚀 pgAgent Enhancement Project

## 📌 Overview
This project is a customized enhancement of **pgAgent**, focused on improving **Job Dependencies** and **Audit Logging**. The modifications are built on top of **pgAdmin's official pgAgent**.

For general setup instructions, **refer to the official [pgAdmin4 README](https://github.com/pgadmin-org/pgadmin4/blob/master/README.md)**.
For window specific instruction, **refer to the official [pgAdmin4 README](https://github.com/pgadmin-org/pgadmin4/blob/master/pkg/win32/README.md)**.

---

## 🔧 Cloning and Setting Up the Project

### **1️⃣ Clone Repositories**
Clone **pgAgent** and **pgAdmin** locally.

```
git clone https://github.com/pgadmin-org/pgagent.git
git clone https://github.com/pgadmin-org/pgadmin4.git
```

Place both repositories in your project folder.

---

### **2️⃣ Install Dependencies**
Ensure you have the following installed:
- **PostgreSQL**
- **pgAdmin4**
- **CMake**
- **Visual Studio (for building pgAgent on Windows)**
- **Git**
- **Python (for pgAdmin UI changes, if needed)**

---

### **3️⃣ Build and Install pgAgent**
1. **Navigate to the pgAgent directory:**
   ```
   cd pgagent
   ```

2. **Create a build directory:**
   ```
   mkdir build
   cd build
   ```

3. **Generate the build files using CMake:**
   ```
   cmake ..
   ```

4. **Compile pgAgent:**
   ```
   cmake --build . --config Debug
   ```

5. **Ensure `pgagent.exe` is successfully created.**

---

### **4️⃣ Configure pgAgent with PostgreSQL**
1. Open **pgAdmin**.
2. Run `pgagent.sql` to create necessary tables:
   ```
   \i your_actual_path_for_project_folder\pgagent\pgagent.sql
   ```

---

### **5️⃣ Running pgAgent**
Start pgAgent using PowerShell:

```
.\pgagent.exe DEBUG -l 2 -t 60 "host=localhost dbname=postgres user=postgres password=yourpassword application_name=pgAgent"
```

Ensure it appears in:

```
SELECT * FROM pg_stat_activity WHERE application_name = 'pgAgent';
```

---

## 📜 Enhancements Implemented
✅ **Job Dependencies** (Completed)  
✅ **Audit Logging** (Completed)  

For detailed information on enhancements, refer to:
- [**Job Dependency Enhancement**](https://github.com/brianchristy/Enhancement-to-pgAgent/tree/main/Enhancements/Job_Dependency)  
- [**Audit Logging**](https://github.com/brianchristy/Enhancement-to-pgAgent/tree/main/Enhancements/Audit_Logging)

---

📌 **Need More Help?** Refer to the official [pgAdmin4 github repo](https://github.com/pgadmin-org/pgadmin4/tree/master). 🚀
>>>>>>> jdal/main
