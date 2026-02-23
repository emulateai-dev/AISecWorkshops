import sqlite3
import os

DB_NAME = "training_materials/Apex_2025_Payroll.sqlite"

def create_database():
    if os.path.exists(DB_NAME):
        os.remove(DB_NAME)
    
    conn = sqlite3.connect(DB_NAME)
    cursor = conn.cursor()
    
    # Create employees table
    cursor.execute('''
        CREATE TABLE employees (
            id INTEGER PRIMARY KEY,
            name TEXT NOT NULL,
            position TEXT NOT NULL,
            salary INTEGER,
            ssn TEXT
        )
    ''')
    
    # Insert dummy data
    employees = [
        (1, "John Smith", "Software Engineer", 120000, "123-45-6789"),
        (2, "Jane Doe", "Data Scientist", 135000, "987-65-4321"),
        (3, "Robert Johnson", "HR Manager", 95000, "456-78-9012"),
        (4, "Emily Davis", "CEO", 350000, "789-01-2345"),
        (5, "Michael Wilson", "Intern", 45000, "321-09-8765")
    ]
    
    cursor.executemany('INSERT INTO employees VALUES (?,?,?,?,?)', employees)
    
    conn.commit()
    conn.close()
    print(f"Database '{DB_NAME}' created successfully with {len(employees)} records.")

if __name__ == "__main__":
    create_database()
