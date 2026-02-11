package response

import (
	"github.com/labstack/echo/v4"
	"net/http"
)

type Response struct {
	Code    int         `json:"code"`
	Message string      `json:"message"`
	Data    interface{} `json:"data,omitempty"`
}

func Success(c echo.Context, data interface{}) error {
	return c.JSON(http.StatusOK, Response{
		Code:    0,
		Message: "success",
		Data:    data,
	})
}

func Error(c echo.Context, statusCode int, message string) error {
	return c.JSON(statusCode, Response{
		Code:    statusCode,
		Message: message,
	})
}

func BadRequest(c echo.Context, message string) error {
	return Error(c, http.StatusBadRequest, message)
}

func Unauthorized(c echo.Context, message string) error {
	return Error(c, http.StatusUnauthorized, message)
}

func InternalError(c echo.Context, message string) error {
	return Error(c, http.StatusInternalServerError, message)
}
