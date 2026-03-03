package database

import (
    "database/sql"
    "fmt"
    "os"
    "os/exec"
    
    _ "github.com/lib/pq"
    "github.com/golang-migrate/migrate/v4"
    "github.com/golang-migrate/migrate/v4/database/postgres"
    _ "github.com/golang-migrate/migrate/v4/source/file"
)

func RunLiquibaseMigrations() error {
    // Вариант 1: Использование liquibase CLI (нужен установленный liquibase)
    if err := runLiquibaseCLI(); err != nil {
        return err
    }
    
    // Вариант 2: Альтернатива - использование golang-migrate с Liquibase форматом
    return runGoMigrate()
}

func runLiquibaseCLI() error {
    dbURL := os.Getenv("DATABASE_URL")
    
    // Парсим DATABASE_URL для liquibase
    // Пример: postgresql://postgres:postgres@localhost:5432/bookmanager?sslmode=disable
    cmd := exec.Command("liquibase",
        "--url="+dbURL,
        "--changeLogFile=./database/liquibase/changelog/db.changelog-master.xml",
        "--username=postgres",
        "--password=postgres",
        "update")
    
    cmd.Stdout = os.Stdout
    cmd.Stderr = os.Stderr
    
    if err := cmd.Run(); err != nil {
        return fmt.Errorf("liquibase failed: %v", err)
    }
    
    return nil
}

// Альтернатива - использовать DATABASE_LIQUIBASE_PATH для монтирования в Docker
func runGoMigrate() error {
    db, err := sql.Open("postgres", os.Getenv("DATABASE_URL"))
    if err != nil {
        return err
    }
    defer db.Close()
    
    driver, err := postgres.WithInstance(db, &postgres.Config{})
    if err != nil {
        return err
    }
    
    // Конвертируем Liquibase XML в миграции
    // Это упрощенный подход - можно создать миграции в SQL формате
    m, err := migrate.NewWithDatabaseInstance(
        "file://database/migrations", // SQL миграции
        "postgres", driver)
    if err != nil {
        return err
    }
    
    if err := m.Up(); err != nil && err != migrate.ErrNoChange {
        return err
    }
    
    return nil
}