package database

import (
	"time"

	"gorm.io/gorm"
)

type Book struct {
	ID uint `json: "id" gorm:"primarykey"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
	DeletedAt gorm.DeletedAt `json:"-" gorm"index"`
	
	Title string `json:"title" gorm:"not null" binding"required"`
	Author string `json:"author" gorm:"not null" binding:"required"`
	ISBN string `json:"isbn" gorm:"uniqueIndex;size:13"`
	Description string `json:"description" gorm:"type:text"`
	Rating float32 `json:"rating" gorm:"default:0"`
	Tags []Tag `json:"tags" gorm:"many2many:book_tags;"`
	ReadStatus string `json:"read_status" gorm:"default:'unread'` //unread, reading, read
	Pages int `json:"pages"`
	CurrentPage int `json:"current_page" gorm:"default:0"`
}

type Tag struct {
	ID uint `json:"id" gorm:"primarykey`
	Name string `json:"name" gorm:"uniqueIndex;not null"`

}