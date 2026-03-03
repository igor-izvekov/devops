package main

import (
	"log"
	"os"
	"github.com/igor-izvekov/devops/database/pkg/database"
	"github.com/igor-izvekov/devops/database/pkg/handlers"
	"github.com/gin-gonic/gin"
	"github.com/gin-contrib/cors"
)

func run_http_server() {
	database.Connect()

	router := gin.Default()

	router.Use(cors.New(cors.Config{
		AllowOrigins: []string{os.Getenv("ALLOW_ORIGIN")},
		AllowMethods: []string{"GET", "POST", "PUT", "DELETE"},
		AllowHeaders: []string{"Origin", "Content-Type"},
	}))

	api := router.Group("/api")
	{
		api.GET("/books", handlers.GetBooks)
		api.POST("/books", handlers.CreateBook)
		api.PUT("/books/:id/progress", handlers.UpdateProgress)
		api.GET("/stats", handlers.GetStats)
	}

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	log.Println("Server is running at:", port)
	router.Run(":" + port)
}

func main() {
	run_http_server()
}
