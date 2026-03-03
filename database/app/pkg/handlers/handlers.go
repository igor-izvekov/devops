package handlers

import (
	"net/http"
	"strconv"
	"github.com/gin-gonic/gin"
	"github.com/igor-izvekov/devops/database/pkg/database"
)

// GET /books - список книг с фильтрацией
func GetBooks(c *gin.Context) {
	var books []database.Book
	query := database.DB.Preload("Tags")

	// Фильтр по статусу чтения
	if status := c.Query("status"); status != "" {
		query = query.Where("read_status = ?", status)
	}

	// Фильтр по тегу
	if tag := c.Query("tag"); tag != "" {
		query = query.Joins("JOIN book_tags ON book_tags.book_id == books.id").
			Joins("JOIN tags on tags.id = book_tags.tag_id").
			Where("tags.name = ?", tag)
	}

	if search := c.Query("search"); search != "" {
		query = query.Where("title ILIKE ? OR author ILIKE ?", "%"+search+"%", "%"+search+"%")
	}

	query.Find(&books)
	c.JSON(http.StatusOK, books)
}

func CreateBook(c *gin.Context) {
	var input struct {
		database.Book
		Tags []string `json:"tags"`
	}

	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	var tags []database.Tag
	for _, tagName := range input.Tags {
		var tag database.Tag
		result := database.DB.Where("name = ?", tagName).FirstOrCreate(&tag, database.Tag{Name: tagName})
		if result.Error == nil {
			tags = append(tags, tag)
		}
	}

	book := input.Book
	book.Tags = tags

	if result := database.DB.Create(&book); result.Error != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": result.Error.Error()})
		return
	}

	c.JSON(http.StatusCreated, book)
}

func UpdateProgress(c *gin.Context) {
	id, _ := strconv.Atoi(c.Param("id"))
	var book database.Book

	if result := database.DB.First(&book, id); result.Error != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Book not found"})
		return
	}

	var input struct {
		CurrentPage int `json:"current_page"`
		ReadStatus string `json:"read_status"`
	}

	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	updates := map[string]interface{}{}
	if input.CurrentPage > 0 {
		updates["current_page"] = input.CurrentPage
		if input.CurrentPage >= book.Pages {
			updates["read_status"] = "read"
		} else if input.CurrentPage > 0 {
			updates["read_status"] = "reading"
		}
	}
	if input.ReadStatus != "" {
		updates["read_status"] = input.ReadStatus
	}

	database.DB.Model(&book).Updates(updates)
	c.JSON(http.StatusOK, book)
}

func GetStats(c *gin.Context) {
    var stats struct {
        TotalBooks    int64   `json:"total_books"`
        TotalPages    int64   `json:"total_pages"`
        BooksRead     int64   `json:"books_read"`
        BooksReading  int64   `json:"books_reading"`
        AvgRating     float64 `json:"avg_rating"`
        TopTags       []struct {
            Name  string `json:"name"`
            Count int    `json:"count"`
        } `json:"top_tags"`
    }
    
    database.DB.Model(&database.Book{}).Count(&stats.TotalBooks)
    database.DB.Model(&database.Book{}).Where("read_status = ?", "read").Count(&stats.BooksRead)
    database.DB.Model(&database.Book{}).Where("read_status = ?", "reading").Count(&stats.BooksReading)
    database.DB.Model(&database.Book{}).Select("COALESCE(AVG(rating), 0)").Scan(&stats.AvgRating)
    database.DB.Model(&database.Book{}).Select("SUM(pages)").Scan(&stats.TotalPages)
    
    database.DB.Raw(`
        SELECT tags.name, COUNT(*) as count 
        FROM tags 
        JOIN book_tags ON book_tags.tag_id = tags.id 
        GROUP BY tags.id 
        ORDER BY count DESC 
        LIMIT 5
    `).Scan(&stats.TopTags)
    
    c.JSON(http.StatusOK, stats)
}